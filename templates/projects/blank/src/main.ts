/**
 * {{APP_NAME}} - Built with Craft
 */

import { state, derived, effect, mount, h } from '@craft-native/stx'
import { Badge } from '@craft-native/stx/components'
import { usePlatform, useTheme } from '@craft-native/stx/composables'

const { platform } = usePlatform()
const { isDark } = useTheme()

const platformName = derived(() => platform().platform)

function App() {
  return h('div', { class: 'flex flex-col items-center justify-center min-h-screen p-8' },
    h('h1', { class: 'text-4xl font-bold mb-4' }, '{{APP_NAME}}'),
    Badge({ variant: 'info', size: 'md' }, 'Built with Craft'),
    h('p', { class: 'text-sm opacity-50 mt-8' }, 'Running on ', platformName),
  )
}

mount(App, '#app')
