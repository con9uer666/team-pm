import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/org/users_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/fade_in.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../meetings/data/meetings_api.dart';
import '../../meetings/widgets/meeting_detail_sheet.dart';

class AdminMeetingsScreen extends ConsumerStatefulWidget {
  const AdminMeetingsScreen({super.key});

  @override
  ConsumerState<AdminMeetingsScreen> createState() =>
      _AdminMeetingsScreenState();
}

class _AdminMeetingsScreenState extends ConsumerState<AdminMeetingsScreen> {
  final _search = TextEditingController();
  String _status = '';
  String _scope = '';

  static const _statusOptions = <_Opt>[
    _Opt('', '全部'),
    _Opt('scheduled', '待开始'),
    _Opt('in_progress', '进行中'),
    _Opt('ended', '已结束'),
    _Opt('cancelled', '已取消'),
  ];

  static const _scopeOptions = <_Opt>[
    _Opt('', '全部'),
    _Opt('team', '全队'),
    _Opt('division', '兵种'),
    _Opt('group', '技术组'),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allMeetingsProvider);
    final org = ref.watch(orgStructureProvider).valueOrNull;
    final keyword = _search.text.trim().toLowerCase();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: '搜索会议标题',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isDense: true,
                  initialValue: _status,
                  decoration: const InputDecoration(
                      isDense: true, labelText: '状态'),
                  items: [
                    for (final f in _statusOptions)
                      DropdownMenuItem(value: f.value, child: Text(f.label)),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? ''),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isDense: true,
                  initialValue: _scope,
                  decoration: const InputDecoration(
                      isDense: true, labelText: '范围'),
                  items: [
                    for (final f in _scopeOptions)
                      DropdownMenuItem(value: f.value, child: Text(f.label)),
                  ],
                  onChanged: (v) => setState(() => _scope = v ?? ''),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allMeetingsProvider);
              await ref.read(allMeetingsProvider.future);
            },
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(children: [
                const SizedBox(height: 80),
                Center(
                  child: Text(dioErrorMessage(e, '加载失败'),
                      style: TextStyle(color: AppTheme.dangerFg)),
                ),
              ]),
              data: (list) {
                final filtered = list.where((m) {
                  if (_status.isNotEmpty && m.status != _status) return false;
                  if (_scope.isNotEmpty && m.scope != _scope) return false;
                  if (keyword.isNotEmpty &&
                      !m.title.toLowerCase().contains(keyword)) {
                    return false;
                  }
                  return true;
                }).toList()
                  ..sort((a, b) => b.startTime.compareTo(a.startTime));

                if (filtered.isEmpty) {
                  return ListView(children: const [
                    SizedBox(height: 120),
                    Center(
                      child: Text('无匹配会议',
                          style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                  ]);
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final m = filtered[i];
                    final card = _MeetingCard(
                      meeting: m,
                      org: org,
                      onTap: () => _openDetail(context, ref, m),
                      onLongPress: () => _showActions(context, ref, m),
                    );
                    if (i >= 5) return card;
                    return FadeInUp.once(
                      key: ValueKey(m.id),
                      delay: Duration(milliseconds: 40 * i),
                      child: card,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
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
    if (changed == true) ref.invalidate(allMeetingsProvider);
  }

  Future<void> _showActions(
      BuildContext context, WidgetRef ref, MeetingInfo m) async {
    final canEnd = m.isInProgress;
    final canCancel = m.isScheduled || m.isInProgress;
    if (!canEnd && !canCancel) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('该会议已无可执行的批量操作')));
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEnd)
              ListTile(
                leading: const Icon(Icons.stop_circle_outlined,
                    color: Color(0xFF1D4ED8)),
                title: const Text('结束会议'),
                onTap: () => Navigator.pop(context, 'end'),
              ),
            if (canCancel)
              ListTile(
                leading:
                    Icon(Icons.cancel_outlined, color: AppTheme.dangerFg),
                title:
                    Text('取消会议', style: TextStyle(color: AppTheme.dangerFg)),
                onTap: () => Navigator.pop(context, 'cancel'),
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('关闭'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
    if (choice == 'end') {
      await _act(context, ref, m, () => ref.read(meetingsApiProvider).end(m.id),
          successMsg: '已结束');
    } else if (choice == 'cancel') {
      final ok = await _confirm(context, '取消会议', '确认取消「${m.title}」？');
      if (!ok) return;
      await _act(
          context, ref, m, () => ref.read(meetingsApiProvider).cancel(m.id),
          successMsg: '已取消');
    }
  }

  Future<void> _act(BuildContext context, WidgetRef ref, MeetingInfo m,
      Future<void> Function() op,
      {required String successMsg}) async {
    try {
      await op();
      ref.invalidate(allMeetingsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMsg)));
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e, '操作失败'))),
      );
    }
  }

  Future<bool> _confirm(
      BuildContext context, String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认')),
        ],
      ),
    );
    return ok == true;
  }
}

class _Opt {
  const _Opt(this.value, this.label);
  final String value;
  final String label;
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({
    required this.meeting,
    required this.org,
    required this.onTap,
    required this.onLongPress,
  });
  final MeetingInfo meeting;
  final OrgStructure? org;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final organizer = org?.userName(meeting.organizerId) ?? '';
    final scopeLabel = _scopeLabel(meeting, org);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
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
              const SizedBox(height: 6),
              Text(
                '${_fmtDT(meeting.startTime)} → ${_fmtDT(meeting.endTime)}',
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 2),
              Text(
                '${organizer.isEmpty ? '组织者' : organizer} · $scopeLabel',
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              if (meeting.location != null && meeting.location!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(meeting.location!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF94A3B8))),
                ),
            ],
          ),
        ),
      ),
    );
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
  return '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
