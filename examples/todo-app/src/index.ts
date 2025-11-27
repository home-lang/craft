/**
 * Craft Todo App - Cross-Platform Example
 *
 * This example demonstrates:
 * - Using Craft's database API for persistent storage
 * - Cross-platform UI with Headwind CSS
 * - Native haptic feedback on mobile
 * - Keyboard shortcuts on desktop
 * - Dark mode support
 */

import {
  db,
  getPlatform,
  isMobile,
  isDesktop
} from 'ts-craft'
import { haptics } from 'ts-craft/api/mobile'

// ============================================================================
// Types
// ============================================================================

interface Todo {
  id: number
  text: string
  completed: boolean
  createdAt: number
  completedAt: number | null
}

interface AppState {
  todos: Todo[]
  filter: 'all' | 'active' | 'completed'
  editingId: number | null
}

// ============================================================================
// Database
// ============================================================================

const database = db.openDatabase('todos.db')

async function initDatabase(): Promise<void> {
  await database.execute(`
    CREATE TABLE IF NOT EXISTS todos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      text TEXT NOT NULL,
      completed INTEGER DEFAULT 0,
      created_at INTEGER NOT NULL,
      completed_at INTEGER
    )
  `)
}

async function loadTodos(): Promise<Todo[]> {
  const result = await database.query<{
    id: number
    text: string
    completed: number
    created_at: number
    completed_at: number | null
  }>('SELECT * FROM todos ORDER BY created_at DESC')

  return result.map(row => ({
    id: row.id,
    text: row.text,
    completed: row.completed === 1,
    createdAt: row.created_at,
    completedAt: row.completed_at
  }))
}

async function addTodo(text: string): Promise<Todo> {
  const now = Date.now()
  const result = await database.execute(
    'INSERT INTO todos (text, created_at) VALUES (?, ?)',
    [text, now]
  )

  if (isMobile()) {
    haptics.impact('light')
  }

  return {
    id: result.lastInsertRowId!,
    text,
    completed: false,
    createdAt: now,
    completedAt: null
  }
}

async function updateTodo(id: number, updates: Partial<Todo>): Promise<void> {
  const setClauses: string[] = []
  const values: (string | number | null)[] = []

  if (updates.text !== undefined) {
    setClauses.push('text = ?')
    values.push(updates.text)
  }

  if (updates.completed !== undefined) {
    setClauses.push('completed = ?')
    values.push(updates.completed ? 1 : 0)

    if (updates.completed) {
      setClauses.push('completed_at = ?')
      values.push(Date.now())

      if (isMobile()) {
        haptics.notification('success')
      }
    } else {
      setClauses.push('completed_at = NULL')
    }
  }

  values.push(id)

  await database.execute(
    `UPDATE todos SET ${setClauses.join(', ')} WHERE id = ?`,
    values
  )
}

async function deleteTodo(id: number): Promise<void> {
  await database.execute('DELETE FROM todos WHERE id = ?', [id])

  if (isMobile()) {
    haptics.impact('medium')
  }
}

async function clearCompleted(): Promise<void> {
  await database.execute('DELETE FROM todos WHERE completed = 1')
}

// ============================================================================
// State Management
// ============================================================================

const state: AppState = {
  todos: [],
  filter: 'all',
  editingId: null
}

function getFilteredTodos(): Todo[] {
  switch (state.filter) {
    case 'active':
      return state.todos.filter(t => !t.completed)
    case 'completed':
      return state.todos.filter(t => t.completed)
    default:
      return state.todos
  }
}

function getActiveCount(): number {
  return state.todos.filter(t => !t.completed).length
}

function getCompletedCount(): number {
  return state.todos.filter(t => t.completed).length
}

// ============================================================================
// Rendering
// ============================================================================

function render(): void {
  const app = document.getElementById('app')!
  const filteredTodos = getFilteredTodos()
  const activeCount = getActiveCount()
  const completedCount = getCompletedCount()

  app.innerHTML = `
    <div class="todo-app">
      <header class="header">
        <h1>Todos</h1>
        <p class="platform-badge">${getPlatform()}</p>
      </header>

      <div class="input-section">
        <input
          id="new-todo"
          class="new-todo"
          placeholder="What needs to be done?"
          autofocus
        />
      </div>

      ${state.todos.length > 0 ? `
        <section class="main">
          <div class="toggle-all-container">
            <input
              id="toggle-all"
              class="toggle-all"
              type="checkbox"
              ${activeCount === 0 ? 'checked' : ''}
            />
            <label for="toggle-all">Mark all as complete</label>
          </div>

          <ul class="todo-list">
            ${filteredTodos.map(todo => `
              <li class="todo-item ${todo.completed ? 'completed' : ''} ${state.editingId === todo.id ? 'editing' : ''}" data-id="${todo.id}">
                <div class="view">
                  <input
                    class="toggle"
                    type="checkbox"
                    ${todo.completed ? 'checked' : ''}
                  />
                  <label class="todo-text">${escapeHtml(todo.text)}</label>
                  <button class="destroy"></button>
                </div>
                <input class="edit" value="${escapeHtml(todo.text)}" />
              </li>
            `).join('')}
          </ul>
        </section>

        <footer class="footer">
          <span class="todo-count">
            <strong>${activeCount}</strong> ${activeCount === 1 ? 'item' : 'items'} left
          </span>

          <ul class="filters">
            <li>
              <a href="#/" class="${state.filter === 'all' ? 'selected' : ''}">All</a>
            </li>
            <li>
              <a href="#/active" class="${state.filter === 'active' ? 'selected' : ''}">Active</a>
            </li>
            <li>
              <a href="#/completed" class="${state.filter === 'completed' ? 'selected' : ''}">Completed</a>
            </li>
          </ul>

          ${completedCount > 0 ? `
            <button class="clear-completed">Clear completed</button>
          ` : ''}
        </footer>
      ` : ''}

      <footer class="info">
        <p>Double-click to edit a todo</p>
        ${isDesktop() ? '<p>Press <kbd>Cmd/Ctrl+N</kbd> for new todo</p>' : ''}
      </footer>
    </div>
  `

  attachEventListeners()
}

