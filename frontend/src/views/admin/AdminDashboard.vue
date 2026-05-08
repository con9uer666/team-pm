<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { showFailToast } from 'vant'
import { adminApi, type DashboardStats } from '../../api/admin'

const stats = ref<DashboardStats | null>(null)
const loading = ref(false)

async function load() {
  loading.value = true
  try {
    stats.value = await adminApi.getDashboardStats()
  } catch (e: any) {
    showFailToast(e?.message || '加载失败')
  } finally {
    loading.value = false
  }
}

const roleNames: Record<string, string> = {
  '1': '梯队员', '2': '正式队员', '3': '组长', '4': '项管', '5': '队长', '6': '指导老师',
}

onMounted(load)
</script>

<template>
  <div class="dashboard">
    <div v-if="loading && !stats" class="loading"><van-loading /></div>
    <template v-else-if="stats">
      <h2 class="section-title">概览</h2>
      <div class="card-grid">
        <div class="stat-card stat-card--blue">
          <div class="stat-label">全部用户</div>
          <div class="stat-value">{{ stats.users.total }}</div>
          <div class="stat-hint">已审核 {{ stats.users.approved }}</div>
        </div>
        <div class="stat-card stat-card--amber">
          <div class="stat-label">待审核</div>
          <div class="stat-value">{{ stats.users.pending }}</div>
          <div class="stat-hint">需尽快处理</div>
        </div>
        <div class="stat-card stat-card--green">
          <div class="stat-label">进行中任务</div>
          <div class="stat-value">{{ stats.tasks.active }}</div>
          <div class="stat-hint">待审核 {{ stats.tasks.pendingReview }}</div>
        </div>
        <div class="stat-card stat-card--red">
          <div class="stat-label">逾期任务</div>
          <div class="stat-value">{{ stats.tasks.overdue }}</div>
          <div class="stat-hint">需关注</div>
        </div>
        <div class="stat-card stat-card--purple">
          <div class="stat-label">活跃目标</div>
          <div class="stat-value">{{ stats.objectives.active }}</div>
          <div class="stat-hint">已完成 {{ stats.objectives.completed }}</div>
        </div>
        <div class="stat-card stat-card--cyan">
          <div class="stat-label">会议</div>
          <div class="stat-value">{{ stats.meetings.scheduled }}</div>
          <div class="stat-hint">总计 {{ stats.meetings.total }}</div>
        </div>
      </div>

      <div class="split">
        <section class="panel">
          <h3>角色分布</h3>
          <div v-for="(count, level) in stats.users.byRole" :key="level" class="role-row">
            <span>{{ roleNames[level] || `Lv.${level}` }}</span>
            <span class="role-count">{{ count }}</span>
          </div>
        </section>

        <section class="panel">
          <h3>组织规模</h3>
          <div class="role-row"><span>兵种组</span><span class="role-count">{{ stats.organization.divisions }}</span></div>
          <div class="role-row"><span>技术组</span><span class="role-count">{{ stats.organization.groups }}</span></div>
          <div class="role-row"><span>任务总数</span><span class="role-count">{{ stats.tasks.total }}</span></div>
        </section>
      </div>
    </template>
  </div>
</template>

<style scoped>
.dashboard {
  padding: 8px 4px;
}

.section-title {
  margin: 0 0 16px;
  font-size: 17px;
  color: #0f172a;
  font-weight: 600;
}

.card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 16px;
  margin-bottom: 24px;
}

.stat-card {
  padding: 20px;
  border-radius: 14px;
  background: #fff;
  box-shadow: 0 2px 12px rgba(15, 23, 42, 0.05);
  position: relative;
  overflow: hidden;
}

.stat-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  width: 4px;
  height: 100%;
}

.stat-card--blue::before { background: linear-gradient(180deg, #3b82f6, #6366f1); }
.stat-card--amber::before { background: linear-gradient(180deg, #f59e0b, #f97316); }
.stat-card--green::before { background: linear-gradient(180deg, #10b981, #34d399); }
.stat-card--red::before { background: linear-gradient(180deg, #ef4444, #f87171); }
.stat-card--purple::before { background: linear-gradient(180deg, #8b5cf6, #a855f7); }
.stat-card--cyan::before { background: linear-gradient(180deg, #06b6d4, #14b8a6); }

.stat-label {
  font-size: 13px;
  color: #64748b;
  margin-bottom: 6px;
}

.stat-value {
  font-size: 30px;
  font-weight: 700;
  color: #0f172a;
  margin-bottom: 4px;
}

.stat-hint {
  font-size: 12px;
  color: #94a3b8;
}

.split {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 16px;
}

.panel {
  padding: 20px;
  background: #fff;
  border-radius: 14px;
  box-shadow: 0 2px 12px rgba(15, 23, 42, 0.05);
}

.panel h3 {
  margin: 0 0 16px;
  font-size: 14px;
  color: #64748b;
  font-weight: 600;
}

.role-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 0;
  border-bottom: 1px dashed #e5e7eb;
  font-size: 14px;
  color: #0f172a;
}

.role-row:last-child {
  border-bottom: none;
}

.role-count {
  font-weight: 600;
  color: #6366f1;
}

.loading {
  display: flex;
  justify-content: center;
  padding: 60px 0;
}
</style>
