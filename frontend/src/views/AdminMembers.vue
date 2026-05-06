<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { showSuccessToast, showFailToast } from 'vant'
import { usersApi, orgApi, type UserInfo, type GroupInfo, type DivisionInfo } from '../api/users'
import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()
const canManageRole = computed(() => (auth.user?.roleLevel || 0) >= 5 || auth.user?.isSuperAdmin)
const canDelete = computed(() => (auth.user?.roleLevel || 0) >= 5 || auth.user?.isSuperAdmin)

const members = ref<UserInfo[]>([])
const groups = ref<GroupInfo[]>([])
const divisions = ref<DivisionInfo[]>([])
const loading = ref(false)

const roleNames: Record<number, string> = {
  1: '梯队员',
  2: '正式队员',
  3: '组长',
  4: '项目管理',
  5: '队长',
  6: '指导老师',
}

const showRolePicker = ref(false)
const showGroupPicker = ref(false)
const showDivisionPicker = ref(false)
const showCreateGroup = ref(false)
const showCreateDivision = ref(false)
const showCreateUser = ref(false)
const showLeaderPicker = ref(false)
const editingUser = ref<UserInfo | null>(null)
const newGroupName = ref('')
const newDivisionName = ref('')
const newUser = ref({ username: '', password: '', realName: '', roleLevel: 1, groupIds: [] as string[], divisionIds: [] as string[] })
const editDivisionIds = ref<string[]>([])
const editGroupIds = ref<string[]>([])
const editLeaderIds = ref<string[]>([])
const editingLeaderTarget = ref<{ type: 'group' | 'division'; id: string; name: string } | null>(null)
const roleOptions = [
  { text: '梯队员', value: 1 },
  { text: '正式队员', value: 2 },
  { text: '组长', value: 3 },
  { text: '项目管理', value: 4 },
  { text: '队长', value: 5 },
  { text: '指导老师', value: 6 },
]

async function loadData() {
  loading.value = true
  try {
    const [m, g, d] = await Promise.all([
      usersApi.getAll(),
      orgApi.getGroups(),
      orgApi.getDivisions(),
    ])
    members.value = m
    groups.value = g
    divisions.value = d
  } catch (e: any) {
    showFailToast(e.message || '加载失败')
  } finally {
    loading.value = false
  }
}

function openRolePicker(user: UserInfo) {
  editingUser.value = user
  showRolePicker.value = true
}

async function onRoleConfirm({ selectedOptions }: any) {
  if (!editingUser.value) return
  const role = selectedOptions[0]?.value
  if (!role) return
  try {
    await usersApi.updateRole(editingUser.value.id, role)
    showSuccessToast('角色已更新')
    showRolePicker.value = false
    await loadData()
  } catch (e: any) {
    showFailToast(e.message || '更新失败')
  }
}

function openGroupPicker(user: UserInfo) {
  editingUser.value = user
  editGroupIds.value = user.groupIds ? [...user.groupIds] : []
  showGroupPicker.value = true
}

function toggleGroup(id: string) {
  const idx = editGroupIds.value.indexOf(id)
  if (idx >= 0) {
    editGroupIds.value.splice(idx, 1)
  } else {
    editGroupIds.value.push(id)
  }
}

async function saveGroups() {
  if (!editingUser.value) return
  try {
    await usersApi.assignGroups(editingUser.value.id, editGroupIds.value)
    showSuccessToast('技术组已更新')
    showGroupPicker.value = false
    await loadData()
  } catch (e: any) {
    showFailToast(e.message || '更新失败')
  }
}

async function createGroup() {
  if (!newGroupName.value) return
  try {
    await orgApi.createGroup({ name: newGroupName.value })
    showSuccessToast('小组已创建')
    newGroupName.value = ''
    showCreateGroup.value = false
    await loadData()
  } catch (e: any) {
    showFailToast(e.message || '创建失败')
  }
}

