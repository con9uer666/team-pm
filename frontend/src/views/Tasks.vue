<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { showToast } from 'vant'
import { tasksApi, type Task, type TaskWithMeta, type TaskReviewInfo, type CreateTaskDto } from '../api/tasks'
import { usersApi, orgApi, type UserInfo, type GroupInfo, type DivisionInfo } from '../api/users'
import { useAuthStore } from '../stores/auth'
import TaskCard from '../components/TaskCard.vue'
import FileUploader from '../components/FileUploader.vue'

const router = useRouter()
const auth = useAuthStore()
const activeTab = ref(0)
const statusFilter = ref('')
const viewMode = ref<'list' | 'person' | 'gantt'>('list')
const tasks = ref<TaskWithMeta[]>([])
const allTasks = ref<Task[]>([])
const groups = ref<GroupInfo[]>([])
const divisions = ref<DivisionInfo[]>([])
const members = ref<UserInfo[]>([])
const currentUser = ref<UserInfo | null>(null)
const loading = ref(false)
const showCreate = ref(false)
const showRejectDialog = ref(false)
const rejectReason = ref('')
const rejectTarget = ref<{ id: string; type: 'division' | 'group' } | null>(null)

const showCompleteDialog = ref(false)
const completeTarget = ref<string>('')
const completeAttachments = ref<string[]>([])
const completeNote = ref('')

const showVerifyDialog = ref(false)
const verifyTarget = ref<string>('')
const verifyAction = ref<'approve' | 'reject'>('approve')
const verifyReason = ref('')

const isLeader = computed(() => (auth.user?.roleLevel || 0) >= 3)
const isManager = computed(() => (auth.user?.roleLevel || 0) >= 4 || auth.user?.isSuperAdmin)

const statusFilters = [
  { value: '', text: '全部' },
  { value: 'pending_review', text: '待审核' },
  { value: 'approved', text: '进行中' },
  { value: 'pending_completion', text: '待结案审核' },
  { value: 'completed', text: '已完成' },
  { value: 'rejected', text: '已驳回' },
  { value: 'overdue', text: '已逾期' },
]

const statusConfig: Record<string, { text: string; color: string; border: string }> = {
  pending_review: { text: '待审核', color: '#d97706', border: '#f59e0b' },
  approved: { text: '进行中', color: '#2563eb', border: '#3b82f6' },
  rejected: { text: '已驳回', color: '#dc2626', border: '#ef4444' },
  pending_completion: { text: '待结案', color: '#7c3aed', border: '#8b5cf6' },
  completed: { text: '已完成', color: '#16a34a', border: '#22c55e' },
  overdue: { text: '已逾期', color: '#dc2626', border: '#ef4444' },
  blocked: { text: '阻塞中', color: '#6b7280', border: '#9ca3af' },
}

const filteredTasks = computed(() => {
  const scope = activeTab.value === 0 ? 'own' : 'team'
  let list = tasks.value
  if (scope === 'own') {
    list = list.filter(t => t.assigneeId === auth.user?.id)
  } else {
    list = list.filter(t => t.assigneeId !== auth.user?.id)
  }
  if (statusFilter.value) {
    list = list.filter(t => t.status === statusFilter.value)
  }
  return list
})

const myDivisions = computed(() => {
  const ids = currentUser.value?.divisionIds || []
  return divisions.value.filter(d => ids.includes(d.id))
})

const myGroups = computed(() => {
  const ids = currentUser.value?.groupIds || []
  return groups.value.filter(g => ids.includes(g.id))
})

const isAssignMode = ref(false)
const selectedLeaderRole = ref<{ type: 'division' | 'group'; id: string } | null>(null)
const selectedAssigneeId = ref<string>('')

const leaderRoles = computed(() => {
  const userId = auth.user?.id
  if (!userId) return []
  const roles: { type: 'division' | 'group'; id: string; label: string }[] = []
  for (const d of divisions.value) {
    if (d.leaderIds?.includes(userId)) {
      roles.push({ type: 'division', id: d.id, label: `[兵种] ${d.name}` })
    }
  }
  for (const g of groups.value) {
    if (g.leaderIds?.includes(userId)) {
      roles.push({ type: 'group', id: g.id, label: `[技术组] ${g.name}` })
    }
  }
  return roles
})

const assignableMembers = computed(() => {
  if (!selectedLeaderRole.value) return []
  const role = selectedLeaderRole.value
  return members.value.filter(m => {
    if (m.id === auth.user?.id) return false
    if (role.type === 'division') {
      return m.divisionIds?.includes(role.id)
    } else {
      return m.groupIds?.includes(role.id)
    }
  })
})

const assigneeOtherDimOptions = computed(() => {
  if (!selectedAssigneeId.value || !selectedLeaderRole.value) return []
  const assignee = members.value.find(m => m.id === selectedAssigneeId.value)
  if (!assignee) return []
  if (selectedLeaderRole.value.type === 'division') {
    return groups.value.filter(g => assignee.groupIds?.includes(g.id))
  } else {
    return divisions.value.filter(d => assignee.divisionIds?.includes(d.id))
  }
})

const newTask = ref<CreateTaskDto & { selectedDeps: string[] }>({
  title: '',
  divisionId: undefined,
  groupId: undefined,
  completionRequirements: '',
  dueDate: '',
  dependencyIds: [],
  selectedDeps: [],
})
const showDepPicker = ref(false)

