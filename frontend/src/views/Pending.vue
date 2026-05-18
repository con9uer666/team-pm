<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { showToast } from 'vant'
import { useAuthStore } from '../stores/auth'
import { approvalsApi, type ApprovalStatus } from '../api/approvals'

const router = useRouter()
const auth = useAuthStore()
const status = ref<ApprovalStatus | null>(null)
const loading = ref(false)

async function load() {
  loading.value = true
  try {
    status.value = await approvalsApi.getMyStatus()
    if (status.value.approvalStatus === 'approved') {
      await auth.init()
      router.replace('/')
    }
  } catch (e: any) {
    showToast(e?.message || '加载失败')
  } finally {
    loading.value = false
  }
}

async function refresh() {
  await load()
  if (status.value?.approvalStatus === 'pending') {
    showToast('仍在审核中')
  } else {
    // approved/rejected — 已经在 load() 里更新了 status.value，让用户看到结果。
    showToast('已刷新')
  }
}

async function handleLogout() {
  await auth.logout()
  router.replace('/login')
}

onMounted(load)
</script>

<template>
  <div class="pending-page">
    <div class="pending-card animate-fade-in-up">
      <template v-if="status?.approvalStatus === 'rejected'">
        <div class="icon-wrap icon--reject">
          <van-icon name="close" size="36" color="#fff" />
        </div>
        <h1>注册未通过</h1>
        <p class="reason-label">原因</p>
        <p class="reason">{{ status.approvalRejectReason || '未填写' }}</p>
        <p class="hint">如有疑问请联系组长或项管</p>
      </template>

      <template v-else>
        <div class="icon-wrap icon--pending">
          <van-icon name="clock-o" size="36" color="#fff" />
        </div>
        <h1>注册审核中</h1>
        <p class="hint">你所选技术组的组长和高层已收到通知，请耐心等待审核</p>
        <p class="hint-secondary">审核通过后可访问全部功能；在此之前可以查看团队架构和个人通知。</p>
      </template>

      <div class="actions">
        <van-button block type="primary" :loading="loading" @click="refresh">刷新状态</van-button>
        <van-button block plain @click="router.push('/team-structure')">查看团队架构</van-button>
        <van-button block plain @click="router.push('/notifications')">查看通知</van-button>
        <van-button block plain @click="handleLogout">退出登录</van-button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.pending-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
  background: var(--sidebar-bg);
}

.pending-card {
  width: 100%;
  max-width: 420px;
  background: var(--bg-card);
  padding: 32px 24px;
  border-radius: var(--radius-xl);
  text-align: center;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
}

.icon-wrap {
  width: 72px;
  height: 72px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 20px;
}

.icon--pending {
  background: linear-gradient(135deg, #3b82f6, #8b5cf6);
}

.icon--reject {
  background: linear-gradient(135deg, #ef4444, #f97316);
}

h1 {
  margin: 0 0 12px;
  font-size: 22px;
  color: var(--text-primary);
}

.reason-label {
  margin: 12px 0 4px;
  font-size: 13px;
  color: var(--text-muted);
}

.reason {
  margin: 0 0 16px;
  padding: 12px 16px;
  background: rgba(239, 68, 68, 0.08);
  border-radius: 10px;
  color: #dc2626;
  font-size: 14px;
  text-align: left;
}

.hint {
  margin: 0 0 8px;
  color: var(--text-primary);
  font-size: 14px;
  line-height: 1.6;
}

.hint-secondary {
  margin: 0 0 20px;
  color: var(--text-muted);
  font-size: 12px;
  line-height: 1.6;
}

.actions {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
</style>
