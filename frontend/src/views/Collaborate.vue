<script setup lang="ts">
import { useRouter } from 'vue-router'
import { showToast } from 'vant'
const router = useRouter()

function comingSoon(name: string) {
  showToast(`${name} 功能开发中，敬请期待`)
}
</script>

<template>
  <div class="collaborate-page">
    <h2 class="animate-fade-in-up" style="padding: 0 16px;">协作</h2>
    <van-cell-group inset class="animate-fade-in-up stagger-1">
      <van-cell title="会议" icon="clock-o" is-link @click="router.push('/meetings')" label="会议安排、签到、纪要" />
      <van-cell title="讨论" icon="chat-o" label="组内讨论（开发中）" class="cell-disabled" @click="comingSoon('讨论')" />
      <van-cell title="知识库" icon="description" label="文档与资料（开发中）" class="cell-disabled" @click="comingSoon('知识库')" />
      <van-cell title="赛程日历" icon="calendar-o" label="比赛与训练安排（开发中）" class="cell-disabled" @click="comingSoon('赛程日历')" />
    </van-cell-group>
  </div>
</template>

<style scoped>
.cell-disabled {
  opacity: 0.55;
}
</style>
