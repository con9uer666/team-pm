<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { showToast, showFailToast, showSuccessToast, showDialog } from 'vant'
import { attendanceApi, AttendanceSessionStatus, type AttendanceFence, type AttendanceSession, type AttendanceStatRow } from '../api/attendance'
import { getPosition, haversine } from '../utils/geolocation'
import { reverseGeocode, hasAmapKey } from '../utils/amap'
import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()

const activeTab = ref<'mine' | 'rank'>('mine')
const rankScope = ref<'week' | 'month' | 'all'>('week')

const activeSession = ref<AttendanceSession | null>(null)
const mySessions = ref<AttendanceSession[]>([])
const fences = ref<AttendanceFence[]>([])
const stats = ref<AttendanceStatRow[]>([])

const loadingAction = ref(false)
const loadingPage = ref(false)
const loadingRank = ref(false)
const nowTick = ref(Date.now())

const myWeekMinutes = computed(() => {
  const monday = startOfWeek()
  return mySessions.value
    .filter(s => s.status === AttendanceSessionStatus.CLOSED && new Date(s.clockInAt) >= monday)
    .reduce((sum, s) => sum + (s.durationMinutes || 0), 0)
})

const myMonthMinutes = computed(() => {
  const firstDay = new Date(new Date().getFullYear(), new Date().getMonth(), 1)
  return mySessions.value
    .filter(s => s.status === AttendanceSessionStatus.CLOSED && new Date(s.clockInAt) >= firstDay)
    .reduce((sum, s) => sum + (s.durationMinutes || 0), 0)
})

const liveElapsedMinutes = computed(() => {
  if (!activeSession.value) return 0
  const start = new Date(activeSession.value.clockInAt).getTime()
  return Math.floor((nowTick.value - start) / 60000)
})

function startOfWeek() {
  const d = new Date()
  const day = (d.getDay() + 6) % 7
  d.setDate(d.getDate() - day)
  d.setHours(0, 0, 0, 0)
  return d
}

function fmtMinutes(m: number) {
  if (!m) return '0h'
  const h = Math.floor(m / 60)
  const min = m % 60
  return h ? `${h}h${min ? ` ${min}m` : ''}` : `${min}m`
}

