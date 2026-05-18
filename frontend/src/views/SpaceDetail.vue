<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { showToast, showConfirmDialog, showFailToast } from 'vant'
import { useAuthStore } from '../stores/auth'
import { spacesApi, type SpaceDetail } from '../api/spaces'
import { objectivesApi, type Objective } from '../api/objectives'
import { orgApi, type GroupInfo, type DivisionInfo } from '../api/users'
import type { Task } from '../api/tasks'
import { roleLabel } from '../composables/useRoleLabel'
import { taskStatusLabel } from '../utils/status'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const scope = computed(() => route.params.scope as 'group' | 'division')
const id = computed(() => route.params.id as string)

const detail = ref<SpaceDetail | null>(null)
const loading = ref(false)
const active = ref(0)

const allGroups = ref<GroupInfo[]>([])
const allDivisions = ref<DivisionInfo[]>([])

const showCreate = ref(false)
const newTitle = ref('')
const newDesc = ref('')
const newDue = ref<Date | null>(null)
const showDatePicker = ref(false)
const creating = ref(false)

const expandedObjId = ref<string | null>(null)
const objTasksMap = ref<Record<string, Task[]>>({})

async function toggleExpand(o: Objective) {
  if (expandedObjId.value === o.id) {
    expandedObjId.value = null
    return
  }
  expandedObjId.value = o.id
  if (!objTasksMap.value[o.id]) {
    try {
      objTasksMap.value[o.id] = await objectivesApi.getTasks(o.id)
    } catch (e: any) {
      showFailToast(e?.message || '加载任务失败')
    }
  }
}

function gotoCreateTask(o: Objective) {
  router.push({ name: 'tasks', query: { prefillObjective: o.id } })
}

const canDeliver = computed(() => {
  if (!detail.value || !auth.user) return false
  if (auth.user.isSuperAdmin || auth.user.roleLevel >= 5) return true
  return detail.value.info.leaderIds.includes(auth.user.id)
})

const currentGroupId = computed(() => scope.value === 'group' ? id.value : null)
const currentDivisionId = computed(() => scope.value === 'division' ? id.value : null)

const groupNameMap = computed(() => {
  const map: Record<string, string> = {}
  for (const g of allGroups.value) map[g.id] = g.name
  return map
})
const divisionNameMap = computed(() => {
  const map: Record<string, string> = {}
  for (const d of allDivisions.value) map[d.id] = d.name
  return map
})

function groupName(gid: string) { return groupNameMap.value[gid] || gid.slice(0, 6) }
function divisionName(did: string) { return divisionNameMap.value[did] || did.slice(0, 6) }

async function load() {
  loading.value = true
  try {
    const [d, gs, ds] = await Promise.all([
      scope.value === 'group'
        ? spacesApi.getGroup(id.value)
        : spacesApi.getDivision(id.value),
      orgApi.getGroups().catch(() => [] as GroupInfo[]),
      orgApi.getDivisions().catch(() => [] as DivisionInfo[]),
    ])
    detail.value = d
    allGroups.value = gs
    allDivisions.value = ds
  } catch (e: any) {
    showToast(e?.message || '加载失败')
  } finally {
    loading.value = false
  }
}

function fmtDate(d: string | Date | null | undefined) {
  if (!d) return ''
  const date = typeof d === 'string' ? new Date(d) : d
  const pad = (n: number) => n.toString().padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}

function openCreate() {
  newTitle.value = ''
  newDesc.value = ''
  newDue.value = null
  showCreate.value = true
}

async function submitCreate() {
  if (creating.value) return
  if (!newTitle.value.trim()) return showFailToast('请填写目标标题')
  if (!newDue.value) return showFailToast('请选择截止日期')
  creating.value = true
  try {
    await objectivesApi.create({
      title: newTitle.value.trim(),
      description: newDesc.value.trim() || undefined,
      scope: scope.value,
      divisionId: scope.value === 'division' ? id.value : undefined,
      groupId: scope.value === 'group' ? id.value : undefined,
      dueDate: newDue.value.toISOString(),
    })
    showToast('已下达')
    showCreate.value = false
    await load()
  } catch (e: any) {
    showFailToast(e?.message || '创建失败')
  } finally {
    creating.value = false
  }
}

async function completeObjective(o: Objective) {
  await showConfirmDialog({ title: '确认', message: `将目标「${o.title}」标记为已完成？` })
  try {
    await objectivesApi.complete(o.id)
    showToast('已标记完成')
    delete objTasksMap.value[o.id]
    await load()
  } catch (e: any) {
    showFailToast(e?.message || '操作失败')
  }
}