async function createDivision() {
  if (!newDivisionName.value) return
  try {
    await orgApi.createDivision({ name: newDivisionName.value })
    showSuccessToast('兵种已创建')
    newDivisionName.value = ''
    showCreateDivision.value = false
    await loadData()
  } catch (e: any) {
    showFailToast(e.message || '创建失败')
  }
}

function getGroupNames(ids: string[] | null) {
  if (!ids || !ids.length) return '未分组'
  return ids.map(id => groups.value.find(g => g.id === id)?.name || '未知').join('、')
}

function getDivisionNames(ids: string[] | null) {
  if (!ids || !ids.length) return '未分配'
  return ids.map(id => divisions.value.find(d => d.id === id)?.name || '未知').join('、')
}

function openDivisionPicker(user: UserInfo) {
  editingUser.value = user
  editDivisionIds.value = user.divisionIds ? [...user.divisionIds] : []
  showDivisionPicker.value = true
}

function toggleDivision(id: string) {
  const idx = editDivisionIds.value.indexOf(id)
  if (idx >= 0) {
    editDivisionIds.value.splice(idx, 1)
  } else {
    editDivisionIds.value.push(id)
  }
}

async function saveDivisions() {
  if (!editingUser.value) return
  try {
    await usersApi.assignDivisions(editingUser.value.id, editDivisionIds.value)
    showSuccessToast('兵种已更新')
    showDivisionPicker.value = false
    await loadData()
  } catch (e: any) {
    showFailToast(e.message || '更新失败')
  }
}

function toggleNewUserDivision(id: string) {
  const idx = newUser.value.divisionIds.indexOf(id)
  if (idx >= 0) {
    newUser.value.divisionIds.splice(idx, 1)
  } else {
    newUser.value.divisionIds.push(id)
  }
}

function toggleNewUserGroup(id: string) {
  const idx = newUser.value.groupIds.indexOf(id)
  if (idx >= 0) {
    newUser.value.groupIds.splice(idx, 1)
  } else {
    newUser.value.groupIds.push(id)
  }
}

async function createUser() {
  if (!newUser.value.username || !newUser.value.password || !newUser.value.realName) {
    showFailToast('请填写完整信息')
    return
  }
  try {
    await usersApi.createUser({
      username: newUser.value.username,
      password: newUser.value.password,
      realName: newUser.value.realName,
      roleLevel: newUser.value.roleLevel,
      groupIds: newUser.value.groupIds.length ? newUser.value.groupIds : undefined,
      divisionIds: newUser.value.divisionIds.length ? newUser.value.divisionIds : undefined,
    })
    showSuccessToast('账号已创建')
    newUser.value = { username: '', password: '', realName: '', roleLevel: 1, groupIds: [], divisionIds: [] }
    showCreateUser.value = false
    await loadData()
  } catch (e: any) {
    showFailToast(e.message || '创建失败')
  }
}

async function removeUser(user: UserInfo) {
  try {
    await usersApi.removeUser(user.id)
    showSuccessToast('账号已删除')
    await loadData()
  } catch (e: any) {
    showFailToast(e.message || '删除失败')
  }
}

function getLeaderNames(leaderIds: string[] | null) {
  if (!leaderIds || !leaderIds.length) return '未设置'
  return leaderIds.map(id => members.value.find(m => m.id === id)?.realName || '未知').join('、')
}

function openLeaderPicker(type: 'group' | 'division', id: string, name: string, currentLeaderIds: string[] | null) {
  editingLeaderTarget.value = { type, id, name }
  editLeaderIds.value = currentLeaderIds ? [...currentLeaderIds] : []
  showLeaderPicker.value = true
}

function toggleLeader(id: string) {
  const idx = editLeaderIds.value.indexOf(id)
  if (idx >= 0) {
    editLeaderIds.value.splice(idx, 1)
  } else {
    editLeaderIds.value.push(id)
  }
}

