export interface TaskStatusSpec {
  text: string
  color: string
  border: string
}

/// Task status -> Chinese label + colors. Mirrors the iOS `taskStatusStyle`
/// in mobile/lib/features/tasks/data/task_models.dart so both ends stay in sync.
export const taskStatusConfig: Record<string, TaskStatusSpec> = {
  pending_review: { text: '待审核', color: '#d97706', border: '#f59e0b' },
  approved: { text: '进行中', color: '#2563eb', border: '#3b82f6' },
  rejected: { text: '已驳回', color: '#dc2626', border: '#ef4444' },
  pending_completion: { text: '待结案', color: '#7c3aed', border: '#8b5cf6' },
  completed: { text: '已完成', color: '#16a34a', border: '#22c55e' },
  overdue: { text: '已逾期', color: '#dc2626', border: '#ef4444' },
  blocked: { text: '阻塞中', color: '#6b7280', border: '#9ca3af' },
}

export function taskStatusLabel(status: string): string {
  return taskStatusConfig[status]?.text ?? status
}
