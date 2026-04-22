<script setup lang="ts">
import { computed } from 'vue'
import '../assets/iconfont/iconfont.css'
import manifestData from '../../../public/latest.json'

type InstallMode = 'external' | 'apk' | 'appinstaller' | 'sparkle'

interface AndroidVariant {
  abi: string
  url: string
}

interface DownloadEntry {
  mode: InstallMode
  url?: string
  feedUrl?: string
  fallbackUrl?: string
  variants?: AndroidVariant[]
}

interface PlatformEntry {
  download: DownloadEntry
}

interface ManifestPayload {
  platforms?: Record<string, PlatformEntry>
}

interface PlatformCard {
  key: string
  name: string
  href: string
}

const manifest = manifestData as ManifestPayload

const platformLabels: Record<string, string> = {
  ios: 'iOS',
  android: 'Android',
  macos: 'macOS',
  windows: 'Windows'
}

const platformIconClasses: Record<string, string> = {
  ios: 'icon-ios',
  android: 'icon-android',
  macos: 'icon-iconMac',
  windows: 'icon-windows'
}

const resolvePrimaryLink = (
  platformKey: string,
  download: DownloadEntry
): string | null => {
  if (platformKey === 'android') {
    if (download.fallbackUrl) {
      return download.fallbackUrl
    }

    return download.variants?.find((variant) => variant.url)?.url ?? null
  }

  return download.feedUrl ?? download.url ?? null
}

const cards = computed<PlatformCard[]>(() => {
  const platforms = manifest.platforms ?? {}

  return ['ios', 'android', 'macos', 'windows']
    .flatMap((platformKey) => {
      const entry = platforms[platformKey]
      if (!entry?.download) {
        return []
      }

      const href = resolvePrimaryLink(platformKey, entry.download)
      if (!href) {
        return []
      }

      return [
        {
          key: platformKey,
          name: platformLabels[platformKey] ?? platformKey,
          href
        }
      ]
    })
})
</script>

<template>
  <section class="home-downloads" id="downloads">
    <div v-if="cards.length === 0" class="home-downloads__status">
      当前还没有可展示的下载平台。
    </div>
    <div v-else class="home-downloads__grid">
      <a
        v-for="card in cards"
        :key="card.key"
        class="home-downloads__card"
        :href="card.href"
        target="_blank"
        rel="noreferrer"
      >
        <div class="home-downloads__icon">
          <i
            class="iconfont home-downloads__icon-glyph"
            :class="platformIconClasses[card.key]"
            aria-hidden="true"
          />
        </div>
        <span class="home-downloads__platform">{{ card.name }}</span>
      </a>
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
}

.home-downloads__card:hover,
.home-downloads__card:focus-visible {
  border-color: rgba(255, 122, 24, 0.28);
  background: rgba(255, 122, 24, 0.13);
  transform: translate3d(0, -6px, 0);
  box-shadow: 0 14px 28px rgba(255, 122, 24, 0.12);
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

@media (max-width: 640px) {
  .home-downloads {
    padding: 8px 16px 22px;
  }

  .home-downloads__grid {
    gap: 16px;
  }
}
</style>