async function saveLeaders() {
  if (!editingLeaderTarget.value) return
  try {
    if (editingLeaderTarget.value.type === 'group') {
      await orgApi.setGroupLeaders(editingLeaderTarget.value.id, editLeaderIds.value)
    } else {
      await orgApi.setDivisionLeaders(editingLeaderTarget.value.id, editLeaderIds.value)
    }
    showSuccessToast('组长已更新')
    showLeaderPicker.value = false
    await loadData()
  } catch (e: any) {
    showFailToast(e.message || '更新失败')
  }
}

onMounted(loadData)
</script>

<template>
  <div class="admin-page">
    <van-nav-bar title="成员管理" left-arrow @click-left="$router.back()" />

    <van-tabs>
      <van-tab title="成员列表">
        <div style="padding: 12px 16px;">
          <van-button type="primary" size="small" block @click="showCreateUser = true">+ 创建账号</van-button>
        </div>
        <van-cell-group v-for="member in members" :key="member.id" inset class="member-card">
          <van-cell :title="member.realName" :label="'@' + member.username">
            <template #right-icon>
              <van-tag v-if="member.isSuperAdmin" type="danger">超级管理员</van-tag>
              <van-tag v-else type="primary" plain>{{ roleNames[member.roleLevel] }}</van-tag>
            </template>
          </van-cell>
          <van-cell title="所属技术组" :value="getGroupNames(member.groupIds)" is-link @click="openGroupPicker(member)" />
          <van-cell title="所属兵种" :value="getDivisionNames(member.divisionIds)" is-link @click="openDivisionPicker(member)" />
          <van-cell v-if="!member.isSuperAdmin && canManageRole" title="修改角色" is-link @click="openRolePicker(member)" />
          <van-cell v-if="!member.isSuperAdmin && canDelete" title="删除账号" @click="removeUser(member)">
            <template #right-icon>
              <van-icon name="delete-o" color="#ee0a24" />
            </template>
          </van-cell>
        </van-cell-group>
      </van-tab>

      <van-tab title="组织架构">
        <van-cell-group title="兵种组" inset>
          <van-cell v-for="d in divisions" :key="d.id" :title="d.name" :label="'组长: ' + getLeaderNames(d.leaderIds)" is-link @click="openLeaderPicker('division', d.id, d.name, d.leaderIds)" />
          <van-cell title="+ 创建兵种" is-link @click="showCreateDivision = true" />
        </van-cell-group>
        <van-cell-group title="技术组" inset style="margin-top: 12px;">
          <van-cell v-for="g in groups" :key="g.id" :title="g.name" :label="'组长: ' + getLeaderNames(g.leaderIds)" is-link @click="openLeaderPicker('group', g.id, g.name, g.leaderIds)" />
          <van-cell title="+ 创建技术组" is-link @click="showCreateGroup = true" />
        </van-cell-group>
      </van-tab>
    </van-tabs>

    <!-- 角色选择器 -->
    <van-popup v-model:show="showRolePicker" position="bottom" round>
      <van-picker
        :columns="roleOptions"
        @confirm="onRoleConfirm"
        @cancel="showRolePicker = false"
      />
    </van-popup>

    <!-- 技术组选择器（多选） -->
    <van-popup v-model:show="showGroupPicker" position="bottom" round style="height: 50%;">
      <van-nav-bar title="选择技术组（多选）" left-text="取消" right-text="确认" @click-left="showGroupPicker = false" @click-right="saveGroups" />
      <van-cell-group>
        <van-cell
          v-for="g in groups" :key="g.id"
          :title="g.name"
          clickable
          @click="toggleGroup(g.id)"
        >
          <template #right-icon>
            <van-icon v-if="editGroupIds.includes(g.id)" name="success" color="#1989fa" size="20" />
          </template>
        </van-cell>
      </van-cell-group>
    </van-popup>

    <!-- 创建技术组 -->
    <van-dialog v-model:show="showCreateGroup" title="创建技术组" show-cancel-button @confirm="createGroup">
      <div style="padding: 16px;">
        <van-field v-model="newGroupName" label="名称" placeholder="技术组名称" />
      </div>
    </van-dialog>

    <!-- 创建兵种 -->
    <van-dialog v-model:show="showCreateDivision" title="创建兵种" show-cancel-button @confirm="createDivision">
      <div style="padding: 16px;">
        <van-field v-model="newDivisionName" label="名称" placeholder="兵种名称" />
      </div>
    </van-dialog>

    <!-- 创建账号 -->
    <van-popup v-model:show="showCreateUser" position="bottom" round style="height: 75%;">
      <van-nav-bar title="创建账号" left-text="取消" right-text="确认" @click-left="showCreateUser = false" @click-right="createUser" />
      <van-field v-model="newUser.username" label="用户名" placeholder="登录用户名" />
      <van-field v-model="newUser.password" label="密码" placeholder="初始密码" type="password" />
      <van-field v-model="newUser.realName" label="姓名" placeholder="真实姓名" />
      <van-field label="角色">
        <template #input>
          <select v-model.number="newUser.roleLevel" style="width: 100%; border: none; font-size: 14px;">
            <option v-for="r in roleOptions" :key="r.value" :value="r.value">{{ r.text }}</option>
          </select>
        </template>
      </van-field>
      <van-field label="技术组">
        <template #input>
          <div style="display: flex; flex-wrap: wrap; gap: 6px;">
            <van-tag
              v-for="g in groups" :key="g.id"
              :type="newUser.groupIds.includes(g.id) ? 'primary' : 'default'"
              :plain="!newUser.groupIds.includes(g.id)"
              style="cursor: pointer;"
              @click="toggleNewUserGroup(g.id)"
            >{{ g.name }}</van-tag>
          </div>
        </template>
      </van-field>
      <van-field label="兵种">
        <template #input>
          <div style="display: flex; flex-wrap: wrap; gap: 6px;">
            <van-tag
              v-for="d in divisions" :key="d.id"
              :type="newUser.divisionIds.includes(d.id) ? 'primary' : 'default'"
              :plain="!newUser.divisionIds.includes(d.id)"
              style="cursor: pointer;"
              @click="toggleNewUserDivision(d.id)"
            >{{ d.name }}</van-tag>
          </div>
        </template>
      </van-field>
    </van-popup>

    <!-- 兵种选择器（多选） -->
    <van-popup v-model:show="showDivisionPicker" position="bottom" round style="height: 50%;">
      <van-nav-bar title="选择兵种（多选）" left-text="取消" right-text="确认" @click-left="showDivisionPicker = false" @click-right="saveDivisions" />
      <van-cell-group>
        <van-cell
          v-for="d in divisions" :key="d.id"
          :title="d.name"
          clickable
          @click="toggleDivision(d.id)"
        >
          <template #right-icon>
            <van-icon v-if="editDivisionIds.includes(d.id)" name="success" color="#1989fa" size="20" />
          </template>
        </van-cell>
      </van-cell-group>
    </van-popup>

    <!-- 组长选择器（多选） -->
    <van-popup v-model:show="showLeaderPicker" position="bottom" round style="height: 60%;">
      <van-nav-bar :title="'设置组长 - ' + (editingLeaderTarget?.name || '')" left-text="取消" right-text="确认" @click-left="showLeaderPicker = false" @click-right="saveLeaders" />
      <div style="overflow-y: auto; max-height: calc(60vh - 46px);">
        <van-cell-group>
          <van-cell
            v-for="m in members" :key="m.id"
            :title="m.realName"
            :label="roleNames[m.roleLevel]"
            clickable
            @click="toggleLeader(m.id)"
          >
            <template #right-icon>
              <van-icon v-if="editLeaderIds.includes(m.id)" name="success" color="#1989fa" size="20" />
            </template>
          </van-cell>
        </van-cell-group>
      </div>
    </van-popup>
  </div>
</template>

<style scoped>
.admin-page {
  max-width: 900px;
  margin: 0 auto;
}

.member-card {
  margin-top: 12px;
  animation: fadeInUp 0.3s ease both;
  transition: transform var(--transition-fast), box-shadow var(--transition-fast);
}

.member-card:hover {
  transform: translateY(-2px);
  box-shadow: var(--shadow-md);
}
</style>
