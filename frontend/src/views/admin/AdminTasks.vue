<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { showConfirmDialog, showFailToast, showSuccessToast } from 'vant'
import { tasksApi, type Task } from '../../api/tasks'
import { usersApi, orgApi, type UserInfo, type GroupInfo, type DivisionInfo } from '../../api/users'

const tasks = ref<Task[]>([])
const users = ref<UserInfo[]>([])
const groups = ref<GroupInfo[]>([])
const divisions = ref<DivisionInfo[]>([])
const loading = ref(false)

const searchTerm = ref('')
const filterStatus = ref<string>('')
const filterAssignee = ref<string>('')

const usersById = computed(() => {
  const map: Record<string, UserInfo> = {}
  for (const u of users.value) map[u.id] = u
  return map
})

function userLabel(id: string | null) {
  if (!id) return '—'
  const u = usersById.value[id]
  return u ? u.realName : id.slice(0, 8)
}

function groupName(id: string | null) {
  if (!id) return '—'
  return groups.value.find(g => g.id === id)?.name || '—'
}

function divName(id: string | null) {
  if (!id) return '—'
  return divisions.value.find(d => d.id === id)?.name || '—'
}

const STATUS_LABEL: Record<string, string> = {
  pending_dependency: '等待前置',
  pending_review: '待审核',
  in_progress: '进行中',
  pending_verification: '待验收',
  completed: '已完成',
  overdue: '逾期',
  rejected: '被驳回',
}

const STATUS_COLOR: Record<string, string> = {
  pending_dependency: '#94a3b8',
  pending_review: '#f59e0b',
  in_progress: '#3b82f6',
  pending_verification: '#8b5cf6',
  completed: '#10b981',
  overdue: '#ef4444',
  rejected: '#f43f5e',
}

const filtered = computed(() => {
  let list = tasks.value
  if (searchTerm.value) {
    const t = searchTerm.value.toLowerCase()
    list = list.filter(task => task.title.toLowerCase().includes(t))
  }
  if (filterStatus.value) list = list.filter(task => task.status === filterStatus.value)
  if (filterAssignee.value) list = list.filter(task => task.assigneeId === filterAssignee.value)
  return list
})

const statusCounts = computed(() => {
  const counts: Record<string, number> = {}
  for (const t of tasks.value) counts[t.status] = (counts[t.status] || 0) + 1
  return counts
})

async function load() {
  loading.value = true
  try {
    const [ts, us, gs, ds] = await Promise.all([
      tasksApi.getAll(),
      usersApi.getAll(),
      orgApi.getGroups(),
      orgApi.getDivisions(),
    ])
    tasks.value = ts
    users.value = us as UserInfo[]
    groups.value = gs
    divisions.value = ds
  } catch (e: any) {
    showFailToast(e?.message || '加载失败')
  } finally {
    loading.value = false
  }
}

async function removeTask(task: Task) {
  try {
    await showConfirmDialog({
      title: '删除任务',
      message: `确认删除「${task.title}」？此操作不可撤销`,
    })
  } catch {
    return
  }
  try {
    await tasksApi.deleteTask(task.id)
    showSuccessToast('已删除')
    await load()
  } catch (e: any) {
    showFailToast(e?.message || '删除失败')
  }
}

async function forceApprove(task: Task) {
  try {
    await showConfirmDialog({
      title: '强制通过',
      message: '将以管理员身份强制审核通过该任务',
    })
  } catch {
    return
  }
  try {
    await tasksApi.review(task.id, { action: 'approve', reviewType: 'group' })
    showSuccessToast('已通过')
    await load()
  } catch (e: any) {
    showFailToast(e?.message || '操作失败')
  }
}

function fmtDate(s: string | null) {
  if (!s) return '—'
  return s.slice(0, 10)
}

onMounted(load)
</script>

