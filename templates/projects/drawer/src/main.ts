/**
 * {{APP_NAME}} - Drawer Navigation Template
 */

import { state, effect, mount, h } from '@craft-native/stx'
import { Card, Toggle, Badge } from '@craft-native/stx/components'
import { usePlatform, useHaptics } from '@craft-native/stx/composables'

interface MenuItem {
  id: string
  label: string
  icon: string
  badge?: string
}

interface MenuSection {
  title?: string
  items: MenuItem[]
}

const menuSections: MenuSection[] = [
  {
    items: [
      { id: 'home', label: 'Home', icon: '<path d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"/>' },
      { id: 'inbox', label: 'Inbox', icon: '<path d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"/>', badge: '3' },
      { id: 'starred', label: 'Starred', icon: '<path d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"/>' },
      { id: 'archive', label: 'Archive', icon: '<path d="M5 8h14M5 8a2 2 0 110-4h14a2 2 0 110 4M5 8v10a2 2 0 002 2h10a2 2 0 002-2V8m-9 4h4"/>' }
    ]
  },
  {
    title: 'Labels',
    items: [
      { id: 'personal', label: 'Personal', icon: '<circle cx="12" cy="12" r="10" fill="#4CAF50" stroke="none"/>' },
      { id: 'work', label: 'Work', icon: '<circle cx="12" cy="12" r="10" fill="#2196F3" stroke="none"/>' },
      { id: 'projects', label: 'Projects', icon: '<circle cx="12" cy="12" r="10" fill="#FF9800" stroke="none"/>' }
    ]
  },
  {
    items: [
      { id: 'settings', label: 'Settings', icon: '<path d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/><path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>' },
      { id: 'help', label: 'Help & Feedback', icon: '<path d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>' }
    ]
  }
]

const { isMobile } = usePlatform()
const { impact, selection } = useHaptics()

// Reactive state
const activePage = state('home')
const isDrawerOpen = state(false)
const notificationsOn = state(true)
const darkModeOn = state(false)
const autoSyncOn = state(true)

function renderIcon(path: string) {
  return h('svg', {
    xmlns: 'http://www.w3.org/2000/svg',
    fill: 'none',
    viewBox: '0 0 24 24',
    stroke: 'currentColor',
    'stroke-width': '2',
    innerHTML: path
  })
}

function toggleDrawer(): void {
  isDrawerOpen.update(v => !v)
  if (isMobile()) {
    impact('light')
  }
}

function closeDrawer(): void {
  if (!isDrawerOpen()) return
  isDrawerOpen.set(false)
}

function navigateTo(pageId: string): void {
  if (activePage() === pageId) {
    closeDrawer()
    return
  }

  activePage.set(pageId)

  if (isMobile()) {
    selection()
  }

  closeDrawer()
}

// Page content builders

function buildListItem(icon: string, title: string, subtitle: string, action?: string) {
  return h('div', { class: 'list-item' },
    h('div', { class: 'list-item-icon', '@text': icon }),
    h('div', { class: 'list-item-content' },
      h('div', { class: 'list-item-title', '@text': title }),
      h('div', { class: 'list-item-subtitle', '@text': subtitle })
    ),
    ...(action ? [h('span', { class: 'list-item-action', '@text': action })] : [])
  )
}

function buildHomePage() {
  return h('div', { class: 'page', '@show': () => activePage() === 'home' },
    Card({},
      h('h3', { '@text': 'Welcome to {{APP_NAME}}' }),
      h('p', { '@text': 'This is a drawer navigation template built with Craft. Tap the menu icon to open the navigation drawer.' })
    ),
    Card({},
      h('h3', { '@text': 'Recent Items' }),
      buildListItem('\u{1F4C4}', 'Project Proposal', 'Modified 2 hours ago', '\u2192'),
      buildListItem('\u{1F4CA}', 'Q4 Report', 'Modified yesterday', '\u2192'),
      buildListItem('\u{1F4DD}', 'Meeting Notes', 'Modified 3 days ago', '\u2192')
    )
  )
}

function buildInboxPage() {
  return h('div', { class: 'page', '@show': () => activePage() === 'inbox' },
    Card({},
      buildListItem('\u{1F464}', 'New message from Alex', 'Hey! Just wanted to check in about the project...'),
      buildListItem('\u{1F514}', 'System notification', 'Your backup completed successfully'),
      buildListItem('\u{1F4C5}', 'Meeting reminder', 'Team standup in 30 minutes')
    )
  )
}

