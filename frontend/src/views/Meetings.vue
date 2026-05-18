<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { showSuccessToast, showFailToast } from 'vant'
import { meetingsApi, type MeetingInfo, type ParticipantInfo } from '../api/meetings'
import { usersApi, type UserInfo } from '../api/users'
import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()
const meetings = ref<MeetingInfo[]>([])
const members = ref<UserInfo[]>([])
const loading = ref(false)
const showCreate = ref(false)
const showDetail = ref(false)
const showMinutes = ref(false)

const currentMeeting = ref<MeetingInfo | null>(null)
const participants = ref<ParticipantInfo[]>([])
const minutesContent = ref('')

const isLeader = computed(() => (auth.user?.roleLevel || 0) >= 3)

const createForm = ref({
  title: '', description: '', scope: 'group' as string,
  location: '', startTime: '', endTime: '',
})

const statusMap: Record<string, { text: string; type: string }> = {
  scheduled: { text: '已安排', type: 'primary' },
  in_progress: { text: '进行中', type: 'success' },
  ended: { text: '已结束', type: 'default' },
  cancelled: { text: '已取消', type: 'danger' },
}

const scopeMap: Record<string, string> = {
  group: '组内会议',
  division: '兵种会议',
  team: '全队会议',
}

async function loadData() {
  loading.value = true
  try {
    meetings.value = await meetingsApi.getMy()
    if (isLeader.value) {
      members.value = await usersApi.getAll()
    }
  } catch (e: any) {
    showFailToast(e.message || '加载失败')
  } finally {
    loading.value = false
  }
}

function getMemberName(id: string) {
  return members.value.find(m => m.id === id)?.realName || auth.user?.realName || '未知'
}

async function submitCreate() {
  if (!createForm.value.title || !createForm.value.startTime || !createForm.value.endTime) {
    showFailToast('请填写必要信息')
    return
  }
  try {
    await meetingsApi.create({
      title: createForm.value.title,
      description: createForm.value.description || undefined,
      scope: createForm.value.scope,
      location: createForm.value.location || undefined,
      startTime: createForm.value.startTime,
      endTime: createForm.value.endTime,
    })
    showSuccessToast('会议已创建')
    showCreate.value = false
    createForm.value = { title: '', description: '', scope: 'group', location: '', startTime: '', endTime: '' }
    await loadData()
  } catch (e: any) {
    showFailToast(e.message || '创建失败')
  }
}

async function openDetail(meeting: MeetingInfo) {
  currentMeeting.value = meeting
  try {
    participants.value = await meetingsApi.getParticipants(meeting.id)
  } catch (e: any) {
    participants.value = []
    showFailToast(e?.message || '获取参与者失败')
  }
  showDetail.value = true
}

async function startMeeting() {
  if (!currentMeeting.value) return
  try {
    currentMeeting.value = await meetingsApi.start(currentMeeting.value.id)
    showSuccessToast('会议已开始，签到已开启')
    await loadData()
  } catch (e: any) { showFailToast(e.message || '操作失败') }
}

async function endMeeting() {
  if (!currentMeeting.value) return
  try {
    currentMeeting.value = await meetingsApi.end(currentMeeting.value.id)
    showSuccessToast('会议已结束')
    await loadData()
  } catch (e: any) { showFailToast(e.message || '操作失败') }
}

async function cancelMeeting() {
  if (!currentMeeting.value) return
  try {
    await meetingsApi.cancel(currentMeeting.value.id)
    showSuccessToast('会议已取消')
    showDetail.value = false
    await loadData()
  } catch (e: any) { showFailToast(e.message || '操作失败') }
}

async function checkIn() {
  if (!currentMeeting.value) return
  try {
    await meetingsApi.checkIn(currentMeeting.value.id)
    showSuccessToast('签到成功')
    participants.value = await meetingsApi.getParticipants(currentMeeting.value.id)
  } catch (e: any) { showFailToast(e.message || '签到失败') }
}

async function openMinutes() {
  if (!currentMeeting.value) return
  try {
    const m = await meetingsApi.getMinutes(currentMeeting.value.id)
    minutesContent.value = m?.content || ''
  } catch { minutesContent.value = '' }
  showMinutes.value = true
}

async function saveMinutes() {
  if (!currentMeeting.value || !minutesContent.value) return
  try {
    await meetingsApi.saveMinutes(currentMeeting.value.id, minutesContent.value)
    showSuccessToast('纪要已保存')
    showMinutes.value = false
  } catch (e: any) { showFailToast(e.message || '保存失败') }
}

onMounted(loadData)
</script>

