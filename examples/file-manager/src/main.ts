/**
 * Craft Files - A cross-platform file manager
 * Demonstrates: File System API, keyboard shortcuts, context menus
 */

import { fs, window, Platform } from 'ts-craft'

interface FileEntry {
  name: string
  path: string
  isFile: boolean
  isDirectory: boolean
  size: number
  modified: Date
}

let currentPath = Platform.OS === 'win32' ? 'C:\\' : (process.env?.HOME || '/')
let files: FileEntry[] = []
let selectedFiles: Set<string> = new Set()
let viewMode: 'list' | 'grid' = 'list'
let history: string[] = []
let historyIndex = -1
let loading = false

// Sidebar locations
const locations = [
  { name: 'Home', path: process.env?.HOME || '/', icon: '🏠' },
  { name: 'Desktop', path: `${process.env?.HOME || ''}/Desktop`, icon: '🖥️' },
  { name: 'Documents', path: `${process.env?.HOME || ''}/Documents`, icon: '📄' },
  { name: 'Downloads', path: `${process.env?.HOME || ''}/Downloads`, icon: '⬇️' },
  { name: 'Pictures', path: `${process.env?.HOME || ''}/Pictures`, icon: '🖼️' },
  { name: 'Music', path: `${process.env?.HOME || ''}/Music`, icon: '🎵' },
]

// File icons by extension
function getFileIcon(name: string, isDirectory: boolean): string {
  if (isDirectory) return '📁'

  const ext = name.split('.').pop()?.toLowerCase()
  const icons: Record<string, string> = {
    // Documents
    pdf: '📕', doc: '📘', docx: '📘', txt: '📝', md: '📝',
    xls: '📗', xlsx: '📗', csv: '📊',
    ppt: '📙', pptx: '📙',
    // Code
    js: '📜', ts: '📜', jsx: '📜', tsx: '📜',
    html: '🌐', css: '🎨', json: '📋',
    py: '🐍', rb: '💎', go: '🔷', rs: '🦀',
    // Images
    jpg: '🖼️', jpeg: '🖼️', png: '🖼️', gif: '🖼️', svg: '🖼️', webp: '🖼️',
    // Media
    mp3: '🎵', wav: '🎵', flac: '🎵', m4a: '🎵',
    mp4: '🎬', mov: '🎬', avi: '🎬', mkv: '🎬',
    // Archives
    zip: '📦', rar: '📦', tar: '📦', gz: '📦', '7z': '📦',
    // Other
    exe: '⚙️', app: '⚙️', dmg: '💿', iso: '💿',
  }

  return icons[ext || ''] || '📄'
}

// Format file size
function formatSize(bytes: number): string {
  if (bytes === 0) return '—'
  const units = ['B', 'KB', 'MB', 'GB', 'TB']
  const i = Math.floor(Math.log(bytes) / Math.log(1024))
  return `${(bytes / Math.pow(1024, i)).toFixed(i > 0 ? 1 : 0)} ${units[i]}`
}

// Format date
function formatDate(date: Date): string {
  const now = new Date()
  const diff = now.getTime() - date.getTime()

  if (diff < 86400000) {
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  } else if (diff < 604800000) {
    return date.toLocaleDateString([], { weekday: 'short', hour: '2-digit', minute: '2-digit' })
  } else {
    return date.toLocaleDateString([], { month: 'short', day: 'numeric', year: 'numeric' })
  }
}

// Get file kind
function getFileKind(name: string, isDirectory: boolean): string {
  if (isDirectory) return 'Folder'

  const ext = name.split('.').pop()?.toLowerCase()
  const kinds: Record<string, string> = {
    pdf: 'PDF Document', doc: 'Word Document', docx: 'Word Document',
    txt: 'Text File', md: 'Markdown', js: 'JavaScript', ts: 'TypeScript',
    html: 'HTML', css: 'Stylesheet', json: 'JSON',
    jpg: 'JPEG Image', jpeg: 'JPEG Image', png: 'PNG Image', gif: 'GIF Image',
    mp3: 'MP3 Audio', mp4: 'MP4 Video', zip: 'ZIP Archive',
  }

  return kinds[ext || ''] || (ext ? `${ext.toUpperCase()} File` : 'File')
}

