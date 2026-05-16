import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../objectives/data/objective_models.dart';
import '../../objectives/data/objectives_api.dart';

/// Picker for an active objective matching the given scope. Returns the
/// selected objective id (nullable to clear), or null if dismissed without
/// confirming. Shared by task create + detail sheets.
class ObjectivePickerSheet extends ConsumerStatefulWidget {
  const ObjectivePickerSheet({
    super.key,
    required this.scope, // 'group' | 'division' | null
    this.groupId,
    this.divisionId,
    this.initialId,
  });

  final String? scope;
  final String? groupId;
  final String? divisionId;
  final String? initialId;

  @override
  ConsumerState<ObjectivePickerSheet> createState() => _ObjectivePickerSheetState();
}

class _ObjectivePickerSheetState extends ConsumerState<ObjectivePickerSheet> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialId;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(objectivesByScopeProvider(ObjectiveScopeKey(
      scope: widget.scope,
      groupId: widget.groupId,
      divisionId: widget.divisionId,
    )));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
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
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('选择关联目标',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('加载失败：$e')),
                data: (items) {
                  final active = items.where((o) => o.isActive).toList();
                  if (active.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('暂无可选目标',
                            style: TextStyle(color: Color(0xFF94A3B8))),
                      ),
                    );
                  }
                  return ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      RadioListTile<String?>(
                        title: const Text('不关联目标'),
                        value: null,
                        groupValue: _selected,
                        onChanged: (v) => setState(() => _selected = v),
                      ),
                      const Divider(height: 1),
                      for (final o in active)
                        _ObjectiveTile(
                          obj: o,
                          selected: _selected == o.id,
                          onTap: () => setState(() => _selected = o.id),
                        ),
                    ],
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.of(context).padding.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pop(PickerResult(_selected)),
                      child: const Text('确定'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ObjectiveTile extends StatelessWidget {
  const _ObjectiveTile({required this.obj, required this.selected, required this.onTap});
  final ObjectiveSummary obj;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final due = DateFormat('yyyy-MM-dd').format(obj.dueDate.toLocal());
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(obj.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('截止 $due',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
            if (obj.progress != null)
              Text(
                '${(obj.progress! * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Wraps the selected objective id (or null) returned from the sheet, so we
/// can distinguish "dismissed" (null pop) from "explicitly cleared" (pop with
/// PickerResult(null)).
class PickerResult {
  const PickerResult(this.objectiveId);
  final String? objectiveId;
}

/// Open the picker and return: explicit choice tuple (changed: bool, id: String?)
/// or null if dismissed.
Future<ObjectivePickerOutcome?> pickObjective(
  BuildContext context, {
  required String? scope,
  String? groupId,
  String? divisionId,
  String? initialId,
}) async {
  final res = await showModalBottomSheet<PickerResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => ObjectivePickerSheet(
      scope: scope,
      groupId: groupId,
      divisionId: divisionId,
      initialId: initialId,
    ),
  );
  if (res == null) return null;
  return ObjectivePickerOutcome(objectiveId: res.objectiveId);
}

class ObjectivePickerOutcome {
  const ObjectivePickerOutcome({required this.objectiveId});
  final String? objectiveId;
}
