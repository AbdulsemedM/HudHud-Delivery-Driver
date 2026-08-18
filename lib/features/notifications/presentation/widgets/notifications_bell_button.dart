import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';

class NotificationsBellButton extends StatefulWidget {
  const NotificationsBellButton({
    super.key,
    this.padding = EdgeInsets.zero,
    this.constraints = const BoxConstraints(minWidth: 36, minHeight: 36),
  });

  final EdgeInsetsGeometry padding;
  final BoxConstraints constraints;

  @override
  State<NotificationsBellButton> createState() =>
      _NotificationsBellButtonState();
}

class _NotificationsBellButtonState extends State<NotificationsBellButton>
    with WidgetsBindingObserver {
  static const Duration _pollInterval = Duration(seconds: 45);
  static const Duration _maxBackoff = Duration(seconds: 30);

  int _unreadCount = 0;
  Timer? _pollTimer;
  bool _isForeground = true;
  Duration _backoff = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isForeground = true;
      _startPolling();
      _refresh();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _isForeground = false;
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    if (!_isForeground) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (_backoff > Duration.zero) return;
      _refresh();
    });
  }

  Future<void> _refresh() async {
    try {
      final page = await getIt<ApiService>().getNotifications(
        page: 1,
        perPage: 1,
      );
      _backoff = Duration.zero;
      if (!mounted) return;
      setState(() => _unreadCount = page.unreadCount);
    } on ServerException {
      _scheduleBackoff();
    } catch (_) {}
  }

  void _scheduleBackoff() {
    if (_backoff == Duration.zero) {
      _backoff = const Duration(seconds: 2);
    } else {
      final next = (_backoff.inMilliseconds * 2)
          .clamp(2000, _maxBackoff.inMilliseconds);
      _backoff = Duration(milliseconds: next);
    }
    _pollTimer?.cancel();
    _pollTimer = Timer(_backoff, () {
      if (!mounted || !_isForeground) return;
      _refresh();
      _startPolling();
    });
  }

  Future<void> _openInbox() async {
    await context.pushNamed(AppRouter.notifications);
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: _openInbox,
          padding: widget.padding,
          constraints: widget.constraints,
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _unreadCount > 99 ? '99+' : '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