async function removeObjective(o: Objective) {
  await showConfirmDialog({ title: '确认', message: `删除目标「${o.title}」？关联任务会保留。` })
  try {
    await objectivesApi.remove(o.id)
    showToast('已删除')
    delete objTasksMap.value[o.id]
    if (expandedObjId.value === o.id) expandedObjId.value = null
    await load()
  } catch (e: any) {
    showFailToast(e?.message || '删除失败')
  }
}

const dueValues = computed<string[]>(() => {
  if (!newDue.value) return []
  const d = newDue.value
  return [
    d.getFullYear().toString(),
    (d.getMonth() + 1).toString().padStart(2, '0'),
    d.getDate().toString().padStart(2, '0'),
  ]
})

function onDateConfirm({ selectedValues }: { selectedValues: string[] }) {
  newDue.value = new Date(
    Number(selectedValues[0]),
    Number(selectedValues[1]) - 1,
    Number(selectedValues[2]),
    23,
    59,
    0,
  )
  showDatePicker.value = false
}

onMounted(load)
</script>

<template>
  <div class="space-detail" v-if="detail">
    <header class="header animate-fade-in-up">
      <van-icon name="arrow-left" @click="router.back()" size="20" class="back" />
      <div>
        <h1>{{ detail.info.name }}</h1>
        <p class="sub">{{ scope === 'group' ? '技术组' : '兵种组' }} · {{ detail.members.length }} 人</p>
      </div>
    </header>

    <van-tabs v-model:active="active" sticky class="animate-fade-in-up stagger-1">
      <van-tab title="阶段性目标">
        <div class="tab-content">
          <div v-if="canDeliver" class="actions-row">
            <van-button type="primary" size="small" icon="plus" @click="openCreate">下达目标</van-button>
          </div>
          <van-empty v-if="!detail.objectives.length" description="暂无目标" />
          <div
            v-for="(o, i) in detail.objectives"
            :key="o.id"
            :class="['obj-card', i < 5 ? `animate-fade-in-up stagger-${Math.min(i + 1, 5)}` : '']"
            @click="toggleExpand(o)"
          >
            <div class="obj-head">
              <div class="obj-title">{{ o.title }}</div>
              <van-tag :type="o.status === 'completed' ? 'success' : 'primary'">
                {{ o.status === 'completed' ? '已完成' : '进行中' }}
              </van-tag>
            </div>
            <p v-if="o.description" class="obj-desc">{{ o.description }}</p>
            <div class="obj-progress">
              <van-progress :percentage="o.progress || 0" />
              <span class="progress-text">
                {{ o.completedTasks || 0 }} / {{ o.totalTasks || 0 }} 任务
                <span v-if="o.manuallyCompleted"> · 手动完成</span>
              </span>
            </div>
            <div class="obj-foot" @click.stop>
              <span>截止 {{ fmtDate(o.dueDate) }}</span>
              <div class="foot-actions">
                <van-button
                  v-if="o.status !== 'completed'"
                  size="mini"
                  type="primary"
                  plain
                  @click="gotoCreateTask(o)"
                >新建任务</van-button>
                <template v-if="canDeliver">
                  <van-button
                    v-if="o.status !== 'completed'"
                    size="mini"
                    type="success"
                    plain
                    @click="completeObjective(o)"
                  >标记完成</van-button>
                  <van-button size="mini" type="danger" plain @click="removeObjective(o)">删除</van-button>
                </template>
              </div>
            </div>
            <div v-if="expandedObjId === o.id" class="obj-tasks" @click.stop>
              <van-empty v-if="!(objTasksMap[o.id] || []).length" description="该目标暂无任务" />
              <van-cell
                v-for="t in objTasksMap[o.id] || []"
                :key="t.id"
                :title="t.title"
                :label="`${taskStatusLabel(t.status)} · 截止 ${fmtDate(t.dueDate)}`"
              />
            </div>
          </div>
        </div>
      </van-tab>

      <van-tab title="成员">
        <div class="tab-content">
          <van-cell
            v-for="m in detail.members"
            :key="m.id"
            :title="m.realName"
          >
            <template #label>
              <div class="member-meta">
                <span class="muted">@{{ m.username }}</span>
                <span class="role">· {{ roleLabel(m.roleLevel, m.position) }}</span>
              </div>
              <div
                v-if="(m.groupIds || []).some(gid => gid !== currentGroupId) || (m.divisionIds || []).some(did => did !== currentDivisionId)"
                class="member-tags"
              >
                <span
                  v-for="gid in (m.groupIds || []).filter(g => g !== currentGroupId)"
                  :key="'g-' + gid"
                  class="member-chip member-chip--group"
                >{{ groupName(gid) }}</span>
                <span
                  v-for="did in (m.divisionIds || []).filter(d => d !== currentDivisionId)"
                  :key="'d-' + did"
                  class="member-chip member-chip--division"
                >{{ divisionName(did) }}</span>
              </div>
            </template>
            <template #right-icon>
              <van-tag
                v-if="detail.info.leaderIds.includes(m.id)"
                type="primary"
              >组长</van-tag>
            </template>
          </van-cell>
        </div>
      </van-tab>

      <van-tab title="任务">
        <div class="tab-content">
          <van-empty v-if="!detail.tasks.length" description="暂无任务" />
          <van-cell
            v-for="t in detail.tasks"
            :key="t.id"
            :title="t.title"
            :label="`${taskStatusLabel(t.status)} · 截止 ${fmtDate(t.dueDate)}`"
          />
        </div>
      </van-tab>
    </van-tabs>

    <van-popup
      v-model:show="showCreate"
      position="bottom"
      round
      :style="{ height: '90%' }"
    >
      <div class="create-panel">
        <h3>下达阶段性目标</h3>
        <van-cell-group inset>
          <van-field v-model="newTitle" label="标题" placeholder="目标标题" maxlength="200" />
          <van-field
            v-model="newDesc"
            label="描述"
            type="textarea"
            rows="3"
            placeholder="目标描述（可选）"
            maxlength="2000"
          />
          <van-field
            readonly
            is-link
            label="截止日期"
            :model-value="fmtDate(newDue || undefined)"
            placeholder="请选择"
            @click="showDatePicker = true"
          />
        </van-cell-group>
        <div class="create-actions">
          <van-button block type="primary" :loading="creating" :disabled="creating" @click="submitCreate">
            确认下达
          </van-button>
        </div>
      </div>
    </van-popup>

    <van-popup v-model:show="showDatePicker" position="bottom" round>
      <van-date-picker
        :model-value="dueValues"
        title="选择截止日期"
        :min-date="new Date()"
        @confirm="onDateConfirm"
        @cancel="showDatePicker = false"
      />
    </van-popup>
  </div>
  <van-loading v-else class="full-loading" />
