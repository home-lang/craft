/**
 * Craft Notes - A cross-platform notes application
 * Demonstrates: SQLite, keyboard shortcuts, dark mode, mobile support
 */

import { db, window, Platform, haptics } from '@stacksjs/ts-craft'

interface Note {
  id: number
  title: string
  content: string
  createdAt: string
  updatedAt: string
}

let database: Awaited<ReturnType<typeof db.open>>
let notes: Note[] = []
let activeNoteId: number | null = null
let searchQuery = ''
let sidebarOpen = false

// Initialize database
async function initDatabase() {
  database = await db.open('notes.db')

  await database.execute(`
    CREATE TABLE IF NOT EXISTS notes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL DEFAULT 'Untitled',
      content TEXT NOT NULL DEFAULT '',
      createdAt TEXT DEFAULT CURRENT_TIMESTAMP,
      updatedAt TEXT DEFAULT CURRENT_TIMESTAMP
    )
  `)
}

// Load notes from database
async function loadNotes() {
  const query = searchQuery
    ? `SELECT * FROM notes WHERE title LIKE ? OR content LIKE ? ORDER BY updatedAt DESC`
    : `SELECT * FROM notes ORDER BY updatedAt DESC`

  if (searchQuery) {
    const pattern = `%${searchQuery}%`
    notes = await database.query<Note>(query, [pattern, pattern])
  } else {
    notes = await database.query<Note>(query)
  }
}

// Create new note
async function createNote() {
  const result = await database.execute(
    `INSERT INTO notes (title, content) VALUES (?, ?)`,
    ['Untitled', '']
  )

  await loadNotes()
  activeNoteId = result.lastInsertId

  if (Platform.OS === 'ios' || Platform.OS === 'android') {
    await haptics.impact('light')
  }

  render()
  focusTitle()
}

// Save current note
async function saveNote() {
  if (activeNoteId === null) return

  const titleInput = document.getElementById('note-title') as HTMLInputElement
  const contentArea = document.getElementById('note-content') as HTMLTextAreaElement

  if (!titleInput || !contentArea) return

  await database.execute(
    `UPDATE notes SET title = ?, content = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?`,
    [titleInput.value || 'Untitled', contentArea.value, activeNoteId]
  )

  await loadNotes()
  renderNotesList()
}

// Delete note
async function deleteNote(id: number) {
  await database.execute(`DELETE FROM notes WHERE id = ?`, [id])

  if (activeNoteId === id) {
    activeNoteId = null
  }

  await loadNotes()

  if (Platform.OS === 'ios' || Platform.OS === 'android') {
    await haptics.notification('success')
  }

  render()
}

// Select note
async function selectNote(id: number) {
  // Save current note first
  await saveNote()

  activeNoteId = id

  if (Platform.OS === 'ios' || Platform.OS === 'android') {
    await haptics.selection()
    sidebarOpen = false
  }

  render()
}

// Search notes
async function search(query: string) {
  searchQuery = query
  await loadNotes()
  renderNotesList()
}

// Toggle sidebar (mobile)
function toggleSidebar() {
  sidebarOpen = !sidebarOpen
  render()
}

// Focus title input
function focusTitle() {
  setTimeout(() => {
    const titleInput = document.getElementById('note-title') as HTMLInputElement
    if (titleInput) {
      titleInput.focus()
      titleInput.select()
    }
  }, 50)
}

// Format date
function formatDate(dateStr: string): string {
  const date = new Date(dateStr)
  const now = new Date()
  const diff = now.getTime() - date.getTime()

  if (diff < 86400000) {
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  } else if (diff < 604800000) {
    return date.toLocaleDateString([], { weekday: 'short' })
  } else {
    return date.toLocaleDateString([], { month: 'short', day: 'numeric' })
  }
}

// Get note preview
function getPreview(content: string): string {
  return content.slice(0, 100).replace(/\n/g, ' ') || 'No content'
}

// Render notes list
function renderNotesList() {
  const list = document.getElementById('notes-list')
  if (!list) return

  if (notes.length === 0) {
    list.innerHTML = `
      <div class="empty-state" style="padding: 24px; text-align: center;">
        <p style="color: var(--text-secondary);">
          ${searchQuery ? 'No notes found' : 'No notes yet'}
        </p>
      </div>
    `
    return
  }

  list.innerHTML = notes.map(note => `
    <div
      class="note-item ${note.id === activeNoteId ? 'active' : ''}"
      data-id="${note.id}"
    >
      <div class="note-title">${note.title || 'Untitled'}</div>
      <div class="note-preview">${getPreview(note.content)}</div>
      <div class="note-date">${formatDate(note.updatedAt)}</div>
    </div>
  `).join('')

  // Add click handlers
  list.querySelectorAll('.note-item').forEach(item => {
    item.addEventListener('click', () => {
      const id = parseInt(item.getAttribute('data-id') || '0')
      selectNote(id)
    })
  })
}

