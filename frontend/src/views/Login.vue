<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { showFailToast, showSuccessToast } from 'vant'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const auth = useAuthStore()

const isRegister = ref(false)
const username = ref('')
const password = ref('')
const realName = ref('')
const email = ref('')
const loading = ref(false)

async function handleSubmit() {
  if (!username.value || !password.value) {
    showFailToast('请填写用户名和密码')
    return
  }
  if (isRegister.value && !realName.value) {
    showFailToast('请填写真实姓名')
    return
  }
  if (isRegister.value && !email.value) {
    showFailToast('请填写邮箱')
    return
  }
  if (isRegister.value && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.value)) {
    showFailToast('邮箱格式不正确')
    return
  }

  loading.value = true
  try {
    if (isRegister.value) {
      await auth.register(username.value, password.value, realName.value, email.value)
      showSuccessToast('注册成功')
    } else {
      await auth.login(username.value, password.value)
      showSuccessToast('登录成功')
    }
    router.push('/')
  } catch (e: any) {
    const msg = typeof e === 'string' ? e : (e?.message || '操作失败')
    showFailToast(msg)
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="login-page">
    <div class="login-card">
      <h1 class="title">战队管理系统</h1>
      <p class="subtitle">{{ isRegister ? '注册新账号' : '登录' }}</p>

      <van-cell-group inset>
        <van-field
          v-model="username"
          name="username"
          label="用户名"
          placeholder="请输入用户名"
        />
        <van-field
          v-model="password"
          name="password"
          type="password"
          label="密码"
          placeholder="请输入密码"
        />
        <van-field
          v-if="isRegister"
          v-model="realName"
          name="realName"
          label="姓名"
          placeholder="请输入真实姓名"
        />
        <van-field
          v-if="isRegister"
          v-model="email"
          name="email"
          label="邮箱"
          placeholder="请输入邮箱"
          type="email"
        />
      </van-cell-group>

      <div class="actions">
        <van-button
          type="primary"
          block
          :loading="loading"
          @click="handleSubmit"
        >
          {{ isRegister ? '注册' : '登录' }}
        </van-button>
        <van-button
          plain
          block
          @click="isRegister = !isRegister"
          class="switch-btn"
        >
          {{ isRegister ? '已有账号？去登录' : '没有账号？去注册' }}
        </van-button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.login-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--sidebar-bg);
  position: relative;
  overflow: hidden;
}

.login-page::before {
  content: '';
  position: absolute;
  top: -50%;
  left: -50%;
  width: 200%;
  height: 200%;
  background: radial-gradient(circle at 30% 50%, rgba(59, 130, 246, 0.15) 0%, transparent 50%),
              radial-gradient(circle at 70% 80%, rgba(139, 92, 246, 0.1) 0%, transparent 40%);
  animation: float 8s ease-in-out infinite;
}

.login-card {
  background: var(--bg-card);
  border-radius: var(--radius-xl);
  padding: 40px 32px;
  width: 100%;
  max-width: 420px;
  box-shadow: 0 25px 80px rgba(0, 0, 0, 0.3);
  position: relative;
  animation: scaleIn 0.5s cubic-bezier(0.4, 0, 0.2, 1);
}

.title {
  text-align: center;
  font-size: 26px;
  margin: 0 0 4px;
  color: var(--text-primary);
  font-weight: 700;
}

.subtitle {
  text-align: center;
  color: var(--text-muted);
  margin: 0 0 28px;
  font-size: 14px;
}

.actions {
  padding: 20px 0 0;
}

.switch-btn {
  margin-top: 12px;
}
</style>
