<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useAuthStore } from './stores/auth'

const auth = useAuthStore()
const loading = ref(true)

onMounted(async () => {
  await auth.init()
  loading.value = false
})
</script>

<template>
  <van-loading v-if="loading" type="spinner" vertical style="margin-top: 40vh;">加载中...</van-loading>
  <router-view v-else />
</template>
