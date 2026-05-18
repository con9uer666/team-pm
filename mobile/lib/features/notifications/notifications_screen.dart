import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/fade_in.dart';
import 'data/notifications_api.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final unread = async.maybeWhen(
      data: (list) => list.where((n) => !n.isRead).length,
      orElse: () => 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () async {
                try {
                  await ref.read(notificationsApiProvider).markAllRead();
                  ref.invalidate(notificationsProvider);
                  ref.invalidate(unreadCountProvider);
                } on Object catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(dioErrorMessage(e, '操作失败'))),
                  );
                }
              },
              child: const Text('全部已读'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          ref.invalidate(unreadCountProvider);
          await ref.read(notificationsProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(dioErrorMessage(e, '加载失败'),
                      style: TextStyle(color: AppTheme.dangerFg)),
                ),
              ),
            ],
          ),
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text('暂无通知',
                        style: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
              itemBuilder: (_, i) {
                final n = list[i];
                final tile = _NotificationTile(
                  item: n,
                  onTap: () => _handleTap(context, ref, n),
                );
                if (i >= 6) return tile;
                return FadeInUp.once(
                  key: ValueKey(n.id),
                  delay: Duration(milliseconds: 35 * i),
                  child: tile,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleTap(
      BuildContext context, WidgetRef ref, NotificationItem n) async {
    if (!n.isRead) {
      try {
        await ref.read(notificationsApiProvider).markRead(n.id);
        ref.invalidate(notificationsProvider);
        ref.invalidate(unreadCountProvider);
      } on Object catch (_) {
        // silent — user can pull to refresh
      }
    }
    if (!context.mounted) return;
    final route = _routeFor(n);
    if (route != null) context.push(route);
  }

  String? _routeFor(NotificationItem n) {
    if (n.type.startsWith('task_') && n.relatedId != null) {
      return '/tasks';
    }
    if (n.type.startsWith('meeting_')) {
      return '/meetings';
    }
    return null;
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});
  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;
    final spec = _iconSpec(item.type);
    return Material(
      color: unread ? const Color(0xFFEFF6FF) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: spec.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(spec.icon, size: 18, color: spec.color),
                  ),
                  if (unread)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            unread ? FontWeight.w600 : FontWeight.w500,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (item.content != null &&
                        item.content!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.content!,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF475569)),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(item.createdAt),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

class _IconSpec {
  const _IconSpec(this.icon, this.color);
  final IconData icon;
  final Color color;
}

_IconSpec _iconSpec(String type) {
  if (type.startsWith('task_')) {
    return const _IconSpec(Icons.assignment_outlined, Color(0xFF3B82F6));
  }
  if (type.startsWith('meeting_')) {
    return const _IconSpec(Icons.event_outlined, Color(0xFF8B5CF6));
  }
  return const _IconSpec(Icons.notifications_none, Color(0xFF94A3B8));
}
