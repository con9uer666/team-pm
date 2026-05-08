<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { showToast } from 'vant'
import { spacesApi, type MySpaces } from '../api/spaces'

const router = useRouter()
const spaces = ref<MySpaces>({ groups: [], divisions: [] })
const loading = ref(false)

async function load() {
  loading.value = true
  try {
    spaces.value = await spacesApi.getMy()
  } catch (e: any) {
    showToast(e?.message || '加载失败')
  } finally {
    loading.value = false
  }
}

function openSpace(scope: 'group' | 'division', id: string) {
  router.push({ name: 'space-detail', params: { scope, id } })
}

onMounted(load)
</script>

<template>
  <div class="my-space">
    <header class="page-header">
      <h1>我的空间</h1>
      <p class="sub">你所在的组别都会聚合在这里</p>
    </header>

    <van-loading v-if="loading" class="loading" />

    <template v-else>
      <section class="section" v-if="spaces.divisions.length">
        <h2><van-icon name="flag-o" class="section-icon" /> 兵种组</h2>
        <div class="grid">
          <div
            v-for="d in spaces.divisions"
            :key="d.id"
            class="card card--division"
            @click="openSpace('division', d.id)"
          >
            <van-icon name="flag-o" class="card__bg-icon" />
            <div class="card__title">
              <van-icon name="medal-o" class="card__title-icon" />
              <span>{{ d.name }}</span>
            </div>
            <div class="card__meta">
              <span><van-icon name="friends-o" /> {{ d.memberCount }} 人</span>
              <span class="tag">兵种组</span>
            </div>
          </div>
        </div>
      </section>

      <section class="section" v-if="spaces.groups.length">
        <h2><van-icon name="apartment-o" class="section-icon" /> 技术组</h2>
        <div class="grid">
          <div
            v-for="g in spaces.groups"
            :key="g.id"
            class="card card--group"
            @click="openSpace('group', g.id)"
          >
            <van-icon name="apartment-o" class="card__bg-icon" />
            <div class="card__title">
              <van-icon name="setting-o" class="card__title-icon" />
              <span>{{ g.name }}</span>
            </div>
            <div class="card__meta">
              <span><van-icon name="friends-o" /> {{ g.memberCount }} 人</span>
              <span class="tag">技术组</span>
            </div>
          </div>
        </div>
      </section>

      <van-empty
        v-if="!spaces.groups.length && !spaces.divisions.length"
        description="你还没有加入任何组"
      />
    </template>
  </div>
</template>

<style scoped>
.my-space {
  padding: 16px;
}

.page-header {
  margin-bottom: 20px;
}

.page-header h1 {
  margin: 0 0 4px;
  font-size: 22px;
  color: var(--text-primary);
}

.page-header .sub {
  margin: 0;
  color: var(--text-muted);
  font-size: 13px;
}

.section {
  margin-bottom: 24px;
}

.section h2 {
  margin: 0 0 12px;
  font-size: 15px;
  color: var(--text-secondary, var(--text-primary));
  display: flex;
  align-items: center;
  gap: 6px;
}

.section-icon {
  font-size: 16px;
  color: var(--text-primary);
}

.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: 12px;
}

.card {
  position: relative;
  overflow: hidden;
  padding: 16px;
  border-radius: 14px;
  color: #fff;
  cursor: pointer;
  transition: transform 0.2s ease;
  min-height: 100px;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
}

.card__bg-icon {
  position: absolute;
  right: -14px;
  bottom: -14px;
  font-size: 86px;
  opacity: 0.14;
  pointer-events: none;
}

.card:active {
  transform: scale(0.98);
}

.card--division {
  background: linear-gradient(135deg, #f97316, #ef4444);
}

.card--group {
  background: linear-gradient(135deg, #3b82f6, #8b5cf6);
}

.card__title {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 17px;
  font-weight: 600;
  position: relative;
  z-index: 1;
}

.card__title-icon {
  font-size: 18px;
}

.card__meta {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 12px;
  opacity: 0.92;
  position: relative;
  z-index: 1;
}

.card__meta span {
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.tag {
  padding: 2px 8px;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 999px;
}

.loading {
  display: flex;
  justify-content: center;
  padding: 40px 0;
}
</style>
