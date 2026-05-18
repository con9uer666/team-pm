import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/geo/geolocator_service.dart';
import '../../../../core/network/dio_client.dart';
import '../../../attendance/data/attendance_api.dart';

/// Create or edit a single attendance fence. Reused by AdminFencesScreen
/// for both flows — pass [initial] to populate fields when editing.
class AdminFenceEditSheet extends ConsumerStatefulWidget {
  const AdminFenceEditSheet({super.key, this.initial});
  final AttendanceFence? initial;

  @override
  ConsumerState<AdminFenceEditSheet> createState() =>
      _AdminFenceEditSheetState();
}

class _AdminFenceEditSheetState extends ConsumerState<AdminFenceEditSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  double _radius = 100;
  bool _enabled = true;
  bool _busy = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    if (f != null) {
      _name.text = f.name;
      _lat.text = f.centerLat.toStringAsFixed(6);
      _lng.text = f.centerLng.toStringAsFixed(6);
      _radius = f.radius.clamp(10, 5000);
      _enabled = f.enabled;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  Future<void> _useCurrent() async {
    setState(() => _locating = true);
    try {
      final pos = await const GeolocatorService().current();
      if (!mounted) return;
      setState(() {
        _lat.text = pos.lat.toStringAsFixed(6);
        _lng.text = pos.lng.toStringAsFixed(6);
      });
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e, '获取位置失败'))),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) return;
    final latVal = double.tryParse(_lat.text.trim());
    final lngVal = double.tryParse(_lng.text.trim());
    if (latVal == null || latVal < -90 || latVal > 90) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入合法纬度（-90 ~ 90）')));
      return;
    }
    if (lngVal == null || lngVal < -180 || lngVal > 180) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入合法经度（-180 ~ 180）')));
      return;
    }

    setState(() => _busy = true);
    try {
      final api = ref.read(attendanceApiProvider);
      if (widget.initial == null) {
        await api.createFence(
          name: _name.text.trim(),
          centerLat: latVal,
          centerLng: lngVal,
          radius: _radius,
          enabled: _enabled,
        );
      } else {
        await api.updateFence(
          id: widget.initial!.id,
          name: _name.text.trim(),
          centerLat: latVal,
          centerLng: lngVal,
          radius: _radius,
          enabled: _enabled,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e, '保存失败'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) => Column(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(editing ? '编辑围栏' : '新增围栏',
                    style: const TextStyle(
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
                      controller: _name,
                      maxLength: 50,
                      decoration: const InputDecoration(
                        labelText: '名称 *',
                        hintText: '例如：基地训练场',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请填写名称' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _lat,
                            keyboardType: const TextInputType.numberWithOptions(
                                signed: true, decimal: true),
                            decoration:
                                const InputDecoration(labelText: '纬度 *'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _lng,
                            keyboardType: const TextInputType.numberWithOptions(
                                signed: true, decimal: true),
                            decoration:
                                const InputDecoration(labelText: '经度 *'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _locating ? null : _useCurrent,
                        icon: _locating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location, size: 16),
                        label: const Text('使用当前位置'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('半径', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 8),
                        Text('${_radius.round()} m',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Slider(
                      value: _radius,
                      min: 10,
                      max: 5000,
                      divisions: 499,
                      label: '${_radius.round()} m',
                      onChanged: (v) => setState(() => _radius = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('启用'),
                      subtitle: const Text('启用后此围栏会用于打卡自动识别'),
                      value: _enabled,
                      onChanged: (v) => setState(() => _enabled = v),
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
                          : Text(editing ? '保存' : '创建'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