function onAssignModeChange(val: boolean) {
  if (!val) {
    selectedLeaderRole.value = null
    selectedAssigneeId.value = ''
    newTask.value.assigneeId = undefined
    newTask.value.divisionId = undefined
    newTask.value.groupId = undefined
  }
}

function onLeaderRoleChange(key: string) {
  const [type, id] = key.split(':') as ['division' | 'group', string]
  selectedLeaderRole.value = { type, id }
  selectedAssigneeId.value = ''
  newTask.value.assigneeId = undefined
  if (type === 'division') {
    newTask.value.divisionId = id
    newTask.value.groupId = undefined
  } else {
    newTask.value.groupId = id
    newTask.value.divisionId = undefined
  }
}

function onAssigneeChange(assigneeId: string) {
  selectedAssigneeId.value = assigneeId
  newTask.value.assigneeId = assigneeId
  const opts = assigneeOtherDimOptions.value
  if (opts.length === 1) {
    if (selectedLeaderRole.value?.type === 'division') {
      newTask.value.groupId = opts[0].id
    } else {
      newTask.value.divisionId = opts[0].id
    }
  } else {
    if (selectedLeaderRole.value?.type === 'division') {
      newTask.value.groupId = undefined
    } else {
      newTask.value.divisionId = undefined
    }
  }
}

async function loadData() {
  loading.value = true
  try {
    const [scopeTasks, structure, me, all] = await Promise.all([
      tasksApi.getMyScope({ status: undefined }),
      orgApi.getStructure(),
      usersApi.getMe(),
      tasksApi.getAll(),
    ])
    tasks.value = scopeTasks
    members.value = structure.users as UserInfo[]
    groups.value = structure.groups
    divisions.value = structure.divisions
    currentUser.value = me
    allTasks.value = all
  } catch (e: any) {
    showToast({ message: e.message || '加载失败', type: 'fail' })
  } finally {
    loading.value = false
  }
}

function getMemberName(id: string) {
  return members.value.find(m => m.id === id)?.realName || '未知'
}

function getGroupName(id: string | null) {
  if (!id) return ''
  return groups.value.find(g => g.id === id)?.name || ''
}

function getDivisionName(id: string | null) {
  if (!id) return ''
  return divisions.value.find(d => d.id === id)?.name || ''
}

async function handleComplete(id: string) {
  completeTarget.value = id
  completeAttachments.value = []
  completeNote.value = ''
  showCompleteDialog.value = true
}

async function submitComplete() {
  if (!completeAttachments.value.length) {
    showToast({ message: '请上传至少一个附件', type: 'fail' })
    return
  }
  try {
    await tasksApi.complete(completeTarget.value, {
      attachments: completeAttachments.value,
      note: completeNote.value || undefined,
    })
    showToast({ message: '已提交结案', type: 'success' })
    showCompleteDialog.value = false
    await loadData()
  } catch (e: any) {
    showToast({ message: e.message || '操作失败', type: 'fail' })
  }
}

function handleVerifyCompletion(id: string, action: 'approve' | 'reject') {
  if (action === 'approve') {
    submitVerifyCompletion(id, 'approve')
  } else {
    verifyTarget.value = id
    verifyAction.value = 'reject'
    verifyReason.value = ''
    showVerifyDialog.value = true
  }
}

async function submitVerifyCompletion(id?: string, action?: 'approve' | 'reject') {
  const taskId = id || verifyTarget.value
  const act = action || verifyAction.value
  try {
    await tasksApi.verifyCompletion(taskId, {
      action: act,
      reason: act === 'reject' ? verifyReason.value : undefined,
    })
    showToast({ message: act === 'approve' ? '已通过结案' : '已驳回结案', type: 'success' })
    showVerifyDialog.value = false
    await loadData()
  } catch (e: any) {
    showToast({ message: e.message || '操作失败', type: 'fail' })
  }
}

async function handleReview(id: string, type: 'division' | 'group') {
  try {
    await tasksApi.review(id, { action: 'approve', reviewType: type })
    showToast({ message: '已通过', type: 'success' })
    await loadData()
  } catch (e: any) {
    showToast({ message: e.message || '操作失败', type: 'fail' })
  }
}

function handleReject(id: string, type: 'division' | 'group') {
  rejectTarget.value = { id, type }
  rejectReason.value = ''
  showRejectDialog.value = true
}

async function submitReject() {
  if (!rejectTarget.value || !rejectReason.value) {
    showToast({ message: '请填写驳回原因', type: 'fail' })
    return
  }
  try {
    await tasksApi.review(rejectTarget.value.id, {
      action: 'reject',
      reviewType: rejectTarget.value.type,
      reason: rejectReason.value,
    })
    showToast({ message: '已驳回', type: 'success' })
    showRejectDialog.value = false
    await loadData()
  } catch (e: any) {
    showToast({ message: e.message || '操作失败', type: 'fail' })
  }
}