<template>
  <div class="admin-tasks">
    <div class="header-bar">
      <h2 class="section-title">任务管理</h2>
      <div class="count-chips">
        <span class="chip chip--total">总数 {{ tasks.length }}</span>
        <span v-for="(v, k) in statusCounts" :key="k" class="chip" :style="{ color: STATUS_COLOR[k] }">
          {{ STATUS_LABEL[k] || k }} {{ v }}
        </span>
      </div>
    </div>

    <div class="filters">
      <van-field v-model="searchTerm" placeholder="搜索标题" clearable left-icon="search" />
      <div class="select-wrap">
        <label>状态</label>
        <select v-model="filterStatus" class="native-select">
          <option value="">全部</option>
          <option v-for="(label, key) in STATUS_LABEL" :key="key" :value="key">{{ label }}</option>
        </select>
      </div>
      <div class="select-wrap">
        <label>负责人</label>
        <select v-model="filterAssignee" class="native-select">
          <option value="">全部</option>
          <option v-for="u in users" :key="u.id" :value="u.id">{{ u.realName }}</option>
        </select>
      </div>
    </div>

    <div v-if="loading && !tasks.length" class="loading"><van-loading /></div>

    <div v-else class="table-wrap">
      <table class="tasks-table">
        <thead>
          <tr>
            <th>标题</th>
            <th>状态</th>
            <th>负责人</th>
            <th>技术组</th>
            <th>兵种组</th>
            <th>截止</th>
            <th style="width: 140px;">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="t in filtered" :key="t.id">
            <td>
              <div class="task-title">{{ t.title }}</div>
              <div v-if="t.priority > 0" class="task-sub">优先级 {{ t.priority }}</div>
            </td>
            <td>
              <span class="status-dot" :style="{ background: STATUS_COLOR[t.status] }"></span>
              {{ STATUS_LABEL[t.status] || t.status }}
            </td>
            <td>{{ userLabel(t.assigneeId) }}</td>
            <td>{{ groupName(t.groupId) }}</td>
            <td>{{ divName(t.divisionId) }}</td>
            <td>{{ fmtDate(t.dueDate) }}</td>
            <td>
              <van-button
                v-if="t.status === 'pending_review' || t.status === 'pending_verification'"
                size="mini"
                type="primary"
                plain
                @click="forceApprove(t)"
              >
                强制通过
              </van-button>
              <van-button size="mini" type="danger" plain @click="removeTask(t)">删除</van-button>
            </td>
          </tr>
          <tr v-if="!filtered.length">
            <td colspan="7" class="empty-row">无匹配任务</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<style scoped>
.admin-tasks {
  padding: 8px 4px;
}

.header-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  flex-wrap: wrap;
  gap: 12px;
}

.section-title {
  margin: 0;
  font-size: 17px;
  font-weight: 600;
  color: #0f172a;
}

.count-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.chip {
  padding: 4px 10px;
  background: #f1f5f9;
  border-radius: 12px;
  font-size: 12px;
  color: #475569;
}

.chip--total {
  background: #eef2ff;
  color: #4338ca;
  font-weight: 600;
}

.filters {
  display: flex;
  gap: 12px;
  align-items: center;
  margin-bottom: 16px;
  flex-wrap: wrap;
  background: #fff;
  padding: 14px;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(15, 23, 42, 0.04);
}

.filters .van-field {
  flex: 1;
  min-width: 220px;
  padding: 0;
}

.select-wrap {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  color: #64748b;
}

.native-select {
  padding: 6px 8px;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  background: #fff;
  font-size: 13px;
  min-width: 120px;
}

.table-wrap {
  background: #fff;
  border-radius: 12px;
  overflow-x: auto;
  box-shadow: 0 2px 12px rgba(15, 23, 42, 0.05);
}

.tasks-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
  min-width: 900px;
}

.tasks-table th {
  text-align: left;
  padding: 12px 14px;
  background: #f8fafc;
  color: #64748b;
  font-weight: 500;
  border-bottom: 1px solid #e5e7eb;
}

.tasks-table td {
  padding: 14px;
  border-bottom: 1px solid #f1f5f9;
  color: #0f172a;
  vertical-align: middle;
}

.task-title {
  font-weight: 500;
}

.task-sub {
  font-size: 11px;
  color: #94a3b8;
  margin-top: 2px;
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  margin-right: 6px;
  vertical-align: middle;
}

.empty-row {
  text-align: center;
  padding: 40px 0;
  color: #94a3b8;
}

.loading {
  display: flex;
  justify-content: center;
  padding: 40px 0;
}
</style>
