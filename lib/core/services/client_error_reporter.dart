import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hudhud_delivery_driver/core/config/api_config.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/device_utils.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Returns `{route: '/current/path'}` (and optionally `screen`, `locale`).
typedef ClientErrorContextProvider = Map<String, String?> Function();

/// Sends one request body to `POST /api/client-errors`. Throws on failure.
typedef ClientErrorSender = Future<void> Function(Map<String, dynamic> body);

/// Reports uncaught Flutter/platform errors to our backend
/// (`POST /api/client-errors`), replacing a third-party crash SDK.
///
/// Guarantees: [record] is synchronous and never throws; sending happens on a
/// timer in small batches (≤ [maxBatchSize]); a batch is retried at most
/// [maxSendAttempts] times and then dropped; at most [maxReportsPerMinute]
/// reports are accepted per minute; nothing is reported in debug builds
/// unless built with `--dart-define=REPORT_CLIENT_ERRORS_IN_DEBUG=true`.
class ClientErrorReporter {
  ClientErrorReporter({
    ClientErrorSender? sender,
    DateTime Function()? clock,
    bool? enabled,
    bool? platformSupported,
    bool autoFlush = true,
    Duration flushDelay = const Duration(seconds: 5),
  })  : _sender = sender,
        _clock = clock ?? DateTime.now,
        _enabled = enabled ?? (!kDebugMode || reportInDebug),
        _platformSupportedOverride = platformSupported,
        _autoFlush = autoFlush,
        _flushDelay = flushDelay;

  /// App-wide instance used by `main.dart`.
  static final ClientErrorReporter instance = ClientErrorReporter();

  static const bool reportInDebug =
      bool.fromEnvironment('REPORT_CLIENT_ERRORS_IN_DEBUG');

  static const String appName = 'driver';
  static const int maxBatchSize = 20;
  static const int maxQueueSize = 50;
  static const int maxReportsPerMinute = 20;
  static const int maxSendAttempts = 3;
  static const int maxMessageLength = 2000;
  static const int maxStackLength = 12000;

  /// Used only if package_info_plus cannot read the installed version.
  static const String unknownVersion = 'unknown';

  ClientErrorSender? _sender;
  ClientErrorContextProvider? _contextProvider;
  final DateTime Function() _clock;
  final bool _enabled;
  final bool? _platformSupportedOverride;
  final bool _autoFlush;
  final Duration _flushDelay;

  final List<Map<String, dynamic>> _queue = [];
  final List<DateTime> _acceptedAt = [];
  Map<String, String> _device = const {};
  String? _locale;
  Timer? _timer;
  bool _flushing = false;
  int _failedAttempts = 0;
  bool _endpointMissing = false;

  bool get enabled => _enabled;

  @visibleForTesting
  List<Map<String, dynamic>> get pendingReports => List.unmodifiable(_queue);

  bool get _platformSupported {
    final override = _platformSupportedOverride;
    if (override != null) return override;
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Connects the reporter to the app's API client (auth token is attached by
  /// [ApiService] when the driver is logged in). Safe to call once after DI.
  void attach({
    required ApiService api,
    ClientErrorContextProvider? contextProvider,
  }) {
    _sender ??= (body) async {
      try {
        await api.post(
          ApiConfig.clientErrorsEndpoint,
          body: body,
          // A stale token must not log the driver out from a crash report.
          requiresAuth: false,
          logTraffic: false,
          timeout: const Duration(seconds: 15),
        );
      } on ApiException catch (e) {
        // ApiService only treats 200/201/202 as success.
        if (e.code == '204') return;
        rethrow;
      }
    };
    _contextProvider = contextProvider;
    if (_enabled && _platformSupported) unawaited(_loadDeviceInfo());
    if (_queue.isNotEmpty) _scheduleFlush();
  }

  /// Latest app locale (e.g. `en`, `ar`), set from `MyApp.build`.
  void updateLocale(String? locale) {
    if (locale != null && locale.isNotEmpty) _locale = locale;
  }

  /// Hooks [FlutterError.onError] and [ui.PlatformDispatcher.onError],
  /// keeping any previously installed handlers.
  void installGlobalHandlers() {
    final previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (previousFlutterHandler != null) {
        previousFlutterHandler(details);
      } else {
        FlutterError.presentError(details);
      }
      recordFlutterError(details);
    };

    final dispatcher = ui.PlatformDispatcher.instance;
    final previousPlatformHandler = dispatcher.onError;
    dispatcher.onError = (Object error, StackTrace stack) {
      record(error, stack, fatal: true);
      if (previousPlatformHandler != null) {
        return previousPlatformHandler(error, stack);
      }
      if (kDebugMode) debugPrint('Uncaught error: $error\n$stack');
      return true;
    };
  }

