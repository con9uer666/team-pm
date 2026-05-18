import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/org/users_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/status_chip.dart';
import '../data/meetings_api.dart';
import 'meeting_minutes_sheet.dart';

class MeetingDetailSheet extends ConsumerStatefulWidget {
  const MeetingDetailSheet({super.key, required this.meetingId});
  final String meetingId;

  @override
  ConsumerState<MeetingDetailSheet> createState() => _MeetingDetailSheetState();
}

class _MeetingDetailSheetState extends ConsumerState<MeetingDetailSheet> {
  late Future<_DetailBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DetailBundle> _load() async {
    final api = ref.read(meetingsApiProvider);
    final meeting = await api.getById(widget.meetingId);
    final participants = await api.getParticipants(widget.meetingId);
    return _DetailBundle(meeting: meeting, participants: participants);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _runOp(Future<void> Function() op, String successMsg) async {
    try {
      await op();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMsg)));
      _reload();
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e, '操作失败'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final org = ref.watch(orgStructureProvider).valueOrNull;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        return FutureBuilder<_DetailBundle>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(dioErrorMessage(snap.error!, '加载失败'),
                      style: TextStyle(color: AppTheme.dangerFg)),
                ),
              );
            }
            final m = snap.data!.meeting;
            final ps = snap.data!.participants;
            final isOrganizer = user != null && user.id == m.organizerId;
            final isLeader = user != null && user.roleLevel >= 3;
            final myPart = ps.where((p) => p.userId == user?.id).toList();
            final mineStatus =
                myPart.isEmpty ? null : myPart.first.attendanceStatus;

            return Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(m.title,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                          ),
                          StatusChip(status: m.status),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _Row(
                        icon: Icons.access_time,
                        text: '${_fmtDT(m.startTime)} → ${_fmtDT(m.endTime)}',
                      ),
                      if (m.location != null && m.location!.isNotEmpty)
                        _Row(icon: Icons.place_outlined, text: m.location!),
                      _Row(
                        icon: Icons.person_outline,
                        text:
                            '${org?.userName(m.organizerId) ?? '组织者'} · ${_scopeLabel(m, org)}',
                      ),
                      if (m.description != null &&
                          m.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(m.description!,
                              style:
                                  const TextStyle(height: 1.5, fontSize: 13)),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text('参与者',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (ps.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('暂无参与者',
                              style: TextStyle(color: Color(0xFF94A3B8))),
                        )
                      else
                        ...ps.map((p) => _ParticipantRow(
                              p: p,
                              name: org?.userName(p.userId) ?? p.userId,
                            )),
                    ],
                  ),
                ),
                _ActionBar(
                  meeting: m,
                  isOrganizer: isOrganizer,
                  isLeader: isLeader,
                  myCheckInStatus: mineStatus,
                  onStart: () => _runOp(
                      () => ref.read(meetingsApiProvider).start(m.id).then((_) {}),
                      '已开始'),
                  onEnd: () => _runOp(
                      () => ref.read(meetingsApiProvider).end(m.id).then((_) {}),
                      '已结束'),
                  onCancel: () => _runOp(
                      () => ref
                          .read(meetingsApiProvider)
                          .cancel(m.id)
                          .then((_) {}),
                      '已取消'),
                  onCheckIn: () => _runOp(
                      () => ref
                          .read(meetingsApiProvider)
                          .checkIn(m.id)
                          .then((_) {}),
                      '签到成功'),
                  onMinutes: () => _openMinutes(context, m.id, isLeader),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openMinutes(
      BuildContext context, String id, bool canEdit) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) =>
          MeetingMinutesSheet(meetingId: id, canEdit: canEdit),
    );
  }
}

class _DetailBundle {
  const _DetailBundle({required this.meeting, required this.participants});
  final MeetingInfo meeting;
  final List<MeetingParticipant> participants;
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style:
                    const TextStyle(fontSize: 13, color: Color(0xFF334155))),
          ),
        ],
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({required this.p, required this.name});
  final MeetingParticipant p;
  final String name;

  @override
  Widget build(BuildContext context) {
    final spec = _statusSpec(p.attendanceStatus);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFFE2E8F0),
            child: Text(
              name.isEmpty ? '?' : name.characters.first,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF334155)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: spec.bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(spec.label,
                style: TextStyle(fontSize: 11, color: spec.fg)),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.meeting,
    required this.isOrganizer,
    required this.isLeader,
    required this.myCheckInStatus,
    required this.onStart,
    required this.onEnd,
    required this.onCancel,
    required this.onCheckIn,
    required this.onMinutes,
  });

  final MeetingInfo meeting;
  final bool isOrganizer;
  final bool isLeader;
  final String? myCheckInStatus;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final VoidCallback onCancel;
  final VoidCallback onCheckIn;
  final VoidCallback onMinutes;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];

    if (isOrganizer && meeting.isScheduled) {
      actions.add(_btn('开始会议', onStart, primary: true));
      actions.add(_btn('取消', onCancel, danger: true));
    }
    if (isOrganizer && meeting.isInProgress) {
      actions.add(_btn('结束会议', onEnd, primary: true));
    }
    if (!isOrganizer && meeting.isInProgress) {
      final already = myCheckInStatus == 'present' ||
          myCheckInStatus == 'late';
      actions.add(_btn(
        already ? '已签到' : '签到',
        already ? () {} : onCheckIn,
        primary: !already,
        disabled: already,
      ));
    }
    if (meeting.isEnded || meeting.isInProgress) {
      actions.add(_btn(isLeader ? '编辑纪要' : '查看纪要', onMinutes));
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: actions[i]),
          ],
        ],
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap,
      {bool primary = false, bool danger = false, bool disabled = false}) {
    if (primary) {
      return FilledButton(
        onPressed: disabled ? null : onTap,
        child: Text(label),
      );
    }
    if (danger) {
      return OutlinedButton(
        onPressed: disabled ? null : onTap,
        style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFDC2626)),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: disabled ? null : onTap,
      child: Text(label),
    );
  }
}

class _PSpec {
  const _PSpec(this.label, this.fg, this.bg);
  final String label;
  final Color fg;
  final Color bg;
}

_PSpec _statusSpec(String s) {
  switch (s) {
    case 'present':
      return const _PSpec('已签到', Color(0xFF047857), Color(0xFFD1FAE5));
    case 'late':
      return const _PSpec('迟到', Color(0xFFB45309), Color(0xFFFEF3C7));
    case 'absent':
      return const _PSpec('缺席', Color(0xFFB91C1C), Color(0xFFFEE2E2));
    case 'pending':
    default:
      return const _PSpec('待签到', Color(0xFF475569), Color(0xFFE2E8F0));
  }
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

String _fmtDT(DateTime t) {
  return '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
