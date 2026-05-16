import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../objectives/data/objectives_api.dart';

class ObjectiveCreateSheet extends ConsumerStatefulWidget {
  const ObjectiveCreateSheet({
    super.key,
    required this.scope,
    this.groupId,
    this.divisionId,
  });

  final String scope;
  final String? groupId;
  final String? divisionId;

  @override
  ConsumerState<ObjectiveCreateSheet> createState() =>
      _ObjectiveCreateSheetState();
}

class _ObjectiveCreateSheetState extends ConsumerState<ObjectiveCreateSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  DateTime? _due;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      initialDate: _due ?? now.add(const Duration(days: 14)),
    );
    if (picked == null) return;
    setState(() => _due = DateTime(picked.year, picked.month, picked.day, 23, 59));
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_due == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择截止日期')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(objectivesApiProvider).create(
            title: _title.text.trim(),
            description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
            scope: widget.scope,
            groupId: widget.groupId,
            divisionId: widget.divisionId,
            dueDate: _due!,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e, '创建失败'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  child: Text('下达阶段性目标',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
              Expanded(
                child: Form(
                  key: _form,
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    children: [
                      TextFormField(
                        controller: _title,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText: '标题 *',
                          hintText: '目标标题',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? '请填写标题' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _desc,
                        maxLength: 2000,
                        maxLines: 4,
                        minLines: 2,
                        decoration: const InputDecoration(
                          labelText: '描述（可选）',
                          hintText: '目标描述',
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event),
                        title: const Text('截止日期 *'),
                        subtitle: Text(_due == null
                            ? '请选择'
                            : '${_due!.year}-${_due!.month.toString().padLeft(2, '0')}-${_due!.day.toString().padLeft(2, '0')}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _pickDate,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                    20, 10, 20, 12 + MediaQuery.of(context).padding.bottom),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _busy ? null : () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.4, color: Colors.white),
                              )
                            : const Text('确认下达'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
