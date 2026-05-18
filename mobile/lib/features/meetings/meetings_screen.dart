import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/dio_client.dart';
import '../../core/org/users_api.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/status_chip.dart';
import 'data/meetings_api.dart';
import 'widgets/meeting_create_sheet.dart';
import 'widgets/meeting_detail_sheet.dart';

class MeetingsScreen extends ConsumerWidget {
  const MeetingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myMeetingsProvider);
    final user = ref.watch(authControllerProvider).user;
    final canCreate = user != null && user.roleLevel >= 3;

    return Scaffold(
      appBar: AppBar(title: const Text('会议')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _openCreate(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('创建'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myMeetingsProvider);
          await ref.read(myMeetingsProvider.future);
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
                    child: Text('暂无会议',
                        style: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                ],
              );
            }
            final active = list
                .where((m) => m.isScheduled || m.isInProgress)
                .toList()
              ..sort((a, b) => a.startTime.compareTo(b.startTime));
            final past = list
                .where((m) => m.isEnded || m.isCancelled)
                .toList()
              ..sort((a, b) => b.startTime.compareTo(a.startTime));

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                if (active.isNotEmpty) ...[
                  const Text('进行中 / 即将开始',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  for (final m in active)
                    _MeetingCard(
                      meeting: m,
                      onTap: () => _openDetail(context, ref, m),
                    ),
                ],
                if (active.isNotEmpty && past.isNotEmpty)
                  const SizedBox(height: 12),
                if (past.isNotEmpty) ...[
                  const Text('已结束',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  for (final m in past)
                    _MeetingCard(
                      meeting: m,
                      onTap: () => _openDetail(context, ref, m),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const MeetingCreateSheet(),
    );
    if (ok == true) ref.invalidate(myMeetingsProvider);
  }

  Future<void> _openDetail(
      BuildContext context, WidgetRef ref, MeetingInfo m) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => MeetingDetailSheet(meetingId: m.id),
    );
    if (changed == true) ref.invalidate(myMeetingsProvider);
  }
}

class _MeetingCard extends ConsumerWidget {
  const _MeetingCard({required this.meeting, required this.onTap});
  final MeetingInfo meeting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(orgStructureProvider).valueOrNull;
    final organizer = org?.userName(meeting.organizerId) ?? '';
    final scopeLabel = _scopeLabel(meeting, org);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(meeting.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  StatusChip(status: meeting.status, compact: true),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatRange(meeting.startTime, meeting.endTime),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              if (meeting.location != null &&
                  meeting.location!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(meeting.location!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B))),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${organizer.isEmpty ? '组织者' : organizer} · $scopeLabel',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _scopeLabel(MeetingInfo m, OrgStructure? org) {
    switch (m.scope) {
      case 'group':
        final n = org?.groupName(m.groupId);
        return n == null || n.isEmpty ? '技术组' : '[技术组] $n';
      case 'division':
        final n = org?.divisionName(m.divisionId);
        return n == null || n.isEmpty ? '兵种组' : '[兵种] $n';
      case 'team':
      default:
        return '全队';
    }
  }
}

String _formatRange(DateTime s, DateTime e) {
  final ss =
      '${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')} ${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';
  final ee = s.day == e.day && s.month == e.month
      ? '${e.hour.toString().padLeft(2, '0')}:${e.minute.toString().padLeft(2, '0')}'
      : '${e.month.toString().padLeft(2, '0')}-${e.day.toString().padLeft(2, '0')} ${e.hour.toString().padLeft(2, '0')}:${e.minute.toString().padLeft(2, '0')}';
  return '$ss → $ee';
}
