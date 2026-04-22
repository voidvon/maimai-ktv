<script setup lang="ts">
import QRCode from 'qrcode'
import {
  computed,
  onBeforeUnmount,
  onMounted,
  ref,
  watch
} from 'vue'
import {
  detectIsMobileClient,
  getPlatformByKey
} from './downloads'
import {
  activeDownloadPlatform,
  closeDownloadModal,
  isDownloadModalOpen
} from './download-modal-state'
import VPButton from './VPButton.vue'

const isMobileClient = ref(false)
const qrCodeDataUrl = ref('')
const previousBodyOverflow = ref('')
let qrCodeRequestId = 0

const platform = computed(() => {
  return activeDownloadPlatform.value
    ? getPlatformByKey(activeDownloadPlatform.value)
    : null
})

const showQrCode = computed(() => {
  return Boolean(
    isDownloadModalOpen.value &&
      platform.value?.primaryOption.href &&
      !isMobileClient.value
  )
})

const handleKeydown = (event: KeyboardEvent) => {
  if (event.key === 'Escape' && isDownloadModalOpen.value) {
    closeDownloadModal()
  }
}

const handleMaskClick = (event: MouseEvent) => {
  if (event.target === event.currentTarget) {
    closeDownloadModal()
  }
}

watch(isDownloadModalOpen, (open) => {
  if (typeof document === 'undefined') {
    return
  }

  if (open) {
    previousBodyOverflow.value = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return
  }

  document.body.style.overflow = previousBodyOverflow.value
})

watch(
  [showQrCode, platform],
  async ([shouldRenderQr, currentPlatform]) => {
    if (!shouldRenderQr || !currentPlatform) {
      qrCodeDataUrl.value = ''
      return
    }

    const currentRequestId = ++qrCodeRequestId
    const dataUrl = await QRCode.toDataURL(currentPlatform.primaryOption.href, {
      margin: 1,
      width: 220,
      color: {
        dark: '#1f1d1a',
        light: '#ffffff'
      }
    })

    if (currentRequestId === qrCodeRequestId) {
      qrCodeDataUrl.value = dataUrl
    }
  },
  { immediate: true }
)

onMounted(() => {
  isMobileClient.value = detectIsMobileClient()
  window.addEventListener('keydown', handleKeydown)
})

onBeforeUnmount(() => {
  if (typeof document !== 'undefined') {
    document.body.style.overflow = previousBodyOverflow.value
  }

  window.removeEventListener('keydown', handleKeydown)
})
</script>

<template>
  <Teleport to="body">
    <Transition name="download-modal" appear>
      <div
        v-if="isDownloadModalOpen && platform"
        class="download-modal"
        @click="handleMaskClick"
      >
        <div
          class="download-modal__panel"
          role="dialog"
          aria-modal="true"
          :aria-label="`${platform.name} 下载`"
        >
          <div class="download-modal__header-shell">
            <button
              class="download-modal__close"
              type="button"
              aria-label="关闭下载弹窗"
              @click="closeDownloadModal"
            >
              ×
            </button>

            <header class="download-modal__header">
              <p class="download-modal__eyebrow">{{ platform.name }} 下载</p>
            </header>
          </div>

          <div class="download-modal__body">
            <div v-if="showQrCode && qrCodeDataUrl" class="download-modal__qr">
              <img
                class="download-modal__qr-image"
                :src="qrCodeDataUrl"
                :alt="`${platform.primaryOption.label} 二维码`"
              >
              <p class="download-modal__qr-label">
                扫码下载：{{ platform.primaryOption.label }}
              </p>
            </div>

            <div class="download-modal__actions">
              <div
                v-for="(option, index) in platform.options"
                :key="option.key"
                class="download-modal__action"
              >
                <VPButton
                  tag="a"
                  size="medium"
                  :theme="index === 0 ? 'brand' : 'alt'"
                  :href="option.href"
                >
                  {{ option.label }}
                </VPButton>
                <p v-if="option.description" class="download-modal__action-note">
                  {{ option.description }}
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.download-modal {
  position: fixed;
  inset: 0;
  z-index: 120;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
  background: rgba(17, 15, 18, 0.56);
  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);
}