function buildEmptyState(icon: string, title: string, text: string) {
  return h('div', { class: 'empty-state' },
    h('div', { class: 'empty-state-icon', '@text': icon }),
    h('div', { class: 'empty-state-title', '@text': title }),
    h('div', { class: 'empty-state-text', '@text': text })
  )
}

function buildStarredPage() {
  return h('div', { class: 'page', '@show': () => activePage() === 'starred' },
    buildEmptyState('\u2B50', 'No starred items', 'Items you star will appear here for quick access.')
  )
}

function buildArchivePage() {
  return h('div', { class: 'page', '@show': () => activePage() === 'archive' },
    buildEmptyState('\u{1F4E6}', 'Archive is empty', 'Archived items will be stored here.')
  )
}

function buildLabelPage(id: string, label: string) {
  return h('div', { class: 'page', '@show': () => activePage() === id },
    buildEmptyState('\u{1F3F7}\uFE0F', `No ${label} items`, `Items labeled as ${label} will appear here.`)
  )
}

function buildSettingsPage() {
  return h('div', { class: 'page', '@show': () => activePage() === 'settings' },
    h('div', { class: 'settings-list' },
      h('div', { class: 'settings-item' },
        h('span', { class: 'settings-item-label', '@text': 'Notifications' }),
        Toggle({
          value: notificationsOn,
          onChange: () => {
            notificationsOn.update(v => !v)
            if (isMobile()) impact('light')
          }
        })
      ),
      h('div', { class: 'settings-item' },
        h('span', { class: 'settings-item-label', '@text': 'Dark Mode' }),
        Toggle({
          value: darkModeOn,
          onChange: () => {
            darkModeOn.update(v => !v)
            if (isMobile()) impact('light')
          }
        })
      ),
      h('div', { class: 'settings-item' },
        h('span', { class: 'settings-item-label', '@text': 'Auto-sync' }),
        Toggle({
          value: autoSyncOn,
          onChange: () => {
            autoSyncOn.update(v => !v)
            if (isMobile()) impact('light')
          }
        })
      )
    ),
    h('div', { class: 'settings-list' },
      h('div', { class: 'settings-item' },
        h('span', { class: 'settings-item-label', '@text': 'Account' }),
        h('span', { class: 'settings-item-value', '@text': 'user@example.com \u2192' })
      ),
      h('div', { class: 'settings-item' },
        h('span', { class: 'settings-item-label', '@text': 'Storage' }),
        h('span', { class: 'settings-item-value', '@text': '2.4 GB used \u2192' })
      ),
      h('div', { class: 'settings-item' },
        h('span', { class: 'settings-item-label', '@text': 'Privacy' }),
        h('span', { class: 'settings-item-value', '@text': '\u2192' })
      )
    )
  )
}

function buildHelpPage() {
  return h('div', { class: 'page', '@show': () => activePage() === 'help' },
    Card({},
      h('h3', { '@text': 'Getting Started' }),
      h('p', { '@text': 'This template demonstrates drawer navigation, commonly used in mobile apps. Swipe from the left edge or tap the menu button to open the drawer.' })
    ),
    Card({},
      h('h3', { '@text': 'Contact Support' }),
      h('p', { '@text': 'Have questions or feedback? We\'d love to hear from you.' }),
      buildListItem('\u{1F4E7}', 'Email Support', 'support@example.com'),
      buildListItem('\u{1F4AC}', 'Live Chat', 'Available 9am - 5pm EST')
    )
  )
}

function buildDrawerItem(item: MenuItem) {
  return h('button', {
    class: 'drawer-item',
    '@class': () => activePage() === item.id ? 'active' : '',
    onClick: () => navigateTo(item.id)
  },
    renderIcon(item.icon),
    h('span', { class: 'drawer-item-label', '@text': item.label }),
    ...(item.badge
      ? [Badge({ '@text': item.badge, class: 'drawer-item-badge' })]
      : [])
  )
}

