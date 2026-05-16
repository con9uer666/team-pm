import 'package:flutter/material.dart';

/// Common task / meeting / objective status -> Chinese label + color.
/// Mirrors `frontend/src/utils/status.ts` semantics so the apps stay in sync.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.compact = false});

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final spec = _specFor(status);
    final padH = compact ? 6.0 : 10.0;
    final padV = compact ? 1.0 : 3.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: spec.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: spec.fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        spec.label,
        style: TextStyle(
          color: spec.fg,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Spec {
  const _Spec(this.label, this.fg, this.bg);
  final String label;
  final Color fg;
  final Color bg;
}

_Spec _specFor(String status) {
  switch (status) {
    // task statuses
    case 'pending_review':
      return const _Spec('待审核', Color(0xFFB45309), Color(0xFFFEF3C7));
    case 'approved':
    case 'in_progress':
      return const _Spec('进行中', Color(0xFF1D4ED8), Color(0xFFDBEAFE));
    case 'pending_completion':
      return const _Spec('待结案审核', Color(0xFF7C3AED), Color(0xFFEDE9FE));
    case 'completed':
      return const _Spec('已完成', Color(0xFF047857), Color(0xFFD1FAE5));
    case 'rejected':
      return const _Spec('已驳回', Color(0xFFB91C1C), Color(0xFFFEE2E2));
    case 'overdue':
      return const _Spec('已逾期', Color(0xFFB91C1C), Color(0xFFFEE2E2));
    case 'cancelled':
      return const _Spec('已取消', Color(0xFF475569), Color(0xFFE2E8F0));
    // meeting statuses
    case 'scheduled':
      return const _Spec('待开始', Color(0xFF1D4ED8), Color(0xFFDBEAFE));
    case 'ended':
      return const _Spec('已结束', Color(0xFF475569), Color(0xFFE2E8F0));
    // objective / attendance
    case 'active':
      return const _Spec('进行中', Color(0xFF1D4ED8), Color(0xFFDBEAFE));
    case 'auto_ended':
      return const _Spec('自动结束', Color(0xFFB45309), Color(0xFFFEF3C7));
    // approval
    case 'pending':
      return const _Spec('审核中', Color(0xFFB45309), Color(0xFFFEF3C7));
    case 'approved_approval':
      return const _Spec('已通过', Color(0xFF047857), Color(0xFFD1FAE5));
    default:
      return _Spec(status, const Color(0xFF475569), const Color(0xFFE2E8F0));
  }
}
