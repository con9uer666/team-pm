<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { showConfirmDialog, showFailToast, showSuccessToast } from 'vant'
import { objectivesApi, type Objective } from '../../api/objectives'
import { orgApi, type GroupInfo, type DivisionInfo } from '../../api/users'

const objectives = ref<Objective[]>([])
const groups = ref<GroupInfo[]>([])
const divisions = ref<DivisionInfo[]>([])
const loading = ref(false)

const filterScope = ref<'' | 'group' | 'division'>('')
const filterStatus = ref<string>('')
const filterTarget = ref<string>('')

function divName(id: string | null) {
  if (!id) return ''
  return divisions.value.find(d => d.id === id)?.name || ''
}

function groupName(id: string | null) {
  if (!id) return ''
  return groups.value.find(g => g.id === id)?.name || ''
}

function targetLabel(o: Objective) {
  if (o.scope === 'group') return `${groupName(o.groupId)} (技术组)`
  return `${divName(o.divisionId)} (兵种组)`
}

const STATUS_LABEL: Record<string, string> = {
  active: '进行中',
  completed: '已完成',
  cancelled: '已取消',
}

const STATUS_COLOR: Record<string, string> = {
  active: '#3b82f6',
  completed: '#10b981',
  cancelled: '#94a3b8',
}

const filtered = computed(() => {
  let list = objectives.value
  if (filterScope.value) list = list.filter(o => o.scope === filterScope.value)
  if (filterStatus.value) list = list.filter(o => o.status === filterStatus.value)
  if (filterTarget.value) {
    list = list.filter(
      o => o.groupId === filterTarget.value || o.divisionId === filterTarget.value,
    )
  }
  return list
})

const grouped = computed(() => {
  const map = new Map<string, Objective[]>()
  for (const o of filtered.value) {
    const key = targetLabel(o)
    const arr = map.get(key) || []
    arr.push(o)
    map.set(key, arr)
  }
  return Array.from(map.entries()).sort((a, b) => a[0].localeCompare(b[0]))
})

const stats = computed(() => {
  const total = objectives.value.length
  const active = objectives.value.filter(o => o.status === 'active').length
  const completed = objectives.value.filter(o => o.status === 'completed').length
  return { total, active, completed }
})

async function load() {
  loading.value = true
  try {
    const [os, gs, ds] = await Promise.all([
      objectivesApi.list(),
      orgApi.getGroups(),
      orgApi.getDivisions(),
    ])
    objectives.value = os
    groups.value = gs
    divisions.value = ds
  } catch (e: any) {
    showFailToast(e?.message || '加载失败')
  } finally {
    loading.value = false
  }
}

async function markComplete(o: Objective) {
  try {
    await showConfirmDialog({
      title: '标记完成',
      message: `手动将「${o.title}」标记为已完成？`,
    })
  } catch {
    return
  }
  try {
    await objectivesApi.complete(o.id)
    showSuccessToast('已完成')
    await load()
  } catch (e: any) {
    showFailToast(e?.message || '操作失败')
  }
}

async function removeObjective(o: Objective) {
  try {
    await showConfirmDialog({
      title: '删除目标',
      message: `确认删除「${o.title}」？关联任务将解除关联`,
    })
  } catch {
    return
  }
  try {
    await objectivesApi.remove(o.id)
    showSuccessToast('已删除')
    await load()
  } catch (e: any) {
    showFailToast(e?.message || '删除失败')
  }
}

function fmtDate(s: string | null) {
  if (!s) return '—'
  return s.slice(0, 10)
}

function isOverdue(o: Objective) {
  if (o.status !== 'active') return false
  return new Date(o.dueDate).getTime() < Date.now()
}

onMounted(load)
</script>

