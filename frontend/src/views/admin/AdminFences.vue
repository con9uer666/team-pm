<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { showConfirmDialog, showFailToast, showSuccessToast, showToast } from 'vant'
import { attendanceApi, type AttendanceFence, type CreateFenceDto } from '../../api/attendance'
import { getPosition } from '../../utils/geolocation'

const fences = ref<AttendanceFence[]>([])
const loading = ref(false)

const showForm = ref(false)
const editingId = ref<string | null>(null)
const form = ref<CreateFenceDto>({ name: '', centerLat: 0, centerLng: 0, radius: 100, enabled: true })

function resetForm() {
  form.value = { name: '', centerLat: 0, centerLng: 0, radius: 100, enabled: true }
  editingId.value = null
}

async function load() {
  loading.value = true
  try {
    fences.value = await attendanceApi.listFences()
  } catch (e: any) {
    showFailToast(e?.message || '加载失败')
  } finally {
    loading.value = false
  }
}

function openCreate() {
  resetForm()
  showForm.value = true
}

function openEdit(f: AttendanceFence) {
  editingId.value = f.id
  form.value = {
    name: f.name,
    centerLat: f.centerLat,
    centerLng: f.centerLng,
    radius: f.radius,
    enabled: f.enabled,
  }
  showForm.value = true
}

async function useCurrentPosition() {
  showToast({ message: '定位中…', type: 'loading', duration: 0, forbidClick: true })
  try {
    const pos = await getPosition()
    form.value.centerLat = Number(pos.lat.toFixed(6))
    form.value.centerLng = Number(pos.lng.toFixed(6))
    showSuccessToast(`定位精度 ±${Math.round(pos.accuracy)}m`)
  } catch (e: any) {
    showFailToast(e?.message || '定位失败')
  }
}

async function save() {
  if (!form.value.name?.trim()) return showFailToast('请填写名称')
  if (!form.value.centerLat || !form.value.centerLng) return showFailToast('请填写中心坐标')
  if (!form.value.radius || form.value.radius < 10 || form.value.radius > 5000) {
    return showFailToast('半径应在 10m 到 5000m 之间')
  }
  try {
    if (editingId.value) {
      await attendanceApi.updateFence(editingId.value, form.value)
      showSuccessToast('已更新')
    } else {
      await attendanceApi.createFence(form.value)
      showSuccessToast('已创建')
    }
    showForm.value = false
    await load()
  } catch (e: any) {
    showFailToast(e?.message || '保存失败')
  }
}

async function toggleEnabled(f: AttendanceFence) {
  try {
    await attendanceApi.updateFence(f.id, { enabled: !f.enabled })
    await load()
  } catch (e: any) {
    showFailToast(e?.message || '操作失败')
  }
}

async function remove(f: AttendanceFence) {
  try {
    await showConfirmDialog({
      title: '删除围栏',
      message: `确认删除「${f.name}」？该围栏下的历史打卡记录不受影响`,
    })
  } catch {
    return
  }
  try {
    await attendanceApi.removeFence(f.id)
    showSuccessToast('已删除')
    await load()
  } catch (e: any) {
    showFailToast(e?.message || '删除失败')
  }
}

onMounted(load)
</script>

