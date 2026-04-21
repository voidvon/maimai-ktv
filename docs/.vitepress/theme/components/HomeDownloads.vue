<script setup lang="ts">
import { computed } from 'vue'
import manifestData from '../../../public/latest.json'

type InstallMode = 'external' | 'apk' | 'appinstaller' | 'sparkle'

interface AndroidVariant {
  abi: string
  url: string
  sha256?: string
}

interface DownloadEntry {
  mode: InstallMode
  url?: string
  feedUrl?: string
  sha256?: string
  fallbackUrl?: string
  fallbackSha256?: string
  variants?: AndroidVariant[]
}

interface PlatformEntry {
  version: string
  buildNumber: number
  publishedAt?: string
  notes?: string[]
  download: DownloadEntry
}

interface ManifestPayload {
  platforms?: Record<string, PlatformEntry>
}

interface DownloadLink {
  label: string
  href: string
}

interface PlatformCard {
  key: string
  name: string
  links: DownloadLink[]
}

const manifest = manifestData as ManifestPayload

const platformLabels: Record<string, string> = {
  android: 'Android',
  ios: 'iPhone / iPad',
  macos: 'macOS',
  windows: 'Windows'
}

const abiLabels: Record<string, string> = {
  'arm64-v8a': 'Android ARM64',
  'armeabi-v7a': 'Android ARMv7',
  x86_64: 'Android x86_64'
}

const resolveDownloadLinks = (
  platformKey: string,
  download: DownloadEntry
): DownloadLink[] => {
  if (platformKey === 'android') {
    const variantLinks =
      download.variants?.flatMap((variant) =>
        variant.url
          ? [
              {
                label: abiLabels[variant.abi] ?? variant.abi,
                href: variant.url
              }
            ]
          : []
      ) ?? []

    if (download.fallbackUrl) {
      variantLinks.push({
        label: 'Android 通用包',
        href: download.fallbackUrl
      })
    }

    return variantLinks
  }

  const primaryUrl = download.feedUrl ?? download.url
  if (!primaryUrl) {
    return []
  }

  const linkLabelMap: Record<string, string> = {
    ios: '下载 IPA',
    macos: download.mode === 'sparkle' ? '打开更新源' : '下载 macOS 包',
    windows: download.mode === 'appinstaller' ? '打开安装源' : '下载 Windows 包'
  }

  return [
    {
      label: linkLabelMap[platformKey] ?? '立即下载',
      href: primaryUrl
    }
  ]
}

const cards = computed<PlatformCard[]>(() => {
  const platforms = manifest.platforms ?? {}

  return ['android', 'ios', 'macos', 'windows']
    .flatMap((platformKey) => {
      const entry = platforms[platformKey]
      if (!entry?.download) {
        return []
      }

      const links = resolveDownloadLinks(platformKey, entry.download)
      if (links.length === 0) {
        return []
      }

      return [
        {
          key: platformKey,
          name: platformLabels[platformKey] ?? platformKey,
          links
        }
      ]
    })
})
</script>

<template>
  <section class="home-downloads" id="downloads">
    <div class="home-downloads__header">
      <p class="home-downloads__eyebrow">最新下载</p>
      <h2>按平台直接下载安装包</h2>
    </div>

    <div v-if="cards.length === 0" class="home-downloads__status">
      当前还没有可展示的下载平台。
    </div>
    <div v-else class="home-downloads__grid">
      <article
        v-for="card in cards"
        :key="card.key"
        class="home-downloads__card"
      >
        <div class="home-downloads__card-head">
          <p class="home-downloads__platform">{{ card.name }}</p>
        </div>
        <div class="home-downloads__links">
          <a
            v-for="link in card.links"
            :key="`${card.key}-${link.label}`"
            class="home-downloads__link"
            :href="link.href"
            target="_blank"
            rel="noreferrer"
          >
            <span>{{ link.label }}</span>
          </a>
        </div>
      </article>
    </div>
  </section>
</template>

<style scoped>
.home-downloads {
  margin: 48px 0 20px;
  padding: 28px;
  border: 1px solid rgba(255, 122, 24, 0.14);
  border-radius: 28px;
  background:
    radial-gradient(circle at top right, rgba(255, 106, 61, 0.12), transparent 30%),
    linear-gradient(180deg, rgba(255, 255, 255, 0.88), rgba(255, 248, 243, 0.96));
  box-shadow: 0 18px 40px rgba(121, 61, 29, 0.08);
}

.home-downloads__header h2 {
  margin: 0;
  font-size: 30px;
  line-height: 1.1;
}

.home-downloads__eyebrow {
  margin: 0 0 10px;
  color: var(--vp-c-brand-1);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.18em;
  text-transform: uppercase;
}

.home-downloads__intro {
  max-width: 720px;
  margin: 12px 0 0;
  color: var(--vp-c-text-2);
}

.home-downloads__status {
  margin-top: 24px;
  padding: 18px 20px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.72);
  color: var(--vp-c-text-2);
}

.home-downloads__grid {
  display: grid;
  gap: 18px;
  margin-top: 28px;
}

.home-downloads__card {
  padding: 22px;
  border: 1px solid rgba(255, 122, 24, 0.12);
  border-radius: 22px;
  background: rgba(255, 255, 255, 0.82);
}

.home-downloads__card-head {
  margin-bottom: 14px;
}

.home-downloads__platform {
  margin: 0;
  color: var(--vp-c-text-2);
  font-size: 13px;
}

.home-downloads__links {
  display: grid;
  gap: 12px;
  margin-top: 18px;
}

.home-downloads__link {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 14px 16px;
  border-radius: 16px;
  background: rgba(255, 122, 24, 0.08);
  border: 1px solid rgba(255, 122, 24, 0.12);
  text-decoration: none;
}

.home-downloads__link:hover {
  border-color: rgba(255, 122, 24, 0.28);
  background: rgba(255, 122, 24, 0.13);
}

.home-downloads__link span {
  color: var(--vp-c-brand-1);
  font-weight: 700;
}

.home-downloads__link small {
  color: var(--vp-c-text-3);
}

.dark .home-downloads {
  background:
    radial-gradient(circle at top right, rgba(255, 106, 61, 0.18), transparent 35%),
    linear-gradient(180deg, rgba(31, 22, 35, 0.92), rgba(23, 17, 25, 0.98));
  box-shadow: none;
}

.dark .home-downloads__status,
.dark .home-downloads__card {
  background: rgba(27, 20, 31, 0.92);
  border-color: rgba(255, 122, 24, 0.14);
}

.dark .home-downloads__status--error {
  background: rgba(120, 28, 32, 0.28);
}

.dark .home-downloads__link {
  background: rgba(255, 122, 24, 0.12);
}

@media (min-width: 860px) {
  .home-downloads__grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
</style>
