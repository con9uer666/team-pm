<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { showConfirmDialog, showFailToast, showSuccessToast } from 'vant'
import { usersApi, orgApi, type UserInfo, type GroupInfo, type DivisionInfo, type Position } from '../../api/users'
import { approvalsApi } from '../../api/approvals'
import { useAuthStore } from '../../stores/auth'
import { ROLE_LEVELS, roleLabel } from '../../composables/useRoleLabel'

const auth = useAuthStore()
const activeTab = ref<'approved' | 'pending'>('approved')

const approvedUsers = ref<UserInfo[]>([])
const pendingUsers = ref<UserInfo[]>([])
const groups = ref<GroupInfo[]>([])
const divisions = ref<DivisionInfo[]>([])
const loading = ref(false)

const searchTerm = ref('')
const filterRole = ref<number | null>(null)
const filterGroup = ref<string | null>(null)

const showApproveModal = ref(false)
const showEditModal = ref(false)
const showCreateModal = ref(false)
const showPwdModal = ref(false)
const target = ref<UserInfo | null>(null)
const formRole = ref<number>(1)
const formPosition = ref<Position | null>(null)
const formGroupIds = ref<string[]>([])
const formDivisionIds = ref<string[]>([])
const formReason = ref('')
const saving = ref(false)

const createForm = ref({
  username: '',
  realName: '',
  email: '',
  password: '',
  roleLevel: 1 as number,
  position: null as Position | null,
  groupIds: [] as string[],
  divisionIds: [] as string[],
})

const pwdForm = ref({ newPassword: '', confirm: '' })

const canAssignDivision = computed(
  () => !!auth.user && (auth.user.isSuperAdmin || auth.user.roleLevel >= 5),
)

async function loadAll() {
  loading.value = true
  try {
    const [all, pend, gs, ds] = await Promise.all([
      usersApi.getAll(),
      approvalsApi.getPending(),
      orgApi.getGroups(),
      orgApi.getDivisions(),
    ])
    approvedUsers.value = (all as UserInfo[]).filter(u => u.approvalStatus === 'approved')
    pendingUsers.value = pend
    groups.value = gs
    divisions.value = ds
  } catch (e: any) {
    showFailToast(e?.message || '加载失败')
  } finally {
    loading.value = false
  }
}

const filteredApproved = computed(() => {
  let list = approvedUsers.value
  if (searchTerm.value) {
    const t = searchTerm.value.toLowerCase()
    list = list.filter(u =>
      u.username.toLowerCase().includes(t) || u.realName.toLowerCase().includes(t),
    )
  }
  if (filterRole.value !== null) {
    list = list.filter(u => u.roleLevel === filterRole.value)
  }
  if (filterGroup.value) {
    list = list.filter(u => (u.groupIds || []).includes(filterGroup.value!))
  }
  return list
})

function openApprove(u: UserInfo) {
  target.value = u
  formRole.value = 1
  formPosition.value = null
  formGroupIds.value = u.groupIds || []
  formDivisionIds.value = u.divisionIds || []
  formReason.value = ''
  showApproveModal.value = true
}

function openEdit(u: UserInfo) {
  target.value = u
  formRole.value = u.roleLevel
  formPosition.value = u.position || null
  formGroupIds.value = u.groupIds || []
  formDivisionIds.value = u.divisionIds || []
  showEditModal.value = true
}

function openCreate() {
  createForm.value = {
    username: '',
    realName: '',
    email: '',
    password: '',
    roleLevel: 1,
    position: null,
    groupIds: [],
    divisionIds: [],
  }
  showCreateModal.value = true
}

function openResetPwd(u: UserInfo) {
  target.value = u
  pwdForm.value = { newPassword: '', confirm: '' }
  showPwdModal.value = true
}

function toggleInList(list: string[], id: string) {
  const i = list.indexOf(id)
  if (i >= 0) list.splice(i, 1)
  else list.push(id)
}

function normalizePosition(role: number, pos: Position | null): Position | null {
  if (role === 5) {
    return pos === 'project_manager' || pos === 'team_captain' ? pos : null
  }
  if (role === 4) return 'vice_captain'
  return null
}