function fmtTime(s: string | null) {
  if (!s) return '—'
  const d = new Date(s)
  return `${d.getMonth() + 1}/${d.getDate()} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
}

function statusLabel(s: AttendanceSessionStatus) {
  if (s === AttendanceSessionStatus.ACTIVE) return '进行中'
  if (s === AttendanceSessionStatus.CLOSED) return '正常'
  return '异常'
}

function statusTagType(s: AttendanceSessionStatus): 'primary' | 'success' | 'danger' {
  if (s === AttendanceSessionStatus.ACTIVE) return 'primary'
  if (s === AttendanceSessionStatus.CLOSED) return 'success'
  return 'danger'
}

async function refreshMine() {
  loadingPage.value = true
  try {
    const [active, my, fenceList] = await Promise.all([
      attendanceApi.getActive().catch(() => null),
      attendanceApi.getMy({ limit: 30 }),
      attendanceApi.listFences().catch(() => [] as AttendanceFence[]),
    ])
    activeSession.value = active
    mySessions.value = my
    fences.value = fenceList
  } catch (e: any) {
    showFailToast(e?.message || '加载失败')
  } finally {
    loadingPage.value = false
  }
}

async function refreshRank() {
  loadingRank.value = true
  try {
    stats.value = await attendanceApi.getStats({ scope: rankScope.value })
  } catch (e: any) {
    showFailToast(e?.message || '加载排行失败')
  } finally {
    loadingRank.value = false
  }
}

async function handleClockIn() {
  if (loadingAction.value) return
  loadingAction.value = true
  try {
    showToast({ message: '正在获取位置…', type: 'loading', duration: 0, forbidClick: true })
    const pos = await getPosition()
    const address = await reverseGeocode(pos.lat, pos.lng)
    const session = await attendanceApi.clockIn({
      lat: pos.lat,
      lng: pos.lng,
      accuracy: pos.accuracy,
      address: address || undefined,
    })
    activeSession.value = session
    showSuccessToast('上工成功')
    refreshMine()
  } catch (e: any) {
    showFailToast(e?.message || '上工失败')
  } finally {
    loadingAction.value = false
  }
}

async function handleClockOut() {
  if (loadingAction.value) return
  try {
    await showDialog({
      title: '确认下工？',
      message: '确认后将结束本次工时记录',
      showCancelButton: true,
    })
  } catch {
    return
  }
  loadingAction.value = true
  try {
    showToast({ message: '正在获取位置…', type: 'loading', duration: 0, forbidClick: true })
    const pos = await getPosition()
    const address = await reverseGeocode(pos.lat, pos.lng)
    await attendanceApi.clockOut({
      lat: pos.lat,
      lng: pos.lng,
      accuracy: pos.accuracy,
      address: address || undefined,
    })
    activeSession.value = null
    showSuccessToast('下工成功')
    refreshMine()
  } catch (e: any) {
    showFailToast(e?.message || '下工失败')
  } finally {
    loadingAction.value = false
  }
}

// 开屏自检
async function runAutoCheck() {
  if (sessionStorage.getItem('attendance-auto-checked')) return
  sessionStorage.setItem('attendance-auto-checked', '1')

  let pos
  try {
    pos = await getPosition({ enableHighAccuracy: true, timeout: 8000, maximumAge: 60000 })
  } catch {
    return
  }

  const inside = fences.value.find(
    (f) => f.enabled && haversine(pos!.lat, pos!.lng, f.centerLat, f.centerLng) <= f.radius,
  )

  if (!activeSession.value && inside) {
    try {
      await showDialog({
        title: '自动上工',
        message: `检测到你位于 "${inside.name}"，是否立即上工？`,
        showCancelButton: true,
        confirmButtonText: '上工',
      })
    } catch {
      return
    }
    const address = await reverseGeocode(pos.lat, pos.lng)
    try {
      const session = await attendanceApi.clockIn({
        lat: pos.lat,
        lng: pos.lng,
        accuracy: pos.accuracy,
        address: address || undefined,
      })
      activeSession.value = session
      showSuccessToast('已上工')
      refreshMine()
    } catch (e: any) {
      showFailToast(e?.message || '自动上工失败')
    }
  } else if (activeSession.value && !inside) {
    try {
      await showDialog({
        title: '自动下工',
        message: '检测到你已离开打卡范围，是否立即下工？',
        showCancelButton: true,
        confirmButtonText: '下工',
      })
    } catch {
      return
    }
    const address = await reverseGeocode(pos.lat, pos.lng)
    try {
      await attendanceApi.clockOut({
        lat: pos.lat,
        lng: pos.lng,
        accuracy: pos.accuracy,
        address: address || undefined,
      })
      activeSession.value = null
      showSuccessToast('已下工')
      refreshMine()
    } catch (e: any) {
      showFailToast(e?.message || '自动下工失败')
    }
  }
}

function onTabChange(name: string | number) {
  if (name === 'rank' && !stats.value.length) refreshRank()
}

let timer: number | null = null

onMounted(async () => {
  await refreshMine()
  timer = window.setInterval(() => {
    nowTick.value = Date.now()
  }, 30000)
  // 延迟跑自检避免和加载并发
  setTimeout(runAutoCheck, 800)
})
</script>

<template>
  <div class="attendance-page">
    <div class="page-header">
      <h2>打卡考勤</h2>
      <div class="hint" v-if="!hasAmapKey()">未配置 VITE_AMAP_KEY，地址将留空</div>
    </div>

    <van-tabs v-model:active="activeTab" shrink sticky @change="onTabChange">
      <van-tab title="我的" name="mine">
        <div class="status-card animate-fade-in-up" :class="{ 'status-card--active': activeSession }">
          <div class="status-title">
            <van-icon :name="activeSession ? 'clock-o' : 'location-o'" size="18" />
            <span>{{ activeSession ? '已上工' : '未上工' }}</span>
          </div>

          <div v-if="activeSession" class="status-detail">
            <div class="elapsed">{{ fmtMinutes(liveElapsedMinutes) }}</div>
            <div class="sub">上工 {{ fmtTime(activeSession.clockInAt) }}</div>
            <div class="sub" v-if="activeSession.clockInAddress">
              <van-icon name="location-o" /> {{ activeSession.clockInAddress }}
            </div>
          </div>
          <div v-else class="status-empty">点击下方按钮开始新的上工</div>

          <div class="status-actions">
            <van-button
              v-if="!activeSession"
              block
              type="primary"
              :loading="loadingAction"
              @click="handleClockIn"
            >
              上工打卡
            </van-button>
            <van-button
              v-else
              block
              type="danger"
              :loading="loadingAction"
              @click="handleClockOut"
            >
              下工打卡
            </van-button>
          </div>
        </div>

        <div class="summary-row">
          <div class="summary-card">
            <div class="summary-label">本周</div>
            <div class="summary-value">{{ fmtMinutes(myWeekMinutes) }}</div>
          </div>
          <div class="summary-card">
            <div class="summary-label">本月</div>
            <div class="summary-value">{{ fmtMinutes(myMonthMinutes) }}</div>
          </div>
          <div class="summary-card">
            <div class="summary-label">围栏数</div>
            <div class="summary-value">{{ fences.filter(f => f.enabled).length }}</div>
          </div>
        </div>

        <div class="section-title">最近记录</div>
        <van-loading v-if="loadingPage" class="loading" />
        <van-empty v-else-if="!mySessions.length" description="还没有打卡记录" />
        <div v-else class="session-list">
          <div v-for="s in mySessions" :key="s.id" class="session-row">
            <div class="sr-head">
              <van-tag :type="statusTagType(s.status)" plain>{{ statusLabel(s.status) }}</van-tag>
              <span class="sr-duration">{{ fmtMinutes(s.durationMinutes) }}</span>
            </div>
            <div class="sr-times">
              <span>上工 {{ fmtTime(s.clockInAt) }}</span>
              <span class="arrow">→</span>
              <span>{{ s.clockOutAt ? '下工 ' + fmtTime(s.clockOutAt) : '进行中' }}</span>
            </div>
            <div v-if="s.clockInAddress" class="sr-addr">
              <van-icon name="location-o" /> {{ s.clockInAddress }}
            </div>
          </div>
        </div>
      </van-tab>

      <van-tab title="排行榜" name="rank">
        <van-tabs v-model:active="rankScope" shrink @change="refreshRank">
          <van-tab title="本周" name="week" />
          <van-tab title="本月" name="month" />
          <van-tab title="全部" name="all" />
        </van-tabs>

        <van-loading v-if="loadingRank" class="loading" />
        <van-empty v-else-if="!stats.length" description="暂无打卡数据" />
        <div v-else class="rank-list">
          <div
            v-for="(row, idx) in stats"
            :key="row.userId"
            class="rank-row"
            :class="{ 'rank-row--me': row.userId === auth.user?.id }"
          >
            <div class="rank-idx" :class="idx < 3 ? `top-${idx + 1}` : ''">{{ idx + 1 }}</div>
            <div class="rank-name">
              {{ row.realName }}
              <span v-if="row.userId === auth.user?.id" class="me-tag">我</span>
            </div>
            <div class="rank-stat">
              <div class="rank-minutes">{{ fmtMinutes(row.totalMinutes) }}</div>
              <div class="rank-count">{{ row.sessionCount }} 次</div>
            </div>
          </div>
        </div>
      </van-tab>
    </van-tabs>
  </div>
</template>

<style scoped>
.attendance-page {
  padding: 16px;
  padding-bottom: 32px;
}

.page-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 16px;
}

.page-header h2 {
  margin: 0;
  font-size: 20px;
  color: var(--text-primary);
}

.hint {
  font-size: 11px;
  color: var(--text-muted);
}

.status-card {
  margin-top: 14px;
  padding: 20px;
  border-radius: 16px;
  background: linear-gradient(135deg, #60a5fa, #6366f1);
  color: #fff;
  box-shadow: 0 8px 24px rgba(99, 102, 241, 0.18);
}

.status-card--active {
  background: linear-gradient(135deg, #34d399, #10b981);
  box-shadow: 0 8px 24px rgba(16, 185, 129, 0.22);
}

.status-title {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 15px;
  opacity: 0.95;
}

.status-detail {
  margin-top: 14px;
}

.elapsed {
  font-size: 32px;
  font-weight: 700;
  letter-spacing: 1px;
}

.sub {
  margin-top: 4px;
  font-size: 13px;
  opacity: 0.9;
  display: flex;
  align-items: center;
  gap: 4px;
}

.status-empty {
  margin-top: 20px;
  font-size: 14px;
  opacity: 0.85;
}

.status-actions {
  margin-top: 18px;
}

.status-actions :deep(.van-button) {
  background: rgba(255, 255, 255, 0.95);
  color: #0f172a;
  border: none;
}

.status-actions :deep(.van-button--danger) {
  background: rgba(255, 255, 255, 0.95);
  color: #ef4444;
}

.summary-row {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
  margin-top: 14px;
}

.summary-card {
  padding: 12px;
  border-radius: 12px;
  background: var(--bg-card, #fff);
  border: 1px solid rgba(148, 163, 184, 0.15);
  text-align: center;
}

.summary-label {
  font-size: 12px;
  color: var(--text-muted);
}

.summary-value {
  margin-top: 4px;
  font-size: 18px;
  font-weight: 600;
  color: var(--text-primary);
}

.section-title {
  margin: 20px 0 10px;
  font-size: 14px;
  color: var(--text-secondary, var(--text-primary));
  font-weight: 600;
}

.session-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.session-row {
  padding: 12px;
  border-radius: 12px;
  background: var(--bg-card, #fff);
  border: 1px solid rgba(148, 163, 184, 0.15);
}

.sr-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.sr-duration {
  font-weight: 600;
  color: var(--text-primary);
}

.sr-times {
  margin-top: 6px;
  font-size: 13px;
  color: var(--text-secondary, #475569);
  display: flex;
  gap: 6px;
  align-items: center;
  flex-wrap: wrap;
}

.sr-times .arrow {
  color: var(--text-muted);
}

.sr-addr {
  margin-top: 6px;
  font-size: 12px;
  color: var(--text-muted);
  display: flex;
  align-items: center;
  gap: 4px;
}

.rank-list {
  margin-top: 10px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.rank-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  border-radius: 12px;
  background: var(--bg-card, #fff);
  border: 1px solid rgba(148, 163, 184, 0.15);
}

.rank-row--me {
  border-color: rgba(59, 130, 246, 0.4);
  background: rgba(59, 130, 246, 0.05);
}

.rank-idx {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(148, 163, 184, 0.2);
  color: var(--text-secondary, #475569);
  font-weight: 600;
  font-size: 13px;
  flex-shrink: 0;
}

.rank-idx.top-1 {
  background: linear-gradient(135deg, #fbbf24, #f59e0b);
  color: #fff;
}

.rank-idx.top-2 {
  background: linear-gradient(135deg, #cbd5e1, #94a3b8);
  color: #fff;
}

.rank-idx.top-3 {
  background: linear-gradient(135deg, #fb923c, #ea580c);
  color: #fff;
}

.rank-name {
  flex: 1;
  font-size: 14px;
  color: var(--text-primary);
  font-weight: 500;
  display: flex;
  align-items: center;
  gap: 6px;
}

.me-tag {
  font-size: 10px;
  padding: 1px 6px;
  border-radius: 999px;
  background: rgba(59, 130, 246, 0.15);
  color: #3b82f6;
}

.rank-stat {
  text-align: right;
}

.rank-minutes {
  font-size: 15px;
  font-weight: 600;
  color: var(--text-primary);
}

.rank-count {
  font-size: 11px;
  color: var(--text-muted);
}

.loading {
  display: flex;
  justify-content: center;
  padding: 40px 0;
}
</style>
