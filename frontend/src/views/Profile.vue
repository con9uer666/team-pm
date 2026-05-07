<script setup lang="ts">
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const auth = useAuthStore()

const roleNames: Record<number, string> = {
  1: '梯队员',
  2: '正式队员',
  3: '组长',
  4: '项目管理',
  5: '队长',
  6: '指导老师',
}

async function handleLogout() {
  await auth.logout()
  router.push('/login')
}
</script>

<template>
  <div class="profile-page">
    <div class="profile-header animate-fade-in-up">
      <div class="profile-avatar">
        {{ (auth.user?.realName || 'U').charAt(0) }}
      </div>
      <h2 class="profile-name">{{ auth.user?.realName || '用户' }}</h2>
      <p class="profile-role">{{ roleNames[auth.user?.roleLevel || 1] }}</p>
    </div>

    <van-cell-group inset class="animate-fade-in-up stagger-1">
      <van-cell title="用户名" :value="auth.user?.username" />
      <van-cell title="姓名" :value="auth.user?.realName" />
      <van-cell title="角色" :value="roleNames[auth.user?.roleLevel || 1]" />
    </van-cell-group>

    <van-cell-group v-if="(auth.user?.roleLevel || 0) >= 4" inset class="animate-fade-in-up stagger-2" style="margin-top: 12px;">
      <van-cell title="成员管理" is-link @click="router.push('/admin/members')" />
    </van-cell-group>

    <van-cell-group inset class="animate-fade-in-up stagger-2" style="margin-top: 12px;">
      <van-cell title="团队架构" is-link @click="router.push('/team-structure')" />
    </van-cell-group>

    <div class="animate-fade-in-up stagger-3" style="padding: 20px 16px;">
      <van-button type="danger" block round @click="handleLogout">退出登录</van-button>
    </div>
  </div>
</template>

<style scoped>
.profile-page {
  max-width: 600px;
  margin: 0 auto;
}

.profile-header {
  text-align: center;
  padding: 32px 16px 24px;
}

.profile-avatar {
  width: 72px;
  height: 72px;
  background: var(--gradient-blue);
  border-radius: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-size: 28px;
  font-weight: 700;
  margin: 0 auto 16px;
  box-shadow: 0 8px 24px rgba(102, 126, 234, 0.3);
  animation: float 3s ease-in-out infinite;
}

.profile-name {
  font-size: 22px;
  font-weight: 700;
  margin: 0;
  color: var(--text-primary);
}

.profile-role {
  margin: 4px 0 0;
  color: var(--text-muted);
  font-size: 14px;
}
</style>
