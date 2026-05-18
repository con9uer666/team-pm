<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { showFailToast } from 'vant'
import { useAuthStore } from '../stores/auth'
import { tasksApi } from '../api/tasks'
import { meetingsApi } from '../api/meetings'

const router = useRouter()
const auth = useAuthStore()
const loaded = ref(false)

// Bumps the stat numbers exactly once when data first lands, so the user
// gets a small visual confirmation of "fresh data" without the bump
// recurring on every silent refresh.
const bumpKey = ref(0)

const stats = ref({
  pendingTasks: 0,
  overdueTasks: 0,
  upcomingMeetings: 0,
  completedTasks: 0,
  totalTasks: 0,
})

async function loadStats() {
  try {
    const [tasks, meetings] = await Promise.all([
      tasksApi.getAll({ assigneeId: auth.user?.id }),
      meetingsApi.getMy(),
    ])
    stats.value.totalTasks = tasks.length
    stats.value.pendingTasks = tasks.filter(t => t.status === 'approved' || t.status === 'pending_review').length
    stats.value.overdueTasks = tasks.filter(t => t.status === 'overdue').length
    stats.value.completedTasks = tasks.filter(t => t.status === 'completed').length
    stats.value.upcomingMeetings = meetings.filter(m => m.status === 'scheduled').length
  } catch (e: any) {
    showFailToast(e?.message || '加载首页数据失败，请下拉刷新')
  }
  if (!loaded.value) bumpKey.value++
  loaded.value = true
}

const completionRate = computed(() => {
  if (!stats.value.totalTasks) return 0
  return Math.round((stats.value.completedTasks / stats.value.totalTasks) * 100)
})

const greeting = computed(() => {
  const hour = new Date().getHours()
  if (hour < 12) return '早上好'
  if (hour < 18) return '下午好'
  return '晚上好'
})

onMounted(loadStats)
</script>

<template>
  <div class="dashboard">
    <!-- Header -->
    <div class="dashboard__header animate-fade-in-up">
      <div>
        <h1 class="dashboard__greeting">{{ greeting }}，{{ auth.user?.realName || '队员' }}</h1>
        <p class="dashboard__subtitle">这是你的工作概览</p>
      </div>
      <div class="header__date">
        {{ new Date().toLocaleDateString('zh-CN', { month: 'long', day: 'numeric', weekday: 'long' }) }}
      </div>
    </div>

    <!-- Stat Cards -->
    <div class="stat-cards">
      <div class="card-gradient animate-fade-in-up stagger-1" style="background: var(--gradient-blue);" @click="router.push({ path: '/tasks', query: { status: 'pending_review' }})">
        <div class="stat-number animate-count-bump" :key="`p-${bumpKey}`">{{ stats.pendingTasks }}</div>
        <div class="stat-label">待完成任务</div>
        <div class="stat-icon">
          <van-icon name="todo-list-o" size="32" color="rgba(255,255,255,0.3)" />
        </div>
      </div>
      <div class="card-gradient animate-fade-in-up stagger-2" style="background: var(--gradient-green);" @click="router.push({ path: '/tasks', query: { status: 'completed' }})">
        <div class="stat-number animate-count-bump" :key="`c-${bumpKey}`">{{ stats.completedTasks }}</div>
        <div class="stat-label">已完成任务</div>
        <div class="stat-icon">
          <van-icon name="label-o" size="32" color="rgba(255,255,255,0.3)" />
        </div>
      </div>
      <div class="card-gradient animate-fade-in-up stagger-3" style="background: var(--gradient-cyan);" @click="router.push('/meetings')">
        <div class="stat-number animate-count-bump" :key="`m-${bumpKey}`">{{ stats.upcomingMeetings }}</div>
        <div class="stat-label">近期会议</div>
        <div class="stat-icon">
          <van-icon name="clock-o" size="32" color="rgba(255,255,255,0.3)" />
        </div>
      </div>
      <div class="card-gradient animate-fade-in-up stagger-4" style="background: var(--gradient-orange);" @click="router.push({ path: '/tasks', query: { status: 'overdue' }})">
        <div class="stat-number animate-count-bump" :key="`o-${bumpKey}`">{{ stats.overdueTasks }}</div>
        <div class="stat-label">逾期任务</div>
        <div class="stat-icon">
          <van-icon name="warning-o" size="32" color="rgba(255,255,255,0.3)" />
        </div>
      </div>
    </div>

    <!-- Progress Section -->
    <div class="dashboard__row">
      <div class="card progress-card animate-fade-in-up stagger-3">
        <div class="card__header">
          <h3>任务完成率</h3>
        </div>
        <div class="progress-ring-wrapper">
          <div class="progress-ring">
            <svg viewBox="0 0 120 120">
              <circle cx="60" cy="60" r="50" fill="none" stroke="#e2e8f0" stroke-width="10" />
              <circle
                cx="60" cy="60" r="50" fill="none"
                stroke="url(#progressGradient)" stroke-width="10"
                stroke-linecap="round"
                :stroke-dasharray="`${completionRate * 3.14} 314`"
                transform="rotate(-90 60 60)"
                class="progress-circle"
              />
              <defs>
                <linearGradient id="progressGradient" x1="0%" y1="0%" x2="100%" y2="0%">
                  <stop offset="0%" stop-color="#667eea" />
                  <stop offset="100%" stop-color="#764ba2" />
                </linearGradient>
              </defs>
            </svg>
            <div class="progress-text">
              <span class="progress-value">{{ completionRate }}%</span>
              <span class="progress-label">完成</span>
            </div>
          </div>
          <div class="progress-stats">
            <div class="progress-stat-item">
              <span class="dot dot--completed"></span>
              <span>已完成 {{ stats.completedTasks }}</span>
            </div>
            <div class="progress-stat-item">
              <span class="dot dot--pending"></span>
              <span>进行中 {{ stats.pendingTasks }}</span>
            </div>
            <div class="progress-stat-item">
              <span class="dot dot--overdue"></span>
              <span>已逾期 {{ stats.overdueTasks }}</span>
            </div>
          </div>
        </div>
      </div>

      <div class="card quick-actions animate-fade-in-up stagger-4">
        <div class="card__header">
          <h3>快捷操作</h3>
        </div>
        <div class="actions-grid">
          <div class="action-item" @click="router.push('/tasks')">
            <div class="action-icon" style="background: rgba(59,130,246,0.1); color: var(--accent-blue);">
              <van-icon name="plus" size="20" />
            </div>
            <span>创建任务</span>
          </div>
          <div class="action-item" @click="router.push('/meetings')">
            <div class="action-icon" style="background: rgba(16,185,129,0.1); color: var(--accent-green);">
              <van-icon name="clock-o" size="20" />
            </div>
            <span>安排会议</span>
          </div>
          <div class="action-item" @click="router.push('/attendance')">
            <div class="action-icon" style="background: rgba(245,158,11,0.1); color: var(--accent-orange);">
              <van-icon name="clock-o" size="20" />
            </div>
            <span>打卡考勤</span>
          </div>
          <div class="action-item" @click="router.push('/notifications')">
            <div class="action-icon" style="background: rgba(139,92,246,0.1); color: var(--accent-purple);">
              <van-icon name="bell" size="20" />
            </div>
            <span>查看通知</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.dashboard {
  max-width: 1200px;
  margin: 0 auto;
}

