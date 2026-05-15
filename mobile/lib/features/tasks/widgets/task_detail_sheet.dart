import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/config.dart';
import '../../../core/network/dio_client.dart';
import '../data/task_models.dart';
import '../data/tasks_api.dart';
import 'task_complete_sheet.dart';

class TaskDetailSheet extends ConsumerStatefulWidget {
  const TaskDetailSheet({super.key, required this.task});
  final TaskItem task;

  @override
  ConsumerState<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<TaskDetailSheet> {
  bool _busy = false;

  Future<T?> _guard<T>(Future<T> Function() fn, {String fallbackError = '操作失败'}) async {
    if (_busy) return null;
    setState(() => _busy = true);
    try {
      return await fn();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dioErrorMessage(e, fallbackError))),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve(String reviewType) async {
    final api = ref.read(tasksApiProvider);
    final ok = await _guard(
      () => api.review(id: widget.task.id, action: 'approve', reviewType: reviewType),
      fallbackError: '审核失败',
    );
    if (ok != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已审核通过')));
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _reject(String reviewType) async {
    final reason = await _askReason(context, title: '驳回任务', hint: '请输入驳回原因');
    if (reason == null || reason.isEmpty) return;
    final api = ref.read(tasksApiProvider);
    final ok = await _guard(
      () => api.review(
        id: widget.task.id,
        action: 'reject',
        reviewType: reviewType,
        reason: reason,
      ),
      fallbackError: '驳回失败',
    );
    if (ok != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已驳回')));
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _complete() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => TaskCompleteSheet(taskId: widget.task.id),
    );
    if (ok == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _verify(String action) async {
    String? reason;
    if (action == 'reject') {
      reason = await _askReason(context, title: '驳回结案', hint: '请输入驳回原因');
      if (reason == null || reason.isEmpty) return;
    }
    final api = ref.read(tasksApiProvider);
    final ok = await _guard(
      () => api.verifyCompletion(id: widget.task.id, action: action, reason: reason),
      fallbackError: '操作失败',
    );
    if (ok != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action == 'approve' ? '已通过结案' : '已驳回结案')),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final style = taskStatusStyle(t.status);
    final auth = ref.watch(authControllerProvider);
    final isMine = auth.user?.id == t.assigneeId;
    final dueFmt = DateFormat('yyyy-MM-dd HH:mm').format(t.dueDate.toLocal());

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
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
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: style.border.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            style.label,
                            style: TextStyle(
                                color: style.fg, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Row(icon: Icons.schedule, label: '截止时间', value: dueFmt),
                    _Row(
                      icon: Icons.priority_high,
                      label: '优先级',
                      value: _priorityLabel(t.priority),
                    ),
                    if ((t.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const _Heading('任务描述'),
                      const SizedBox(height: 6),
                      Text(
                        t.description!,
                        style: const TextStyle(color: Color(0xFF334155), fontSize: 14),
                      ),
                    ],
                    if ((t.content ?? '').isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const _Heading('任务内容'),
                      const SizedBox(height: 6),
                      Text(
                        t.content!,
                        style: const TextStyle(color: Color(0xFF334155), fontSize: 14),
                      ),
                    ],
                    if ((t.rejectionReason ?? '').isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '驳回原因',
                                    style: TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    t.rejectionReason!,
                                    style: const TextStyle(
                                        color: Color(0xFF7F1D1D), fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (t.status == TaskStatus.pendingCompletion ||
                        t.status == TaskStatus.completed) ...[
                      if ((t.completionNote ?? '').isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const _Heading('结案说明'),
                        const SizedBox(height: 6),
                        Text(
                          t.completionNote!,
                          style: const TextStyle(color: Color(0xFF334155), fontSize: 14),
                        ),
                      ],
                      if (t.completionAttachments.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const _Heading('结案附件'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final url in t.completionAttachments)
                              _AttachmentThumb(url: AppConfig.absoluteUrl(url)),
                          ],
                        ),
                      ],
                    ],
                    if (t.reviews.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const _Heading('审核记录'),
                      const SizedBox(height: 6),
                      for (final r in t.reviews)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                r.status == 'approved'
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                size: 16,
                                color: r.status == 'approved'
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFFEF4444),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${r.reviewType == 'division' ? '兵种' : '技术组'} · ${r.status == 'approved' ? '通过' : '驳回'}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              const Spacer(),
                              Text(
                                DateFormat('MM-dd HH:mm').format(r.reviewedAt.toLocal()),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            _ActionBar(
              task: t,
              isMine: isMine,
              busy: _busy,
              onApprove: _approve,
              onReject: _reject,
              onComplete: _complete,
              onVerify: _verify,
            ),
          ],
        );
      },
    );
  }
}

String _priorityLabel(int p) {
  switch (p) {
    case 2:
      return '紧急';
    case 1:
      return '重要';
    default:
      return '普通';
  }
}

String _dimLabel(String type) => type == 'division' ? '兵种' : '技术组';

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF64748B),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({required this.url});
  final String url;

  bool get _isVideo {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.webm');
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _preview(context),
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 72,
          height: 72,
          color: const Color(0xFFF1F5F9),
          child: _isVideo
              ? const Center(
                  child: Icon(Icons.play_circle_outline,
                      color: Color(0xFF64748B), size: 32),
                )
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image,
                      color: Color(0xFF94A3B8), size: 28),
                  loadingBuilder: (_, child, p) {
                    if (p == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _preview(BuildContext context) {
    if (_isVideo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('视频预览暂未支持，链接：$url')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Container(
          alignment: Alignment.center,
          child: InteractiveViewer(
            child: Image.network(
              url,
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image,
                  color: Colors.white, size: 64),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.task,
    required this.isMine,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onComplete,
    required this.onVerify,
  });

  final TaskItem task;
  final bool isMine;
  final bool busy;
  final Future<void> Function(String) onApprove;
  final Future<void> Function(String) onReject;
  final Future<void> Function() onComplete;
  final Future<void> Function(String) onVerify;

  @override
  Widget build(BuildContext context) {
    final canReviewInitial =
        task.status == TaskStatus.pendingReview && task.reviewableTypes.isNotEmpty;
    final canSubmit = isMine &&
        (task.status == TaskStatus.approved || task.status == TaskStatus.rejected);
    final canVerify = task.status == TaskStatus.pendingCompletion && task.canVerifyCompletion;

    if (!canReviewInitial && !canSubmit && !canVerify) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: busy
          ? const SizedBox(height: 44, child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canReviewInitial)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final rt in task.reviewableTypes) ...[
                        OutlinedButton.icon(
                          onPressed: () => onReject(rt),
                          icon: const Icon(Icons.close, size: 16),
                          label: Text('${_dimLabel(rt)}驳回'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => onApprove(rt),
                          icon: const Icon(Icons.check, size: 16),
                          label: Text('${_dimLabel(rt)}通过'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ],
                  ),
                if (canSubmit)
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onComplete,
                          icon: const Icon(Icons.done_all),
                          label: const Text('提交结案'),
                        ),
                      ),
                    ],
                  ),
                if (canVerify)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onVerify('reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                          ),
                          child: const Text('驳回结案'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => onVerify('approve'),
                          child: const Text('通过结案'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}

Future<String?> _askReason(
  BuildContext context, {
  required String title,
  required String hint,
  bool required = true,
}) async {
  final controller = TextEditingController();
  final res = await showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              if (required && v.isEmpty) return;
              Navigator.of(ctx).pop(v);
            },
            child: const Text('确定'),
          ),
        ],
      );
    },
  );
  return res;
}
