/**
 * {{APP_NAME}} - Tab-based Navigation Template
 */

import { state, effect, mount, h } from '@craft-native/stx'
import { Card, Badge, Button } from '@craft-native/stx/components'
import { usePlatform, useHaptics } from '@craft-native/stx/composables'

const { isMobile } = usePlatform()
const { impact } = useHaptics()

const activeTab = state('home')

function renderHome() {
  return h('div', {},
    Card({},
      h('h3', { class: 'text-lg font-semibold mb-2' }, 'Welcome to {{APP_NAME}}'),
      h('p', { class: 'text-sm text-gray-500' }, 'This is a tab-based navigation template built with Craft.'),
    ),
    Card({},
      h('h3', { class: 'text-lg font-semibold mb-2' }, 'Recent Activity'),
      h('div', { class: 'flex items-center gap-3 py-3 border-b border-gray-200' },
        h('span', { class: 'text-xl' }, '📱'),
        h('div', {},
          h('div', { class: 'font-medium text-sm' }, 'New feature added'),
          h('div', { class: 'text-xs text-gray-400' }, '2 hours ago'),
        ),
      ),
      h('div', { class: 'flex items-center gap-3 py-3' },
        h('span', { class: 'text-xl' }, '🎨'),
        h('div', {},
          h('div', { class: 'font-medium text-sm' }, 'UI update deployed'),
          h('div', { class: 'text-xs text-gray-400' }, 'Yesterday'),
        ),
      ),
    ),
  )
}

function renderSearch() {
  return h('div', {},
    h('input', {
      type: 'search',
      placeholder: 'Search...',
      class: 'w-full h-10 px-4 mb-4 rounded-lg border border-gray-300 bg-white text-sm focus:outline-none focus:ring-2 focus:ring-blue-500',
    }),
    h('p', { class: 'text-center text-gray-400 py-10' }, 'Search for something...'),
  )
}

function renderFavorites() {
  return Card({},
    h('h3', { class: 'text-lg font-semibold mb-2' }, 'Your Favorites'),
    h('p', { class: 'text-sm text-gray-500' }, 'Items you\'ve marked as favorite will appear here.'),
  )
}

function renderProfile() {
  return h('div', {},
    h('div', { class: 'text-center py-5' },
      h('div', { class: 'w-20 h-20 rounded-full bg-blue-500 mx-auto mb-4 flex items-center justify-center text-3xl text-white' }, '👤'),
      h('h2', { class: 'text-xl font-bold mb-1' }, 'User Name'),
      h('p', { class: 'text-sm text-gray-400' }, 'user@example.com'),
    ),
    Card({ padding: false },
      h('div', { class: 'px-4 py-3 border-b border-gray-200 flex justify-between items-center' },
        h('span', { class: 'text-sm font-medium' }, 'Settings'),
        h('span', { class: 'text-gray-400' }, '\u2192'),
      ),
      h('div', { class: 'px-4 py-3 border-b border-gray-200 flex justify-between items-center' },
        h('span', { class: 'text-sm font-medium' }, 'Help & Support'),
        h('span', { class: 'text-gray-400' }, '\u2192'),
      ),
      h('div', { class: 'px-4 py-3 flex justify-between items-center' },
        h('span', { class: 'text-sm font-medium' }, 'About'),
        h('span', { class: 'text-gray-400' }, '\u2192'),
      ),
    ),
  )
}

interface Tab {
  id: string
  label: string
  icon: string
}

const tabs: Tab[] = [
  { id: 'home', label: 'Home', icon: 'M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6' },
  { id: 'search', label: 'Search', icon: 'M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z' },
  { id: 'favorites', label: 'Favorites', icon: 'M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z' },
  { id: 'profile', label: 'Profile', icon: 'M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z' },
]

function svgIcon(path: string) {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
  svg.setAttribute('viewBox', '0 0 24 24')
  svg.setAttribute('fill', 'none')
  svg.setAttribute('stroke', 'currentColor')
  svg.setAttribute('stroke-width', '2')
  svg.setAttribute('class', 'w-6 h-6')
  const p = document.createElementNS('http://www.w3.org/2000/svg', 'path')
  p.setAttribute('d', path)
  svg.appendChild(p)
  return svg
}

function App() {
  const header = h('header', { class: 'sticky top-0 bg-white border-b border-gray-200 px-5 py-4 z-50' },
    h('h1', { class: 'text-2xl font-bold', '@text': () => {
      const tab = tabs.find(t => t.id === activeTab())
      return tab?.label ?? 'Home'
    } }),
  )

  const contentArea = h('main', { class: 'p-5 pb-20 min-h-screen' })
  effect(() => {
    contentArea.innerHTML = ''
    switch (activeTab()) {
      case 'home': contentArea.appendChild(renderHome()); break
      case 'search': contentArea.appendChild(renderSearch()); break
      case 'favorites': contentArea.appendChild(renderFavorites()); break
      case 'profile': contentArea.appendChild(renderProfile()); break
    }
  })

  const tabBar = h('nav', { class: 'fixed bottom-0 left-0 right-0 h-14 bg-gray-50 border-t border-gray-200 flex justify-around items-start pt-2 z-50' })

  for (const tab of tabs) {
    const btn = h('button', { class: 'flex flex-col items-center gap-1 px-4 py-1 text-gray-400 cursor-pointer' })
    btn.appendChild(svgIcon(tab.icon))
    btn.appendChild(h('span', { class: 'text-xs font-medium' }, tab.label))

    effect(() => {
      if (activeTab() === tab.id) {
        btn.className = 'flex flex-col items-center gap-1 px-4 py-1 text-blue-500 cursor-pointer'
      }
      else {
        btn.className = 'flex flex-col items-center gap-1 px-4 py-1 text-gray-400 cursor-pointer'
      }
    })

    btn.addEventListener('click', () => {
      activeTab.set(tab.id)
      if (isMobile()) impact('light')
    })

    tabBar.appendChild(btn)
  }

  const container = h('div', {})
  container.appendChild(header)
  container.appendChild(contentArea)
  container.appendChild(tabBar)
  return container
}

mount(App, '#app')