// Main render
function render() {
  const app = document.getElementById('app')!
  const activeNote = notes.find(n => n.id === activeNoteId)

  const isMobile = window.innerWidth <= 768

  app.innerHTML = `
    <div class="sidebar-overlay ${sidebarOpen ? 'open' : ''}" id="sidebar-overlay"></div>

    <aside class="sidebar ${sidebarOpen ? 'open' : ''}">
      <div class="sidebar-header">
        <h1>Notes</h1>
        <button id="new-note-btn" title="New Note">+</button>
      </div>

      <div class="search-box">
        <input
          type="text"
          id="search-input"
          placeholder="Search notes..."
          value="${searchQuery}"
        >
      </div>

      <div class="notes-list" id="notes-list"></div>
    </aside>

    ${activeNote ? `
      <main class="editor">
        <div class="editor-header">
          ${isMobile ? `
            <button id="menu-btn" style="margin-right: 12px; font-size: 1.25rem;">☰</button>
          ` : ''}
          <input
            type="text"
            id="note-title"
            value="${activeNote.title}"
            placeholder="Note title"
          >
          <div class="editor-actions">
            <button id="delete-btn" class="delete" title="Delete Note">🗑</button>
          </div>
        </div>
        <div class="editor-content">
          <textarea
            id="note-content"
            placeholder="Start writing..."
          >${activeNote.content}</textarea>
        </div>
      </main>
    ` : `
      <main class="empty-state">
        ${isMobile ? `
          <button id="menu-btn" style="position: absolute; top: 16px; left: 16px; font-size: 1.5rem; background: none; border: none; color: var(--text-primary);">☰</button>
        ` : ''}
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
          <path d="M19 3H5a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2V5a2 2 0 00-2-2z"/>
          <path d="M7 7h10M7 12h10M7 17h6"/>
        </svg>
        <h2>Select a note</h2>
        <p>Or create a new one to get started</p>
      </main>
    `}
  `

  // Render notes list
  renderNotesList()

  // Event handlers
  document.getElementById('new-note-btn')?.addEventListener('click', createNote)

  document.getElementById('search-input')?.addEventListener('input', (e) => {
    search((e.target as HTMLInputElement).value)
  })

  document.getElementById('delete-btn')?.addEventListener('click', () => {
    if (activeNoteId && confirm('Delete this note?')) {
      deleteNote(activeNoteId)
    }
  })

  document.getElementById('note-title')?.addEventListener('blur', saveNote)
  document.getElementById('note-content')?.addEventListener('blur', saveNote)

  document.getElementById('sidebar-overlay')?.addEventListener('click', () => {
    sidebarOpen = false
    render()
  })

  document.getElementById('menu-btn')?.addEventListener('click', toggleSidebar)

  // Auto-save on input
  let saveTimeout: number
  document.getElementById('note-content')?.addEventListener('input', () => {
    clearTimeout(saveTimeout)
    saveTimeout = window.setTimeout(saveNote, 1000)
  })

  document.getElementById('note-title')?.addEventListener('input', () => {
    clearTimeout(saveTimeout)
    saveTimeout = window.setTimeout(saveNote, 1000)
  })
}

// Keyboard shortcuts
function setupShortcuts() {
  document.addEventListener('keydown', async (e) => {
    const isMod = Platform.OS === 'darwin' ? e.metaKey : e.ctrlKey

    // Cmd/Ctrl + N: New note
    if (isMod && e.key === 'n') {
      e.preventDefault()
      await createNote()
    }

    // Cmd/Ctrl + S: Save note
    if (isMod && e.key === 's') {
      e.preventDefault()
      await saveNote()
    }

    // Cmd/Ctrl + F: Focus search
    if (isMod && e.key === 'f') {
      e.preventDefault()
      document.getElementById('search-input')?.focus()
    }

    // Escape: Clear search or close sidebar
    if (e.key === 'Escape') {
      if (searchQuery) {
        searchQuery = ''
        await loadNotes()
        render()
      } else if (sidebarOpen) {
        sidebarOpen = false
        render()
      }
    }
  })
}

// Initialize app
async function init() {
  await initDatabase()
  await loadNotes()

  // Set window title
  window.setTitle('Craft Notes')

  setupShortcuts()
  render()

  // Handle window resize
  globalThis.addEventListener('resize', () => {
    render()
  })
}

// Start app
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init)
} else {
  init()
}