// Navigate to path
async function navigateTo(path: string, addToHistory = true) {
  loading = true
  render()

  try {
    const entries = await fs.readDir(path)

    files = await Promise.all(entries.map(async (entry) => {
      const fullPath = `${path}/${entry.name}`.replace(/\/+/g, '/')
      let stat = { size: 0, modified: new Date() }

      try {
        stat = await fs.stat(fullPath)
      } catch {
        // Ignore stat errors
      }

      return {
        name: entry.name,
        path: fullPath,
        isFile: entry.isFile,
        isDirectory: entry.isDirectory,
        size: stat.size || 0,
        modified: stat.modified || new Date()
      }
    }))

    // Sort: folders first, then by name
    files.sort((a, b) => {
      if (a.isDirectory && !b.isDirectory) return -1
      if (!a.isDirectory && b.isDirectory) return 1
      return a.name.localeCompare(b.name)
    })

    currentPath = path
    selectedFiles.clear()

    if (addToHistory) {
      history = history.slice(0, historyIndex + 1)
      history.push(path)
      historyIndex = history.length - 1
    }

    window.setTitle(`Craft Files - ${path}`)
  } catch (error) {
    console.error('Failed to read directory:', error)
    files = []
  }

  loading = false
  render()
}

// Go back
function goBack() {
  if (historyIndex > 0) {
    historyIndex--
    navigateTo(history[historyIndex], false)
  }
}

// Go forward
function goForward() {
  if (historyIndex < history.length - 1) {
    historyIndex++
    navigateTo(history[historyIndex], false)
  }
}

// Go up
function goUp() {
  const parent = currentPath.split('/').slice(0, -1).join('/') || '/'
  if (parent !== currentPath) {
    navigateTo(parent)
  }
}

// Open file/folder
async function openItem(item: FileEntry) {
  if (item.isDirectory) {
    navigateTo(item.path)
  } else {
    // Open with default application
    try {
      await (window as any).shell?.openPath(item.path)
    } catch {
      console.log('Open file:', item.path)
    }
  }
}

// Toggle selection
function toggleSelect(path: string, multi = false) {
  if (!multi) {
    selectedFiles.clear()
  }

  if (selectedFiles.has(path)) {
    selectedFiles.delete(path)
  } else {
    selectedFiles.add(path)
  }

  render()
}

// Select all
function selectAll() {
  selectedFiles = new Set(files.map(f => f.path))
  render()
}

// Get breadcrumb parts
function getBreadcrumbs(): { name: string; path: string }[] {
  const parts = currentPath.split('/').filter(Boolean)
  const crumbs = [{ name: Platform.OS === 'win32' ? 'C:' : '/', path: Platform.OS === 'win32' ? 'C:\\' : '/' }]

  let accumulated = ''
  for (const part of parts) {
    accumulated += '/' + part
    crumbs.push({ name: part, path: accumulated })
  }

  return crumbs
}

