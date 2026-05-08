<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { showToast } from 'vant'
import { orgApi, type UserInfo, type GroupInfo, type DivisionInfo } from '../api/users'
import { roleLabel } from '../composables/useRoleLabel'

const users = ref<UserInfo[]>([])
const groups = ref<GroupInfo[]>([])
const divisions = ref<DivisionInfo[]>([])
const loading = ref(false)
const expandedDivisions = ref<Set<string>>(new Set())
const expandedGroups = ref<Set<string>>(new Set())

async function loadData() {
  loading.value = true
  try {
    const data = await orgApi.getStructure()
    users.value = data.users
    groups.value = data.groups
    divisions.value = data.divisions
  } catch (e: any) {
    showToast({ message: e.message || '加载失败', type: 'fail' })
  } finally {
    loading.value = false
  }
}

const topManagement = computed(() =>
  users.value.filter(u => u.roleLevel >= 5)
)

function getUser(id: string) {
  return users.value.find(u => u.id === id)
}

function getUserName(id: string) {
  return getUser(id)?.realName || '未知'
}

function getUserLabel(u: UserInfo) {
  return roleLabel(u.roleLevel, u.position)
}

function getDivisionLeaders(d: DivisionInfo) {
  return (d.leaderIds || []).map(id => getUserName(id))
}

function getDivisionMembers(d: DivisionInfo) {
  return users.value.filter(u =>
    u.divisionIds?.includes(d.id) && !(d.leaderIds || []).includes(u.id)
  )
}

function getGroupLeaders(g: GroupInfo) {
  return (g.leaderIds || []).map(id => getUserName(id))
}

function getGroupMembers(g: GroupInfo) {
  return users.value.filter(u =>
    u.groupIds?.includes(g.id) && !(g.leaderIds || []).includes(u.id)
  )
}

function toggleDivision(id: string) {
  if (expandedDivisions.value.has(id)) {
    expandedDivisions.value.delete(id)
  } else {
    expandedDivisions.value.add(id)
  }
}

function toggleGroup(id: string) {
  if (expandedGroups.value.has(id)) {
    expandedGroups.value.delete(id)
  } else {
    expandedGroups.value.add(id)
  }
}

onMounted(loadData)
</script>

<template>
  <div class="structure-page">
    <div class="page-header animate-fade-in-up">
      <h2>团队架构</h2>
    </div>

    <van-pull-refresh v-model="loading" @refresh="loadData">
      <div class="tree">
        <!-- 高层管理 -->
        <div class="tree-node tree-root animate-fade-in-up">
          <div class="tree-label">管理层</div>
          <div class="tree-children">
            <div v-for="u in topManagement" :key="u.id" class="tree-leaf">
              <span class="leaf-name">{{ u.realName }}</span>
              <van-tag type="primary" plain size="medium">{{ getUserLabel(u) }}</van-tag>
            </div>
          </div>
        </div>

        <!-- 兵种组 -->
        <div class="tree-node animate-fade-in-up stagger-1">
          <div class="tree-label">兵种组</div>
          <div class="tree-children">
            <div v-for="d in divisions" :key="d.id" class="tree-branch">
              <div class="branch-header" @click="toggleDivision(d.id)">
                <van-icon :name="expandedDivisions.has(d.id) ? 'arrow-down' : 'arrow'" size="14" />
                <span class="branch-name">{{ d.name }}</span>
                <van-tag v-if="getDivisionLeaders(d).length" type="success" plain size="medium">
                  {{ getDivisionLeaders(d).join('、') }}
                </van-tag>
              </div>
              <div v-if="expandedDivisions.has(d.id)" class="branch-children">
                <div v-if="getDivisionLeaders(d).length" class="role-section">
                  <span class="role-label">组长</span>
                  <span v-for="name in getDivisionLeaders(d)" :key="name" class="member-tag leader">{{ name }}</span>
                </div>
                <div class="role-section">
                  <span class="role-label">组员</span>
                  <span v-for="m in getDivisionMembers(d)" :key="m.id" class="member-tag">{{ m.realName }}</span>
                  <span v-if="!getDivisionMembers(d).length" class="empty-text">暂无组员</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- 技术组 -->
        <div class="tree-node animate-fade-in-up stagger-2">
          <div class="tree-label">技术组</div>
          <div class="tree-children">
            <div v-for="g in groups" :key="g.id" class="tree-branch">
              <div class="branch-header" @click="toggleGroup(g.id)">
                <van-icon :name="expandedGroups.has(g.id) ? 'arrow-down' : 'arrow'" size="14" />
                <span class="branch-name">{{ g.name }}</span>
                <van-tag v-if="getGroupLeaders(g).length" type="success" plain size="medium">
                  {{ getGroupLeaders(g).join('、') }}
                </van-tag>
              </div>
              <div v-if="expandedGroups.has(g.id)" class="branch-children">
                <div v-if="getGroupLeaders(g).length" class="role-section">
                  <span class="role-label">组长</span>
                  <span v-for="name in getGroupLeaders(g)" :key="name" class="member-tag leader">{{ name }}</span>
                </div>
                <div class="role-section">
                  <span class="role-label">组员</span>
                  <span v-for="m in getGroupMembers(g)" :key="m.id" class="member-tag">{{ m.realName }}</span>
                  <span v-if="!getGroupMembers(g).length" class="empty-text">暂无组员</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </van-pull-refresh>
  </div>
</template>

<style scoped>
.structure-page {
  max-width: 800px;
  margin: 0 auto;
}

.page-header {
  margin-bottom: 20px;
}

.page-header h2 {
  font-size: 22px;
  font-weight: 700;
  margin: 0;
  color: var(--text-primary);
}

.tree {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.tree-node {
  background: var(--bg-card);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-sm);
  overflow: hidden;
}

.tree-label {
  padding: 14px 20px;
  font-size: 15px;
  font-weight: 600;
  color: var(--text-primary);
  background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
  border-bottom: 1px solid #e2e8f0;
}

.tree-children {
  padding: 12px 16px;
}

.tree-leaf {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  border-radius: 8px;
  transition: background 0.2s;
}

.tree-leaf:hover {
  background: #f8fafc;
}

.leaf-name {
  font-size: 14px;
  color: var(--text-primary);
}

.tree-branch {
  margin-bottom: 4px;
}

.branch-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 12px;
  border-radius: 8px;
  cursor: pointer;
  transition: background 0.2s;
}

.branch-header:hover {
  background: #f8fafc;
}

.branch-name {
  font-size: 14px;
  font-weight: 500;
  color: var(--text-primary);
  flex: 1;
}

.branch-children {
  padding: 8px 12px 8px 32px;
}

.role-section {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 6px;
  margin-bottom: 8px;
}

.role-label {
  font-size: 12px;
  color: var(--text-muted);
  min-width: 36px;
}

.member-tag {
  display: inline-block;
  padding: 2px 10px;
  font-size: 13px;
  background: #f1f5f9;
  border-radius: 12px;
  color: var(--text-secondary);
}

.member-tag.leader {
  background: #ecfdf5;
  color: #059669;
  font-weight: 500;
}

.empty-text {
  font-size: 12px;
  color: var(--text-muted);
}
</style>
