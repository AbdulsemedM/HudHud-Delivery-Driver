import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/services/client_error_reporter.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';

void main() {
  group('ClientErrorReporter.buildReport', () {
    test('matches the /api/client-errors shape', () {
      final report = ClientErrorReporter.buildReport(
        error: StateError('boom'),
        stack: StackTrace.fromString('#0 main (file.dart:1:1)'),
        fatal: true,
        occurredAt: DateTime.utc(2026, 11, 5, 9, 30),
        platform: 'android',
        osVersion: 'Android 14',
        device: const {
          'app_version': '1.0.1',
          'build_number': '19',
          'device_model': 'samsung SM-A155F',
          'device_id': 'abc123',
        },
        context: const {
          'screen': '/delivery/:id/chat',
          'route': '/delivery/12/chat',
          'locale': 'en',
          'empty': null,
        },
      );

      expect(report['app'], 'driver');
      expect(report['app_version'], '1.0.1');
      expect(report['build_number'], '19');
      expect(report['platform'], 'android');
      expect(report['os_version'], 'Android 14');
      expect(report['device_model'], 'samsung SM-A155F');
      expect(report['error_type'], 'StateError');
      expect(report['message'], contains('boom'));
      expect(report['stack'], contains('file.dart'));
      expect(report['fatal'], isTrue);
      expect(report['occurred_at'], '2026-11-05T09:30:00.000Z');
      expect(report['device_id'], 'abc123');
      expect(report['context'], {
        'screen': '/delivery/:id/chat',
        'route': '/delivery/12/chat',
        'locale': 'en',
      });
    });

    test('omits device_model/device_id when unknown and truncates', () {
      final report = ClientErrorReporter.buildReport(
        error: Exception('x' * 5000),
        stack: null,
        fatal: false,
        occurredAt: DateTime.utc(2026),
        platform: 'ios',
        osVersion: '17.5',
      );
      expect(report.containsKey('device_model'), isFalse);
      expect(report.containsKey('device_id'), isFalse);
      expect(report['app_version'], ClientErrorReporter.unknownVersion);
      expect(
        (report['message'] as String).length,
        ClientErrorReporter.maxMessageLength,
      );
      expect(report['stack'], '');
      expect(report['fatal'], isFalse);
    });

    test('uses AppException.message', () {
      final report = ClientErrorReporter.buildReport(
        error: ServerException('Server error'),
        stack: null,
        fatal: false,
        occurredAt: DateTime.utc(2026),
        platform: 'android',
        osVersion: '14',
      );
      expect(report['message'], 'Server error');
      expect(report['error_type'], 'ServerException');
    });
  });

  test('screenFromRoute replaces numeric segments', () {
    expect(
      ClientErrorReporter.screenFromRoute('/delivery/123/chat'),
      '/delivery/:id/chat',
    );
    expect(ClientErrorReporter.screenFromRoute('/wallet'), '/wallet');
  });

  group('queue, batching, retry and rate limit', () {
    late List<Map<String, dynamic>> sent;
    late DateTime now;

    ClientErrorReporter build({
      Future<void> Function(Map<String, dynamic> body)? sender,
      bool enabled = true,
    }) {
      return ClientErrorReporter(
        sender: sender ??
            (body) async {
              sent.add(body);
            },
        clock: () => now,
        enabled: enabled,
        platformSupported: true,
        autoFlush: false,
      );
    }

    setUp(() {
      sent = [];
      now = DateTime.utc(2026, 11, 5, 10);
    });

    test('single report is sent unwrapped, many as {reports: [...]}', () async {
      final reporter = build();
      reporter.record(StateError('one'), null);
      await reporter.flush();
      expect(sent.single['error_type'], 'StateError');
      expect(sent.single.containsKey('reports'), isFalse);

      reporter.record(StateError('a'), null);
      reporter.record(StateError('b'), null);
      await reporter.flush();
      expect(sent.last['reports'], hasLength(2));
      expect(reporter.pendingReports, isEmpty);
    });

    test('batches at most 20 per request', () async {
      final reporter = build();
      for (var i = 0; i < 20; i++) {
        now = now.add(const Duration(seconds: 4));
        reporter.record(StateError('e$i'), null);
      }
      await reporter.flush();
      expect(sent.single['reports'], hasLength(20));
    });

    test('rate limits to 20 reports per minute', () async {
      final reporter = build();
      for (var i = 0; i < 30; i++) {
        reporter.record(StateError('e$i'), null);
      }
      expect(reporter.pendingReports, hasLength(20));

      now = now.add(const Duration(minutes: 1));
      reporter.record(StateError('later'), null);
      expect(reporter.pendingReports, hasLength(21));
    });

    test('retries transient failures 3 times then drops the batch', () async {
      var calls = 0;
      final reporter = build(sender: (body) async {
        calls++;
        throw NetworkException('No Internet connection');
      });
      reporter.record(StateError('x'), null);
      await reporter.flush();
      await reporter.flush();
      expect(reporter.pendingReports, hasLength(1));
      await reporter.flush();
      expect(calls, ClientErrorReporter.maxSendAttempts);
      expect(reporter.pendingReports, isEmpty);
    });

    test('drops immediately on a 422', () async {
      final reporter = build(sender: (body) async {
        throw BadRequestException('Invalid', code: '422');
      });
      reporter.record(StateError('x'), null);
      await reporter.flush();
      expect(reporter.pendingReports, isEmpty);
    });

    test('stops reporting when the endpoint is missing (404)', () async {
      var calls = 0;
      final reporter = build(sender: (body) async {
        calls++;
        throw NotFoundException('Not found');
      });
      reporter.record(StateError('x'), null);
      await reporter.flush();
      reporter.record(StateError('y'), null);
      await reporter.flush();
      expect(calls, 1);
      expect(reporter.pendingReports, isEmpty);
    });

    test('a throwing sender never escapes flush', () async {
      final reporter = build(sender: (body) async {
        throw StateError('sender bug');
      });
      reporter.record(StateError('x'), null);
      await expectLater(reporter.flush(), completes);
    });

    test('disabled reporter (debug default) records nothing', () async {
      final reporter = build(enabled: false);
      reporter.record(StateError('x'), null);
      await reporter.flush();
      expect(reporter.pendingReports, isEmpty);
      expect(sent, isEmpty);
    });
  });

  test('isPermanentFailure', () {
    expect(
      ClientErrorReporter.isPermanentFailure(BadRequestException('x')),
      isTrue,
    );
    expect(
      ClientErrorReporter.isPermanentFailure(ApiException('x', code: '413')),
      isTrue,
    );
    expect(
      ClientErrorReporter.isPermanentFailure(TooManyRequestsException('x')),
      isFalse,
    );
    expect(
      ClientErrorReporter.isPermanentFailure(ServerException('x')),
      isFalse,
    );
    expect(
      ClientErrorReporter.isPermanentFailure(NetworkException('x')),
      isFalse,
    );
  });
}
