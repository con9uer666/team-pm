<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { showFailToast, showSuccessToast } from 'vant'
import { orgApi, usersApi, type GroupInfo, type DivisionInfo, type UserInfo } from '../../api/users'

const groups = ref<GroupInfo[]>([])
const divisions = ref<DivisionInfo[]>([])
const users = ref<UserInfo[]>([])
const loading = ref(false)

const showCreateGroup = ref(false)
const showCreateDiv = ref(false)
const showLeaders = ref(false)

const newGroupName = ref('')
const newDivName = ref('')
const newDivDesc = ref('')
const saving = ref(false)

const leadersTarget = ref<{ kind: 'group' | 'division'; id: string; name: string } | null>(null)
const leadersSelected = ref<string[]>([])

const usersById = computed(() => {
  const map: Record<string, UserInfo> = {}
  for (const u of users.value) map[u.id] = u
  return map
})

function userLabel(id: string) {
  const u = usersById.value[id]
  return u ? `${u.realName}(${u.username})` : id.slice(0, 8)
}

const eligibleLeaders = computed(() =>
  users.value.filter(u => u.approvalStatus === 'approved' && u.roleLevel >= 3),
)

async function load() {
  loading.value = true
  try {
    const [gs, ds, us] = await Promise.all([
      orgApi.getGroups(),
      orgApi.getDivisions(),
      usersApi.getAll(),
    ])
    groups.value = gs
    divisions.value = ds
    users.value = us as UserInfo[]
  } catch (e: any) {
    showFailToast(e?.message || '加载失败')
  } finally {
    loading.value = false
  }
}

async function createGroup() {
  if (!newGroupName.value.trim()) return showFailToast('请输入组名')
  saving.value = true
  try {
    await orgApi.createGroup({ name: newGroupName.value.trim() })
    showSuccessToast('创建成功')
    showCreateGroup.value = false
    newGroupName.value = ''
    await load()
  } catch (e: any) {
    showFailToast(e?.message || '创建失败')
  } finally {
    saving.value = false
  }
}

async function createDivision() {
  if (!newDivName.value.trim()) return showFailToast('请输入兵种组名')
  saving.value = true
  try {
    await orgApi.createDivision({
      name: newDivName.value.trim(),
      description: newDivDesc.value.trim() || undefined,
    })
    showSuccessToast('创建成功')
    showCreateDiv.value = false
    newDivName.value = ''
    newDivDesc.value = ''
    await load()
  } catch (e: any) {
    showFailToast(e?.message || '创建失败')
  } finally {
    saving.value = false
  }
}

function openLeaders(kind: 'group' | 'division', id: string, name: string, current: string[] | null) {
  leadersTarget.value = { kind, id, name }
  leadersSelected.value = [...(current || [])]
  showLeaders.value = true
}

async function saveLeaders() {
  if (!leadersTarget.value) return
  saving.value = true
  try {
    const { kind, id } = leadersTarget.value
    if (kind === 'group') {
      await orgApi.setGroupLeaders(id, leadersSelected.value)
    } else {
      await orgApi.setDivisionLeaders(id, leadersSelected.value)
    }
    showSuccessToast('已更新')
    showLeaders.value = false
    await load()
  } catch (e: any) {
    showFailToast(e?.message || '保存失败')
  } finally {
    saving.value = false
  }
}

function toggleLeader(id: string) {
  const i = leadersSelected.value.indexOf(id)
  if (i >= 0) leadersSelected.value.splice(i, 1)
  else leadersSelected.value.push(id)
}

onMounted(load)
</script>

