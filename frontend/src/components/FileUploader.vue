<script setup lang="ts">
import { ref } from 'vue'
import { showToast } from 'vant'
import type { UploaderFileListItem } from 'vant'
import { uploadsApi } from '../api/uploads'

const props = withDefaults(defineProps<{
  modelValue: string[]
  maxCount?: number
  accept?: string
}>(), {
  maxCount: 9,
  accept: 'image/*,video/*',
})

const emit = defineEmits<{
  'update:modelValue': [urls: string[]]
}>()

const fileList = ref<UploaderFileListItem[]>([])

const uploading = ref(false)

async function afterRead(file: UploaderFileListItem | UploaderFileListItem[]) {
  const files = Array.isArray(file) ? file : [file]
  uploading.value = true
  try {
    for (const f of files) {
      f.status = 'uploading'
      f.message = '上传中...'
      const result = await uploadsApi.upload(f.file as File)
      f.status = 'done'
      f.message = ''
      f.url = result.url
    }
    emit('update:modelValue', [...props.modelValue, ...files.map(f => f.url!)])
  } catch (e: any) {
    files.forEach(f => {
      f.status = 'failed'
      f.message = '上传失败'
    })
    showToast({ message: e.message || '上传失败', type: 'fail' })
  } finally {
    uploading.value = false
  }
}

function onDelete(file: UploaderFileListItem) {
  const urls = props.modelValue.filter(u => u !== file.url)
  emit('update:modelValue', urls)
  return true
}
</script>

<template>
  <van-uploader
    v-model="fileList"
    :max-count="maxCount"
    :accept="accept"
    :after-read="afterRead"
    :before-delete="onDelete"
    multiple
    :preview-size="80"
  />
</template>
