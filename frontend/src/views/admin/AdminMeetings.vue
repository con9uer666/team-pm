<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { showConfirmDialog, showFailToast, showSuccessToast } from 'vant'
import { meetingsApi, type MeetingInfo } from '../../api/meetings'
import { usersApi, orgApi, type UserInfo, type GroupInfo, type DivisionInfo } from '../../api/users'

const meetings = ref<MeetingInfo[]>([])
const users = ref<UserInfo[]>([])
const groups = ref<GroupInfo[]>([])
const divisions = ref<DivisionInfo[]>([])
const loading = ref(false)

const searchTerm = ref('')
const filterStatus = ref<string>('')
const filterScope = ref<string>('')

const usersById = computed(() => {
  const map: Record<string, UserInfo> = {}
  for (const u of users.value) map[u.id] = u
  return map
})

function userLabel(id: string | null) {
  if (!id) return '—'
  return usersById.value[id]?.realName || id.slice(0, 8)
}

function groupName(id: string | null) {
  if (!id) return '—'
  return groups.value.find(g => g.id === id)?.name || '—'
}

function divName(id: string | null) {
  if (!id) return '—'
  return divisions.value.find(d => d.id === id)?.name || '—'
}

const SCOPE_LABEL: Record<string, string> = {
  team: '全队',
  division: '兵种组',
  group: '技术组',
}

const STATUS_LABEL: Record<string, string> = {
  scheduled: '已安排',
  in_progress: '进行中',
  ended: '已结束',
  cancelled: '已取消',
}

const STATUS_COLOR: Record<string, string> = {
  scheduled: '#3b82f6',
  in_progress: '#10b981',
  ended: '#64748b',
  cancelled: '#ef4444',
}

function scopeDesc(m: MeetingInfo) {
  if (m.scope === 'team') return '全队'
  if (m.scope === 'division') return `${divName(m.divisionId)} (兵种组)`
  return `${groupName(m.groupId)} (技术组)`
}

const filtered = computed(() => {
  let list = meetings.value
  if (searchTerm.value) {
    const t = searchTerm.value.toLowerCase()
    list = list.filter(m => m.title.toLowerCase().includes(t))
  }
  if (filterStatus.value) list = list.filter(m => m.status === filterStatus.value)
  if (filterScope.value) list = list.filter(m => m.scope === filterScope.value)
  return list
})

async function load() {
  loading.value = true
  try {
    const [ms, us, gs, ds] = await Promise.all([
      meetingsApi.getAll(),
      usersApi.getAll(),
      orgApi.getGroups(),
      orgApi.getDivisions(),
    ])
    meetings.value = ms
    users.value = us as UserInfo[]
    groups.value = gs
    divisions.value = ds
  } catch (e: any) {
    showFailToast(e?.message || '加载失败')
  } finally {
    loading.value = false
  }
}

async function cancelMeeting(m: MeetingInfo) {
  try {
    await showConfirmDialog({
      title: '取消会议',
      message: `确认取消「${m.title}」？`,
    })
  } catch {
    return
  }
  try {
    await meetingsApi.cancel(m.id)
    showSuccessToast('已取消')
    await load()
  } catch (e: any) {
    showFailToast(e?.message || '操作失败')
  }
}

async function endMeeting(m: MeetingInfo) {
  try {
    await showConfirmDialog({
      title: '结束会议',
      message: `确认结束「${m.title}」？`,
    })
  } catch {
    return
  }
  try {
    await meetingsApi.end(m.id)
    showSuccessToast('已结束')
    await load()
  } catch (e: any) {
    showFailToast(e?.message || '操作失败')
  }
}

function fmtTime(s: string) {
  const d = new Date(s)
  return `${d.getMonth() + 1}/${d.getDate()} ${d.getHours().toString().padStart(2, '0')}:${d
    .getMinutes()
    .toString()
    .padStart(2, '0')}`
}

onMounted(load)
</script>

<template>
  <div class="admin-meetings">
    <div class="header-bar">
      <h2 class="section-title">会议管理</h2>
      <div class="count-chips">
        <span class="chip chip--total">总数 {{ meetings.length }}</span>
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
        <label>范围</label>
        <select v-model="filterScope" class="native-select">
          <option value="">全部</option>
          <option v-for="(label, key) in SCOPE_LABEL" :key="key" :value="key">{{ label }}</option>
        </select>
      </div>
    </div>

    <div v-if="loading && !meetings.length" class="loading"><van-loading /></div>

    <div v-else class="table-wrap">
      <table class="meet-table">
        <thead>
          <tr>
            <th>标题</th>
            <th>范围</th>
            <th>组织者</th>
            <th>时间</th>
            <th>地点</th>
            <th>状态</th>
            <th style="width: 150px;">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="m in filtered" :key="m.id">
            <td>
              <div class="meet-title">{{ m.title }}</div>
              <div v-if="m.description" class="meet-sub">{{ m.description }}</div>
            </td>
            <td>{{ scopeDesc(m) }}</td>
            <td>{{ userLabel(m.organizerId) }}</td>
            <td>{{ fmtTime(m.startTime) }} - {{ fmtTime(m.endTime) }}</td>
            <td>{{ m.location || '—' }}</td>
            <td>
              <span class="status-dot" :style="{ background: STATUS_COLOR[m.status] }"></span>
              {{ STATUS_LABEL[m.status] || m.status }}
            </td>
            <td>
              <van-button
                v-if="m.status === 'in_progress'"
                size="mini"
                type="primary"
                plain
                @click="endMeeting(m)"
              >
                结束
              </van-button>
              <van-button
                v-if="m.status === 'scheduled' || m.status === 'in_progress'"
                size="mini"
                type="danger"
                plain
                @click="cancelMeeting(m)"
              >
                取消
              </van-button>
            </td>
          </tr>
          <tr v-if="!filtered.length">
            <td colspan="7" class="empty-row">无匹配会议</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<style scoped>
.admin-meetings {
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

.meet-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
  min-width: 900px;
}

.meet-table th {
  text-align: left;
  padding: 12px 14px;
  background: #f8fafc;
  color: #64748b;
  font-weight: 500;
  border-bottom: 1px solid #e5e7eb;
}

.meet-table td {
  padding: 14px;
  border-bottom: 1px solid #f1f5f9;
  color: #0f172a;
  vertical-align: middle;
}

.meet-title {
  font-weight: 500;
}

.meet-sub {
  font-size: 11px;
  color: #94a3b8;
  margin-top: 2px;
  max-width: 300px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  margin-right: 6px;
  vertical-align: middle;
}

.meet-table td .van-button + .van-button {
  margin-left: 6px;
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
