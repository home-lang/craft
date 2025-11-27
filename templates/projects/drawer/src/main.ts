/**
 * {{APP_NAME}} - Drawer Navigation Template
 */

import { isMobile, haptics } from '@craft-native/craft'

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

let activePage = 'home'
let isDrawerOpen = false

function renderIcon(path: string): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">${path}</svg>`
}

function toggleDrawer(): void {
  isDrawerOpen = !isDrawerOpen

  if (isMobile()) {
    haptics.impact('light')
  }

  document.querySelector('.drawer')?.classList.toggle('open', isDrawerOpen)
  document.querySelector('.drawer-overlay')?.classList.toggle('open', isDrawerOpen)
  document.body.style.overflow = isDrawerOpen ? 'hidden' : ''
}

function closeDrawer(): void {
  if (!isDrawerOpen) return
  isDrawerOpen = false
  document.querySelector('.drawer')?.classList.remove('open')
  document.querySelector('.drawer-overlay')?.classList.remove('open')
  document.body.style.overflow = ''
}

function navigateTo(pageId: string): void {
  if (activePage === pageId) {
    closeDrawer()
    return
  }

  activePage = pageId

  if (isMobile()) {
    haptics.selection()
  }

  // Update drawer items
  document.querySelectorAll('.drawer-item').forEach(item => {
    item.classList.toggle('active', item.getAttribute('data-page') === pageId)
  })

  // Update pages
  document.querySelectorAll('.page').forEach(page => {
    page.classList.toggle('active', page.id === `page-${pageId}`)
  })

  // Update header title
  const menuItem = menuSections.flatMap(s => s.items).find(item => item.id === pageId)
  const headerTitle = document.querySelector('.header h1')
  if (headerTitle && menuItem) {
    headerTitle.textContent = menuItem.label
  }

  closeDrawer()
}

function renderHomePage(): string {
  return `
    <div class="card">
      <h3>Welcome to {{APP_NAME}}</h3>
      <p>This is a drawer navigation template built with Craft. Tap the menu icon to open the navigation drawer.</p>
    </div>
    <div class="card">
      <h3>Recent Items</h3>
      <div class="list-item">
        <div class="list-item-icon">📄</div>
        <div class="list-item-content">
          <div class="list-item-title">Project Proposal</div>
          <div class="list-item-subtitle">Modified 2 hours ago</div>
        </div>
        <span class="list-item-action">→</span>
      </div>
      <div class="list-item">
        <div class="list-item-icon">📊</div>
        <div class="list-item-content">
          <div class="list-item-title">Q4 Report</div>
          <div class="list-item-subtitle">Modified yesterday</div>
        </div>
        <span class="list-item-action">→</span>
      </div>
      <div class="list-item">
        <div class="list-item-icon">📝</div>
        <div class="list-item-content">
          <div class="list-item-title">Meeting Notes</div>
          <div class="list-item-subtitle">Modified 3 days ago</div>
        </div>
        <span class="list-item-action">→</span>
      </div>
    </div>
  `
}

function renderInboxPage(): string {
  return `
    <div class="card">
      <div class="list-item">
        <div class="list-item-icon">👤</div>
        <div class="list-item-content">
          <div class="list-item-title">New message from Alex</div>
          <div class="list-item-subtitle">Hey! Just wanted to check in about the project...</div>
        </div>
      </div>
      <div class="list-item">
        <div class="list-item-icon">🔔</div>
        <div class="list-item-content">
          <div class="list-item-title">System notification</div>
          <div class="list-item-subtitle">Your backup completed successfully</div>
        </div>
      </div>
      <div class="list-item">
        <div class="list-item-icon">📅</div>
        <div class="list-item-content">
          <div class="list-item-title">Meeting reminder</div>
          <div class="list-item-subtitle">Team standup in 30 minutes</div>
        </div>
      </div>
    </div>
  `
}

function renderStarredPage(): string {
  return `
    <div class="empty-state">
      <div class="empty-state-icon">⭐</div>
      <div class="empty-state-title">No starred items</div>
      <div class="empty-state-text">Items you star will appear here for quick access.</div>
    </div>
  `
}

function renderArchivePage(): string {
  return `
    <div class="empty-state">
      <div class="empty-state-icon">📦</div>
      <div class="empty-state-title">Archive is empty</div>
      <div class="empty-state-text">Archived items will be stored here.</div>
    </div>
  `
}

function renderLabelPage(label: string): string {
  return `
    <div class="empty-state">
      <div class="empty-state-icon">🏷️</div>
      <div class="empty-state-title">No ${label} items</div>
      <div class="empty-state-text">Items labeled as ${label} will appear here.</div>
    </div>
  `
}

function renderSettingsPage(): string {
  return `
    <div class="settings-list">
      <div class="settings-item">
        <span class="settings-item-label">Notifications</span>
        <div class="toggle on" data-setting="notifications"></div>
      </div>
      <div class="settings-item">
        <span class="settings-item-label">Dark Mode</span>
        <div class="toggle" data-setting="darkmode"></div>
      </div>
      <div class="settings-item">
        <span class="settings-item-label">Auto-sync</span>
        <div class="toggle on" data-setting="autosync"></div>
      </div>
    </div>
    <div class="settings-list">
      <div class="settings-item">
        <span class="settings-item-label">Account</span>
        <span class="settings-item-value">user@example.com →</span>
      </div>
      <div class="settings-item">
        <span class="settings-item-label">Storage</span>
        <span class="settings-item-value">2.4 GB used →</span>
      </div>
      <div class="settings-item">
        <span class="settings-item-label">Privacy</span>
        <span class="settings-item-value">→</span>
      </div>
    </div>
  `
}