async function createTask() {
  if (!newTask.value.title) {
    showToast({ message: '请填写任务内容', type: 'fail' })
    return
  }
  if (!newTask.value.divisionId || !newTask.value.groupId) {
    showToast({ message: '请选择兵种和技术组', type: 'fail' })
    return
  }
  if (!newTask.value.dueDate) {
    showToast({ message: '请选择结案日期', type: 'fail' })
    return
  }
  if (!newTask.value.completionRequirements) {
    showToast({ message: '请填写结案要求', type: 'fail' })
    return
  }
  try {
    const dto: CreateTaskDto = {
      title: newTask.value.title,
      dueDate: newTask.value.dueDate,
      divisionId: newTask.value.divisionId,
      groupId: newTask.value.groupId,
      completionRequirements: newTask.value.completionRequirements,
    }
    if (newTask.value.selectedDeps.length) dto.dependencyIds = newTask.value.selectedDeps
    if (newTask.value.assigneeId) dto.assigneeId = newTask.value.assigneeId

    await tasksApi.create(dto)
    showToast({ message: '任务创建成功', type: 'success' })
    showCreate.value = false
    isAssignMode.value = false
    selectedLeaderRole.value = null
    selectedAssigneeId.value = ''
    newTask.value = { title: '', divisionId: undefined, groupId: undefined, completionRequirements: '', dueDate: '', dependencyIds: [], selectedDeps: [] }
    await loadData()
  } catch (e: any) {
    showToast({ message: e.message || '创建失败', type: 'fail' })
  }
}

function toggleDep(id: string) {
  const idx = newTask.value.selectedDeps.indexOf(id)
  if (idx >= 0) {
    newTask.value.selectedDeps.splice(idx, 1)
  } else {
    newTask.value.selectedDeps.push(id)
  }
}

function getDepTaskTitle(id: string) {
  return allTasks.value.find(t => t.id === id)?.title || '未知任务'
}

// Detail popup
const showDetail = ref(false)
const detailTask = ref<Task | null>(null)
const detailReviews = ref<TaskReviewInfo[]>([])
const detailDeps = ref<Task[]>([])
const detailLoading = ref(false)

async function openDetail(id: string) {
  showDetail.value = true
  detailLoading.value = true
  try {
    const [t, revs, deps] = await Promise.all([
      tasksApi.getById(id),
      tasksApi.getReviews(id),
      tasksApi.getDependencies(id),
    ])
    detailTask.value = t
    detailReviews.value = revs
    detailDeps.value = deps
  } catch (e: any) {
    showToast({ message: e.message || '加载失败', type: 'fail' })
  } finally {
    detailLoading.value = false
  }
}

function formatDateTime(d: string) {
  const date = new Date(d)
  return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')} ${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`
}

function formatOverdue(minutes: number) {
  if (minutes < 60) return `${minutes}分钟`
  const h = Math.floor(minutes / 60)
  const m = minutes % 60
  return m > 0 ? `${h}小时${m}分钟` : `${h}小时`
}

// Person view
const personCollapseActive = ref<string[]>([])

const tasksByPerson = computed(() => {
  const map = new Map<string, { name: string; tasks: TaskWithMeta[] }>()
  for (const t of filteredTasks.value) {
    if (!map.has(t.assigneeId)) {
      map.set(t.assigneeId, { name: getMemberName(t.assigneeId), tasks: [] })
    }
    map.get(t.assigneeId)!.tasks.push(t)
  }
  return Array.from(map.entries()).map(([id, data]) => ({
    id,
    name: data.name,
    tasks: data.tasks,
    total: data.tasks.length,
    completed: data.tasks.filter(t => t.status === 'completed').length,
  }))
})

// Gantt view
const ganttScale = ref<'week' | 'month'>('week')
const ganttOffset = ref(0)

const ganttRange = computed(() => {
  const now = new Date()
  const start = new Date(now)
  if (ganttScale.value === 'week') {
    const day = start.getDay() || 7
    start.setDate(start.getDate() - day + 1 + ganttOffset.value * 7)
    const end = new Date(start)
    end.setDate(end.getDate() + 6)
    return { start, end, days: 7 }
  } else {
    start.setDate(1)
    start.setMonth(start.getMonth() + ganttOffset.value)
    const end = new Date(start.getFullYear(), start.getMonth() + 1, 0)
    const days = end.getDate()
    return { start, end, days }
  }
})

const ganttDates = computed(() => {
  const { start, days } = ganttRange.value
  const dates: string[] = []
  for (let i = 0; i < days; i++) {
    const d = new Date(start)
    d.setDate(d.getDate() + i)
    dates.push(`${d.getMonth() + 1}-${d.getDate().toString().padStart(2, '0')}`)
  }
  return dates
})

const ganttRangeLabel = computed(() => {
  const { start, end } = ganttRange.value
  if (ganttScale.value === 'week') {
    return `${start.getMonth() + 1}/${start.getDate()} - ${end.getMonth() + 1}/${end.getDate()}`
  }
  return `${start.getFullYear()}年${start.getMonth() + 1}月`
})

function ganttBarStyle(task: TaskWithMeta) {
  const { start, days } = ganttRange.value
  const rangeStart = start.getTime()
  const dayMs = 86400000
  const rangeEnd = rangeStart + days * dayMs

  const taskStart = new Date(task.createdAt).getTime()
  const taskEnd = new Date(task.dueDate).getTime()

  const clampedStart = Math.max(taskStart, rangeStart)
  const clampedEnd = Math.min(taskEnd, rangeEnd)

  if (clampedStart >= rangeEnd || clampedEnd <= rangeStart) return null

  const left = ((clampedStart - rangeStart) / (days * dayMs)) * 100
  const width = ((clampedEnd - clampedStart) / (days * dayMs)) * 100

  const color = task.status === 'completed' ? '#22c55e' : task.status === 'overdue' ? '#ef4444' : '#3b82f6'
  const totalDays = Math.ceil((taskEnd - taskStart) / dayMs)
  const overflowLeft = taskStart < rangeStart
  const overflowRight = taskEnd > rangeEnd

  return { left: `${left}%`, width: `${Math.max(width, 1.5)}%`, background: color, totalDays, overflowLeft, overflowRight }
}

