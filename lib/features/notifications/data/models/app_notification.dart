import 'dart:convert';

class AppNotification {
  const AppNotification({
    required this.id,
    this.type,
    this.typeClass,
    this.title,
    this.message,
    this.data = const {},
    this.readAt,
    this.isRead = false,
    this.createdAt,
  });

  final String id;
  final String? type;
  final String? typeClass;
  final String? title;
  final String? message;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final bool isRead;
  final DateTime? createdAt;

  AppNotification copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return AppNotification(
      id: id,
      type: type,
      typeClass: typeClass,
      title: title,
      message: message,
      data: data,
      readAt: readAt ?? this.readAt,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  /// Tolerates object, array, JSON string, malformed JSON, and null.
  static Map<String, dynamic> parseData(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is List) {
      return {'items': raw};
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return {};
      try {
        return parseData(jsonDecode(trimmed));
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final readAt = DateTime.tryParse(json['read_at']?.toString() ?? '');
    final explicitRead = json['is_read'] ?? json['isRead'];
    final isRead = explicitRead == true ||
        explicitRead == 1 ||
        explicitRead == 'true' ||
        readAt != null;

    return AppNotification(
      id: id,
      type: json['type']?.toString(),
      typeClass: (json['type_class'] ?? json['typeClass'])?.toString(),
      title: json['title']?.toString(),
      message: (json['message'] ?? json['body'])?.toString(),
      data: parseData(json['data']),
      readAt: readAt,
      isRead: isRead,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class NotificationsPage {
  const NotificationsPage({
    this.items = const [],
    this.unreadCount = 0,
    this.total = 0,
    this.perPage = 20,
    this.currentPage = 1,
    this.lastPage = 1,
  });

  final List<AppNotification> items;
  final int unreadCount;
  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;

  static int _int(dynamic value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  factory NotificationsPage.fromResponse(Map<String, dynamic> response) {
    final data = response['data'];
    List<AppNotification> items = [];
    if (data is List) {
      items = data
          .whereType<Map>()
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
          .where((n) => n.id.isNotEmpty)
          .toList();
    }

    final meta = response['meta'];
    final metaMap = meta is Map ? Map<String, dynamic>.from(meta) : <String, dynamic>{};

    return NotificationsPage(
      items: items,
      unreadCount: _int(metaMap['unread_count'] ?? metaMap['unreadCount'], 0),
      total: _int(metaMap['total'], items.length),
      perPage: _int(metaMap['per_page'] ?? metaMap['perPage'], 20),
      currentPage: _int(metaMap['current_page'] ?? metaMap['currentPage'], 1),
      lastPage: _int(metaMap['last_page'] ?? metaMap['lastPage'], 1),
    );
  }
}
