enum ChatContext { delivery, support }

class ChatConversation {
  const ChatConversation({
    this.id,
    this.deliveryId,
    this.title,
    this.lastMessagePreview,
    this.unreadCount = 0,
    this.updatedAt,
    this.context = ChatContext.delivery,
  });

  final int? id;
  final int? deliveryId;
  final String? title;
  final String? lastMessagePreview;
  final int unreadCount;
  final DateTime? updatedAt;
  final ChatContext context;

  static int? _parseId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static String? _parseTitle(Map<String, dynamic> json) {
    for (final key in ['title', 'name', 'subject']) {
      final value = json[key];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    final other = json['other_party'] ?? json['customer'] ?? json['participant'];
    if (other is Map) {
      final name = other['name'] ?? other['full_name'];
      if (name != null) return name.toString();
    }
    return null;
  }

  static String? _parseLastMessage(Map<String, dynamic> json) {
    final last = json['last_message'] ?? json['latest_message'];
    if (last is Map) {
      for (final key in ['message', 'body', 'content', 'text']) {
        final value = last[key];
        if (value != null) return value.toString();
      }
    }
    for (final key in ['last_message_preview', 'preview', 'last_message_text']) {
      final value = json[key];
      if (value != null) return value.toString();
    }
    return null;
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final deliveryId = _parseId(
      json['delivery_id'] ?? json['package_delivery_id'] ?? json['deliveryId'],
    );

    var unread = json['unread_count'] ?? json['unreadCount'] ?? 0;
    if (unread is! int) unread = int.tryParse(unread.toString()) ?? 0;

    return ChatConversation(
      id: _parseId(json['id'] ?? json['conversation_id']),
      deliveryId: deliveryId,
      title: _parseTitle(json),
      lastMessagePreview: _parseLastMessage(json),
      unreadCount: unread,
      updatedAt: _parseDate(
        json['updated_at'] ?? json['last_message_at'] ?? json['created_at'],
      ),
      context: deliveryId != null ? ChatContext.delivery : ChatContext.support,
    );
  }

  static ChatConversation? fromResponse(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map) {
      return ChatConversation.fromJson(Map<String, dynamic>.from(data));
    }
    final conversation = response['conversation'];
    if (conversation is Map) {
      return ChatConversation.fromJson(Map<String, dynamic>.from(conversation));
    }
    if (response.containsKey('id') || response.containsKey('conversation_id')) {
      return ChatConversation.fromJson(response);
    }
    return null;
  }

  static List<ChatConversation> listFromResponse(dynamic response) {
    List<dynamic> raw = [];
    if (response is List) {
      raw = response;
    } else if (response is Map) {
      for (final key in ['data', 'conversations']) {
        final value = response[key];
        if (value is List) {
          raw = value;
          break;
        }
      }
    }
    return raw
        .whereType<Map>()
        .map((e) => ChatConversation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static int? conversationIdFromResponse(Map<String, dynamic> response) {
    final conversation = fromResponse(response);
    if (conversation?.id != null) return conversation!.id;
    return ChatConversation._parseId(
      response['conversation_id'] ?? response['id'],
    );
  }
}
