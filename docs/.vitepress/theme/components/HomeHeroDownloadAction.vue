<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import {
  detectClientPlatform,
  getPlatformByKey,
  resolveHeroPlatformKey,
  type PlatformKey
} from './downloads'
import { openDownloadModal } from './download-modal-state'
import VPButton from './VPButton.vue'

const detectedPlatform = ref<PlatformKey | null>(null)

const selectedPlatformKey = computed(() => {
  return resolveHeroPlatformKey(detectedPlatform.value)
})

const selectedPlatform = computed(() => {
  return selectedPlatformKey.value
    ? getPlatformByKey(selectedPlatformKey.value)
    : null
})

const actionText = computed(() => {
  return selectedPlatform.value ? `${selectedPlatform.value.name} 下载` : '立即下载'
})

const handleOpenDownloadModal = () => {
  if (selectedPlatformKey.value) {
    openDownloadModal(selectedPlatformKey.value)
  }
}

onMounted(() => {
  detectedPlatform.value = detectClientPlatform()
})
</script>

<template>
  <div class="action">
    <VPButton
      tag="button"
      size="medium"
      theme="brand"
      @click="handleOpenDownloadModal"
    >
      {{ actionText }}
    </VPButton>
  </div>
</template>

<style scoped>
.action {
  display: flex;
  flex-shrink: 0;
  padding: 6px;
}
</style>
