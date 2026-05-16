import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/dio_provider.dart';

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    this.content,
    this.relatedId,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String? content;
  final String? relatedId;
  final bool isRead;
  final DateTime createdAt;

  factory NotificationItem.fromJson(Map<String, dynamic> j) {
    final raw = j['createdAt'];
    final created = raw is String
        ? (DateTime.tryParse(raw)?.toLocal() ?? DateTime.now())
        : DateTime.now();
    return NotificationItem(
      id: j['id'] as String,
      type: (j['type'] ?? 'general') as String,
      title: (j['title'] ?? '') as String,
      content: j['content'] as String?,
      relatedId: j['relatedId'] as String?,
      isRead: (j['isRead'] ?? false) as bool,
      createdAt: created,
    );
  }
}

class NotificationsApi {
  NotificationsApi(this._client);
  final DioClient _client;

  Future<List<NotificationItem>> getAll() async {
    final data = await _client.get<List<dynamic>>('/notifications');
    return data
        .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final data = await _client.get<dynamic>('/notifications/unread-count');
    if (data is Map && data['count'] is int) return data['count'] as int;
    if (data is int) return data;
    return 0;
  }

  Future<void> markRead(String id) async {
    await _client.patch<dynamic>('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _client.patch<dynamic>('/notifications/read-all');
  }
}

final notificationsApiProvider = Provider<NotificationsApi>((ref) {
  return NotificationsApi(ref.watch(dioClientProvider));
});

final notificationsProvider =
    FutureProvider.autoDispose<List<NotificationItem>>((ref) async {
  return ref.watch(notificationsApiProvider).getAll();
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return ref.watch(notificationsApiProvider).getUnreadCount();
});
