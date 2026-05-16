import 'package:flutter/material.dart';

enum TaskStatus {
  pendingReview,
  approved,
  pendingCompletion,
  completed,
  rejected,
  overdue,
  blocked,
  unknown,
}

TaskStatus parseTaskStatus(String? raw) {
  switch (raw) {
    case 'pending_review':
      return TaskStatus.pendingReview;
    case 'approved':
      return TaskStatus.approved;
    case 'pending_completion':
      return TaskStatus.pendingCompletion;
    case 'completed':
      return TaskStatus.completed;
    case 'rejected':
      return TaskStatus.rejected;
    case 'overdue':
      return TaskStatus.overdue;
    case 'blocked':
      return TaskStatus.blocked;
    default:
      return TaskStatus.unknown;
  }
}

class TaskStatusStyle {
  const TaskStatusStyle({required this.label, required this.fg, required this.border});
  final String label;
  final Color fg;
  final Color border;
}

TaskStatusStyle taskStatusStyle(TaskStatus s) {
  switch (s) {
    case TaskStatus.pendingReview:
      return const TaskStatusStyle(label: '待审核', fg: Color(0xFFD97706), border: Color(0xFFF59E0B));
    case TaskStatus.approved:
      return const TaskStatusStyle(label: '进行中', fg: Color(0xFF2563EB), border: Color(0xFF3B82F6));
    case TaskStatus.pendingCompletion:
      return const TaskStatusStyle(label: '待结案', fg: Color(0xFF7C3AED), border: Color(0xFF8B5CF6));
    case TaskStatus.completed:
      return const TaskStatusStyle(label: '已完成', fg: Color(0xFF16A34A), border: Color(0xFF22C55E));
    case TaskStatus.rejected:
      return const TaskStatusStyle(label: '已驳回', fg: Color(0xFFDC2626), border: Color(0xFFEF4444));
    case TaskStatus.overdue:
      return const TaskStatusStyle(label: '已逾期', fg: Color(0xFFDC2626), border: Color(0xFFEF4444));
    case TaskStatus.blocked:
      return const TaskStatusStyle(label: '阻塞中', fg: Color(0xFF6B7280), border: Color(0xFF9CA3AF));
    case TaskStatus.unknown:
      return const TaskStatusStyle(label: '未知', fg: Color(0xFF6B7280), border: Color(0xFF9CA3AF));
  }
}

class TaskReview {
  const TaskReview({
    required this.id,
    required this.taskId,
    required this.reviewerId,
    required this.reviewType,
    required this.status,
    required this.rejectionReason,
    required this.reviewedAt,
  });

  final String id;
  final String taskId;
  final String reviewerId;
  final String reviewType; // division | group
  final String status; // approved | rejected
  final String? rejectionReason;
  final DateTime reviewedAt;

  factory TaskReview.fromJson(Map<String, dynamic> j) {
    return TaskReview(
      id: j['id'] as String,
      taskId: j['taskId'] as String,
      reviewerId: j['reviewerId'] as String,
      reviewType: (j['reviewType'] ?? '') as String,
      status: (j['status'] ?? '') as String,
      rejectionReason: j['rejectionReason'] as String?,
      reviewedAt: DateTime.parse(j['reviewedAt'] as String),
    );
  }
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.creatorId,
    required this.assigneeId,
    required this.status,
    required this.rawStatus,
    required this.priority,
    required this.dueDate,
    required this.completedAt,
    required this.rejectionReason,
    required this.completionNote,
    required this.completionAttachments,
    required this.reviews,
    required this.reviewableTypes,
    required this.canVerifyCompletion,
    required this.createdAt,
    this.groupId,
    this.divisionId,
    this.objectiveId,
    this.objectiveTitle,
    this.dependencyIds = const [],
  });

  final String id;
  final String title;
  final String? description;
  final String? content;
  final String creatorId;
  final String assigneeId;
  final TaskStatus status;
  final String rawStatus;
  final int priority;
  final DateTime dueDate;
  final DateTime? completedAt;
  final String? rejectionReason;
  final String? completionNote;
  final List<String> completionAttachments;
  final List<TaskReview> reviews;
  final List<String> reviewableTypes;
  final bool canVerifyCompletion;
  final DateTime createdAt;
  final String? groupId;
  final String? divisionId;
  final String? objectiveId;
  final String? objectiveTitle;
  final List<String> dependencyIds;

  factory TaskItem.fromJson(Map<String, dynamic> j) {
    final rawStatus = (j['status'] ?? '') as String;
    // Backend may inline `objective: { id, title }` or just `objectiveId`.
    final objectiveJson = j['objective'];
    String? oid = j['objectiveId'] as String?;
    String? otitle;
    if (objectiveJson is Map<String, dynamic>) {
      oid ??= objectiveJson['id'] as String?;
      otitle = objectiveJson['title'] as String?;
    }
    return TaskItem(
      id: j['id'] as String,
      title: (j['title'] ?? '') as String,
      description: j['description'] as String?,
      content: j['content'] as String?,
      creatorId: (j['creatorId'] ?? '') as String,
      assigneeId: (j['assigneeId'] ?? '') as String,
      status: parseTaskStatus(rawStatus),
      rawStatus: rawStatus,
      priority: (j['priority'] ?? 0) as int,
      dueDate: DateTime.parse(j['dueDate'] as String),
      completedAt: j['completedAt'] == null ? null : DateTime.parse(j['completedAt'] as String),
      rejectionReason: j['rejectionReason'] as String?,
      completionNote: j['completionNote'] as String?,
      completionAttachments: ((j['completionAttachments'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      reviews: ((j['reviews'] as List?) ?? const [])
          .map((e) => TaskReview.fromJson(e as Map<String, dynamic>))
          .toList(),
      reviewableTypes: ((j['reviewableTypes'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      canVerifyCompletion: (j['canVerifyCompletion'] ?? false) as bool,
      createdAt: j['createdAt'] == null
          ? DateTime.parse(j['dueDate'] as String).subtract(const Duration(days: 1))
          : DateTime.parse(j['createdAt'] as String),
      groupId: j['groupId'] as String?,
      divisionId: j['divisionId'] as String?,
      objectiveId: oid,
      objectiveTitle: otitle,
      dependencyIds: ((j['dependencyIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