onMounted(loadData)
</script>

<template>
  <div class="tasks-page">
    <div class="page-header">
      <h2>任务中心</h2>
      <div class="header-actions">
        <van-button size="small" type="primary" @click="showCreate = true">创建任务</van-button>
      </div>
    </div>

    <van-tabs v-if="isLeader" v-model:active="activeTab" shrink sticky @change="statusFilter = ''">
      <van-tab :title="'我的任务'" />
      <van-tab :title="isManager ? '全部任务' : '组员任务'" />
    </van-tabs>

    <!-- View mode switcher -->
    <div class="view-switcher">
      <span class="view-btn" :class="{ active: viewMode === 'list' }" @click="viewMode = 'list'">
        <van-icon name="bars" /> 列表
      </span>
      <span class="view-btn" :class="{ active: viewMode === 'person' }" @click="viewMode = 'person'">
        <van-icon name="friends-o" /> 人员
      </span>
      <span class="view-btn" :class="{ active: viewMode === 'gantt' }" @click="viewMode = 'gantt'">
        <van-icon name="chart-trending-o" /> 甘特
      </span>
    </div>

    <div class="status-filters">
      <span
        v-for="f in statusFilters"
        :key="f.value"
        class="filter-chip"
        :class="{ active: statusFilter === f.value }"
        @click="statusFilter = f.value"
      >{{ f.text }}</span>
    </div>

    <van-pull-refresh v-model="loading" @refresh="loadData">
      <van-empty v-if="!filteredTasks.length && !loading" description="暂无任务" />

      <!-- List View -->
      <div v-if="viewMode === 'list'" class="task-list">
        <TaskCard
          v-for="task in filteredTasks"
          :key="task.id"
          :task="task"
          :show-assignee="activeTab === 1"
          :assignee-name="getMemberName(task.assigneeId)"
          :group-name="getGroupName(task.groupId)"
          :division-name="getDivisionName(task.divisionId)"
          @click="openDetail(task.id)"
          @complete="handleComplete"
          @review="handleReview"
          @reject="handleReject"
          @resubmit="(id) => router.push(`/tasks/${id}/edit`)"
          @verify-completion="handleVerifyCompletion"
        />
      </div>

      <!-- Person View -->
      <div v-else-if="viewMode === 'person'" class="person-view">
        <van-collapse v-model="personCollapseActive">
          <van-collapse-item v-for="p in tasksByPerson" :key="p.id" :name="p.id">
            <template #title>
              <div class="person-header">
                <span class="person-name">{{ p.name }}</span>
                <span class="person-stats">{{ p.completed }}/{{ p.total }} 完成</span>
                <van-progress :percentage="p.total ? Math.round(p.completed / p.total * 100) : 0" stroke-width="3" :show-pivot="false" style="width: 60px;" />
              </div>
            </template>
            <div class="person-tasks">
              <div v-for="t in p.tasks" :key="t.id" class="person-task-row" @click="openDetail(t.id)">
                <span class="person-task-dot" :style="{ background: statusConfig[t.status]?.border }"></span>
                <span class="person-task-title">{{ t.title }}</span>
                <span class="person-task-status">{{ statusConfig[t.status]?.text }}</span>
              </div>
            </div>
          </van-collapse-item>
        </van-collapse>
      </div>

      <!-- Gantt View -->
      <div v-else-if="viewMode === 'gantt'" class="gantt-view">
        <div class="gantt-nav">
          <van-button size="mini" plain @click="ganttOffset--">←</van-button>
          <span class="gantt-nav__label">{{ ganttRangeLabel }}</span>
          <van-button size="mini" plain @click="ganttOffset++">→</van-button>
          <van-button size="mini" plain @click="ganttOffset = 0">今</van-button>
          <span class="gantt-nav__scale">
            <span :class="{ active: ganttScale === 'week' }" @click="ganttScale = 'week'; ganttOffset = 0">周</span>
            <span :class="{ active: ganttScale === 'month' }" @click="ganttScale = 'month'; ganttOffset = 0">月</span>
          </span>
        </div>
        <div class="gantt-wrapper">
          <div class="gantt-table">
            <div class="gantt-header">
              <div class="gantt-left-col gantt-left-header">任务</div>
              <div class="gantt-right-col">
                <div class="gantt-dates" :style="{ gridTemplateColumns: `repeat(${ganttRange.days}, 1fr)` }">
                  <span v-for="d in ganttDates" :key="d" class="gantt-date-cell">{{ d }}</span>
                </div>
              </div>
            </div>
            <div v-if="!filteredTasks.length" class="gantt-empty">暂无任务</div>
            <div v-for="(task, idx) in filteredTasks" :key="task.id" class="gantt-row" @click="openDetail(task.id)">
              <div class="gantt-left-col gantt-task-label">
                <span class="gantt-idx">{{ idx + 1 }}</span>
                <span class="gantt-assignee">{{ getMemberName(task.assigneeId) }}</span>
                <span class="gantt-sep">_</span>
                <span class="gantt-task-name">{{ task.title }}</span>
              </div>
              <div class="gantt-right-col">
                <div class="gantt-bar-track" :style="{ gridTemplateColumns: `repeat(${ganttRange.days}, 1fr)` }">
                  <template v-if="ganttBarStyle(task)">
                    <div class="gantt-bar" :style="{ left: ganttBarStyle(task)!.left, width: ganttBarStyle(task)!.width, background: ganttBarStyle(task)!.background }">
                      <span v-if="ganttBarStyle(task)!.overflowLeft" class="gantt-overflow-arrow left">←</span>
                      <span class="gantt-bar-label">{{ ganttBarStyle(task)!.totalDays }}天</span>
                      <span v-if="ganttBarStyle(task)!.overflowRight" class="gantt-overflow-arrow right">→</span>
                    </div>
                  </template>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </van-pull-refresh>

    <!-- 驳回弹窗 -->
    <van-dialog v-model:show="showRejectDialog" title="驳回原因" show-cancel-button @confirm="submitReject">
      <div style="padding: 16px;">
        <van-field v-model="rejectReason" type="textarea" placeholder="请输入驳回原因" rows="3" />
      </div>
    </van-dialog>

    <!-- 提交结案弹窗 -->
    <van-popup v-model:show="showCompleteDialog" position="bottom" round style="max-height: 70vh;">
      <van-nav-bar title="提交结案" left-text="取消" right-text="提交" @click-left="showCompleteDialog = false" @click-right="submitComplete" />
      <div style="padding: 16px;">
        <p style="font-size: 13px; color: #666; margin: 0 0 12px;">请上传结案证明（图片/视频），至少1个</p>
        <FileUploader v-model="completeAttachments" :max-count="9" />
        <van-field v-model="completeNote" type="textarea" placeholder="结案说明（可选）" rows="2" autosize style="margin-top: 12px;" />
      </div>
    </van-popup>

    <!-- 驳回结案弹窗 -->
    <van-dialog v-model:show="showVerifyDialog" title="驳回结案原因" show-cancel-button @confirm="submitVerifyCompletion()">
      <div style="padding: 16px;">
        <van-field v-model="verifyReason" type="textarea" placeholder="请输入驳回原因" rows="3" />
      </div>
    </van-dialog>

    <!-- 创建任务弹窗 -->
    <van-popup v-model:show="showCreate" position="bottom" round class="create-popup">
      <div class="create-form">
        <van-nav-bar title="创建本周任务" left-text="取消" right-text="提交" @click-left="showCreate = false" @click-right="createTask" />
        <div class="create-form__body">
          <!-- 派发模式开关 -->
          <van-cell-group v-if="isLeader && leaderRoles.length" inset>
            <van-cell title="派发任务" label="为组员创建任务">
              <template #right-icon>
                <van-switch v-model="isAssignMode" size="20" @change="onAssignModeChange" />
              </template>
            </van-cell>
          </van-cell-group>

          <!-- 派发身份 + 指派人 -->
          <van-cell-group v-if="isAssignMode" inset style="margin-top: 10px;">
            <van-field label="派发身份" required>
              <template #input>
                <select class="native-select" :value="selectedLeaderRole ? `${selectedLeaderRole.type}:${selectedLeaderRole.id}` : ''" @change="onLeaderRoleChange(($event.target as HTMLSelectElement).value)">
                  <option disabled value="">请选择</option>
                  <option v-for="r in leaderRoles" :key="`${r.type}:${r.id}`" :value="`${r.type}:${r.id}`">{{ r.label }}</option>
                </select>
              </template>
            </van-field>
            <van-field v-if="selectedLeaderRole" label="指派人" required>
              <template #input>
                <select v-model="selectedAssigneeId" class="native-select" @change="onAssigneeChange(selectedAssigneeId)">
                  <option disabled value="">请选择组员</option>
                  <option v-for="m in assignableMembers" :key="m.id" :value="m.id">{{ m.realName }}</option>
                </select>
              </template>
            </van-field>
          </van-cell-group>

          <van-cell-group inset style="margin-top: 10px;">
            <van-field v-model="newTask.title" label="任务内容" type="textarea" placeholder="描述你本周要完成的任务" rows="3" autosize required />
          </van-cell-group>

          <van-cell-group inset style="margin-top: 10px;">
            <van-field label="兵种" required>
              <template #input>
                <select v-model="newTask.divisionId" class="native-select" :disabled="isAssignMode && selectedLeaderRole?.type === 'division'">
                  <option disabled :value="undefined">请选择</option>
                  <template v-if="isAssignMode">
                    <template v-if="selectedLeaderRole?.type === 'division'">
                      <option :value="selectedLeaderRole.id">{{ divisions.find(d => d.id === selectedLeaderRole!.id)?.name }}</option>
                    </template>
                    <template v-else-if="selectedLeaderRole?.type === 'group' && selectedAssigneeId">
                      <option v-for="d in assigneeOtherDimOptions" :key="d.id" :value="d.id">{{ d.name }}</option>
                    </template>
                  </template>
                  <template v-else>
                    <option v-for="d in myDivisions" :key="d.id" :value="d.id">{{ d.name }}</option>
                  </template>
                </select>
              </template>
            </van-field>
            <van-field label="技术组" required>
              <template #input>
                <select v-model="newTask.groupId" class="native-select" :disabled="isAssignMode && selectedLeaderRole?.type === 'group'">
                  <option disabled :value="undefined">请选择</option>
                  <template v-if="isAssignMode">
                    <template v-if="selectedLeaderRole?.type === 'group'">
                      <option :value="selectedLeaderRole.id">{{ groups.find(g => g.id === selectedLeaderRole!.id)?.name }}</option>
                    </template>
                    <template v-else-if="selectedLeaderRole?.type === 'division' && selectedAssigneeId">
                      <option v-for="g in assigneeOtherDimOptions" :key="g.id" :value="g.id">{{ g.name }}</option>
                    </template>
                  </template>
                  <template v-else>
                    <option v-for="g in myGroups" :key="g.id" :value="g.id">{{ g.name }}</option>
                  </template>
                </select>
              </template>
            </van-field>
          </van-cell-group>

          <van-cell-group inset style="margin-top: 10px;">
            <van-field v-model="newTask.dueDate" label="结案日期" type="date" placeholder="选择日期" required />
            <van-field v-model="newTask.completionRequirements" label="结案要求" type="textarea" placeholder="任务完成的验收标准" rows="2" autosize required />
          </van-cell-group>

          <van-cell-group inset style="margin-top: 10px;">
            <van-cell title="关联任务" is-link @click="showDepPicker = true" :value="newTask.selectedDeps.length ? `已选${newTask.selectedDeps.length}个` : '无'" />
            <van-cell v-for="depId in newTask.selectedDeps" :key="depId" :title="getDepTaskTitle(depId)">
              <template #right-icon>
                <van-icon name="close" color="#ee0a24" @click="toggleDep(depId)" />
              </template>
            </van-cell>
          </van-cell-group>
        </div>
      </div>
    </van-popup>

    <!-- 关联任务选择器 -->
    <van-popup v-model:show="showDepPicker" position="bottom" round style="height: 60%;">
      <van-nav-bar title="选择关联任务" left-text="取消" right-text="确认" @click-left="showDepPicker = false" @click-right="showDepPicker = false" />
      <div style="overflow-y: auto; max-height: calc(60vh - 46px);">
        <van-empty v-if="!allTasks.length" description="暂无可关联的任务" />
        <van-cell-group v-else>
          <van-cell
            v-for="t in allTasks"
            :key="t.id"
            :title="t.title"
            :label="`${new Date(t.dueDate).toLocaleDateString()}`"
            clickable
            @click="toggleDep(t.id)"
          >
            <template #right-icon>
              <van-icon v-if="newTask.selectedDeps.includes(t.id)" name="success" color="#1989fa" size="20" />
            </template>
          </van-cell>
        </van-cell-group>
      </div>
    </van-popup>

    <!-- 任务详情弹窗 -->
    <van-popup v-model:show="showDetail" position="bottom" round style="height: 85vh;">
      <van-nav-bar title="任务详情" left-text="关闭" @click-left="showDetail = false" />
      <div v-if="detailLoading" style="text-align: center; padding: 40px;">
        <van-loading />
      </div>
      <div v-else-if="detailTask" class="detail-body">
        <div class="detail-header">
          <span class="detail-status" :style="{ color: statusConfig[detailTask.status]?.color, background: statusConfig[detailTask.status]?.color + '18' }">
            {{ statusConfig[detailTask.status]?.text }}
          </span>
          <span v-if="detailTask.priority > 0" class="detail-priority" :class="{ high: detailTask.priority === 2 }">
            {{ detailTask.priority === 2 ? '紧急' : '重要' }}
          </span>
          <span v-if="detailTask.overdueMinutes > 0" class="detail-overdue">逾期{{ formatOverdue(detailTask.overdueMinutes) }}</span>
        </div>

        <h3 class="detail-title">{{ detailTask.title }}</h3>

        <div class="detail-info-grid">
          <div class="detail-info-item"><span class="label">创建人</span><span>{{ getMemberName(detailTask.creatorId) }}</span></div>
          <div class="detail-info-item"><span class="label">指派人</span><span>{{ getMemberName(detailTask.assigneeId) }}</span></div>
          <div class="detail-info-item"><span class="label">兵种</span><span>{{ getDivisionName(detailTask.divisionId) || '—' }}</span></div>
          <div class="detail-info-item"><span class="label">技术组</span><span>{{ getGroupName(detailTask.groupId) || '—' }}</span></div>
          <div class="detail-info-item"><span class="label">创建时间</span><span>{{ formatDateTime(detailTask.createdAt) }}</span></div>
          <div class="detail-info-item"><span class="label">截止日期</span><span :class="{ 'text-red': detailTask.status === 'overdue' }">{{ formatDateTime(detailTask.dueDate) }}</span></div>
        </div>

        <div v-if="detailTask.description" class="detail-section">
          <h4>任务描述</h4>
          <p>{{ detailTask.description }}</p>
        </div>

        <div v-if="detailTask.completionRequirements" class="detail-section">
          <h4>结案要求</h4>
          <p>{{ detailTask.completionRequirements }}</p>
        </div>

        <div v-if="detailDeps.length" class="detail-section">
          <h4>依赖任务</h4>
          <div v-for="dep in detailDeps" :key="dep.id" class="detail-dep-row">
            <span class="dep-dot" :style="{ background: statusConfig[dep.status]?.border }"></span>
            <span class="dep-name">{{ dep.title }}</span>
            <span class="dep-st">{{ statusConfig[dep.status]?.text }}</span>
          </div>
        </div>

        <div v-if="detailReviews.length" class="detail-section">
          <h4>审核记录</h4>
          <div v-for="r in detailReviews" :key="r.id" class="detail-review-row">
            <span class="rv-type">{{ r.reviewType === 'division' ? '兵种' : '技术组' }}</span>
            <span class="rv-status" :class="r.status">{{ r.status === 'approved' ? '通过' : '驳回' }}</span>
            <span class="rv-name">{{ getMemberName(r.reviewerId) }}</span>
            <span class="rv-time">{{ formatDateTime(r.reviewedAt) }}</span>
          </div>
        </div>

        <div v-if="detailTask.rejectionReason" class="detail-section">
          <h4>驳回原因</h4>
          <div class="detail-alert">{{ detailTask.rejectionReason }}</div>
        </div>

        <div v-if="detailTask.completionAttachments?.length" class="detail-section">
          <h4>结案信息</h4>
          <p v-if="detailTask.completionNote" style="margin: 0 0 8px; font-size: 13px; color: #666;">{{ detailTask.completionNote }}</p>
          <div class="detail-attachments">
            <a v-for="(url, i) in detailTask.completionAttachments" :key="i" :href="url" target="_blank" class="detail-att-item">
              <img :src="url" />
            </a>
          </div>
          <p v-if="detailTask.completedAt" style="font-size: 12px; color: #8c8c8c; margin: 8px 0 0;">提交时间：{{ formatDateTime(detailTask.completedAt) }}</p>
        </div>

        <div v-if="detailTask.status === 'completed' && detailTask.reviewedBy" class="detail-section">
          <h4>结案审核</h4>
          <div class="detail-review-row">
            <span class="rv-status approved">通过</span>
            <span class="rv-name">{{ getMemberName(detailTask.reviewedBy) }}</span>
            <span v-if="detailTask.reviewedAt" class="rv-time">{{ formatDateTime(detailTask.reviewedAt) }}</span>
          </div>
        </div>
      </div>
    </van-popup>
  </div>
