import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/auth/logout_helper.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/notifications/notification_router.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/features/notifications/data/models/app_notification.dart';

class NotificationsInboxPage extends StatefulWidget {
  const NotificationsInboxPage({super.key});

  @override
  State<NotificationsInboxPage> createState() => _NotificationsInboxPageState();
}

class _NotificationsInboxPageState extends State<NotificationsInboxPage> {
  static const int _pageSize = 20;
  static const Duration _maxBackoff = Duration(seconds: 30);

  final _scrollController = ScrollController();
  final List<AppNotification> _items = [];

  bool _loading = true;
  bool _loadingMore = false;
  bool _markingAll = false;
  String? _error;
  bool _forbidden = false;
  int _unreadCount = 0;
  int _currentPage = 0;
  int _lastPage = 1;
  Duration _backoff = const Duration(seconds: 2);
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || _loading || _currentPage >= _lastPage) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 200) {
      _load(reset: false);
    }
  }

  Future<void> _handleUnauthorized() async {
    await LogoutHelper.logout();
    if (!mounted) return;
    context.goNamed(AppRouter.login);
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(_backoff, () {
      if (!mounted) return;
      _load(reset: _items.isEmpty);
    });
    final nextMs = (_backoff.inMilliseconds * 2).clamp(2000, _maxBackoff.inMilliseconds);
    _backoff = Duration(milliseconds: nextMs);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      _retryTimer?.cancel();
      setState(() {
        _loading = _items.isEmpty;
        _error = null;
        _forbidden = false;
      });
    } else {
      if (_loadingMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final page = await getIt<ApiService>().getNotifications(
        page: reset ? 1 : _currentPage + 1,
        perPage: _pageSize,
      );
      if (!mounted) return;
      _backoff = const Duration(seconds: 2);
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(page.items);
        } else {
          _items.addAll(page.items);
        }
        _unreadCount = page.unreadCount;
        _currentPage = page.currentPage;
        _lastPage = page.lastPage;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } on UnauthorizedException {
      await _handleUnauthorized();
    } on ForbiddenException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _forbidden = true;
        _error = 'notifications.forbidden'.tr();
      });
    } on ServerException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (_items.isEmpty) {
          _error = e.message;
        }
      });
      if (_items.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('notifications.temporarily_unavailable'.tr())),
        );
      }
      _scheduleRetry();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (_items.isEmpty) {
          _error = e.toString().replaceFirst('Exception: ', '');
        }
      });
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll || _unreadCount == 0) return;
    setState(() => _markingAll = true);
    try {
      await getIt<ApiService>().markAllNotificationsRead();
      if (!mounted) return;
      setState(() {
        _markingAll = false;
        _unreadCount = 0;
        for (var i = 0; i < _items.length; i++) {
          _items[i] = _items[i].copyWith(isRead: true, readAt: DateTime.now());
        }
      });
    } on UnauthorizedException {
      await _handleUnauthorized();
    } catch (e) {
      if (!mounted) return;
      setState(() => _markingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    if (!notification.isRead) {
      try {
        await getIt<ApiService>().markNotificationRead(notification.id);
        if (!mounted) return;
        setState(() {
          final index = _items.indexWhere((n) => n.id == notification.id);
          if (index >= 0) {
            _items[index] = _items[index].copyWith(
              isRead: true,
              readAt: DateTime.now(),
            );
          }
          if (_unreadCount > 0) _unreadCount -= 1;
        });
      } on UnauthorizedException {
        await _handleUnauthorized();
        return;
      } catch (_) {}
    }

    if (notification.data.isEmpty) return;
    await NotificationRouter().handleData({
      ...notification.data,
      if (notification.type != null) 'type': notification.type,
      if (notification.message != null) 'body': notification.message,
    });
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return DateFormat('HH:mm').format(local);
    }
    return DateFormat('MMM d').format(local);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('notifications.title'.tr()),
        backgroundColor: Colors.deepOrange.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markingAll ? null : _markAllRead,
              child: _markingAll
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'notifications.mark_all_read'.tr(),
                      style: const TextStyle(color: Colors.white),
                    ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(_error!, textAlign: TextAlign.center),
                if (!_forbidden) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _load(reset: true),
                    child: Text('common.retry'.tr()),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
          Center(
            child: Text(
              'notifications.empty'.tr(),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _items.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final item = _items[index];
        return ListTile(
          onTap: () => _openNotification(item),
          leading: CircleAvatar(
            backgroundColor: item.isRead
                ? Colors.grey.shade200
                : Colors.orange.shade100,
            child: Icon(
              item.isRead
                  ? Icons.notifications_none
                  : Icons.notifications,
              color: item.isRead
                  ? Colors.grey.shade600
                  : Colors.deepOrange.shade700,
            ),
          ),
          title: Text(
            item.title?.isNotEmpty == true
                ? item.title!
                : 'notifications.title'.tr(),
            style: TextStyle(
              fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
            ),
          ),
          subtitle: item.message == null || item.message!.isEmpty
              ? null
              : Text(
                  item.message!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: Text(
            _formatTime(item.createdAt),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        );
      },
    );
  }
}
