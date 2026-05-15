import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/geo/geolocator_service.dart';
import '../../core/network/dio_client.dart';
import '../../core/theme/app_theme.dart';
import 'data/attendance_api.dart';

class _AttendanceBundle {
  const _AttendanceBundle({
    required this.active,
    required this.sessions,
    required this.fences,
  });
  final AttendanceSession? active;
  final List<AttendanceSession> sessions;
  final List<AttendanceFence> fences;
}

final _attendanceProvider =
    FutureProvider.autoDispose<_AttendanceBundle>((ref) async {
  final api = ref.watch(attendanceApiProvider);
  final results = await Future.wait([
    api.getActive(),
    api.getMy(limit: 30),
    api.listFences(),
  ]);
  return _AttendanceBundle(
    active: results[0] as AttendanceSession?,
    sessions: results[1] as List<AttendanceSession>,
    fences: results[2] as List<AttendanceFence>,
  );
});

final _rankProvider =
    FutureProvider.autoDispose<List<AttendanceStatRow>>((ref) async {
  final api = ref.watch(attendanceApiProvider);
  return api.getStats(scope: 'week');
});

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  int _tab = 0; // 0=mine, 1=rank
  bool _busy = false;

  Future<void> _refresh() async {
    ref.invalidate(_attendanceProvider);
    ref.invalidate(_rankProvider);
  }

  Future<void> _clockIn(_AttendanceBundle data) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final pos = await const GeolocatorService().current();
      final api = ref.read(attendanceApiProvider);
      await api.clockIn(
        lat: pos.lat,
        lng: pos.lng,
        accuracy: pos.accuracy,
      );
      if (!mounted) return;
      final nearest = _nearestFenceHit(data.fences, pos.lat, pos.lng);
      final msg = nearest != null
          ? '签到成功（${nearest.name}）'
          : '签到成功（未匹配到围栏）';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _refresh();
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e, e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clockOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final pos = await const GeolocatorService().current();
      final api = ref.read(attendanceApiProvider);
      await api.clockOut(
        lat: pos.lat,
        lng: pos.lng,
        accuracy: pos.accuracy,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('签退成功')));
      await _refresh();
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e, e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  AttendanceFence? _nearestFenceHit(
      List<AttendanceFence> fences, double lat, double lng) {
    AttendanceFence? best;
    double bestDist = double.infinity;
    for (final f in fences) {
      if (!f.enabled) continue;
      final d = haversine(lat, lng, f.centerLat, f.centerLng);
      if (d <= f.radius && d < bestDist) {
        best = f;
        bestDist = d;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final bundleAsync = ref.watch(_attendanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('考勤打卡'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _SegmentTabs(
              index: _tab,
              items: const ['我的打卡', '排行榜'],
              onChanged: (i) => setState(() => _tab = i),
            ),
            Expanded(
              child: _tab == 0
                  ? bundleAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(
                        child: Text(dioErrorMessage(err, '加载失败'),
                            style: const TextStyle(color: Color(0xFF64748B))),
                      ),
                      data: (data) => RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [
                            _StatusCard(
                              active: data.active,
                              busy: _busy,
                              onClockIn: () => _clockIn(data),
                              onClockOut: _clockOut,
                            ),
                            const SizedBox(height: 14),
                            _SummaryRow(
                              fenceCount: data.fences.where((f) => f.enabled).length,
                              sessions: data.sessions,
                            ),
                            const SizedBox(height: 16),
                            const Padding(
                              padding: EdgeInsets.only(left: 4, bottom: 8),
                              child: Text(
                                '最近打卡',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (data.sessions.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 32),
                                child: Center(
                                  child: Text(
                                    '暂无打卡记录',
                                    style: TextStyle(color: Color(0xFF94A3B8)),
                                  ),
                                ),
                              )
                            else
                              for (final s in data.sessions)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _SessionTile(session: s),
                                ),
                          ],
                        ),
                      ),
                    )
                  : _RankView(onRefresh: _refresh),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentTabs extends StatelessWidget {
  const _SegmentTabs({
    required this.index,
    required this.items,
    required this.onChanged,
  });
  final int index;
  final List<String> items;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: index == i ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: index == i
                          ? const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              )
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      items[i],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: index == i
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.active,
    required this.busy,
    required this.onClockIn,
    required this.onClockOut,
  });
  final AttendanceSession? active;
  final bool busy;
  final VoidCallback onClockIn;
  final VoidCallback onClockOut;

  @override
  Widget build(BuildContext context) {
    final isActive = active != null;
    final gradient = isActive ? AppTheme.gradGreen : AppTheme.gradBlue;
    final status = isActive ? '考勤进行中' : '未签到';
    final time = DateFormat('HH:mm').format(
      (isActive ? active!.clockInAt : DateTime.now()).toLocal(),
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isActive ? Icons.play_circle_fill : Icons.access_time_filled,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isActive ? '签到时间 $time' : '当前 $time',
                      style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : (isActive ? onClockOut : onClockIn),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Icon(isActive ? Icons.logout : Icons.location_on),
              label: Text(isActive ? '签退' : '签到'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.24),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.fenceCount, required this.sessions});
  final int fenceCount;
  final List<AttendanceSession> sessions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    int weekMin = 0;
    int monthMin = 0;
    for (final s in sessions) {
      if (s.clockInAt.isAfter(weekStart)) weekMin += s.durationMinutes;
      if (s.clockInAt.isAfter(monthStart)) monthMin += s.durationMinutes;
    }

    String fmt(int min) {
      final h = min ~/ 60;
      final m = min % 60;
      return '${h}h${m}m';
    }

    return Row(
      children: [
        _SummaryTile(label: '本周', value: fmt(weekMin)),
        const SizedBox(width: 10),
        _SummaryTile(label: '本月', value: fmt(monthMin)),
        const SizedBox(width: 10),
        _SummaryTile(label: '围栏', value: '$fenceCount'),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});
  final AttendanceSession session;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MM-dd HH:mm');
    final inStr = df.format(session.clockInAt.toLocal());
    final outStr = session.clockOutAt == null
        ? '进行中'
        : df.format(session.clockOutAt!.toLocal());
    final isActive = session.status == AttendanceSessionStatus.active;
    final isAuto = session.status == AttendanceSessionStatus.autoClosed;
    final tagColor = isActive
        ? const Color(0xFF22C55E)
        : isAuto
            ? const Color(0xFFF59E0B)
            : const Color(0xFF64748B);
    final tagText = isActive
        ? '进行中'
        : isAuto
            ? '自动结束'
            : '已结束';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Color(0xFF3B82F6), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$inStr → $outStr',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${session.durationMinutes} 分钟',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tagText,
              style: TextStyle(
                color: tagColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankView extends ConsumerWidget {
  const _RankView({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rank = ref.watch(_rankProvider);
    final auth = ref.watch(authControllerProvider);
    return rank.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text(dioErrorMessage(err, '加载失败'),
            style: const TextStyle(color: Color(0xFF64748B))),
      ),
      data: (rows) {
        final sorted = [...rows]
          ..sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: sorted.length,
            itemBuilder: (_, i) {
              final row = sorted[i];
              final isMe = row.userId == auth.user?.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RankTile(index: i, row: row, isMe: isMe),
              );
            },
          ),
        );
      },
    );
  }
}

class _RankTile extends StatelessWidget {
  const _RankTile({required this.index, required this.row, required this.isMe});
  final int index;
  final AttendanceStatRow row;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final gradients = [
      AppTheme.gradOrange,
      const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF94A3B8), Color(0xFFCBD5E1)]),
      const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB45309), Color(0xFFD97706)]),
    ];

    Widget rankBadge() {
      if (index < 3) {
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: gradients[index],
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            '${index + 1}',
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
        );
      }
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          '${index + 1}',
          style: const TextStyle(
              color: Color(0xFF475569), fontSize: 14, fontWeight: FontWeight.w600),
        ),
      );
    }

    final hours = (row.totalMinutes / 60).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMe ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          rankBadge(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${row.realName}${isMe ? ' (我)' : ''}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${row.username} · ${row.sessionCount} 次',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${hours}h',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6)),
              ),
              const Text(
                '本周',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
