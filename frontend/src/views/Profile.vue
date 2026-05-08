<script setup lang="ts">
import { ref, computed, onBeforeUnmount } from 'vue'
import { useRouter } from 'vue-router'
import { showToast } from 'vant'
import { useAuthStore } from '../stores/auth'
import { wechatApi } from '../api/wechat'
import { usersApi } from '../api/users'

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

const showBind = ref(false)
const qrcodeUrl = ref('')
const loadingQr = ref(false)
let pollTimer: number | null = null

const bound = computed(() => !!auth.user?.wechatWorkId)

async function handleBindClick() {
  loadingQr.value = true
  showBind.value = true
  qrcodeUrl.value = ''
  try {
    const res = await wechatApi.getBindQrcode()
    if (!res.success || !res.qrcodeUrl) {
      showToast({ message: res.message || '生成二维码失败', type: 'fail', duration: 3000 })
      showBind.value = false
      return
    }
    qrcodeUrl.value = res.qrcodeUrl
    startPolling()
  } catch (e: any) {
    const msg = e?.message || e?.response?.data?.message || '生成二维码失败（接口未部署？）'
    showToast({ message: msg, type: 'fail', duration: 3000 })
    showBind.value = false
  } finally {
    loadingQr.value = false
  }
}

function startPolling() {
  stopPolling()
  pollTimer = window.setInterval(async () => {
    try {
      const me = await usersApi.getMe()
      if (me.wechatWorkId) {
        auth.user = me
        stopPolling()
        showBind.value = false
        showToast({ message: '绑定成功', type: 'success' })
      }
    } catch {
      /* ignore */
    }
  }, 3000)
}

function stopPolling() {
  if (pollTimer) {
    clearInterval(pollTimer)
    pollTimer = null
  }
}

function closeBind() {
  showBind.value = false
  stopPolling()
}

onBeforeUnmount(stopPolling)

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

    <van-cell-group inset class="animate-fade-in-up stagger-2" style="margin-top: 12px;">
      <van-cell title="微信通知">
        <template #value>
          <span v-if="bound" style="color: #52c41a;">已绑定</span>
          <van-button v-else size="mini" type="primary" @click="handleBindClick">绑定</van-button>
        </template>
      </van-cell>
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

    <van-popup v-model:show="showBind" round :close-on-click-overlay="false" style="padding: 24px; width: 300px;">
      <div style="text-align: center;">
        <h3 style="margin: 0 0 12px;">绑定微信通知</h3>
        <p style="margin: 0 0 16px; color: #666; font-size: 13px;">
          用微信扫码关注公众号后<br>自动完成绑定
        </p>
        <div v-if="loadingQr" style="padding: 40px 0;">
          <van-loading />
        </div>
        <img v-else-if="qrcodeUrl" :src="qrcodeUrl" alt="bind-qr" style="width: 220px; height: 220px;" />
        <p style="margin: 16px 0 12px; color: #999; font-size: 12px;">
          关注成功后本页面会自动关闭
        </p>
        <van-button size="small" block @click="closeBind">取消</van-button>
      </div>
    </van-popup>
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
