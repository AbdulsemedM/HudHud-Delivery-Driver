import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/features/chat/data/models/chat_conversation_model.dart';
import 'package:hudhud_delivery_driver/features/chat/data/models/chat_message_model.dart';
import 'package:hudhud_delivery_driver/features/chat/presentation/widgets/chat_composer.dart';
import 'package:hudhud_delivery_driver/features/chat/presentation/widgets/message_bubble.dart';

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.chatContext,
    this.deliveryId,
    this.conversationId,
    this.title,
  });

  final ChatContext chatContext;
  final int? deliveryId;
  final int? conversationId;
  final String? title;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen>
    with WidgetsBindingObserver {
  static const Duration _pollInterval = Duration(seconds: 4);

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  int? _conversationId;
  int? _currentUserId;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _pollTimer;
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _conversationId = widget.conversationId;
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isForeground = true;
      _startPolling();
      _refreshMessages(silent: true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _isForeground = false;
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = getIt<ApiService>();
      final profile = await api.getDriverProfile();
      if (profile != null) {
        final user = profile['user'];
        if (user is Map) {
          final id = user['id'];
          if (id is int) {
            _currentUserId = id;
          } else {
            _currentUserId = int.tryParse(id?.toString() ?? '');
          }
        }
      }

      if (widget.chatContext == ChatContext.delivery) {
        if (widget.deliveryId == null) {
          throw Exception('Delivery ID is required');
        }
        final res = await api.getOrCreateDeliveryConversation(widget.deliveryId!);
        _conversationId ??= ChatConversation.conversationIdFromResponse(res);
        await api.markDeliveryConversationRead(widget.deliveryId!);
        _mergeMessages(ChatMessage.listFromResponse(
          res,
          currentUserId: _currentUserId,
        ));
      } else {
        if (_conversationId == null) {
          final res = await api.openSupportConversation();
          _conversationId = ChatConversation.conversationIdFromResponse(res);
        }
        if (_conversationId != null) {
          await api.markConversationRead(_conversationId!);
          final res = await api.getConversation(_conversationId!);
          _mergeMessages(ChatMessage.listFromResponse(
            res,
            currentUserId: _currentUserId,
          ));
        }
      }

      if (mounted) {
        setState(() => _loading = false);
        _scrollToBottom();
        _startPolling();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    if (!_isForeground) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      _refreshMessages(silent: true);
    });
  }

  Future<void> _refreshMessages({bool silent = false}) async {
    if (_conversationId == null && widget.deliveryId == null) return;

    try {
      final api = getIt<ApiService>();
      Map<String, dynamic> res;

      if (widget.chatContext == ChatContext.delivery && widget.deliveryId != null) {
        res = await api.getOrCreateDeliveryConversation(widget.deliveryId!);
        _conversationId ??= ChatConversation.conversationIdFromResponse(res);
      } else if (_conversationId != null) {
        res = await api.getConversation(_conversationId!);
      } else {
        return;
      }

      final incoming = ChatMessage.listFromResponse(
        res,
        currentUserId: _currentUserId,
      );
      if (!mounted) return;

      final hadNew = _mergeMessages(incoming);
      if (hadNew) {
        await _markRead();
        _scrollToBottom();
      } else if (!silent) {
        setState(() {});
      }
    } catch (_) {
      // Polling failures are silent.
    }
  }

  bool _mergeMessages(List<ChatMessage> incoming) {
    incoming.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });

    final pending = _messages.where((m) => m.isPending).toList();
    final previous = _messages.where((m) => !m.isPending).toList();

    var changed = incoming.length != previous.length;
    if (!changed) {
      for (var i = 0; i < incoming.length; i++) {
        if (incoming[i].id != previous[i].id ||
            incoming[i].text != previous[i].text) {
          changed = true;
          break;
        }
      }
    }

    _messages = [...incoming, ...pending];
    if (changed && mounted) setState(() {});
    return changed;
  }

  Future<void> _markRead() async {
    try {
      final api = getIt<ApiService>();
      if (widget.chatContext == ChatContext.delivery && widget.deliveryId != null) {
        await api.markDeliveryConversationRead(widget.deliveryId!);
      } else if (_conversationId != null) {
        await api.markConversationRead(_conversationId!);
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    final pending = ChatMessage(
      id: null,
      text: text,
      isMine: true,
      isPending: true,
      createdAt: DateTime.now(),
    );

    setState(() {
      _sending = true;
      _messages = [..._messages, pending];
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final api = getIt<ApiService>();
      Map<String, dynamic> res;

      if (widget.chatContext == ChatContext.delivery && widget.deliveryId != null) {
        res = await api.sendDeliveryMessage(widget.deliveryId!, text);
      } else if (_conversationId != null) {
        res = await api.sendConversationMessage(_conversationId!, text);
      } else {
        throw Exception('Conversation not ready');
      }

      final sentMessages = ChatMessage.listFromResponse(
        res,
        currentUserId: _currentUserId,
      );
      ChatMessage? sent;
      if (sentMessages.isNotEmpty) {
        sent = sentMessages.last;
      } else {
        sent = ChatMessage.fromJson(
          res,
          currentUserId: _currentUserId,
        );
        if (sent.text.isEmpty) {
          sent = pending.copyWith(isPending: false, createdAt: DateTime.now());
        }
      }

      if (mounted) {
        setState(() {
          _messages = [
            ..._messages.where((m) => !m.isPending),
            sent!,
          ];
          _sending = false;
        });
      }
      _scrollToBottom();
      await _refreshMessages(silent: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages = _messages.where((m) => !m.isPending).toList();
          _sending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('chat.failed_send'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  String get _screenTitle {
    if (widget.title != null && widget.title!.isNotEmpty) {
      return widget.title!;
    }
    if (widget.chatContext == ChatContext.support) {
      return 'chat.support'.tr();
    }
    return 'chat.chat_with_customer'.tr();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitle),
        backgroundColor: Colors.deepOrange.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? Center(child: Text('chat.loading'.tr()))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _bootstrap,
                              child: Text('common.retry'.tr()),
                            ),
                          ],
                        ),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Text(
                              'chat.type_message'.tr(),
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: MessageBubble(message: _messages[index]),
                              );
                            },
                          ),
          ),
          ChatComposer(
            controller: _messageController,
            onSend: _sendMessage,
            sending: _sending,
          ),
        ],
      ),
    );
  }
}