<template>
  <div class="meetings-page">
    <van-nav-bar title="会议" left-arrow @click-left="$router.back()">
      <template #right>
        <van-icon v-if="isLeader" name="plus" size="20" @click="showCreate = true" />
      </template>
    </van-nav-bar>

    <van-pull-refresh v-model="loading" @refresh="loadData">
      <van-empty v-if="!meetings.length" description="暂无会议" />
      <van-cell-group v-for="m in meetings" :key="m.id" inset class="meeting-card" @click="openDetail(m)">
        <van-cell :title="m.title" :label="scopeMap[m.scope] + (m.location ? ' · ' + m.location : '')" is-link>
          <template #right-icon>
            <van-tag :type="(statusMap[m.status]?.type as any) || 'default'" plain>
              {{ statusMap[m.status]?.text }}
            </van-tag>
          </template>
        </van-cell>
        <van-cell title="时间" :value="new Date(m.startTime).toLocaleString()" />
      </van-cell-group>
    </van-pull-refresh>

    <!-- 创建会议 -->
    <van-popup v-model:show="showCreate" position="bottom" round style="height: 75%;">
      <van-nav-bar title="创建会议" left-text="取消" right-text="确认" @click-left="showCreate = false" @click-right="submitCreate" />
      <van-field v-model="createForm.title" label="标题" placeholder="会议标题" />
      <van-field v-model="createForm.description" label="描述" type="textarea" placeholder="会议描述" rows="2" />
      <van-field label="范围">
        <template #input>
          <select v-model="createForm.scope" style="width: 100%; border: none; font-size: 14px;">
            <option value="group">组内会议</option>
            <option value="division">兵种会议</option>
            <option value="team">全队会议</option>
          </select>
        </template>
      </van-field>
      <van-field v-model="createForm.location" label="地点" placeholder="线上/线下地点" />
      <van-field v-model="createForm.startTime" label="开始时间" type="datetime-local" />
      <van-field v-model="createForm.endTime" label="结束时间" type="datetime-local" />
    </van-popup>

    <!-- 会议详情 -->
    <van-popup v-model:show="showDetail" position="bottom" round style="height: 80%;">
      <van-nav-bar :title="currentMeeting?.title || '会议详情'" left-text="关闭" @click-left="showDetail = false" />
      <div v-if="currentMeeting" style="padding: 12px;">
        <van-cell-group inset>
          <van-cell title="状态" :value="statusMap[currentMeeting.status]?.text" />
          <van-cell title="范围" :value="scopeMap[currentMeeting.scope]" />
          <van-cell title="地点" :value="currentMeeting.location || '未指定'" />
          <van-cell title="开始" :value="new Date(currentMeeting.startTime).toLocaleString()" />
          <van-cell title="结束" :value="new Date(currentMeeting.endTime).toLocaleString()" />
        </van-cell-group>

        <div v-if="currentMeeting.organizerId === auth.user?.id" style="margin-top: 12px; display: flex; gap: 8px; padding: 0 16px;">
          <van-button v-if="currentMeeting.status === 'scheduled'" size="small" type="primary" @click="startMeeting">开始会议</van-button>
          <van-button v-if="currentMeeting.status === 'in_progress'" size="small" type="warning" @click="endMeeting">结束会议</van-button>
          <van-button v-if="currentMeeting.status === 'scheduled'" size="small" type="danger" @click="cancelMeeting">取消会议</van-button>
        </div>

        <div v-if="currentMeeting.status === 'in_progress'" style="margin-top: 12px; padding: 0 16px;">
          <van-button type="success" block @click="checkIn">签到</van-button>
        </div>

        <van-cell-group title="签到情况" inset style="margin-top: 12px;">
          <van-cell v-for="p in participants" :key="p.id" :title="getMemberName(p.userId)">
            <template #right-icon>
              <van-tag :type="p.attendanceStatus === 'present' ? 'success' : p.attendanceStatus === 'late' ? 'warning' : p.attendanceStatus === 'absent' ? 'danger' : 'default'" plain>
                {{ { pending: '未签到', present: '已签到', late: '迟到', absent: '缺席' }[p.attendanceStatus] }}
              </van-tag>
            </template>
          </van-cell>
        </van-cell-group>

        <div v-if="currentMeeting.status === 'ended' && isLeader" style="margin-top: 12px; padding: 0 16px;">
          <van-button type="primary" block plain @click="openMinutes">编辑纪要</van-button>
        </div>
      </div>
    </van-popup>

    <!-- 会议纪要 -->
    <van-popup v-model:show="showMinutes" position="bottom" round style="height: 70%;">
      <van-nav-bar title="会议纪要" left-text="取消" right-text="保存" @click-left="showMinutes = false" @click-right="saveMinutes" />
      <van-field v-model="minutesContent" type="textarea" placeholder="输入会议纪要内容..." rows="15" style="margin: 12px;" />
    </van-popup>
  </div>
</template>

<style scoped>
.meeting-card { margin-top: 12px; }
</style>