async function doApprove() {
  if (!target.value) return
  if (formRole.value === 5 && !formPosition.value) {
    return showFailToast('请选择具体职位（项管/队长）')
  }
  saving.value = true
  try {
    await approvalsApi.approve(target.value.id, {
      roleLevel: formRole.value,
      position: normalizePosition(formRole.value, formPosition.value),
      groupIds: formGroupIds.value,
      divisionIds: canAssignDivision.value ? formDivisionIds.value : undefined,
    })
    showSuccessToast('已通过')
    showApproveModal.value = false
    await loadAll()
  } catch (e: any) {
    showFailToast(e?.message || '审核失败')
  } finally {
    saving.value = false
  }
}

async function doReject() {
  if (!target.value) return
  if (!formReason.value.trim()) return showFailToast('请填写拒绝原因')
  saving.value = true
  try {
    await approvalsApi.reject(target.value.id, formReason.value.trim())
    showSuccessToast('已驳回')
    showApproveModal.value = false
    await loadAll()
  } catch (e: any) {
    showFailToast(e?.message || '操作失败')
  } finally {
    saving.value = false
  }
}

async function saveEdit() {
  if (!target.value) return
  if (formRole.value === 5 && !formPosition.value) {
    return showFailToast('请选择具体职位（项管/队长）')
  }
  saving.value = true
  try {
    const normalizedPos = normalizePosition(formRole.value, formPosition.value)
    if (
      formRole.value !== target.value.roleLevel ||
      normalizedPos !== (target.value.position || null)
    ) {
      await usersApi.updateRole(target.value.id, formRole.value, normalizedPos)
    }
    await usersApi.assignGroups(target.value.id, formGroupIds.value)
    if (canAssignDivision.value) {
      await usersApi.assignDivisions(target.value.id, formDivisionIds.value)
    }
    showSuccessToast('已更新')
    showEditModal.value = false
    await loadAll()
  } catch (e: any) {
    showFailToast(e?.message || '更新失败')
  } finally {
    saving.value = false
  }
}

async function submitCreate() {
  const f = createForm.value
  if (!f.username.trim()) return showFailToast('请填写用户名')
  if (!f.realName.trim()) return showFailToast('请填写真实姓名')
  if (!f.password || f.password.length < 6) return showFailToast('密码至少 6 位')
  if (f.roleLevel === 5 && !f.position) return showFailToast('请选择具体职位（项管/队长）')
  saving.value = true
  try {
    await usersApi.createUser({
      username: f.username.trim(),
      realName: f.realName.trim(),
      email: f.email.trim() || undefined,
      password: f.password,
      roleLevel: f.roleLevel,
      position: normalizePosition(f.roleLevel, f.position),
      groupIds: f.groupIds,
      divisionIds: canAssignDivision.value ? f.divisionIds : undefined,
    })
    showSuccessToast('账号创建成功')
    showCreateModal.value = false
    await loadAll()
  } catch (e: any) {
    showFailToast(e?.message || '创建失败')
  } finally {
    saving.value = false
  }
}

async function submitResetPwd() {
  if (!target.value) return
  const { newPassword, confirm } = pwdForm.value
  if (!newPassword || newPassword.length < 6) return showFailToast('密码至少 6 位')
  if (newPassword !== confirm) return showFailToast('两次输入不一致')
  saving.value = true
  try {
    await usersApi.resetPassword(target.value.id, newPassword)
    showSuccessToast('密码已重置，该用户会被强制下线')
    showPwdModal.value = false
  } catch (e: any) {
    showFailToast(e?.message || '重置失败')
  } finally {
    saving.value = false
  }
}

async function removeUser(u: UserInfo) {
  await showConfirmDialog({ title: '删除', message: `确定删除用户 ${u.realName}？` })
  try {
    await usersApi.removeUser(u.id)
    showSuccessToast('已删除')
    await loadAll()
  } catch (e: any) {
    showFailToast(e?.message || '删除失败')
  }
}

function groupName(id: string) {
  return groups.value.find(g => g.id === id)?.name || id
}

function divisionName(id: string) {
  return divisions.value.find(d => d.id === id)?.name || id
}

onMounted(loadAll)
</script>