// Render
function render() {
  const app = document.getElementById('app')!
  const breadcrumbs = getBreadcrumbs()

  app.innerHTML = `
    <div class="toolbar">
      <button class="toolbar-btn" id="back-btn" ${historyIndex <= 0 ? 'disabled' : ''}>◀</button>
      <button class="toolbar-btn" id="forward-btn" ${historyIndex >= history.length - 1 ? 'disabled' : ''}>▶</button>
      <button class="toolbar-btn" id="up-btn">↑</button>

      <div class="toolbar-separator"></div>

      <div class="breadcrumb">
        ${breadcrumbs.map((crumb, i) => `
          <button class="breadcrumb-item ${i === breadcrumbs.length - 1 ? 'current' : ''}" data-path="${crumb.path}">
            ${crumb.name}
          </button>
          ${i < breadcrumbs.length - 1 ? '<span class="breadcrumb-separator">/</span>' : ''}
        `).join('')}
      </div>

      <div class="view-toggle">
        <button class="${viewMode === 'list' ? 'active' : ''}" id="list-view-btn">☰</button>
        <button class="${viewMode === 'grid' ? 'active' : ''}" id="grid-view-btn">⊞</button>
      </div>
    </div>

    <div class="main">
      <aside class="sidebar">
        <div class="sidebar-section">
          <div class="sidebar-title">Favorites</div>
          ${locations.map(loc => `
            <div class="sidebar-item ${currentPath === loc.path ? 'active' : ''}" data-path="${loc.path}">
              <span class="icon">${loc.icon}</span>
              <span>${loc.name}</span>
            </div>
          `).join('')}
        </div>
      </aside>

      <div class="file-list ${viewMode}-view">
        ${loading ? `
          <div class="loading">
            <div class="spinner"></div>
          </div>
        ` : files.length === 0 ? `
          <div class="empty-state">
            <div class="icon">📂</div>
            <div>This folder is empty</div>
          </div>
        ` : `
          <div class="file-header">
            <span>Name</span>
            <span>Size</span>
            <span>Kind</span>
            <span>Modified</span>
          </div>
          ${files.map(file => `
            <div
              class="file-item ${selectedFiles.has(file.path) ? 'selected' : ''}"
              data-path="${file.path}"
              data-is-directory="${file.isDirectory}"
            >
              <div class="file-name">
                <span class="file-icon">${getFileIcon(file.name, file.isDirectory)}</span>
                <span>${file.name}</span>
              </div>
              <span class="file-size">${file.isDirectory ? '—' : formatSize(file.size)}</span>
              <span class="file-kind">${getFileKind(file.name, file.isDirectory)}</span>
              <span class="file-date">${formatDate(file.modified)}</span>
            </div>
          `).join('')}
        `}
      </div>
    </div>

    <div class="status-bar">
      ${files.length} items${selectedFiles.size > 0 ? ` • ${selectedFiles.size} selected` : ''}
    </div>
  `

  // Event handlers
  document.getElementById('back-btn')?.addEventListener('click', goBack)
  document.getElementById('forward-btn')?.addEventListener('click', goForward)
  document.getElementById('up-btn')?.addEventListener('click', goUp)

  document.getElementById('list-view-btn')?.addEventListener('click', () => {
    viewMode = 'list'
    render()
  })

  document.getElementById('grid-view-btn')?.addEventListener('click', () => {
    viewMode = 'grid'
    render()
  })

  // Breadcrumb navigation
  document.querySelectorAll('.breadcrumb-item').forEach(item => {
    item.addEventListener('click', () => {
      const path = item.getAttribute('data-path')
      if (path) navigateTo(path)
    })
  })

  // Sidebar navigation
  document.querySelectorAll('.sidebar-item').forEach(item => {
    item.addEventListener('click', () => {
      const path = item.getAttribute('data-path')
      if (path) navigateTo(path)
    })
  })

  // File item handlers
  document.querySelectorAll('.file-item').forEach(item => {
    item.addEventListener('click', (e) => {
      const path = item.getAttribute('data-path')
      if (path) {
        toggleSelect(path, (e as MouseEvent).metaKey || (e as MouseEvent).ctrlKey)
      }
    })

    item.addEventListener('dblclick', () => {
      const path = item.getAttribute('data-path')
      const file = files.find(f => f.path === path)
      if (file) openItem(file)
    })
  })
}

// Keyboard shortcuts
function setupShortcuts() {
  document.addEventListener('keydown', (e) => {
    const isMod = Platform.OS === 'darwin' ? e.metaKey : e.ctrlKey

    // Cmd/Ctrl + A: Select all
    if (isMod && e.key === 'a') {
      e.preventDefault()
      selectAll()
    }

    // Cmd/Ctrl + Backspace: Go up
    if (isMod && e.key === 'Backspace') {
      e.preventDefault()
      goUp()
    }

    // Cmd/Ctrl + [: Back
    if (isMod && e.key === '[') {
      e.preventDefault()
      goBack()
    }

    // Cmd/Ctrl + ]: Forward
    if (isMod && e.key === ']') {
      e.preventDefault()
      goForward()
    }

    // Enter: Open selected
    if (e.key === 'Enter' && selectedFiles.size === 1) {
      e.preventDefault()
      const path = Array.from(selectedFiles)[0]
      const file = files.find(f => f.path === path)
      if (file) openItem(file)
    }

    // Escape: Deselect
    if (e.key === 'Escape') {
      selectedFiles.clear()
      render()
    }

    // Arrow keys for navigation
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault()
      const currentIndex = files.findIndex(f => selectedFiles.has(f.path))
      let newIndex = currentIndex

      if (e.key === 'ArrowDown') {
        newIndex = Math.min(currentIndex + 1, files.length - 1)
      } else {
        newIndex = Math.max(currentIndex - 1, 0)
      }

      if (newIndex >= 0 && newIndex < files.length) {
        selectedFiles.clear()
        selectedFiles.add(files[newIndex].path)
        render()
      }
    }
  })
}

// Initialize
async function init() {
  window.setTitle('Craft Files')
  setupShortcuts()
  await navigateTo(currentPath)
}

// Start app
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init)
} else {
  init()
}
