#!/usr/bin/env bun
/**
 * Cross-Platform Native Sidebar Example
 *
 * Demonstrates the Craft sidebar API with native styling for:
 * - macOS (vibrancy, source list)
 * - Windows (Mica/Acrylic, Fluent Design)
 * - Linux (GTK/Adwaita styling)
 *
 * Run: bun examples/sidebar-app.ts
 */

import { createApp } from '../packages/typescript/src/index.ts'

const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Sidebar Demo</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }

    :root {
      --sidebar-width: 220px;
      --font: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Ubuntu, sans-serif;
      --bg: #f5f5f5;
      --bg-dark: #1e1e1e;
      --sidebar-bg: rgba(245, 245, 245, 0.85);
      --sidebar-bg-dark: rgba(30, 30, 30, 0.85);
      --text: #1a1a1a;
      --text-dark: #f0f0f0;
      --text-muted: #666;
      --text-muted-dark: #999;
      --border: rgba(0, 0, 0, 0.1);
      --border-dark: rgba(255, 255, 255, 0.1);
      --accent: #0066cc;
      --hover: rgba(0, 0, 0, 0.05);
      --hover-dark: rgba(255, 255, 255, 0.08);
    }

    @media (prefers-color-scheme: dark) {
      :root {
        --bg: var(--bg-dark);
        --sidebar-bg: var(--sidebar-bg-dark);
        --text: var(--text-dark);
        --text-muted: var(--text-muted-dark);
        --border: var(--border-dark);
        --hover: var(--hover-dark);
      }
    }

    body {
      font-family: var(--font);
      background: var(--bg);
      color: var(--text);
      height: 100vh;
      display: flex;
      overflow: hidden;
    }

    /* Sidebar */
    .sidebar {
      width: var(--sidebar-width);
      height: 100vh;
      background: var(--sidebar-bg);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      border-right: 1px solid var(--border);
      display: flex;
      flex-direction: column;
      user-select: none;
    }

    .sidebar-header {
      padding: 16px;
      border-bottom: 1px solid var(--border);
    }

    .sidebar-title {
      font-size: 13px;
      font-weight: 600;
      margin-bottom: 4px;
    }

    .sidebar-subtitle {
      font-size: 11px;
      color: var(--text-muted);
    }

    .sidebar-search {
      padding: 8px 12px;
    }

    .sidebar-search input {
      width: 100%;
      padding: 6px 10px;
      border-radius: 6px;
      border: 1px solid var(--border);
      background: rgba(0,0,0,0.03);
      color: var(--text);
      font-size: 12px;
      outline: none;
    }

    @media (prefers-color-scheme: dark) {
      .sidebar-search input {
        background: rgba(255,255,255,0.06);
      }
    }

    .sidebar-search input:focus {
      border-color: var(--accent);
    }

    .sidebar-content {
      flex: 1;
      overflow-y: auto;
      padding: 4px 0;
    }

    /* Section */
    .section { margin-bottom: 8px; }

    .section-header {
      display: flex;
      align-items: center;
      padding: 6px 12px;
      font-size: 11px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.3px;
      color: var(--text-muted);
      cursor: pointer;
    }

    .section-header:hover { color: var(--text); }

    .section-chevron {
      width: 10px;
      height: 10px;
      margin-right: 4px;
      transition: transform 0.15s;
    }

    .section-header.collapsed .section-chevron {
      transform: rotate(-90deg);
    }

    .section-items {
      overflow: hidden;
      transition: max-height 0.2s ease-out;
    }

    .section-items.collapsed {
      max-height: 0 !important;
    }

    /* Item */
    .item {
      display: flex;
      align-items: center;
      padding: 6px 12px 6px 20px;
      margin: 1px 8px;
      border-radius: 6px;
      cursor: pointer;
      gap: 8px;
      font-size: 13px;
      transition: background 0.1s;
    }

    .item:hover { background: var(--hover); }

    .item.selected {
      background: var(--accent);
      color: white;
    }

    .item-icon {
      width: 16px;
      height: 16px;
      flex-shrink: 0;
      opacity: 0.8;
    }

    .item.selected .item-icon { opacity: 1; }

    .item-label { flex: 1; }

    .item-badge {
      padding: 2px 6px;
      border-radius: 10px;
      font-size: 10px;
      font-weight: 500;
      background: rgba(0,0,0,0.08);
    }

    @media (prefers-color-scheme: dark) {
      .item-badge { background: rgba(255,255,255,0.1); }
    }

    .item.selected .item-badge {
      background: rgba(255,255,255,0.25);
    }

    /* Tag dot */
    .tag-dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
      flex-shrink: 0;
    }

    /* Content */
    .content {
      flex: 1;
      display: flex;
      flex-direction: column;
    }

    .content-header {
      padding: 20px 24px;
      border-bottom: 1px solid var(--border);
    }

    .content-header h1 {
      font-size: 20px;
      font-weight: 600;
    }

    .content-header p {
      font-size: 13px;
      color: var(--text-muted);
      margin-top: 4px;
    }

    .content-body {
      flex: 1;
      padding: 24px;
      overflow-y: auto;
    }

    .content-body h2 {
      font-size: 16px;
      font-weight: 600;
      margin-bottom: 12px;
    }

    .content-body p {
      font-size: 14px;
      line-height: 1.6;
      color: var(--text-muted);
      margin-bottom: 16px;
    }

    .features {
      list-style: none;
    }

    .features li {
      padding: 12px 16px;
      background: var(--hover);
      border-radius: 8px;
      margin-bottom: 8px;
      font-size: 13px;
    }

    .features li strong {
      color: var(--accent);
    }

    code {
      background: var(--hover);
      padding: 2px 6px;
      border-radius: 4px;
      font-family: 'SF Mono', Menlo, Monaco, monospace;
      font-size: 12px;
    }

    pre {
      background: var(--hover);
      padding: 16px;
      border-radius: 8px;
      overflow-x: auto;
      font-size: 12px;
      line-height: 1.5;
    }
  </style>