<template>
  <div class="admin-users">
    <div class="top">
      <van-tabs v-model:active="activeTab" shrink>
        <van-tab title="全部用户" name="approved" />
        <van-tab :title="`待审核 (${pendingUsers.length})`" name="pending" />
      </van-tabs>
      <div class="top-actions">
        <van-button type="primary" icon="plus" size="small" @click="openCreate">新建账号</van-button>
      </div>
    </div>

    <template v-if="activeTab === 'approved'">
      <div class="filters">
        <van-field
          v-model="searchTerm"
          placeholder="搜索姓名或用户名"
          clearable
          class="filter-field"
        />
        <select v-model="filterRole" class="select">
          <option :value="null">全部角色</option>
          <option v-for="r in ROLE_LEVELS" :key="r.value" :value="r.value">{{ r.label }}</option>
        </select>
        <select v-model="filterGroup" class="select">
          <option :value="null">全部技术组</option>
          <option v-for="g in groups" :key="g.id" :value="g.id">{{ g.name }}</option>
        </select>
      </div>

      <div v-if="loading" class="loading"><van-loading /></div>

      <table v-else class="user-table">
        <thead>
          <tr>
            <th>姓名</th>
            <th>用户名</th>
            <th>角色</th>
            <th>技术组</th>
            <th>兵种组</th>
            <th>操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="u in filteredApproved" :key="u.id">
            <td>
              {{ u.realName }}
              <van-tag v-if="u.isSuperAdmin" type="warning" size="mini">超管</van-tag>
            </td>
            <td class="muted">{{ u.username }}</td>
            <td>{{ roleLabel(u.roleLevel, u.position) }}</td>
            <td>
              <span v-for="gid in u.groupIds || []" :key="gid" class="chip">{{ groupName(gid) }}</span>
              <span v-if="!u.groupIds?.length" class="muted">—</span>
            </td>
            <td>
              <span v-for="did in u.divisionIds || []" :key="did" class="chip chip--orange">{{ divisionName(did) }}</span>
              <span v-if="!u.divisionIds?.length" class="muted">—</span>
            </td>
            <td>
              <van-button size="mini" plain @click="openEdit(u)">编辑</van-button>
              <van-button
                v-if="!u.isSuperAdmin"
                size="mini"
                plain
                type="warning"
                @click="openResetPwd(u)"
              >改密</van-button>
              <van-button
                v-if="!u.isSuperAdmin"
                size="mini"
                type="danger"
                plain
                @click="removeUser(u)"
              >删除</van-button>
            </td>
          </tr>
        </tbody>
      </table>
    </template>

    <template v-else>
      <div v-if="loading" class="loading"><van-loading /></div>
      <van-empty v-else-if="!pendingUsers.length" description="暂无待审核用户" />
      <div v-else class="pending-list">
        <div v-for="u in pendingUsers" :key="u.id" class="pending-card">
          <div class="pending-head">
            <div>
              <div class="pending-name">{{ u.realName }}</div>
              <div class="pending-meta">@{{ u.username }} · {{ u.email }}</div>
            </div>
            <div class="pending-groups">
              <span v-for="gid in u.groupIds || []" :key="gid" class="chip">{{ groupName(gid) }}</span>
            </div>
          </div>
          <div class="pending-actions">
            <van-button size="small" type="primary" @click="openApprove(u)">审核</van-button>
          </div>
        </div>
      </div>
    </template>

    <van-popup
      v-model:show="showApproveModal"
      round
      :style="{ width: '90%', maxWidth: '520px', padding: '24px' }"
    >
      <h3 class="modal-title">审核 {{ target?.realName }}</h3>
      <van-cell-group inset>
        <van-field label="授予角色">
          <template #input>
            <select v-model="formRole" class="select w-full">
              <option v-for="r in ROLE_LEVELS" :key="r.value" :value="r.value">{{ r.label }}</option>
            </select>
          </template>
        </van-field>

        <van-field v-if="formRole === 5" label="具体职位">
          <template #input>
            <div class="radio-row">
              <label class="chk">
                <input type="radio" value="project_manager" v-model="formPosition" />
                项管
              </label>
              <label class="chk">
                <input type="radio" value="team_captain" v-model="formPosition" />
                队长
              </label>
            </div>
          </template>
        </van-field>

        <van-field label="技术组">
          <template #input>
            <div class="checkbox-grid">
              <label v-for="g in groups" :key="g.id" class="chk">
                <input
                  type="checkbox"
                  :value="g.id"
                  :checked="formGroupIds.includes(g.id)"
                  @change="formGroupIds = formGroupIds.includes(g.id) ? formGroupIds.filter(i => i !== g.id) : [...formGroupIds, g.id]"
                />
                {{ g.name }}
              </label>
            </div>
          </template>
        </van-field>

        <van-field v-if="canAssignDivision" label="兵种组">
          <template #input>
            <div class="checkbox-grid">
              <label v-for="d in divisions" :key="d.id" class="chk">
                <input
                  type="checkbox"
                  :value="d.id"
                  :checked="formDivisionIds.includes(d.id)"
                  @change="formDivisionIds = formDivisionIds.includes(d.id) ? formDivisionIds.filter(i => i !== d.id) : [...formDivisionIds, d.id]"
                />
                {{ d.name }}
              </label>
            </div>
          </template>
        </van-field>

        <van-field
          v-model="formReason"
          label="拒绝原因"
          type="textarea"
          rows="2"
          placeholder="仅驳回时填写"
        />
      </van-cell-group>

      <div class="modal-actions">
        <van-button plain @click="showApproveModal = false">取消</van-button>
        <van-button type="danger" :loading="saving" @click="doReject">驳回</van-button>
        <van-button type="primary" :loading="saving" @click="doApprove">通过</van-button>
      </div>
    </van-popup>

    <van-popup
      v-model:show="showEditModal"
      round
      :style="{ width: '90%', maxWidth: '520px', padding: '24px' }"
    >
      <h3 class="modal-title">编辑 {{ target?.realName }}</h3>
      <van-cell-group inset>
        <van-field label="角色">
          <template #input>
            <select v-model="formRole" class="select w-full" :disabled="target?.isSuperAdmin">
              <option v-for="r in ROLE_LEVELS" :key="r.value" :value="r.value">{{ r.label }}</option>
            </select>
          </template>
        </van-field>
        <van-field v-if="formRole === 5" label="具体职位">
          <template #input>
            <div class="radio-row">
              <label class="chk">
                <input type="radio" value="project_manager" v-model="formPosition" />
                项管
              </label>
              <label class="chk">
                <input type="radio" value="team_captain" v-model="formPosition" />
                队长
              </label>
            </div>
          </template>
        </van-field>
        <van-field label="技术组">
          <template #input>
            <div class="checkbox-grid">
              <label v-for="g in groups" :key="g.id" class="chk">
                <input
                  type="checkbox"
                  :checked="formGroupIds.includes(g.id)"
                  @change="formGroupIds = formGroupIds.includes(g.id) ? formGroupIds.filter(i => i !== g.id) : [...formGroupIds, g.id]"
                />
                {{ g.name }}
              </label>
            </div>
          </template>
        </van-field>
        <van-field v-if="canAssignDivision" label="兵种组">
          <template #input>
            <div class="checkbox-grid">
              <label v-for="d in divisions" :key="d.id" class="chk">
                <input
                  type="checkbox"
                  :checked="formDivisionIds.includes(d.id)"
                  @change="formDivisionIds = formDivisionIds.includes(d.id) ? formDivisionIds.filter(i => i !== d.id) : [...formDivisionIds, d.id]"
                />
                {{ d.name }}
              </label>
            </div>
          </template>
        </van-field>
      </van-cell-group>
      <div class="modal-actions">
        <van-button plain @click="showEditModal = false">取消</van-button>
        <van-button type="primary" :loading="saving" @click="saveEdit">保存</van-button>
      </div>
    </van-popup>

    <van-popup
      v-model:show="showCreateModal"
      round
      :style="{ width: '90%', maxWidth: '520px', padding: '24px' }"
    >
      <h3 class="modal-title">新建账号</h3>
      <p class="hint" style="margin:-8px 0 12px;color:#64748b;font-size:12px;">
        管理员创建的账号默认已审核，可直接登录。
      </p>
      <van-cell-group inset>
        <van-field v-model="createForm.username" label="用户名" placeholder="登录名" maxlength="32" />
        <van-field v-model="createForm.realName" label="真实姓名" maxlength="32" />
        <van-field v-model="createForm.email" label="邮箱" placeholder="（可选）" maxlength="128" />
        <van-field v-model="createForm.password" label="初始密码" type="password" placeholder="至少 6 位" />
        <van-field label="角色">
          <template #input>
            <select v-model="createForm.roleLevel" class="select w-full">
              <option v-for="r in ROLE_LEVELS" :key="r.value" :value="r.value">{{ r.label }}</option>
            </select>
          </template>
        </van-field>
        <van-field v-if="createForm.roleLevel === 5" label="具体职位">
          <template #input>
            <div class="radio-row">
              <label class="chk">
                <input type="radio" value="project_manager" v-model="createForm.position" />
                项管
              </label>
              <label class="chk">
                <input type="radio" value="team_captain" v-model="createForm.position" />
                队长
              </label>
            </div>
          </template>
        </van-field>
        <van-field label="技术组">
          <template #input>
            <div class="checkbox-grid">
              <label v-for="g in groups" :key="g.id" class="chk">
                <input
                  type="checkbox"
                  :checked="createForm.groupIds.includes(g.id)"
                  @change="toggleInList(createForm.groupIds, g.id)"
                />
                {{ g.name }}
              </label>
            </div>
          </template>
        </van-field>
        <van-field v-if="canAssignDivision" label="兵种组">
          <template #input>
            <div class="checkbox-grid">
              <label v-for="d in divisions" :key="d.id" class="chk">
                <input
                  type="checkbox"
                  :checked="createForm.divisionIds.includes(d.id)"
                  @change="toggleInList(createForm.divisionIds, d.id)"
                />
                {{ d.name }}
              </label>
            </div>
          </template>
        </van-field>
      </van-cell-group>
      <div class="modal-actions">
        <van-button plain @click="showCreateModal = false">取消</van-button>
        <van-button type="primary" :loading="saving" @click="submitCreate">创建</van-button>
      </div>
    </van-popup>

    <van-popup
      v-model:show="showPwdModal"
      round
      :style="{ width: '90%', maxWidth: '420px', padding: '24px' }"
    >
      <h3 class="modal-title">重置 {{ target?.realName }} 的密码</h3>
      <p class="hint" style="margin:-8px 0 12px;color:#92400e;font-size:12px;background:#fef3c7;padding:8px 10px;border-radius:6px;">
        修改后该用户会被强制下线，需要用新密码重新登录。
      </p>
      <van-cell-group inset>
        <van-field
          v-model="pwdForm.newPassword"
          label="新密码"
          type="password"
          placeholder="至少 6 位"
          autocomplete="new-password"
        />
        <van-field
          v-model="pwdForm.confirm"
          label="再次输入"
          type="password"
          autocomplete="new-password"
        />
      </van-cell-group>
      <div class="modal-actions">
        <van-button plain @click="showPwdModal = false">取消</van-button>
        <van-button type="primary" :loading="saving" @click="submitResetPwd">确认重置</van-button>
      </div>
    </van-popup>
  </div>
