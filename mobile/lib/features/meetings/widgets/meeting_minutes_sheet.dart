import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../data/meetings_api.dart';

class MeetingMinutesSheet extends ConsumerStatefulWidget {
  const MeetingMinutesSheet({
    super.key,
    required this.meetingId,
    required this.canEdit,
  });

  final String meetingId;
  final bool canEdit;

  @override
  ConsumerState<MeetingMinutesSheet> createState() =>
      _MeetingMinutesSheetState();
}

class _MeetingMinutesSheetState extends ConsumerState<MeetingMinutesSheet> {
  final _ctrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  MeetingMinutes? _current;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final m = await ref.read(meetingsApiProvider).getMinutes(widget.meetingId);
      if (!mounted) return;
      setState(() {
        _current = m;
        _ctrl.text = m?.content ?? '';
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = dioErrorMessage(e, '加载纪要失败');
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final content = _ctrl.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写纪要内容')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(meetingsApiProvider).saveMinutes(widget.meetingId, content);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('纪要已保存')));
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e, '保存失败'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('会议纪要',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    if (_current?.updatedAt != null)
                      Text('更新于 ${_fmt(_current!.updatedAt!)}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(
                              child: Text(_error!,
                                  style: TextStyle(
                                      color: AppTheme.dangerFg)))
                          : widget.canEdit
                              ? TextField(
                                  controller: _ctrl,
                                  scrollController: controller,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  decoration: const InputDecoration(
                                    hintText: '记录会议内容、决议、待办项…',
                                    border: OutlineInputBorder(),
                                  ),
                                )
                              : SingleChildScrollView(
                                  controller: controller,
                                  child: Text(
                                    _ctrl.text.isEmpty ? '暂无纪要' : _ctrl.text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.6,
                                      color: _ctrl.text.isEmpty
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
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
                            _saving ? null : () => Navigator.of(context).pop(),
                        child: const Text('关闭'),
                      ),
                    ),
                    if (widget.canEdit) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving || _loading ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.4, color: Colors.white),
                                )
                              : const Text('保存'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _fmt(DateTime t) {
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}