</head>
<body>
  <aside class="sidebar">
    <div class="sidebar-header">
      <div class="sidebar-title">My App</div>
      <div class="sidebar-subtitle">Cross-platform sidebar</div>
    </div>

    <div class="sidebar-search">
      <input type="text" placeholder="Search..." id="search">
    </div>

    <div class="sidebar-content">
      <!-- Favorites -->
      <div class="section">
        <div class="section-header" onclick="toggleSection('favorites')">
          <svg class="section-chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m9 18 6-6-6-6"/></svg>
          Favorites
        </div>
        <div class="section-items" id="favorites">
          <div class="item selected" data-id="home" onclick="selectItem(this)">
            <svg class="item-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></svg>
            <span class="item-label">Home</span>
          </div>
          <div class="item" data-id="documents" onclick="selectItem(this)">
            <svg class="item-icon" viewBox="0 0 24 24" fill="currentColor"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>
            <span class="item-label">Documents</span>
          </div>
          <div class="item" data-id="downloads" onclick="selectItem(this)">
            <svg class="item-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
            <span class="item-label">Downloads</span>
            <span class="item-badge">3</span>
          </div>
        </div>
      </div>

      <!-- Cloud -->
      <div class="section">
        <div class="section-header" onclick="toggleSection('cloud')">
          <svg class="section-chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m9 18 6-6-6-6"/></svg>
          Cloud
        </div>
        <div class="section-items" id="cloud">
          <div class="item" data-id="cloud-storage" onclick="selectItem(this)">
            <svg class="item-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z"/></svg>
            <span class="item-label">Cloud Storage</span>
          </div>
          <div class="item" data-id="shared" onclick="selectItem(this)">
            <svg class="item-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87m-4-12a4 4 0 0 1 0 7.75"/></svg>
            <span class="item-label">Shared</span>
          </div>
        </div>
      </div>

      <!-- Tags -->
      <div class="section">
        <div class="section-header collapsed" onclick="toggleSection('tags')">
          <svg class="section-chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m9 18 6-6-6-6"/></svg>
          Tags
        </div>
        <div class="section-items collapsed" id="tags">
          <div class="item" data-id="tag-red" onclick="selectItem(this)">
            <div class="tag-dot" style="background:#ef4444"></div>
            <span class="item-label">Important</span>
          </div>
          <div class="item" data-id="tag-blue" onclick="selectItem(this)">
            <div class="tag-dot" style="background:#3b82f6"></div>
            <span class="item-label">Work</span>
          </div>
          <div class="item" data-id="tag-green" onclick="selectItem(this)">
            <div class="tag-dot" style="background:#22c55e"></div>
            <span class="item-label">Personal</span>
          </div>
        </div>
      </div>
    </div>
  </aside>

  <main class="content">
    <div class="content-header">
      <h1 id="title">Home</h1>
      <p id="subtitle">Welcome to your cross-platform app</p>
    </div>
    <div class="content-body">
      <h2>Cross-Platform Sidebar</h2>
      <p>This sidebar adapts to the native styling of each platform:</p>

      <ul class="features">
        <li><strong>macOS</strong> - Vibrancy blur, source list appearance, SF-style icons</li>
        <li><strong>Windows</strong> - Mica/Acrylic material, Segoe UI, Fluent Design</li>
        <li><strong>Linux</strong> - GTK/Adwaita styling, native fonts</li>
      </ul>

      <h2>Usage</h2>
      <pre>import { sidebar, createFileSidebar } from '@craft/api'

