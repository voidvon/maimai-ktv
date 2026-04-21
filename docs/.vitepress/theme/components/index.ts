import type { App } from 'vue'

import HomeDownloads from './HomeDownloads.vue'

export const registerComponents = (app: App) => {
  app.component('HomeDownloads', HomeDownloads)
}
