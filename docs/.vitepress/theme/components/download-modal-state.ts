import { ref } from 'vue'
import type { PlatformKey } from './downloads'

export const isDownloadModalOpen = ref(false)
export const activeDownloadPlatform = ref<PlatformKey | null>(null)

export const openDownloadModal = (platformKey: PlatformKey) => {
  activeDownloadPlatform.value = platformKey
  isDownloadModalOpen.value = true
}

export const closeDownloadModal = () => {
  isDownloadModalOpen.value = false
}