</template>

<style scoped>
.tasks-page {
  max-width: 900px;
  margin: 0 auto;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}

.page-header h2 {
  font-size: 22px;
  font-weight: 700;
  margin: 0;
  color: var(--text-primary);
}

.header-actions {
  display: flex;
  gap: 8px;
}

.status-filters {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding: 12px 0;
  -webkit-overflow-scrolling: touch;
}

.status-filters::-webkit-scrollbar {
  display: none;
}

.filter-chip {
  flex-shrink: 0;
  padding: 5px 14px;
  border-radius: 16px;
  font-size: 13px;
  background: #f1f5f9;
  color: var(--text-secondary, #666);
  cursor: pointer;
  transition: all 0.2s;
}

.filter-chip.active {
  background: #2563eb;
  color: #fff;
  font-weight: 500;
}

.task-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 10px;
  padding-bottom: 20px;
}

.create-popup {
  height: auto !important;
  max-height: 70vh !important;
  max-width: 500px;
  left: 50% !important;
  transform: translateX(-50%);
}

.create-form {
  display: flex;
  flex-direction: column;
  max-height: 70vh;
}

.create-form__body {
  overflow-y: auto;
  padding: 10px 0 20px;
  flex: 1;
}

.native-select {
  width: 100%;
  border: none;
  font-size: 14px;
  background: transparent;
  color: var(--text-primary, #333);
  outline: none;
}

/* View switcher */
.view-switcher {
  display: flex;
  gap: 4px;
  padding: 8px 0;
}

.view-btn {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 4px 12px;
  border-radius: 14px;
  font-size: 12px;
  color: var(--text-secondary, #666);
  cursor: pointer;
  transition: all 0.2s;
}

.view-btn.active {
  background: #2563eb;
  color: #fff;
  font-weight: 500;
}

/* Person view */
.person-view {
  padding-bottom: 20px;
}

.person-header {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
}

.person-name {
  font-size: 14px;
  font-weight: 500;
}

.person-stats {
  font-size: 11px;
  color: var(--text-muted, #8c8c8c);
  margin-left: auto;
  margin-right: 8px;
}

.person-tasks {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.person-task-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 0;
  cursor: pointer;
}

.person-task-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  flex-shrink: 0;
}

.person-task-title {
  font-size: 13px;
  flex: 1;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.person-task-status {
  font-size: 11px;
  color: var(--text-muted, #8c8c8c);
  flex-shrink: 0;
}

/* Gantt view */
.gantt-view {
  padding-bottom: 20px;
}

.gantt-nav {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 0;
  flex-wrap: wrap;
}

.gantt-nav__label {
  font-size: 13px;
  font-weight: 600;
  min-width: 100px;
  text-align: center;
}

.gantt-nav__scale {
  margin-left: auto;
  display: flex;
  gap: 2px;
  background: #f1f5f9;
  border-radius: 12px;
  padding: 2px;
}

.gantt-nav__scale span {
  padding: 3px 10px;
  font-size: 12px;
  border-radius: 10px;
  cursor: pointer;
  color: var(--text-secondary, #666);
}

.gantt-nav__scale span.active {
  background: #2563eb;
  color: #fff;
  font-weight: 500;
}

.gantt-wrapper {
  overflow-x: auto;
  background: var(--bg-card, #fff);
  border-radius: 10px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.06);
}

.gantt-table {
  min-width: 600px;
}

.gantt-header {
  display: flex;
  border-bottom: 1px solid #e2e8f0;
  position: sticky;
  top: 0;
  background: var(--bg-card, #fff);
  z-index: 1;
}

.gantt-left-col {
  width: 180px;
  min-width: 180px;
  flex-shrink: 0;
  padding: 8px 10px;
  border-right: 1px solid #e2e8f0;
}

.gantt-left-header {
  font-size: 12px;
  font-weight: 600;
  color: var(--text-muted, #8c8c8c);
}

.gantt-right-col {
  flex: 1;
  min-width: 0;
  padding: 0;
}

.gantt-dates {
  display: grid;
  height: 100%;
}

.gantt-date-cell {
  font-size: 10px;
  color: var(--text-muted, #8c8c8c);
  text-align: center;
  padding: 8px 2px;
  border-right: 1px solid #f1f5f9;
}

.gantt-empty {
  text-align: center;
  padding: 30px;
  font-size: 13px;
  color: var(--text-muted, #8c8c8c);
}

.gantt-row {
  display: flex;
  border-bottom: 1px solid #f1f5f9;
  cursor: pointer;
  transition: background 0.15s;
}

.gantt-row:hover {
  background: #f8fafc;
}

.gantt-task-label {
  display: flex;
  align-items: center;
  gap: 2px;
  font-size: 12px;
  overflow: hidden;
  white-space: nowrap;
}

.gantt-idx {
  color: var(--text-muted, #8c8c8c);
  min-width: 18px;
  flex-shrink: 0;
}

.gantt-assignee {
  color: #7c3aed;
  font-weight: 500;
  flex-shrink: 0;
}

.gantt-sep {
  color: var(--text-muted, #8c8c8c);
  flex-shrink: 0;
}

.gantt-task-name {
  overflow: hidden;
  text-overflow: ellipsis;
  color: var(--text-primary, #1a1a1a);
}

.gantt-bar-track {
  position: relative;
  height: 100%;
  min-height: 32px;
}

.gantt-bar {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  height: 18px;
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 2px;
  min-width: 20px;
}

.gantt-bar-label {
  font-size: 10px;
  color: #fff;
  font-weight: 600;
  white-space: nowrap;
}

.gantt-overflow-arrow {
  font-size: 10px;
  color: rgba(255, 255, 255, 0.8);
}

.gantt-overflow-arrow.left { margin-right: auto; }
.gantt-overflow-arrow.right { margin-left: auto; }

/* Detail popup */
.detail-body {
  padding: 16px;
  overflow-y: auto;
  max-height: calc(85vh - 46px);
}

.detail-header {
  display: flex;
  align-items: center;
  gap: 8px;
}

.detail-status {
  font-size: 12px;
  font-weight: 600;
  padding: 2px 10px;
  border-radius: 4px;
}

.detail-priority {
  font-size: 11px;
  font-weight: 600;
  padding: 2px 6px;
  border-radius: 3px;
  background: #fef3c7;
  color: #d97706;
}

.detail-priority.high {
  background: #fee2e2;
  color: #dc2626;
}

.detail-overdue {
  font-size: 12px;
  font-weight: 500;
  color: #dc2626;
  margin-left: auto;
}

.detail-title {
  font-size: 18px;
  font-weight: 700;
  margin: 10px 0 14px;
  line-height: 1.4;
}

.detail-info-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  padding: 12px;
  background: #f8fafc;
  border-radius: 8px;
  margin-bottom: 14px;
}

.detail-info-item {
  display: flex;
  flex-direction: column;
  gap: 2px;
  font-size: 13px;
}

.detail-info-item .label {
  font-size: 11px;
  color: var(--text-muted, #8c8c8c);
}

.text-red { color: #dc2626; }

.detail-section {
  margin-bottom: 14px;
}

.detail-section h4 {
  font-size: 13px;
  font-weight: 600;
  margin: 0 0 6px;
  color: var(--text-primary, #1a1a1a);
}

.detail-section p {
  font-size: 13px;
  color: var(--text-secondary, #666);
  line-height: 1.6;
  margin: 0;
  white-space: pre-wrap;
}

.detail-dep-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 0;
}

.dep-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
}

.dep-name {
  font-size: 13px;
  flex: 1;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.dep-st {
  font-size: 11px;
  color: var(--text-muted, #8c8c8c);
}

.detail-review-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 4px 0;
  font-size: 13px;
}

.rv-type {
  font-weight: 500;
  min-width: 42px;
}

.rv-status.approved { color: #16a34a; font-weight: 600; }
.rv-status.rejected { color: #dc2626; font-weight: 600; }

.rv-name { color: var(--text-secondary, #666); }
.rv-time { font-size: 11px; color: var(--text-muted, #8c8c8c); margin-left: auto; }

.detail-alert {
  padding: 8px 12px;
  border-radius: 6px;
  background: #fff2f0;
  color: #dc2626;
  font-size: 13px;
}

.detail-attachments {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.detail-att-item {
  display: block;
  width: 72px;
  height: 72px;
  border-radius: 6px;
  overflow: hidden;
}

.detail-att-item img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
</style>