function renderHelpPage(): string {
  return `
    <div class="card">
      <h3>Getting Started</h3>
      <p>This template demonstrates drawer navigation, commonly used in mobile apps. Swipe from the left edge or tap the menu button to open the drawer.</p>
    </div>
    <div class="card">
      <h3>Contact Support</h3>
      <p>Have questions or feedback? We'd love to hear from you.</p>
      <div class="list-item">
        <div class="list-item-icon">📧</div>
        <div class="list-item-content">
          <div class="list-item-title">Email Support</div>
          <div class="list-item-subtitle">support@example.com</div>
        </div>
      </div>
      <div class="list-item">
        <div class="list-item-icon">💬</div>
        <div class="list-item-content">
          <div class="list-item-title">Live Chat</div>
          <div class="list-item-subtitle">Available 9am - 5pm EST</div>
        </div>
      </div>
    </div>
  `
}

function getPageContent(pageId: string): string {
  switch (pageId) {
    case 'home': return renderHomePage()
    case 'inbox': return renderInboxPage()
    case 'starred': return renderStarredPage()
    case 'archive': return renderArchivePage()
    case 'personal': return renderLabelPage('Personal')
    case 'work': return renderLabelPage('Work')
    case 'projects': return renderLabelPage('Projects')
    case 'settings': return renderSettingsPage()
    case 'help': return renderHelpPage()
    default: return ''
  }
}

function init(): void {
  const app = document.getElementById('app')!

  // Get all page IDs
  const allPages = menuSections.flatMap(s => s.items).map(item => item.id)

  app.innerHTML = `
    <div class="drawer-overlay"></div>

    <aside class="drawer">
      <div class="drawer-header">
        <div class="drawer-header-avatar">👤</div>
        <div class="drawer-header-title">User Name</div>
        <div class="drawer-header-subtitle">user@example.com</div>
      </div>

      <nav class="drawer-content">
        ${menuSections.map((section, index) => `
          ${index > 0 ? '<div class="drawer-divider"></div>' : ''}
          <div class="drawer-section">
            ${section.title ? `<div class="drawer-section-title">${section.title}</div>` : ''}
            ${section.items.map(item => `
              <button class="drawer-item ${item.id === activePage ? 'active' : ''}" data-page="${item.id}">
                ${renderIcon(item.icon)}
                <span class="drawer-item-label">${item.label}</span>
                ${item.badge ? `<span class="drawer-item-badge">${item.badge}</span>` : ''}
              </button>
            `).join('')}
          </div>
        `).join('')}
      </nav>

      <div class="drawer-footer">
        <div class="drawer-footer-version">{{APP_NAME}} v1.0.0</div>
      </div>
    </aside>

    <header class="header">
      <button class="header-menu-btn" aria-label="Open menu">
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path d="M4 6h16M4 12h16M4 18h16"/>
        </svg>
      </button>
      <h1>Home</h1>
      <button class="header-action" aria-label="Search">
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
        </svg>
      </button>
    </header>

    <main class="content">
      ${allPages.map(pageId => `
        <div id="page-${pageId}" class="page ${pageId === activePage ? 'active' : ''}">
          ${getPageContent(pageId)}
        </div>
      `).join('')}
    </main>

    <button class="fab" aria-label="Add new">
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path d="M12 4v16m8-8H4"/>
      </svg>
    </button>
  `

  // Event listeners
  document.querySelector('.header-menu-btn')?.addEventListener('click', toggleDrawer)
  document.querySelector('.drawer-overlay')?.addEventListener('click', closeDrawer)

  document.querySelectorAll('.drawer-item').forEach(item => {
    item.addEventListener('click', () => {
      const pageId = item.getAttribute('data-page')
      if (pageId) navigateTo(pageId)
    })
  })

  // Toggle switches
  document.querySelectorAll('.toggle').forEach(toggle => {
    toggle.addEventListener('click', () => {
      toggle.classList.toggle('on')
      if (isMobile()) {
        haptics.impact('light')
      }
    })
  })

  // FAB
  document.querySelector('.fab')?.addEventListener('click', () => {
    if (isMobile()) {
      haptics.impact('medium')
    }
    alert('Add new item')
  })

  // Touch gesture for opening drawer (swipe from left edge)
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

    // Open drawer: swipe right from left edge
    if (touchStartX < 30 && deltaX > 50 && deltaY < 50 && !isDrawerOpen) {
      toggleDrawer()
    }
    // Close drawer: swipe left when open
    else if (isDrawerOpen && deltaX < -50 && deltaY < 50) {
      closeDrawer()
    }
  }, { passive: true })

  // Keyboard shortcuts
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && isDrawerOpen) {
      closeDrawer()
    }
  })
}

// Start app
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init)
} else {
  init()
}