</template>

<style scoped>
.space-detail {
  padding-bottom: 60px;
}

.header {
  display: flex;
  gap: 12px;
  align-items: center;
  padding: 16px;
  background: var(--bg-card);
  border-bottom: 1px solid rgba(148, 163, 184, 0.12);
}

.back {
  cursor: pointer;
}

.header h1 {
  margin: 0;
  font-size: 18px;
  color: var(--text-primary);
}

.header .sub {
  margin: 2px 0 0;
  color: var(--text-muted);
  font-size: 12px;
}

.tab-content {
  padding: 12px;
}

.actions-row {
  display: flex;
  justify-content: flex-end;
  margin-bottom: 10px;
}

.obj-card {
  padding: 14px;
  background: var(--bg-card);
  border-radius: 12px;
  margin-bottom: 10px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

.obj-head {
  display: flex;
  justify-content: space-between;
  gap: 8px;
  align-items: flex-start;
  margin-bottom: 6px;
}

.obj-title {
  font-weight: 600;
  color: var(--text-primary);
}

.obj-desc {
  margin: 0 0 10px;
  color: var(--text-muted);
  font-size: 13px;
  line-height: 1.5;
}

.obj-progress {
  margin-bottom: 10px;
}

.progress-text {
  display: block;
  margin-top: 4px;
  font-size: 12px;
  color: var(--text-muted);
}

.obj-foot {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 12px;
  color: var(--text-muted);
}

.foot-actions {
  display: flex;
  gap: 6px;
}

.obj-tasks {
  margin-top: 10px;
  padding-top: 10px;
  border-top: 1px solid rgba(148, 163, 184, 0.18);
}

.create-panel {
  padding: 20px 16px;
}

.create-panel h3 {
  margin: 0 0 16px;
}

.create-actions {
  margin-top: 20px;
}

.full-loading {
  display: flex;
  justify-content: center;
  padding: 60px 0;
}

.member-meta {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
}

.member-meta .muted {
  color: var(--text-muted);
}

.member-meta .role {
  color: var(--text-secondary);
}

.member-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  margin-top: 4px;
}

.member-chip {
  display: inline-block;
  padding: 1px 8px;
  border-radius: 10px;
  font-size: 11px;
}

.member-chip--group {
  background: #eef2ff;
  color: #4338ca;
}

.member-chip--division {
  background: #fff7ed;
  color: #c2410c;
}
</style>