  void recordFlutterError(FlutterErrorDetails details) {
    // Silent errors are framework noise (e.g. image load failures).
    if (details.silent) return;
    record(details.exception, details.stack, fatal: false);
  }

  /// Queues a report. Never throws and never blocks.
  void record(Object error, StackTrace? stack, {bool fatal = false}) {
    try {
      if (!_enabled || _endpointMissing || !_platformSupported) return;
      final now = _clock();
      _acceptedAt.removeWhere(
        (t) => now.difference(t) >= const Duration(minutes: 1),
      );
      if (_acceptedAt.length >= maxReportsPerMinute) return;
      _acceptedAt.add(now);

      _queue.add(buildReport(
        error: error,
        stack: stack,
        fatal: fatal,
        occurredAt: now,
        platform: _platformName(),
        osVersion: _osVersion(),
        device: _device,
        context: _currentContext(),
      ));
      if (_queue.length > maxQueueSize) {
        _queue.removeRange(0, _queue.length - maxQueueSize);
      }
      _scheduleFlush(immediate: fatal);
    } catch (_) {
      // Reporting must never cause another error.
    }
  }

  /// Sends up to [maxBatchSize] queued reports. Never throws.
  Future<void> flush() async {
    if (_flushing || _queue.isEmpty) return;
    final sender = _sender;
    if (sender == null) return;
    _flushing = true;
    _timer?.cancel();
    _timer = null;
    final batch = _queue.take(maxBatchSize).toList();
    try {
      for (final report in batch) {
        _fillDeviceFields(report);
      }
      final body = batch.length == 1
          ? batch.first
          : <String, dynamic>{'reports': batch};
      await sender(body);
      _removeBatch(batch);
      _failedAttempts = 0;
    } catch (e) {
      if (e is NotFoundException) {
        // Endpoint not deployed: stop reporting for this session.
        _endpointMissing = true;
        _queue.clear();
        _failedAttempts = 0;
      } else if (isPermanentFailure(e) ||
          ++_failedAttempts >= maxSendAttempts) {
        _removeBatch(batch);
        _failedAttempts = 0;
      }
    } finally {
      _flushing = false;
    }
    if (_queue.isNotEmpty) _scheduleFlush();
  }

  /// 4xx responses (except 408/429) will not succeed on retry.
  @visibleForTesting
  static bool isPermanentFailure(Object error) {
    if (error is TooManyRequestsException) return false;
    if (error is BadRequestException ||
        error is UnauthorizedException ||
        error is ForbiddenException ||
        error is NotFoundException ||
        error is ConflictException ||
        error is GoneException ||
        error is LockedException) {
      return true;
    }
    if (error is ApiException) {
      final status = int.tryParse(error.code ?? '');
      return status != null &&
          status >= 400 &&
          status < 500 &&
          status != 408 &&
          status != 429;
    }
    return false;
  }