function buildDrawerSection(section: MenuSection, index: number) {
  return h('div', {},
    ...(index > 0 ? [h('div', { class: 'drawer-divider' })] : []),
    h('div', { class: 'drawer-section' },
      ...(section.title
        ? [h('div', { class: 'drawer-section-title', '@text': section.title })]
        : []),
      ...section.items.map(item => buildDrawerItem(item))
    )
  )
}

function buildApp() {
  return h('div', {},
    // Drawer overlay
    h('div', {
      class: 'drawer-overlay',
      '@class': () => isDrawerOpen() ? 'open' : '',
      onClick: closeDrawer
    }),

    // Drawer sidebar
    h('aside', {
      class: 'drawer',
      '@class': () => isDrawerOpen() ? 'open' : ''
    },
      h('div', { class: 'drawer-header' },
        h('div', { class: 'drawer-header-avatar', '@text': '\u{1F464}' }),
        h('div', { class: 'drawer-header-title', '@text': 'User Name' }),
        h('div', { class: 'drawer-header-subtitle', '@text': 'user@example.com' })
      ),
      h('nav', { class: 'drawer-content' },
        ...menuSections.map((section, index) => buildDrawerSection(section, index))
      ),
      h('div', { class: 'drawer-footer' },
        h('div', { class: 'drawer-footer-version', '@text': '{{APP_NAME}} v1.0.0' })
      )
    ),

    // Header
    h('header', { class: 'header' },
      h('button', {
        class: 'header-menu-btn',
        'aria-label': 'Open menu',
        onClick: toggleDrawer
      },
        h('svg', {
          xmlns: 'http://www.w3.org/2000/svg',
          fill: 'none',
          viewBox: '0 0 24 24',
          stroke: 'currentColor',
          'stroke-width': '2',
          innerHTML: '<path d="M4 6h16M4 12h16M4 18h16"/>'
        })
      ),
      h('h1', {
        '@text': () => {
          const menuItem = menuSections.flatMap(s => s.items).find(item => item.id === activePage())
          return menuItem ? menuItem.label : 'Home'
        }
      }),
      h('button', {
        class: 'header-action',
        'aria-label': 'Search'
      },
        h('svg', {
          xmlns: 'http://www.w3.org/2000/svg',
          fill: 'none',
          viewBox: '0 0 24 24',
          stroke: 'currentColor',
          'stroke-width': '2',
          innerHTML: '<path d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>'
        })
      )
    ),

    // Main content with pages
    h('main', { class: 'content' },
      buildHomePage(),
      buildInboxPage(),
      buildStarredPage(),
      buildArchivePage(),
      buildLabelPage('personal', 'Personal'),
      buildLabelPage('work', 'Work'),
      buildLabelPage('projects', 'Projects'),
      buildSettingsPage(),
      buildHelpPage()
    ),

    // FAB
    h('button', {
      class: 'fab',
      'aria-label': 'Add new',
      onClick: () => {
        if (isMobile()) impact('medium')
        alert('Add new item')
      }
    },
      h('svg', {
        xmlns: 'http://www.w3.org/2000/svg',
        fill: 'none',
        viewBox: '0 0 24 24',
        stroke: 'currentColor',
        'stroke-width': '2',
        innerHTML: '<path d="M12 4v16m8-8H4"/>'
      })
    )
  )
}

// Body overflow side effect
effect(() => {
  document.body.style.overflow = isDrawerOpen() ? 'hidden' : ''
})

// Touch gesture for opening/closing drawer (global concern)
let touchStartX = 0
let touchStartY = 0

document.addEventListener('touchstart', (e) => {
  touchStartX = e.touches[0].clientX
  touchStartY = e.touches[0].clientY
}, { passive: true })

document.addEventListener('touchend', (e) => {
  const touchEndX = e.changedTouches[0].clientX
  const touchEndY = e.changedTouches[0].clientY
  const deltaX = touchEndX - touchStartX
  const deltaY = Math.abs(touchEndY - touchStartY)

  if (touchStartX < 30 && deltaX > 50 && deltaY < 50 && !isDrawerOpen()) {
    toggleDrawer()
  } else if (isDrawerOpen() && deltaX < -50 && deltaY < 50) {
    closeDrawer()
  }
}, { passive: true })

// Keyboard shortcuts (global concern)
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && isDrawerOpen()) {
    closeDrawer()
  }
})

// Mount the app
mount(buildApp(), '#app')