// Quick file browser sidebar
const nav = createFileSidebar()
nav.mount()

// Custom sidebar
const custom = sidebar.create({
  sections: [
    {
      id: 'main',
      title: 'Main',
      items: [
        { id: 'home', label: 'Home', icon: 'home' },
        { id: 'settings', label: 'Settings', icon: 'settings' }
      ]
    }
  ]
})
custom.onSelect(e => console.log('Selected:', e.itemId))
custom.mount()</pre>
    </div>
  </main>

  <script>
    const content = {
      home: { title: 'Home', subtitle: 'Welcome to your cross-platform app' },
      documents: { title: 'Documents', subtitle: 'Your personal documents' },
      downloads: { title: 'Downloads', subtitle: '3 recent downloads' },
      'cloud-storage': { title: 'Cloud Storage', subtitle: 'Files synced to the cloud' },
      shared: { title: 'Shared', subtitle: 'Files shared with you' },
      'tag-red': { title: 'Important', subtitle: 'Items tagged as important' },
      'tag-blue': { title: 'Work', subtitle: 'Work-related items' },
      'tag-green': { title: 'Personal', subtitle: 'Personal items' }
    }

    function selectItem(el) {
      document.querySelectorAll('.item').forEach(i => i.classList.remove('selected'))
      el.classList.add('selected')
      const id = el.dataset.id
      const c = content[id] || { title: id, subtitle: '' }
      document.getElementById('title').textContent = c.title
      document.getElementById('subtitle').textContent = c.subtitle
    }

    function toggleSection(id) {
      const header = document.querySelector(\`[onclick="toggleSection('\${id}')"]\`)
      const items = document.getElementById(id)
      header.classList.toggle('collapsed')
      items.classList.toggle('collapsed')
    }

    document.getElementById('search').addEventListener('input', e => {
      const q = e.target.value.toLowerCase()
      document.querySelectorAll('.item').forEach(item => {
        const label = item.querySelector('.item-label').textContent.toLowerCase()
        item.style.display = label.includes(q) ? '' : 'none'
      })
    })

    // Keyboard nav
    document.addEventListener('keydown', e => {
      if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
        e.preventDefault()
        const items = [...document.querySelectorAll('.item:not([style*="display: none"])')];
        const idx = items.findIndex(i => i.classList.contains('selected'))
        const next = e.key === 'ArrowDown' ? (idx + 1) % items.length : (idx - 1 + items.length) % items.length
        selectItem(items[next])
      }
    })
  </script>
</body>
</html>`

createApp({
  html,
  window: {
    title: 'Sidebar Demo',
    width: 900,
    height: 650,
    resizable: true,
    darkMode: true
  }
}).show()

console.log('Sidebar Demo started')
console.log('Features: Cross-platform sidebar with vibrancy, collapsible sections, search, keyboard nav')
