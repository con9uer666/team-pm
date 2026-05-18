<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { showSuccessToast, showFailToast } from 'vant'
import { notificationsApi, type NotificationInfo } from '../api/notifications'

const notifications = ref<NotificationInfo[]>([])
const loading = ref(false)

async function loadData() {
  loading.value = true
  try {
    notifications.value = await notificationsApi.getAll()
  } catch (e: any) {
    showFailToast(e.message || '加载失败')
  } finally {
    loading.value = false
  }
}

async function markRead(n: NotificationInfo) {
  if (n.isRead) return
  try {
    await notificationsApi.markRead(n.id)
    n.isRead = true
  } catch {}
}

async function markAllRead() {
  try {
    await notificationsApi.markAllRead()
    notifications.value.forEach(n => n.isRead = true)
    showSuccessToast('全部已读')
  } catch (e: any) {
    showFailToast(e.message || '操作失败')
  }
}

function formatTime(dateStr: string) {
  const d = new Date(dateStr)
  const now = new Date()
  const diff = now.getTime() - d.getTime()
  if (diff < 60000) return '刚刚'
  if (diff < 3600000) return `${Math.floor(diff / 60000)}分钟前`
  if (diff < 86400000) return `${Math.floor(diff / 3600000)}小时前`
  return d.toLocaleDateString()
}

onMounted(loadData)
</script>

<template>
  <div class="notifications-page">
    <div style="display: flex; justify-content: space-between; align-items: center; padding: 0 16px;">
      <h2>通知</h2>
      <van-button v-if="notifications.some(n => !n.isRead)" size="small" plain @click="markAllRead">全部已读</van-button>
    </div>

    <van-pull-refresh v-model="loading" @refresh="loadData">
      <van-empty v-if="!notifications.length" description="暂无通知" />
      <van-cell-group v-else inset>
        <van-cell
          v-for="n in notifications"
          :key="n.id"
          :title="n.title"
          :label="n.content || ''"
          :value="formatTime(n.createdAt)"
          :class="{ unread: !n.isRead }"
          @click="markRead(n)"
        />
      </van-cell-group>
    </van-pull-refresh>
  </div>
</template>

<style scoped>
.unread { background-color: var(--unread-bg, #f0f7ff); }
</style>