<template>
  <div class="admin-org">
    <div class="header-bar">
      <h2 class="section-title">组织架构</h2>
      <div class="actions">
        <van-button size="small" type="primary" icon="plus" @click="showCreateDiv = true">新增兵种组</van-button>
        <van-button size="small" type="primary" icon="plus" @click="showCreateGroup = true">新增技术组</van-button>
      </div>
    </div>

    <div v-if="loading && !divisions.length" class="loading"><van-loading /></div>

    <template v-else>
      <section class="panel">
        <div class="panel-head">
          <h3>兵种组 (Divisions)</h3>
          <span class="hint">用于划分队内岗位职能</span>
        </div>
        <div v-if="!divisions.length" class="empty">暂无兵种组</div>
        <div v-for="d in divisions" :key="d.id" class="div-card">
          <div class="div-card__top">
            <div>
              <div class="div-name">{{ d.name }}</div>
              <div class="div-desc">{{ d.description || '—' }}</div>
            </div>
            <van-button size="mini" plain @click="openLeaders('division', d.id, d.name, d.leaderIds)">
              设负责人
            </van-button>
          </div>
          <div class="leaders-row">
            <span class="leaders-label">负责人:</span>
            <template v-if="d.leaderIds && d.leaderIds.length">
              <span v-for="lid in d.leaderIds" :key="lid" class="chip chip--lead">{{ userLabel(lid) }}</span>
            </template>
            <span v-else class="chip chip--empty">未设置</span>
          </div>
        </div>
      </section>

      <section class="panel">
        <div class="panel-head">
          <h3>技术组 (Groups)</h3>
          <span class="hint">技术口子，成员注册时选择</span>
        </div>
        <div v-if="!groups.length" class="empty">暂无技术组</div>
        <table v-else class="grp-table">
          <thead>
            <tr>
              <th>组名</th>
              <th>组长</th>
              <th style="width: 110px;">操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="g in groups" :key="g.id">
              <td>{{ g.name }}</td>
              <td>
                <template v-if="g.leaderIds && g.leaderIds.length">
                  <span v-for="lid in g.leaderIds" :key="lid" class="chip chip--lead">{{ userLabel(lid) }}</span>
                </template>
                <span v-else class="chip chip--empty">未设置</span>
              </td>
              <td>
                <van-button size="mini" plain @click="openLeaders('group', g.id, g.name, g.leaderIds)">
                  设组长
                </van-button>
              </td>
            </tr>
          </tbody>
        </table>
      </section>
    </template>

    <van-popup v-model:show="showCreateGroup" round position="center" style="width: 360px; padding: 24px;">
      <h3 style="margin: 0 0 16px;">新增技术组</h3>
      <van-field v-model="newGroupName" label="组名" placeholder="例如：电控/机械" />
      <div class="modal-actions">
        <van-button block plain @click="showCreateGroup = false">取消</van-button>
        <van-button block type="primary" :loading="saving" @click="createGroup">创建</van-button>
      </div>
    </van-popup>

    <van-popup v-model:show="showCreateDiv" round position="center" style="width: 360px; padding: 24px;">
      <h3 style="margin: 0 0 16px;">新增兵种组</h3>
      <van-field v-model="newDivName" label="名称" placeholder="例如：步兵/英雄" />
      <van-field v-model="newDivDesc" label="描述" placeholder="（可选）" />
      <div class="modal-actions">
        <van-button block plain @click="showCreateDiv = false">取消</van-button>
        <van-button block type="primary" :loading="saving" @click="createDivision">创建</van-button>
      </div>
    </van-popup>

    <van-popup v-model:show="showLeaders" round position="center" style="width: 420px; padding: 24px;">
      <h3 style="margin: 0 0 8px;">
        设置负责人 - {{ leadersTarget?.name }}
      </h3>
      <p class="hint" style="margin: 0 0 16px;">仅展示角色 ≥ 组长且已审核的用户</p>
      <div class="leader-list">
        <label v-for="u in eligibleLeaders" :key="u.id" class="leader-item">
          <input
            type="checkbox"
            :checked="leadersSelected.includes(u.id)"
            @change="toggleLeader(u.id)"
          />
          <span>{{ u.realName }} <small>({{ u.username }})</small></span>
        </label>
        <div v-if="!eligibleLeaders.length" class="empty">没有符合条件的用户</div>
      </div>
      <div class="modal-actions">
        <van-button block plain @click="showLeaders = false">取消</van-button>
        <van-button block type="primary" :loading="saving" @click="saveLeaders">保存</van-button>
      </div>
    </van-popup>
  </div>
</template>

<style scoped>
.admin-org {
  padding: 8px 4px;
}

.header-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.section-title {
  margin: 0;
  font-size: 17px;
  font-weight: 600;
  color: #0f172a;
}

.actions {
  display: flex;
  gap: 8px;
}

.panel {
  background: #fff;
  padding: 20px;
  border-radius: 14px;
  margin-bottom: 16px;
  box-shadow: 0 2px 12px rgba(15, 23, 42, 0.05);
}

.panel-head {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  margin-bottom: 14px;
}

.panel-head h3 {
  margin: 0;
  font-size: 15px;
  color: #0f172a;
  font-weight: 600;
}

.hint {
  font-size: 12px;
  color: #94a3b8;
}

.empty {
  padding: 24px 0;
  text-align: center;
  color: #94a3b8;
  font-size: 13px;
}

.div-card {
  padding: 14px;
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  margin-bottom: 10px;
}

.div-card__top {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 12px;
  margin-bottom: 10px;
}

.div-name {
  font-size: 15px;
  font-weight: 600;
  color: #0f172a;
}

.div-desc {
  font-size: 12px;
  color: #64748b;
  margin-top: 2px;
}

.leaders-row,
.groups-under {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 6px;
}

.leaders-label {
  font-size: 12px;
  color: #64748b;
  margin-right: 4px;
}

.chip {
  display: inline-flex;
  align-items: center;
  padding: 2px 10px;
  background: #f1f5f9;
  color: #475569;
  border-radius: 12px;
  font-size: 12px;
}

.chip--lead {
  background: #ecfdf5;
  color: #047857;
}

.chip--empty {
  background: #fef3c7;
  color: #92400e;
}

.grp-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

.grp-table th {
  text-align: left;
  padding: 10px 8px;
  color: #64748b;
  font-weight: 500;
  border-bottom: 1px solid #e5e7eb;
}

.grp-table td {
  padding: 12px 8px;
  border-bottom: 1px solid #f1f5f9;
  color: #0f172a;
  vertical-align: middle;
}

.grp-table td .chip {
  margin-right: 4px;
}

.warn {
  margin-top: 10px;
  padding: 8px 12px;
  background: #fef3c7;
  color: #92400e;
  border-radius: 8px;
  font-size: 12px;
}

.native-select {
  width: 100%;
  padding: 6px 8px;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  background: #fff;
  font-size: 13px;
}

.modal-actions {
  display: flex;
  gap: 10px;
  margin-top: 20px;
}

.leader-list {
  max-height: 320px;
  overflow-y: auto;
  padding: 8px;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
}

.leader-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 4px;
  cursor: pointer;
  font-size: 13px;
  color: #0f172a;
}

.leader-item:hover {
  background: #f8fafc;
}

.loading {
  display: flex;
  justify-content: center;
  padding: 40px 0;
}
</style>