  /// One report in the `POST /api/client-errors` shape.
  @visibleForTesting
  static Map<String, dynamic> buildReport({
    required Object error,
    required StackTrace? stack,
    required bool fatal,
    required DateTime occurredAt,
    required String platform,
    required String osVersion,
    Map<String, String> device = const {},
    Map<String, String?> context = const {},
  }) {
    final cleanContext = <String, String>{};
    context.forEach((key, value) {
      if (value != null && value.isNotEmpty) cleanContext[key] = value;
    });
    final stackText = stack?.toString() ?? '';
    final deviceModel = device['device_model'];
    final deviceId = device['device_id'];
    return <String, dynamic>{
      'app': appName,
      'app_version': device['app_version'] ?? unknownVersion,
      'build_number': device['build_number'] ?? unknownVersion,
      'platform': platform,
      'os_version': osVersion,
      if (deviceModel != null && deviceModel.isNotEmpty)
        'device_model': deviceModel,
      'error_type': error.runtimeType.toString(),
      'message': _truncate(_messageOf(error), maxMessageLength),
      'stack': _truncate(stackText, maxStackLength),
      'fatal': fatal,
      'context': cleanContext,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
    };
  }

  /// `/delivery/123/chat` -> `/delivery/:id/chat` (stable screen key).
  @visibleForTesting
  static String screenFromRoute(String route) {
    return route
        .split('/')
        .map((segment) => RegExp(r'^\d+$').hasMatch(segment) ? ':id' : segment)
        .join('/');
  }

  static String _messageOf(Object error) {
    if (error is AppException) return error.message;
    try {
      return error.toString();
    } catch (_) {
      return error.runtimeType.toString();
    }
  }

  static String _truncate(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);

  String _platformName() {
    try {
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
      return Platform.operatingSystem;
    } catch (_) {
      return 'unknown';
    }
  }

  String _osVersion() {
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return 'unknown';
    }
  }

  Map<String, String?> _currentContext() {
    String? route;
    String? screen;
    String? locale;
    try {
      final provided = _contextProvider?.call();
      route = provided?['route'];
      screen = provided?['screen'];
      locale = provided?['locale'];
    } catch (_) {}
    if (screen == null && route != null) screen = screenFromRoute(route);
    locale ??= _locale;
    if (locale == null) {
      try {
        locale = ui.PlatformDispatcher.instance.locale.toLanguageTag();
      } catch (_) {}
    }
    return {'screen': screen, 'route': route, 'locale': locale};
  }

  void _fillDeviceFields(Map<String, dynamic> report) {
    final device = _device;
    if (device.isEmpty) return;
    if (report['app_version'] == unknownVersion &&
        device['app_version'] != null) {
      report['app_version'] = device['app_version'];
    }
    if (report['build_number'] == unknownVersion &&
        device['build_number'] != null) {
      report['build_number'] = device['build_number'];
    }
    for (final key in const ['device_model', 'device_id']) {
      final value = device[key];
      if (value != null && value.isNotEmpty) report.putIfAbsent(key, () => value);
    }
  }

  Future<void> _loadDeviceInfo() async {
    final info = <String, String>{};
    try {
      final package = await PackageInfo.fromPlatform();
      if (package.version.isNotEmpty) info['app_version'] = package.version;
      if (package.buildNumber.isNotEmpty) {
        info['build_number'] = package.buildNumber;
      }
    } catch (_) {}
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await plugin.androidInfo;
        info['device_model'] = '${android.manufacturer} ${android.model}'.trim();
      } else if (Platform.isIOS) {
        final ios = await plugin.iosInfo;
        // e.g. iPhone14,2. toString() is safe whether or not it is nullable.
        final machine = ios.utsname.machine.toString().trim();
        if (machine.isNotEmpty && machine != 'null') {
          info['device_model'] = machine;
        }
      }
    } catch (_) {}
    try {
      // Same identifier the app already sends as device_id at login.
      final deviceId = await DeviceUtils.getDeviceId();
      if (deviceId != null && deviceId.isNotEmpty) info['device_id'] = deviceId;
    } catch (_) {}
    _device = Map.unmodifiable(info);
  }

  void _removeBatch(List<Map<String, dynamic>> batch) {
    _queue.removeWhere((report) => batch.any((sent) => identical(sent, report)));
  }

  void _scheduleFlush({bool immediate = false}) {
    if (!_autoFlush || _sender == null) return;
    if (_timer != null && !immediate) return;
    _timer?.cancel();
    final backoff = _flushDelay * (1 << _failedAttempts);
    _timer = Timer(immediate ? Duration.zero : backoff, () {
      _timer = null;
      unawaited(flush());
    });
  }
}
