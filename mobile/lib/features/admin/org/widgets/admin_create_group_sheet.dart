import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/org/org_api.dart';
import '../../../../core/org/users_api.dart';

/// Sheet for creating either a technical group ([kind] = 'group') or
/// a 兵种 division ([kind] = 'division'). Divisions add a description field.
class AdminCreateGroupSheet extends ConsumerStatefulWidget {
  const AdminCreateGroupSheet({super.key, required this.kind});
  final String kind;

  @override
  ConsumerState<AdminCreateGroupSheet> createState() =>
      _AdminCreateGroupSheetState();
}

class _AdminCreateGroupSheetState extends ConsumerState<AdminCreateGroupSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (widget.kind == 'division') {
        await ref.read(orgApiProvider).createDivision(
              name: _name.text.trim(),
              description:
                  _desc.text.trim().isEmpty ? null : _desc.text.trim(),
            );
      } else {
        await ref.read(orgApiProvider).createGroup(name: _name.text.trim());
      }
      ref.invalidate(orgStructureProvider);
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
    final isDivision = widget.kind == 'division';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  isDivision ? '新增兵种组' : '新增技术组',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  maxLength: 50,
                  decoration: const InputDecoration(labelText: '名称 *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '请填写名称' : null,
                ),
                if (isDivision)
                  TextFormField(
                    controller: _desc,
                    maxLength: 200,
                    maxLines: 2,
                    minLines: 1,
                    decoration:
                        const InputDecoration(labelText: '描述（可选）'),
                  ),
                const SizedBox(height: 12),
                Row(
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
                            : const Text('创建'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