<template>
  <div class="admin-fences">
    <div class="header-bar">
      <div>
        <h2 class="section-title">打卡围栏</h2>
        <p class="sub">在这些圆形区域内可上工打卡。未配置任何启用围栏时所有人都无法上工。</p>
      </div>
      <van-button type="primary" size="small" icon="plus" @click="openCreate">新建围栏</van-button>
    </div>

    <div v-if="loading && !fences.length" class="loading"><van-loading /></div>

    <van-empty v-else-if="!fences.length" description="尚未配置打卡围栏" />

    <div v-else class="fence-grid">
      <div v-for="f in fences" :key="f.id" class="fence-card" :class="{ disabled: !f.enabled }">
        <div class="fc-head">
          <h3>{{ f.name }}</h3>
          <span class="chip" :class="f.enabled ? 'chip--on' : 'chip--off'">
            {{ f.enabled ? '启用' : '停用' }}
          </span>
        </div>
        <div class="fc-body">
          <div class="fc-row"><van-icon name="location-o" /> {{ f.centerLat.toFixed(6) }}, {{ f.centerLng.toFixed(6) }}</div>
          <div class="fc-row"><van-icon name="aim" /> 半径 {{ f.radius }} m</div>
        </div>
        <div class="fc-actions">
          <van-button size="mini" plain @click="openEdit(f)">编辑</van-button>
          <van-button size="mini" plain :type="f.enabled ? 'warning' : 'primary'" @click="toggleEnabled(f)">
            {{ f.enabled ? '停用' : '启用' }}
          </van-button>
          <van-button size="mini" plain type="danger" @click="remove(f)">删除</van-button>
        </div>
      </div>
    </div>

    <van-popup v-model:show="showForm" position="center" round :style="{ width: '92%', maxWidth: '480px' }">
      <div class="form-wrap">
        <div class="form-head">
          <h3>{{ editingId ? '编辑围栏' : '新建围栏' }}</h3>
          <van-icon name="cross" @click="showForm = false" />
        </div>

        <van-cell-group inset>
          <van-field v-model="form.name" label="名称" placeholder="如：工训馆" />
          <van-field
            v-model.number="form.centerLat"
            type="number"
            label="纬度"
            placeholder="如 30.12345"
          />
          <van-field
            v-model.number="form.centerLng"
            type="number"
            label="经度"
            placeholder="如 120.12345"
          />
          <van-field v-model.number="form.radius" type="number" label="半径(米)" placeholder="建议 50~300" />
          <van-field label="启用">
            <template #input>
              <van-switch v-model="form.enabled" />
            </template>
          </van-field>
        </van-cell-group>

        <div class="form-tip">
          坐标可手动输入，或点下方按钮以当前位置作为中心（需允许浏览器定位）。
        </div>

        <div class="form-actions">
          <van-button block plain icon="aim" @click="useCurrentPosition">使用当前位置</van-button>
          <van-button block type="primary" @click="save" style="margin-top: 8px;">
            {{ editingId ? '保存' : '创建' }}
          </van-button>
        </div>
      </div>
    </van-popup>
  </div>
</template>

<style scoped>
.admin-fences {
  padding: 8px;
}

.header-bar {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 18px;
  gap: 12px;
}

.section-title {
  margin: 0 0 4px;
  font-size: 18px;
  color: #0f172a;
}

.sub {
  margin: 0;
  font-size: 12px;
  color: #64748b;
}

.fence-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 12px;
}

.fence-card {
  padding: 14px;
  border-radius: 12px;
  background: #fff;
  border: 1px solid #e5e7eb;
  transition: box-shadow 0.15s ease;
}

.fence-card:hover {
  box-shadow: 0 4px 12px rgba(15, 23, 42, 0.06);
}

.fence-card.disabled {
  opacity: 0.7;
}

.fc-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.fc-head h3 {
  margin: 0;
  font-size: 15px;
  color: #0f172a;
}

.chip {
  font-size: 11px;
  padding: 2px 8px;
  border-radius: 999px;
}

.chip--on {
  background: rgba(16, 185, 129, 0.12);
  color: #10b981;
}

.chip--off {
  background: rgba(148, 163, 184, 0.2);
  color: #64748b;
}

.fc-body {
  margin-top: 10px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.fc-row {
  font-size: 12px;
  color: #475569;
  display: flex;
  align-items: center;
  gap: 6px;
}

.fc-actions {
  margin-top: 12px;
  display: flex;
  gap: 8px;
}

.loading {
  display: flex;
  justify-content: center;
  padding: 40px 0;
}

.form-wrap {
  padding: 16px;
}

.form-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 14px;
}

.form-head h3 {
  margin: 0;
  font-size: 16px;
}

.form-tip {
  margin: 10px 4px;
  font-size: 12px;
  color: #64748b;
}

.form-actions {
  margin-top: 8px;
}
</style>
