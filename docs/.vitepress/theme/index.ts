import DefaultTheme from 'vitepress/theme'
import './custom.css'
import { registerComponents } from './components'

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    registerComponents(app)
  }
}