.download-modal__panel {
  position: relative;
  width: min(100%, 560px);
  max-height: min(100vh - 48px, 760px);
  overflow: hidden;
  display: flex;
  flex-direction: column;
  border: 1px solid rgba(255, 122, 24, 0.16);
  border-radius: 28px;
  background:
    radial-gradient(circle at top, rgba(255, 179, 113, 0.16), transparent 42%),
    rgba(255, 255, 255, 0.97);
  box-shadow: 0 28px 80px rgba(18, 10, 8, 0.2);
  padding: 28px;
  transform-origin: center top;
}

.download-modal__header-shell {
  position: sticky;
  top: 0;
  z-index: 2;
  margin: -28px -28px 0;
  padding: 0 28px 10px;
}

.download-modal__close {
  position: absolute;
  top: 16px;
  right: 16px;
  width: 36px;
  height: 36px;
  border: 0;
  border-radius: 999px;
  background: rgba(32, 20, 15, 0.08);
  color: var(--vp-c-text-2);
  font-size: 24px;
  line-height: 1;
  cursor: pointer;
}

.download-modal__header {
  padding-right: 44px;
}

.download-modal__body {
  overflow: auto;
  padding-top: 6px;
}

.download-modal__eyebrow {
  margin: 0;
  color: var(--vp-c-brand-1);
  font-size: 15px;
  font-weight: 700;
  line-height: 1.4;
}

.download-modal__qr {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin-top: 24px;
}

.download-modal__qr-image {
  width: 220px;
  height: 220px;
  border-radius: 18px;
  background: white;
  padding: 12px;
}

.download-modal__qr-label {
  margin: 14px 0 0;
  color: var(--vp-c-text-1);
  font-size: 14px;
  font-weight: 600;
  text-align: center;
}

.download-modal__actions {
  display: grid;
  gap: 14px;
  margin-top: 22px;
}

.download-modal__action {
  display: grid;
  gap: 8px;
  justify-items: center;
}

.download-modal__action-note {
  margin: 0;
  color: var(--vp-c-text-2);
  font-size: 13px;
  line-height: 1.6;
  text-align: center;
}

.download-modal__action :deep(.VPButton) {
  min-width: 220px;
}

.dark .download-modal__panel {
  border-color: rgba(255, 122, 24, 0.18);
  background:
    radial-gradient(circle at top, rgba(255, 179, 113, 0.16), transparent 42%),
    rgba(29, 22, 27, 0.97);
  box-shadow: 0 28px 80px rgba(0, 0, 0, 0.38);
}

.dark .download-modal__close {
  background: rgba(255, 255, 255, 0.08);
}

.download-modal-enter-active,
.download-modal-leave-active {
  transition: background-color 0.3s ease, backdrop-filter 0.3s ease;
}

.download-modal-enter-active .download-modal__panel,
.download-modal-leave-active .download-modal__panel {
  transition:
    opacity 0.32s cubic-bezier(0.22, 1, 0.36, 1),
    transform 0.32s cubic-bezier(0.22, 1, 0.36, 1),
    filter 0.32s ease;
}

.download-modal-enter-from,
.download-modal-leave-to {
  background: rgba(17, 15, 18, 0);
  backdrop-filter: blur(0px);
  -webkit-backdrop-filter: blur(0px);
}

.download-modal-enter-from .download-modal__panel,
.download-modal-leave-to .download-modal__panel {
  opacity: 0;
  transform: translate3d(0, 24px, 0) scale(0.96);
  filter: blur(6px);
}

@media (max-width: 640px) {
  .download-modal {
    padding: 16px;
    align-items: center;
  }

  .download-modal__panel {
    width: 100%;
    max-height: calc(100vh - 32px);
    border-radius: 24px 24px 20px 20px;
    padding: 24px 18px 20px;
    transform-origin: center bottom;
  }

  .download-modal__header-shell {
    margin: -24px -18px 0;
    padding: 0 18px 8px;
  }

  .download-modal__title {
    font-size: 24px;
  }

  .download-modal-enter-from .download-modal__panel,
  .download-modal-leave-to .download-modal__panel {
    transform: translate3d(0, 36px, 0) scale(0.98);
  }
}

@media (prefers-reduced-motion: reduce) {
  .download-modal-enter-active,
  .download-modal-leave-active,
  .download-modal-enter-active .download-modal__panel,
  .download-modal-leave-active .download-modal__panel {
    transition: none;
  }
}
</style>
