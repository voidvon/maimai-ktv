<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'

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
  meta?: string
}

interface PlatformCard {
  key: string
  name: string
  version: string
  publishedAt: string
  summary?: string
  links: DownloadLink[]
}

const manifest = ref<ManifestPayload | null>(null)
const isLoading = ref(true)
const errorMessage = ref('')

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

const formatPublishedAt = (rawValue?: string) => {
  if (!rawValue) {
    return '发布时间待更新'
  }

  const date = new Date(rawValue)
  if (Number.isNaN(date.getTime())) {
    return rawValue
  }

  return new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).format(date)
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
                href: variant.url,
                meta: variant.sha256 ? `SHA256: ${variant.sha256.slice(0, 8)}...` : undefined
              }
            ]
          : []
      ) ?? []

    if (download.fallbackUrl) {
      variantLinks.push({
        label: 'Android 通用包',
        href: download.fallbackUrl,
        meta: download.fallbackSha256
          ? `SHA256: ${download.fallbackSha256.slice(0, 8)}...`
          : undefined
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
      href: primaryUrl,
      meta: download.sha256 ? `SHA256: ${download.sha256.slice(0, 8)}...` : undefined
    }
  ]
}

const cards = computed<PlatformCard[]>(() => {
  const platforms = manifest.value?.platforms ?? {}

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
          version: `${entry.version}+${entry.buildNumber}`,
          publishedAt: formatPublishedAt(entry.publishedAt),
          summary: entry.notes?.[0],
          links
        }
      ]
    })
})

onMounted(async () => {
  try {
    const response = await fetch('/latest.json', {
      headers: {
        Accept: 'application/json'
      }
    })

    if (!response.ok) {
      throw new Error(`latest.json 请求失败: ${response.status}`)
    }

    const payload = (await response.json()) as ManifestPayload
    manifest.value = payload
  } catch (error) {
    errorMessage.value =
      error instanceof Error ? error.message : '下载清单读取失败'
  } finally {
    isLoading.value = false
  }
})
</script>

<template>
  <section class="home-downloads" id="downloads">
    <div class="home-downloads__header">
      <p class="home-downloads__eyebrow">最新下载</p>
      <h2>按平台直接下载安装包</h2>
      <p class="home-downloads__intro">
        这里直接读取站点根路径的 <code>/latest.json</code>。发版后只要清单更新，首页下载入口也会同步变化。
      </p>
    </div>

    <div v-if="isLoading" class="home-downloads__status">
      正在读取下载清单...
    </div>
    <div v-else-if="errorMessage" class="home-downloads__status home-downloads__status--error">
      {{ errorMessage }}
    </div>
    <div v-else-if="cards.length === 0" class="home-downloads__status">
      当前还没有可展示的下载平台。
    </div>
    <div v-else class="home-downloads__grid">
      <article
        v-for="card in cards"
        :key="card.key"
        class="home-downloads__card"
      >
        <div class="home-downloads__card-head">
          <div>
            <p class="home-downloads__platform">{{ card.name }}</p>
            <h3>{{ card.version }}</h3>
          </div>
          <span class="home-downloads__date">{{ card.publishedAt }}</span>
        </div>

        <p v-if="card.summary" class="home-downloads__summary">
          {{ card.summary }}
        </p>

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
            <small v-if="link.meta">{{ link.meta }}</small>
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

.home-downloads__status--error {
  color: #b42318;
  background: rgba(254, 228, 226, 0.8);
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
  display: flex;
  gap: 12px;
  align-items: flex-start;
  justify-content: space-between;
}

.home-downloads__card-head h3 {
  margin: 4px 0 0;
  font-size: 24px;
  line-height: 1.1;
}

.home-downloads__platform,
.home-downloads__date {
  margin: 0;
  color: var(--vp-c-text-2);
  font-size: 13px;
}

.home-downloads__summary {
  margin: 16px 0 0;
  color: var(--vp-c-text-2);
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
