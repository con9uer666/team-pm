import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/fade_in.dart';
import '../../attendance/data/attendance_api.dart';
import 'widgets/admin_fence_edit_sheet.dart';

final _fencesProvider =
    FutureProvider.autoDispose<List<AttendanceFence>>((ref) async {
  return ref.watch(attendanceApiProvider).listFences();
});

class AdminFencesScreen extends ConsumerWidget {
  const AdminFencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_fencesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新增围栏'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_fencesProvider);
          await ref.read(_fencesProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(
                child: Text(dioErrorMessage(e, '加载失败'),
                    style: TextStyle(color: AppTheme.dangerFg)),
              ),
            ],
          ),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                Center(
                  child: Text('暂无围栏',
                      style: TextStyle(color: Color(0xFF94A3B8))),
                ),
              ]);
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final f = list[i];
                final tile = _FenceCard(
                  fence: f,
                  onEdit: () => _openEdit(context, ref, f),
                  onToggle: () => _toggle(context, ref, f),
                  onDelete: () => _delete(context, ref, f),
                );
                if (i >= 6) return tile;
                return FadeInUp.once(
                  key: ValueKey(f.id),
                  delay: Duration(milliseconds: 40 * i),
                  child: tile,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const AdminFenceEditSheet(),
    );
    if (created == true) ref.invalidate(_fencesProvider);
  }

  Future<void> _openEdit(
      BuildContext context, WidgetRef ref, AttendanceFence f) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => AdminFenceEditSheet(initial: f),
    );
    if (updated == true) ref.invalidate(_fencesProvider);
  }

  Future<void> _toggle(
      BuildContext context, WidgetRef ref, AttendanceFence f) async {
    try {
      await ref
          .read(attendanceApiProvider)
          .updateFence(id: f.id, enabled: !f.enabled);
      ref.invalidate(_fencesProvider);
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e, '操作失败'))),
      );
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, AttendanceFence f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除围栏'),
        content: Text('确认删除「${f.name}」？历史打卡记录会保留。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(attendanceApiProvider).removeFence(f.id);
      ref.invalidate(_fencesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已删除')));
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e, '删除失败'))),
      );
    }
  }
}

class _FenceCard extends StatelessWidget {
  const _FenceCard({
    required this.fence,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });
  final AttendanceFence fence;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(fence.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                Switch.adaptive(value: fence.enabled, onChanged: (_) => onToggle()),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '中心 ${fence.centerLat.toStringAsFixed(6)}, ${fence.centerLng.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            Text('半径 ${fence.radius.toStringAsFixed(0)} m',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onEdit, child: const Text('编辑')),
                TextButton(
                  onPressed: onDelete,
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626)),
                  child: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
