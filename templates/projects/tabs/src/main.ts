/**
 * {{APP_NAME}} - Tab-based Navigation Template
 */

import { isMobile, haptics } from '@craft-native/craft'

interface Tab {
  id: string
  label: string
  icon: string
}

const tabs: Tab[] = [
  { id: 'home', label: 'Home', icon: '<path d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"/>' },
  { id: 'search', label: 'Search', icon: '<path d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>' },
  { id: 'favorites', label: 'Favorites', icon: '<path d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"/>' },
  { id: 'profile', label: 'Profile', icon: '<path d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>' }
]

let activeTab = 'home'

function renderIcon(path: string): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">${path}</svg>`
}

function switchTab(tabId: string): void {
  if (activeTab === tabId) return

  activeTab = tabId

  // Haptic feedback on mobile
  if (isMobile()) {
    haptics.impact('light')
  }

  // Update tab bar
  document.querySelectorAll('.tab-item').forEach(item => {
    item.classList.toggle('active', item.getAttribute('data-tab') === tabId)
  })

  // Update content
  document.querySelectorAll('.tab-content').forEach(content => {
    content.classList.toggle('active', content.id === `tab-${tabId}`)
  })

  // Update header
  const tab = tabs.find(t => t.id === tabId)
  document.querySelector('.header h1')!.textContent = tab?.label || ''
}

function renderHome(): string {
  return `
    <div class="card">
      <h3>Welcome to {{APP_NAME}}</h3>
      <p>This is a tab-based navigation template built with Craft.</p>
    </div>
    <div class="card">
      <h3>Recent Activity</h3>
      <div class="list-item">
        <div class="list-item-icon">📱</div>
        <div class="list-item-content">
          <div class="list-item-title">New feature added</div>
          <div class="list-item-subtitle">2 hours ago</div>
        </div>
      </div>
      <div class="list-item">
        <div class="list-item-icon">🎨</div>
        <div class="list-item-content">
          <div class="list-item-title">UI update deployed</div>
          <div class="list-item-subtitle">Yesterday</div>
        </div>
      </div>
    </div>
  `
}

function renderSearch(): string {
  return `
    <div style="margin-bottom: 16px;">
      <input type="search" placeholder="Search..." style="
        width: 100%;
        padding: 12px 16px;
        border: 1px solid var(--border);
        border-radius: 10px;
        background: var(--bg-secondary);
        color: var(--text);
        font-size: 16px;
      ">
    </div>
    <p style="color: var(--text-secondary); text-align: center; padding: 40px;">
      Search for something...
    </p>
  `
}

function renderFavorites(): string {
  return `
    <div class="card">
      <h3>Your Favorites</h3>
      <p>Items you've marked as favorite will appear here.</p>
    </div>
  `
}

function renderProfile(): string {
  return `
    <div style="text-align: center; padding: 20px 0;">
      <div style="width: 80px; height: 80px; border-radius: 50%; background: var(--primary); margin: 0 auto 16px; display: flex; align-items: center; justify-content: center; font-size: 32px; color: white;">
        👤
      </div>
      <h2 style="margin-bottom: 4px;">User Name</h2>
      <p style="color: var(--text-secondary);">user@example.com</p>
    </div>
    <div class="card">
      <div class="list-item">
        <div class="list-item-content">
          <div class="list-item-title">Settings</div>
        </div>
        <span style="color: var(--text-secondary);">→</span>
      </div>
      <div class="list-item">
        <div class="list-item-content">
          <div class="list-item-title">Help & Support</div>
        </div>
        <span style="color: var(--text-secondary);">→</span>
      </div>
      <div class="list-item">
        <div class="list-item-content">
          <div class="list-item-title">About</div>
        </div>
        <span style="color: var(--text-secondary);">→</span>
      </div>
    </div>
  `
}

function init(): void {
  const app = document.getElementById('app')!

  app.innerHTML = `
    <header class="header">
      <h1>Home</h1>
    </header>

    <main class="content">
      <div id="tab-home" class="tab-content active">${renderHome()}</div>
      <div id="tab-search" class="tab-content">${renderSearch()}</div>
      <div id="tab-favorites" class="tab-content">${renderFavorites()}</div>
      <div id="tab-profile" class="tab-content">${renderProfile()}</div>
    </main>

    <nav class="tab-bar">
      ${tabs.map(tab => `
        <button class="tab-item ${tab.id === activeTab ? 'active' : ''}" data-tab="${tab.id}">
          ${renderIcon(tab.icon)}
          <span>${tab.label}</span>
        </button>
      `).join('')}
    </nav>
  `

  // Attach event listeners
  document.querySelectorAll('.tab-item').forEach(item => {
    item.addEventListener('click', () => {
      const tabId = item.getAttribute('data-tab')
      if (tabId) switchTab(tabId)
    })
  })
}

// Start app
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init)
} else {
  init()
}