</template>

<style scoped>
.admin-users {
  background: #fff;
  border-radius: 14px;
  padding: 20px;
  box-shadow: 0 2px 12px rgba(15, 23, 42, 0.05);
}

.top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
}

.top-actions {
  display: flex;
  gap: 8px;
}

.radio-row {
  display: flex;
  gap: 10px;
  align-items: center;
}

.filters {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin: 16px 0;
}

.filter-field {
  flex: 1;
  min-width: 200px;
}

.select {
  padding: 8px 12px;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  background: #fff;
  font-size: 13px;
  color: #0f172a;
}

.select.w-full {
  width: 100%;
}

.user-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

.user-table th {
  text-align: left;
  color: #64748b;
  font-weight: 600;
  padding: 10px 8px;
  border-bottom: 1px solid #e5e7eb;
}

.user-table td {
  padding: 12px 8px;
  border-bottom: 1px solid #f1f5f9;
  vertical-align: top;
}

.muted {
  color: #94a3b8;
}

.chip {
  display: inline-block;
  padding: 2px 10px;
  background: #eef2ff;
  color: #4338ca;
  border-radius: 999px;
  font-size: 12px;
  margin: 1px 4px 1px 0;
}

.chip--orange {
  background: #fff7ed;
  color: #c2410c;
}

.pending-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-top: 16px;
}

.pending-card {
  padding: 14px;
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
}

.pending-name {
  font-weight: 600;
  color: #0f172a;
}

.pending-meta {
  color: #64748b;
  font-size: 12px;
  margin-top: 2px;
}

.pending-head {
  display: flex;
  gap: 14px;
  flex: 1;
  flex-wrap: wrap;
}

.modal-title {
  margin: 0 0 16px;
  color: #0f172a;
}

.modal-actions {
  margin-top: 20px;
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}

.checkbox-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.chk {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 4px 10px;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  font-size: 13px;
  cursor: pointer;
}

.loading {
  padding: 60px 0;
  display: flex;
  justify-content: center;
}
</style>
