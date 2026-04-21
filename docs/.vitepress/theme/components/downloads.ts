import Bowser from 'bowser'
import manifestData from '../../../public/latest.json'

export type InstallMode = 'external' | 'apk' | 'appinstaller' | 'sparkle'
export type PlatformKey = 'ios' | 'android' | 'macos' | 'windows'

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
  platforms?: Partial<Record<PlatformKey, PlatformEntry>>
}

export interface DownloadOption {
  key: string
  label: string
  href: string
  description?: string
}

export interface DownloadPlatform {
  key: PlatformKey
  name: string
  href: string
  primaryOption: DownloadOption
  options: DownloadOption[]
}

export interface PlatformCard {
  key: PlatformKey
  name: string
  href: string
}

const manifest = manifestData as ManifestPayload

export const platformOrder: PlatformKey[] = [
  'ios',
  'android',
  'macos',
  'windows'
]

const heroFallbackOrder: PlatformKey[] = [
  'android',
  'macos',
  'windows',
  'ios'
]

const androidVariantLabels: Record<string, string> = {
  'arm64-v8a': 'Android ARM64 包',
  'armeabi-v7a': 'Android ARMv7 包',
  x86_64: 'Android x86_64 包'
}

const androidVariantDescriptions: Record<string, string> = {
  'arm64-v8a': '推荐大多数 64 位 Android 手机和平板。',
  'armeabi-v7a': '适合较旧的 32 位 Android 设备。',
  x86_64: '适合模拟器或少量 x86_64 设备。'
}

export const platformLabels: Record<PlatformKey, string> = {
  ios: 'iOS',
  android: 'Android',
  macos: 'macOS',
  windows: 'Windows'
}

export const platformIconClasses: Record<PlatformKey, string> = {
  ios: 'icon-ios',
  android: 'icon-android',
  macos: 'icon-iconMac',
  windows: 'icon-windows'
}

const buildAndroidOptions = (download: DownloadEntry): DownloadOption[] => {
  const options: DownloadOption[] = []

  if (download.fallbackUrl) {
    options.push({
      key: 'android-universal',
      label: 'Android 通用包',
      href: download.fallbackUrl,
      description: '适合大多数 Android 设备，也对应弹窗二维码。'
    })
  }

  download.variants
    ?.filter((variant) => Boolean(variant.url))
    .forEach((variant) => {
      options.push({
        key: `android-${variant.abi}`,
        label: androidVariantLabels[variant.abi] ?? `Android ${variant.abi} 包`,
        href: variant.url,
        description:
          androidVariantDescriptions[variant.abi] ?? '按设备架构选择此安装包。'
      })
    })

  return options
}

const buildPlatformOptions = (
  platformKey: PlatformKey,
  download: DownloadEntry
): DownloadOption[] => {
  if (platformKey === 'android') {
    return buildAndroidOptions(download)
  }

  const href = download.feedUrl ?? download.url
  if (!href) {
    return []
  }

  return [
    {
      key: `${platformKey}-primary`,
      label: `${platformLabels[platformKey]} 下载`,
      href
    }
  ]
}

export const getPlatformByKey = (
  platformKey: PlatformKey
): DownloadPlatform | null => {
  const entry = manifest.platforms?.[platformKey]
  if (!entry?.download) {
    return null
  }

  const options = buildPlatformOptions(platformKey, entry.download)
  const primaryOption = options[0]
  if (!primaryOption) {
    return null
  }

  return {
    key: platformKey,
    name: platformLabels[platformKey],
    href: primaryOption.href,
    primaryOption,
    options
  }
}

export const getPlatformCards = (): PlatformCard[] => {
  return platformOrder.flatMap((platformKey) => {
    const platform = getPlatformByKey(platformKey)
    if (!platform) {
      return []
    }

    return [
      {
        key: platform.key,
        name: platform.name,
        href: platform.href
      }
    ]
  })
}

export const resolveHeroPlatformKey = (
  detectedPlatform: PlatformKey | null
): PlatformKey | null => {
  if (detectedPlatform && getPlatformByKey(detectedPlatform)) {
    return detectedPlatform
  }

  return (
    heroFallbackOrder.find((platformKey) => Boolean(getPlatformByKey(platformKey))) ??
    null
  )
}

export const detectClientPlatform = (): PlatformKey | null => {
  if (typeof window === 'undefined') {
    return null
  }

  const normalized = Bowser.getParser(window.navigator.userAgent).getOSName(true)

  if (normalized.includes('android')) {
    return 'android'
  }

  if (normalized.includes('ios')) {
    return 'ios'
  }

  if (normalized.includes('mac')) {
    return 'macos'
  }

  if (normalized.includes('windows')) {
    return 'windows'
  }

  return null
}

export const detectIsMobileClient = (): boolean => {
  if (typeof window === 'undefined') {
    return false
  }

  const parser = Bowser.getParser(window.navigator.userAgent)
  const platformType = parser.getPlatformType(true)
  const osName = parser.getOSName(true)

  return (
    platformType.includes('mobile') ||
    platformType.includes('tablet') ||
    osName.includes('android') ||
    osName.includes('ios')
  )
}
