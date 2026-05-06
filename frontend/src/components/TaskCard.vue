<script setup lang="ts">
import type { TaskWithMeta, TaskReviewInfo } from '../api/tasks'

const props = defineProps<{
  task: TaskWithMeta
  showAssignee: boolean
  assigneeName?: string
  groupName?: string
  divisionName?: string
}>()

const emit = defineEmits<{
  complete: [id: string]
  review: [id: string, type: 'division' | 'group']
  reject: [id: string, type: 'division' | 'group']
  resubmit: [id: string]
  'verify-completion': [id: string, action: 'approve' | 'reject']
}>()

const statusConfig: Record<string, { text: string; color: string; border: string }> = {
  pending_review: { text: '待审核', color: '#d97706', border: '#f59e0b' },
  approved: { text: '进行中', color: '#2563eb', border: '#3b82f6' },
  rejected: { text: '已驳回', color: '#dc2626', border: '#ef4444' },
  pending_completion: { text: '待结案', color: '#7c3aed', border: '#8b5cf6' },
  completed: { text: '已完成', color: '#16a34a', border: '#22c55e' },
  overdue: { text: '已逾期', color: '#dc2626', border: '#ef4444' },
  blocked: { text: '阻塞中', color: '#6b7280', border: '#9ca3af' },
}

function formatDate(d: string) {
  const date = new Date(d)
  return `${date.getMonth() + 1}-${date.getDate().toString().padStart(2, '0')}`
}

function formatOverdue(minutes: number) {
  if (minutes < 60) return `${minutes}分钟`
  const h = Math.floor(minutes / 60)
  const m = minutes % 60
  return m > 0 ? `${h}h${m}m` : `${h}h`
}

function getReviewStatus(type: 'division' | 'group'): TaskReviewInfo | undefined {
  return props.task.reviews?.find(r => r.reviewType === type)
}

function canReview(type: 'division' | 'group') {
  return props.task.reviewableTypes?.includes(type) && !getReviewStatus(type)
}

const hasAction = canReview('division') || canReview('group') ||
  props.task.status === 'approved' || props.task.status === 'overdue' ||
  (props.task.status === 'pending_completion' && props.task.canVerifyCompletion)
</script>

<template>
  <div class="task-card" :style="{ '--status-color': statusConfig[task.status]?.border }">
    <div class="task-card__header">
      <span class="task-card__status" :style="{ color: statusConfig[task.status]?.color }">
        {{ statusConfig[task.status]?.text }}
      </span>
      <span v-if="task.priority > 0" class="task-card__priority" :class="{ high: task.priority === 2 }">
        {{ task.priority === 2 ? '紧急' : '重要' }}
      </span>
      <span class="task-card__date">{{ formatDate(task.dueDate) }}</span>
    </div>

    <div class="task-card__title">{{ task.title }}</div>

    <div class="task-card__footer">
      <div class="task-card__tags">
        <span v-if="divisionName" class="tag">{{ divisionName }}</span>
        <span v-if="groupName" class="tag">{{ groupName }}</span>
        <span v-if="showAssignee && assigneeName" class="tag assignee">{{ assigneeName }}</span>
      </div>
      <span v-if="task.overdueMinutes > 0" class="task-card__overdue">
        逾期{{ formatOverdue(task.overdueMinutes) }}
      </span>
    </div>

    <div v-if="hasAction" class="task-card__actions" @click.stop>
      <van-button v-if="task.status === 'approved' || task.status === 'overdue'" size="mini" type="success" round @click="emit('complete', task.id)">提交结案</van-button>
      <template v-if="task.status === 'pending_completion' && task.canVerifyCompletion">
        <van-button size="mini" type="success" round @click="emit('verify-completion', task.id, 'approve')">通过</van-button>
        <van-button size="mini" type="danger" round plain @click="emit('verify-completion', task.id, 'reject')">驳回</van-button>
      </template>
      <template v-if="canReview('division')">
        <van-button size="mini" type="success" round @click="emit('review', task.id, 'division')">兵种✓</van-button>
        <van-button size="mini" type="danger" round plain @click="emit('reject', task.id, 'division')">兵种✗</van-button>
      </template>
      <template v-if="canReview('group')">
        <van-button size="mini" type="success" round @click="emit('review', task.id, 'group')">技术组✓</van-button>
        <van-button size="mini" type="danger" round plain @click="emit('reject', task.id, 'group')">技术组✗</van-button>
      </template>
    </div>
  </div>
</template>

<style scoped>
.task-card {
  background: var(--bg-card, #fff);
  border-radius: 10px;
  padding: 12px 14px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.06);
  border-left: 3px solid var(--status-color, #e2e8f0);
  cursor: pointer;
  transition: transform 0.15s, box-shadow 0.15s;
}

.task-card:active {
  transform: scale(0.97);
}

.task-card__header {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 4px;
}

.task-card__status {
  font-size: 11px;
  font-weight: 600;
}

.task-card__priority {
  font-size: 10px;
  font-weight: 600;
  padding: 1px 5px;
  border-radius: 3px;
  background: #fef3c7;
  color: #d97706;
}

.task-card__priority.high {
  background: #fee2e2;
  color: #dc2626;
}

.task-card__date {
  margin-left: auto;
  font-size: 11px;
  color: var(--text-muted, #8c8c8c);
}

.task-card__title {
  font-size: 14px;
  font-weight: 600;
  color: var(--text-primary, #1a1a1a);
  line-height: 1.3;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.task-card__footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 6px;
  gap: 8px;
}

.task-card__tags {
  display: flex;
  gap: 4px;
  flex-wrap: wrap;
  min-width: 0;
}

.tag {
  font-size: 11px;
  padding: 1px 6px;
  border-radius: 3px;
  background: #f1f5f9;
  color: var(--text-secondary, #666);
  white-space: nowrap;
}

.tag.assignee {
  background: #ede9fe;
  color: #7c3aed;
}

.task-card__overdue {
  font-size: 11px;
  font-weight: 500;
  color: #dc2626;
  white-space: nowrap;
  flex-shrink: 0;
}

.task-card__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 8px;
  padding-top: 8px;
  border-top: 1px solid #f1f5f9;
}
</style>