function escapeHtml(text: string): string {
  const div = document.createElement('div')
  div.textContent = text
  return div.innerHTML
}

// ============================================================================
// Event Handlers
// ============================================================================

function attachEventListeners(): void {
  // New todo input
  const newTodoInput = document.getElementById('new-todo') as HTMLInputElement
  newTodoInput?.addEventListener('keydown', async (e) => {
    if (e.key === 'Enter') {
      const text = newTodoInput.value.trim()
      if (text) {
        const todo = await addTodo(text)
        state.todos.unshift(todo)
        render()
      }
    }
  })

  // Toggle all
  const toggleAll = document.getElementById('toggle-all') as HTMLInputElement
  toggleAll?.addEventListener('change', async () => {
    const completed = toggleAll.checked
    await Promise.all(
      state.todos.map(async todo => {
        if (todo.completed !== completed) {
          await updateTodo(todo.id, { completed })
          todo.completed = completed
          todo.completedAt = completed ? Date.now() : null
        }
      })
    )
    render()
  })

  // Todo items
  document.querySelectorAll('.todo-item').forEach(item => {
    const id = parseInt(item.getAttribute('data-id')!, 10)
    const todo = state.todos.find(t => t.id === id)
    if (!todo) return

    // Toggle checkbox
    item.querySelector('.toggle')?.addEventListener('change', async () => {
      await updateTodo(id, { completed: !todo.completed })
      todo.completed = !todo.completed
      todo.completedAt = todo.completed ? Date.now() : null
      render()
    })

    // Double-click to edit
    item.querySelector('.todo-text')?.addEventListener('dblclick', () => {
      state.editingId = id
      render()
      const editInput = document.querySelector(`.todo-item[data-id="${id}"] .edit`) as HTMLInputElement
      editInput?.focus()
      editInput?.setSelectionRange(editInput.value.length, editInput.value.length)
    })

    // Edit input
    const editInput = item.querySelector('.edit') as HTMLInputElement
    editInput?.addEventListener('blur', async () => {
      if (state.editingId === id) {
        const text = editInput.value.trim()
        if (text && text !== todo.text) {
          await updateTodo(id, { text })
          todo.text = text
        }
        state.editingId = null
        render()
      }
    })

    editInput?.addEventListener('keydown', async (e) => {
      if (e.key === 'Enter') {
        editInput.blur()
      } else if (e.key === 'Escape') {
        state.editingId = null
        render()
      }
    })

    // Delete button
    item.querySelector('.destroy')?.addEventListener('click', async () => {
      await deleteTodo(id)
      state.todos = state.todos.filter(t => t.id !== id)
      render()
    })
  })

  // Filter links
  document.querySelectorAll('.filters a').forEach(link => {
    link.addEventListener('click', (e) => {
      e.preventDefault()
      const href = link.getAttribute('href')!
      if (href === '#/') {
        state.filter = 'all'
      } else if (href === '#/active') {
        state.filter = 'active'
      } else if (href === '#/completed') {
        state.filter = 'completed'
      }
      render()
    })
  })

  // Clear completed
  document.querySelector('.clear-completed')?.addEventListener('click', async () => {
    await clearCompleted()
    state.todos = state.todos.filter(t => !t.completed)
    render()
  })
}

// Keyboard shortcuts for desktop
if (isDesktop()) {
  document.addEventListener('keydown', (e) => {
    // Cmd/Ctrl + N for new todo
    if ((e.metaKey || e.ctrlKey) && e.key === 'n') {
      e.preventDefault()
      const input = document.getElementById('new-todo') as HTMLInputElement
      input?.focus()
    }
  })
}

// ============================================================================
// Initialize
// ============================================================================

async function init(): Promise<void> {
  await initDatabase()
  state.todos = await loadTodos()
  render()

  // Handle browser back/forward for filters
  window.addEventListener('hashchange', () => {
    const hash = window.location.hash
    if (hash === '#/active') {
      state.filter = 'active'
    } else if (hash === '#/completed') {
      state.filter = 'completed'
    } else {
      state.filter = 'all'
    }
    render()
  })

  // Set initial filter from URL
  const hash = window.location.hash
  if (hash === '#/active') {
    state.filter = 'active'
  } else if (hash === '#/completed') {
    state.filter = 'completed'
  }
}

init().catch(console.error)
