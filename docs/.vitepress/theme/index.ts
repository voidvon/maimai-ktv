import { h } from 'vue'
import DefaultTheme from 'vitepress/theme'
import './custom.css'
import { registerComponents } from './components'
import DownloadModal from './components/DownloadModal.vue'
import HomeDownloads from './components/HomeDownloads.vue'
import HomeHeroDownloadAction from './components/HomeHeroDownloadAction.vue'

export default {
  extends: DefaultTheme,
  Layout() {
    return h(DefaultTheme.Layout, null, {
      'home-hero-actions-before-actions': () => h(HomeHeroDownloadAction),
      'home-features-before': () => h(HomeDownloads),
      'layout-bottom': () => h(DownloadModal)
    })
  },
  enhanceApp({ app }) {
    registerComponents(app)
  }
}