.dashboard__header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 28px;
}

.dashboard__greeting {
  font-size: 26px;
  font-weight: 700;
  margin: 0;
  color: var(--text-primary);
}

.dashboard__subtitle {
  margin: 6px 0 0;
  color: var(--text-secondary);
  font-size: 14px;
}

.header__date {
  font-size: 13px;
  color: var(--text-muted);
  background: var(--bg-card);
  padding: 8px 14px;
  border-radius: var(--radius-sm);
  box-shadow: var(--shadow-sm);
}

/* Stat Cards Grid */
.stat-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 16px;
  margin-bottom: 24px;
}

.card-gradient {
  position: relative;
  cursor: pointer;
}

.stat-icon {
  position: absolute;
  top: 16px;
  right: 16px;
  opacity: 0.6;
}

/* Dashboard Row */
.dashboard__row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
}

@media (max-width: 768px) {
  .dashboard__row {
    grid-template-columns: 1fr;
  }
  .stat-cards {
    grid-template-columns: repeat(2, 1fr);
  }
  .dashboard__header {
    flex-direction: column;
    gap: 12px;
  }
}

/* Card common */
.card__header {
  padding: 20px 20px 0;
}

.card__header h3 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  color: var(--text-primary);
}

/* Progress Card */
.progress-card {
  padding-bottom: 20px;
}

.progress-ring-wrapper {
  display: flex;
  align-items: center;
  gap: 24px;
  padding: 20px;
}

.progress-ring {
  position: relative;
  width: 120px;
  height: 120px;
  flex-shrink: 0;
}

.progress-ring svg {
  width: 100%;
  height: 100%;
}

.progress-circle {
  transition: stroke-dasharray 1s ease;
}

.progress-text {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  text-align: center;
}

.progress-value {
  display: block;
  font-size: 24px;
  font-weight: 700;
  color: var(--text-primary);
}

.progress-label {
  font-size: 12px;
  color: var(--text-muted);
}

.progress-stats {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.progress-stat-item {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  color: var(--text-secondary);
}

.dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}

.dot--completed { background: var(--accent-green); }
.dot--pending { background: var(--accent-blue); }
.dot--overdue { background: var(--accent-red); }

/* Quick Actions */
.quick-actions {
  padding-bottom: 20px;
}

.actions-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
  padding: 16px 20px;
}

.action-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 16px 12px;
  border-radius: var(--radius-sm);
  cursor: pointer;
  transition: all var(--transition-fast);
  border: 1px solid #f1f5f9;
}

.action-item:hover {
  background: #f8fafc;
  transform: translateY(-2px);
  box-shadow: var(--shadow-sm);
}

.action-item:active {
  transform: scale(0.96);
}

.action-icon {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.action-item span {
  font-size: 12px;
  color: var(--text-secondary);
  font-weight: 500;
}
</style>
