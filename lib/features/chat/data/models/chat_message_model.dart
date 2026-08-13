class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    this.type = 'text',
    this.createdAt,
    this.senderId,
    this.senderName,
    this.isMine = false,
    this.isPending = false,
  });

  final int? id;
  final String text;
  final String type;
  final DateTime? createdAt;
  final int? senderId;
  final String? senderName;
  final bool isMine;
  final bool isPending;

  ChatMessage copyWith({
    int? id,
    String? text,
    String? type,
    DateTime? createdAt,
    int? senderId,
    String? senderName,
    bool? isMine,
    bool? isPending,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      isMine: isMine ?? this.isMine,
      isPending: isPending ?? this.isPending,
    );
  }

  static int? _parseId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static String _parseText(Map<String, dynamic> json) {
    for (final key in ['message', 'body', 'content', 'text']) {
      final value = json[key];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  static int? _parseSenderId(Map<String, dynamic> json) {
    for (final key in ['user_id', 'sender_id']) {
      final value = json[key];
      final id = _parseId(value);
      if (id != null) return id;
    }
    final sender = json['sender'] ?? json['user'];
    if (sender is Map) {
      return _parseId(sender['id']);
    }
    return null;
  }

  static String? _parseSenderName(Map<String, dynamic> json) {
    final sender = json['sender'] ?? json['user'];
    if (sender is Map) {
      final name = sender['name'] ?? sender['full_name'];
      if (name != null) return name.toString();
    }
    for (final key in ['sender_name', 'user_name']) {
      final value = json[key];
      if (value != null) return value.toString();
    }
    return null;
  }

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    int? currentUserId,
  }) {
    final senderId = _parseSenderId(json);
    final explicitMine = json['is_mine'] ?? json['isMine'];
    var isMine = explicitMine == true;
    if (!isMine && currentUserId != null && senderId != null) {
      isMine = senderId == currentUserId;
    }

    return ChatMessage(
      id: _parseId(json['id']),
      text: _parseText(json),
      type: json['type']?.toString() ?? 'text',
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
      senderId: senderId,
      senderName: _parseSenderName(json),
      isMine: isMine,
      isPending: json['is_pending'] == true,
    );
  }

  static List<ChatMessage> listFromResponse(
    dynamic response, {
    int? currentUserId,
  }) {
    List<dynamic> raw = [];
    if (response is List) {
      raw = response;
    } else if (response is Map) {
      for (final key in ['messages', 'data']) {
        final value = response[key];
        if (value is List) {
          raw = value;
          break;
        }
        if (value is Map) {
          final nested = value['messages'];
          if (nested is List) {
            raw = nested;
            break;
          }
        }
      }
      final conversation = response['conversation'];
      if (raw.isEmpty && conversation is Map) {
        final nested = conversation['messages'];
        if (nested is List) raw = nested;
      }
    }

    return raw
        .whereType<Map>()
        .map((e) => ChatMessage.fromJson(
              Map<String, dynamic>.from(e),
              currentUserId: currentUserId,
            ))
        .where((m) => m.text.isNotEmpty || m.isPending)
        .toList();
  }
}
