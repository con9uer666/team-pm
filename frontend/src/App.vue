<script setup lang="ts">
import { computed } from 'vue'
import { useAuthStore } from './stores/auth'

const auth = useAuthStore()
const loading = computed(() => !auth.ready)
</script>

<template>
  <van-loading v-if="loading" type="spinner" vertical style="margin-top: 40vh;">加载中...</van-loading>
  <router-view v-else />
</template>