<template>
  <div class="admin-obj">
    <div class="header-bar">
      <h2 class="section-title">阶段性目标</h2>
      <div class="count-chips">
        <span class="chip chip--total">总数 {{ stats.total }}</span>
        <span class="chip" style="color: #3b82f6;">进行中 {{ stats.active }}</span>
        <span class="chip" style="color: #10b981;">已完成 {{ stats.completed }}</span>
      </div>
    </div>

    <div class="filters">
      <div class="select-wrap">
        <label>范围</label>
        <select v-model="filterScope" class="native-select">
          <option value="">全部</option>
          <option value="division">兵种组</option>
          <option value="group">技术组</option>
        </select>
      </div>
      <div class="select-wrap">
        <label>状态</label>
        <select v-model="filterStatus" class="native-select">
          <option value="">全部</option>
          <option v-for="(label, key) in STATUS_LABEL" :key="key" :value="key">{{ label }}</option>
        </select>
      </div>
      <div class="select-wrap">
        <label>目标归属</label>
        <select v-model="filterTarget" class="native-select">
          <option value="">全部</option>
          <optgroup label="兵种组">
            <option v-for="d in divisions" :key="d.id" :value="d.id">{{ d.name }}</option>
          </optgroup>
          <optgroup label="技术组">
            <option v-for="g in groups" :key="g.id" :value="g.id">{{ g.name }}</option>
          </optgroup>
        </select>
      </div>
    </div>

    <div v-if="loading && !objectives.length" class="loading"><van-loading /></div>

    <div v-else-if="!grouped.length" class="empty">无匹配的阶段性目标</div>

    <div v-else class="groups-view">
      <section v-for="[label, items] in grouped" :key="label" class="group-section">
        <div class="group-head">
          <h3>{{ label }}</h3>
          <span class="group-count">{{ items.length }} 项</span>
        </div>
        <div class="obj-grid">
          <div v-for="o in items" :key="o.id" class="obj-card" :class="{ 'obj-card--done': o.status === 'completed' }">
            <div class="obj-card__top">
              <h4>{{ o.title }}</h4>
              <span
                class="obj-status"
                :style="{ background: STATUS_COLOR[o.status] + '20', color: STATUS_COLOR[o.status] }"
              >
                {{ STATUS_LABEL[o.status] || o.status }}
              </span>
            </div>
            <p v-if="o.description" class="obj-desc">{{ o.description }}</p>
            <div class="progress-bar">
              <div class="progress-fill" :style="{ width: (o.progress || 0) + '%' }"></div>
            </div>
            <div class="obj-meta">
              <span>进度 {{ o.progress || 0 }}%</span>
              <span>任务 {{ o.completedTasks || 0 }}/{{ o.totalTasks || 0 }}</span>
              <span :class="{ overdue: isOverdue(o) }">截止 {{ fmtDate(o.dueDate) }}</span>
            </div>
            <div class="obj-actions">
              <van-button
                v-if="o.status === 'active'"
                size="mini"
                type="success"
                plain
                @click="markComplete(o)"
              >
                标完成
              </van-button>
              <van-button size="mini" type="danger" plain @click="removeObjective(o)">删除</van-button>
            </div>
          </div>
        </div>
      </section>
    </div>
  </div>
</template>

<style scoped>
.admin-obj {
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
  flex-wrap: wrap;
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
  margin-bottom: 20px;
  flex-wrap: wrap;
  background: #fff;
  padding: 14px;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(15, 23, 42, 0.04);
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
  min-width: 140px;
}

.empty {
  text-align: center;
  padding: 60px 0;
  color: #94a3b8;
  font-size: 14px;
}

.group-section {
  margin-bottom: 24px;
}

.group-head {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  margin-bottom: 12px;
  padding-bottom: 8px;
  border-bottom: 2px solid #e0e7ff;
}

.group-head h3 {
  margin: 0;
  font-size: 15px;
  color: #0f172a;
  font-weight: 600;
}

.group-count {
  font-size: 12px;
  color: #94a3b8;
}

.obj-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 14px;
}

.obj-card {
  background: #fff;
  padding: 16px;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(15, 23, 42, 0.04);
  border: 1px solid #e5e7eb;
}

.obj-card--done {
  opacity: 0.8;
  border-color: #10b98130;
}

.obj-card__top {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 10px;
  margin-bottom: 8px;
}

.obj-card h4 {
  margin: 0;
  font-size: 14px;
  color: #0f172a;
  font-weight: 600;
  flex: 1;
}

.obj-status {
  padding: 2px 8px;
  border-radius: 10px;
  font-size: 11px;
  white-space: nowrap;
}

.obj-desc {
  margin: 4px 0 10px;
  font-size: 12px;
  color: #64748b;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.progress-bar {
  height: 6px;
  background: #e5e7eb;
  border-radius: 3px;
  overflow: hidden;
  margin-bottom: 6px;
}

.progress-fill {
  height: 100%;
  background: linear-gradient(90deg, #6366f1, #8b5cf6);
  transition: width 0.3s ease;
}

.obj-meta {
  display: flex;
  justify-content: space-between;
  font-size: 11px;
  color: #64748b;
  margin-bottom: 10px;
  flex-wrap: wrap;
  gap: 6px;
}

.obj-meta .overdue {
  color: #ef4444;
  font-weight: 500;
}

.obj-actions {
  display: flex;
  justify-content: flex-end;
  gap: 6px;
  border-top: 1px dashed #e5e7eb;
  padding-top: 10px;
}

.loading {
  display: flex;
  justify-content: center;
  padding: 40px 0;
}
</style>
