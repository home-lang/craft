/**
 * Social Template - {{appName}}
 * A cross-platform social app built with Craft
 */

import { db, window, Platform, haptics, share } from 'ts-craft'

// Types
interface Post {
  id: string
  userId: string
  userName: string
  content: string
  likes: number
  comments: number
  isLiked: boolean
  createdAt: string
}

interface User {
  id: string
  name: string
  username: string
  followers: number
  following: number
}

// State
let posts: Post[] = []
let currentUser: User | null = null
let currentView: 'feed' | 'create' | 'profile' | 'notifications' = 'feed'

// Initialize
async function init(): Promise<void> {
  await initDatabase()
  loadMockData()

  window.setTitle('{{appName}}')
  window.setSize(400, 800)

  render()
}

async function initDatabase(): Promise<void> {
  await db.execute(`
    CREATE TABLE IF NOT EXISTS posts (
      id TEXT PRIMARY KEY,
      content TEXT NOT NULL,
      createdAt TEXT NOT NULL
    )
  `)
}

function loadMockData(): void {
  currentUser = {
    id: 'user-1',
    name: 'You',
    username: 'you',
    followers: 100,
    following: 50,
  }

  posts = [
    { id: '1', userId: 'user-2', userName: 'John', content: 'Hello world! 👋', likes: 42, comments: 5, isLiked: false, createdAt: new Date(Date.now() - 3600000).toISOString() },
    { id: '2', userId: 'user-3', userName: 'Jane', content: 'Building something cool with Craft! 🚀', likes: 128, comments: 12, isLiked: true, createdAt: new Date(Date.now() - 7200000).toISOString() },
    { id: '3', userId: 'user-4', userName: 'Bob', content: 'Great day for coding ☀️', likes: 23, comments: 2, isLiked: false, createdAt: new Date(Date.now() - 86400000).toISOString() },
  ]
}

// Actions
function toggleLike(postId: string): void {
  const post = posts.find(p => p.id === postId)
  if (post) {
    post.isLiked = !post.isLiked
    post.likes += post.isLiked ? 1 : -1

    if (Platform.OS === 'ios' || Platform.OS === 'android') {
      haptics.impact('light')
    }

    render()
  }
}

async function sharePost(postId: string): Promise<void> {
  const post = posts.find(p => p.id === postId)
  if (post) {
    await share.share({
      text: post.content,
      url: `https://example.com/post/${postId}`,
    })
  }
}

async function createPost(content: string): Promise<void> {
  const post: Post = {
    id: Date.now().toString(),
    userId: currentUser!.id,
    userName: currentUser!.name,
    content,
    likes: 0,
    comments: 0,
    isLiked: false,
    createdAt: new Date().toISOString(),
  }

  posts.unshift(post)
  await db.execute('INSERT INTO posts (id, content, createdAt) VALUES (?, ?, ?)', [post.id, post.content, post.createdAt])

  if (Platform.OS === 'ios' || Platform.OS === 'android') {
    haptics.notification('success')
  }

  navigate('feed')
}

// Navigation
function navigate(view: typeof currentView): void {
  currentView = view
  render()
}

// Utilities
function formatTime(timestamp: string): string {
  const diff = Date.now() - new Date(timestamp).getTime()
  if (diff < 60000) return 'now'
  if (diff < 3600000) return `${Math.floor(diff / 60000)}m`
  if (diff < 86400000) return `${Math.floor(diff / 3600000)}h`
  return `${Math.floor(diff / 86400000)}d`
}

// Render
function render(): void {
  const app = document.getElementById('app')
  if (!app) return

  let content = ''
  switch (currentView) {
    case 'feed':
      content = renderFeed()
      break
    case 'create':
      content = renderCreate()
      break
    case 'profile':
      content = renderProfile()
      break
    case 'notifications':
      content = renderNotifications()
      break
  }

  app.innerHTML = `
    <div class="app">
      <header class="header">
        <h1>{{appName}}</h1>
      </header>
      <main>${content}</main>
      <nav class="bottom-nav">
        <button onclick="navigate('feed')" class="${currentView === 'feed' ? 'active' : ''}">🏠</button>
        <button onclick="navigate('create')" class="${currentView === 'create' ? 'active' : ''}">➕</button>
        <button onclick="navigate('notifications')" class="${currentView === 'notifications' ? 'active' : ''}">🔔</button>
        <button onclick="navigate('profile')" class="${currentView === 'profile' ? 'active' : ''}">👤</button>
      </nav>
    </div>
  `
}

function renderFeed(): string {
  return `
    <div class="feed">
      ${posts.map(post => `
        <article class="post">
          <header class="post-header">
            <div class="avatar">${post.userName.charAt(0)}</div>
            <div class="post-meta">
              <strong>${post.userName}</strong>
              <span class="time">${formatTime(post.createdAt)}</span>
            </div>
          </header>
          <p class="post-content">${post.content}</p>
          <footer class="post-actions">
            <button onclick="toggleLike('${post.id}')" class="${post.isLiked ? 'liked' : ''}">
              ${post.isLiked ? '❤️' : '🤍'} ${post.likes}
            </button>
            <button>💬 ${post.comments}</button>
            <button onclick="sharePost('${post.id}')">🔄</button>
          </footer>
        </article>
      `).join('')}
    </div>
  `
}

function renderCreate(): string {
  return `
    <div class="create-post">
      <div class="create-header">
        <div class="avatar">${currentUser?.name.charAt(0)}</div>
        <span>@${currentUser?.username}</span>
      </div>
      <textarea id="post-content" placeholder="What's on your mind?" rows="5"></textarea>
      <button onclick="submitPost()">Post</button>
    </div>
  `
}

function renderProfile(): string {
  return `
    <div class="profile">
      <div class="profile-header">
        <div class="avatar large">${currentUser?.name.charAt(0)}</div>
        <h2>${currentUser?.name}</h2>
        <p>@${currentUser?.username}</p>
        <div class="stats">
          <div class="stat"><strong>${currentUser?.followers}</strong><span>Followers</span></div>
          <div class="stat"><strong>${currentUser?.following}</strong><span>Following</span></div>
        </div>
      </div>
      <h3>Your Posts</h3>
      <div class="user-posts">
        ${posts.filter(p => p.userId === currentUser?.id).map(post => `
          <article class="post">
            <p>${post.content}</p>
            <span class="time">${formatTime(post.createdAt)}</span>
          </article>
        `).join('') || '<p class="empty">No posts yet</p>'}
      </div>
    </div>
  `
}

function renderNotifications(): string {
  return `
    <div class="notifications">
      <div class="notification">
        <span class="notif-icon">❤️</span>
        <p><strong>John</strong> liked your post</p>
        <span class="time">2h</span>
      </div>
      <div class="notification">
        <span class="notif-icon">👤</span>
        <p><strong>Jane</strong> started following you</p>
        <span class="time">5h</span>
      </div>
      <div class="notification">
        <span class="notif-icon">💬</span>
        <p><strong>Bob</strong> commented on your post</p>
        <span class="time">1d</span>
      </div>
    </div>
  `
}

function submitPost(): void {
  const textarea = document.getElementById('post-content') as HTMLTextAreaElement
  const content = textarea?.value.trim()
  if (content) {
    createPost(content)
  }
}

// Expose functions globally
(window as any).navigate = navigate
;(window as any).toggleLike = toggleLike
;(window as any).sharePost = sharePost
;(window as any).submitPost = submitPost

// Start app
init()
