import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/features/chat/data/models/chat_conversation_model.dart';

class DeliveryConversationsScreen extends StatefulWidget {
  const DeliveryConversationsScreen({super.key});

  @override
  State<DeliveryConversationsScreen> createState() =>
      _DeliveryConversationsScreenState();
}

class _DeliveryConversationsScreenState extends State<DeliveryConversationsScreen>
    with WidgetsBindingObserver {
  static const Duration _pollInterval = Duration(seconds: 20);

  bool _loading = true;
  List<ChatConversation> _conversations = [];
  Timer? _pollTimer;
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConversations();
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
      _loadConversations(silent: true);
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
      _loadConversations(silent: true);
    });
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final api = getIt<ApiService>();
      final list = await api.getDeliveryConversations();
      if (!mounted) return;
      setState(() {
        _conversations = ChatConversation.listFromResponse(list);
        _loading = false;
      });
    } catch (_) {
      if (mounted && !silent) {
        setState(() {
          _conversations = [];
          _loading = false;
        });
      }
    }
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final local = date.toLocal();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return DateFormat('HH:mm').format(local);
    }
    return DateFormat('MMM d').format(local);
  }

  void _openConversation(ChatConversation conversation) {
    if (conversation.deliveryId != null) {
      context.pushNamed(
        AppRouter.deliveryChat,
        pathParameters: {'deliveryId': conversation.deliveryId.toString()},
        extra: {
          'conversationId': conversation.id,
          'title': conversation.title,
        },
      );
    } else if (conversation.id != null) {
      context.pushNamed(
        AppRouter.supportChat,
        extra: {'conversationId': conversation.id},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('chat.messages'.tr()),
        backgroundColor: Colors.deepOrange.shade700,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadConversations(),
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _conversations.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
                      Center(
                        child: Text(
                          'chat.no_conversations'.tr(),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final conversation = _conversations[index];
                      final title = conversation.title ??
                          (conversation.deliveryId != null
                              ? 'Delivery #${conversation.deliveryId}'
                              : 'chat.messages'.tr());

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          child: Icon(
                            Icons.local_shipping,
                            color: Colors.deepOrange.shade700,
                          ),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: conversation.lastMessagePreview != null
                            ? Text(
                                conversation.lastMessagePreview!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatTime(conversation.updatedAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (conversation.unreadCount > 0) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange.shade600,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  conversation.unreadCount > 99
                                      ? '99+'
                                      : conversation.unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        onTap: () => _openConversation(conversation),
                      );
                    },
                  ),
      ),
    );
  }
}
