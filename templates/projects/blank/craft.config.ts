import type { CraftAppConfig } from '@craft-native/craft'

const config: CraftAppConfig = {
  name: '{{APP_NAME}}',
  version: '1.0.0',
  identifier: '{{BUNDLE_ID}}',

  window: {
    title: '{{APP_NAME}}',
    width: 800,
    height: 600,
    resizable: true,
    center: true
  },

  entry: './index.html'
}

export default config
