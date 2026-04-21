<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import '../assets/iconfont/iconfont.css'
import {
  detectClientPlatform,
  getPlatformCards,
  platformIconClasses,
  type PlatformCard,
  type PlatformKey
} from './downloads'
import { openDownloadModal } from './download-modal-state'

const recommendedPlatform = ref<PlatformKey | null>(null)

const cards = computed<PlatformCard[]>(() => {
  return getPlatformCards()
})

onMounted(() => {
  recommendedPlatform.value = detectClientPlatform()
})
</script>

<template>
  <section class="home-downloads" id="downloads">
    <div v-if="cards.length === 0" class="home-downloads__status">
      当前还没有可展示的下载平台。
    </div>
    <div v-else class="home-downloads__grid">
      <button
        v-for="card in cards"
        :key="card.key"
        type="button"
        class="home-downloads__card"
        :class="{
          'home-downloads__card--recommended':
            recommendedPlatform === card.key
        }"
        @click="openDownloadModal(card.key)"
      >
        <span
          v-if="recommendedPlatform === card.key"
          class="home-downloads__badge"
        >
          当前设备
        </span>
        <div class="home-downloads__icon">
          <i
            class="iconfont home-downloads__icon-glyph"
            :class="platformIconClasses[card.key]"
            aria-hidden="true"
          />
        </div>
        <span class="home-downloads__platform">{{ card.name }}</span>
      </button>
    </div>
  </section>
</template>

<style scoped>
.home-downloads {
  margin: 48px auto 20px;
  padding: 8px 24px 28px;
  box-sizing: border-box;
}

.home-downloads__status {
  margin-top: 20px;
  padding: 18px 20px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.72);
  color: var(--vp-c-text-2);
}

.home-downloads__grid {
  display: flex;
  flex-wrap: wrap;
  gap: 24px;
  justify-content: center;
}

.home-downloads__card {
  width: 128px;
  height: 140px;
  box-sizing: border-box;
  padding: 18px 14px;
  border: 1px solid rgba(255, 122, 24, 0.12);
  border-radius: 22px;
  background: rgba(255, 255, 255, 0.82);
  text-decoration: none;
  font: inherit;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 16px;
  transform: translate3d(0, 0, 0);
  will-change: transform;
  box-shadow: 0 0 0 rgba(255, 122, 24, 0);
  transition:
    transform 0.36s ease,
    box-shadow 0.36s ease,
    background-color 0.24s ease,
    border-color 0.24s ease;
  position: relative;
  cursor: pointer;
}

.home-downloads__card:hover,
.home-downloads__card:focus-visible {
  border-color: rgba(255, 122, 24, 0.28);
  background: rgba(255, 122, 24, 0.13);
  transform: translate3d(0, -6px, 0);
  box-shadow: 0 14px 28px rgba(255, 122, 24, 0.12);
  outline: none;
}

.home-downloads__card--recommended {
  border-color: rgba(255, 122, 24, 0.34);
  background: rgba(255, 122, 24, 0.15);
  box-shadow: 0 14px 28px rgba(255, 122, 24, 0.14);
}

.home-downloads__badge {
  position: absolute;
  top: 10px;
  right: 10px;
  padding: 3px 8px;
  border-radius: 999px;
  background: var(--vp-c-brand-1);
  color: white;
  font-size: 11px;
  line-height: 1.4;
  font-weight: 600;
}

.home-downloads__icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 56px;
  height: 56px;
}

.home-downloads__icon-glyph {
  color: var(--vp-c-brand-1);
  font-size: 44px;
  line-height: 1;
}

.home-downloads__platform {
  margin: 0;
  color: var(--vp-c-text-1);
  font-size: 15px;
  font-weight: 600;
  text-align: center;
}

.dark .home-downloads__status,
.dark .home-downloads__card {
  background: rgba(27, 20, 31, 0.92);
  border-color: rgba(255, 122, 24, 0.14);
}

.dark .home-downloads__card--recommended {
  border-color: rgba(255, 122, 24, 0.34);
  background: rgba(255, 122, 24, 0.2);
}

@media (max-width: 640px) {
  .home-downloads {
    padding: 8px 16px 22px;
  }

  .home-downloads__grid {
    gap: 16px;
  }
}
</style>
