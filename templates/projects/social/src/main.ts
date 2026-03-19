/**
 * Social Template - {{appName}}
 * A cross-platform social app built with Craft
 */

import { state, derived, effect, mount, h } from '@craft-native/stx'
import { Card, Button, Avatar, Input } from '@craft-native/stx/components'
import { usePlatform, useHaptics } from '@craft-native/stx/composables'

import { db, share } from '@craft-native/craft'

// Composables
const { isMobile } = usePlatform()
const { impact, notification } = useHaptics()

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
const posts = state<Post[]>([
  { id: '1', userId: 'user-2', userName: 'John', content: 'Hello world! 👋', likes: 42, comments: 5, isLiked: false, createdAt: new Date(Date.now() - 3600000).toISOString() },
  { id: '2', userId: 'user-3', userName: 'Jane', content: 'Building something cool with Craft! 🚀', likes: 128, comments: 12, isLiked: true, createdAt: new Date(Date.now() - 7200000).toISOString() },
  { id: '3', userId: 'user-4', userName: 'Bob', content: 'Great day for coding ☀️', likes: 23, comments: 2, isLiked: false, createdAt: new Date(Date.now() - 86400000).toISOString() },
])

const currentUser = state<User>({
  id: 'user-1',
  name: 'You',
  username: 'you',
  followers: 100,
  following: 50,
})

const currentView = state<'feed' | 'create' | 'profile' | 'notifications'>('feed')

// Derived
const userPosts = derived(() => posts().filter(p => p.userId === currentUser().id))

// Utilities
function formatTime(timestamp: string): string {
  const diff = Date.now() - new Date(timestamp).getTime()
  if (diff < 60000) return 'now'
  if (diff < 3600000) return `${Math.floor(diff / 60000)}m`
  if (diff < 86400000) return `${Math.floor(diff / 3600000)}h`
  return `${Math.floor(diff / 86400000)}d`
}

// Actions
function toggleLike(postId: string): void {
  const updated = posts().map(p => {
    if (p.id === postId) {
      const isLiked = !p.isLiked
      return { ...p, isLiked, likes: p.likes + (isLiked ? 1 : -1) }
    }
    return p
  })
  posts.set(updated)
  if (isMobile()) impact('light')
}

async function sharePost(postId: string): Promise<void> {
  const post = posts().find(p => p.id === postId)
  if (post) {
    await share.share({
      text: post.content,
      url: `https://example.com/post/${postId}`,
    })
  }
}

async function createPost(content: string): Promise<void> {
  const user = currentUser()
  const post: Post = {
    id: Date.now().toString(),
    userId: user.id,
    userName: user.name,
    content,
    likes: 0,
    comments: 0,
    isLiked: false,
    createdAt: new Date().toISOString(),
  }

  posts.set([post, ...posts()])
  await db.execute('INSERT INTO posts (id, content, createdAt) VALUES (?, ?, ?)', [post.id, post.content, post.createdAt])

  if (isMobile()) notification('success')
  currentView.set('feed')
}

// Initialize database
async function initDatabase(): Promise<void> {
  await db.execute(`
    CREATE TABLE IF NOT EXISTS posts (
      id TEXT PRIMARY KEY,
      content TEXT NOT NULL,
      createdAt TEXT NOT NULL
    )
  `)
}

initDatabase()

// Components
function renderPostCard(post: Post) {
  return h('article', { class: 'post' },
    h('header', { class: 'post-header' },
      Avatar({ class: 'avatar' }, post.userName.charAt(0)),
      h('div', { class: 'post-meta' },
        h('strong', {}, post.userName),
        h('span', { class: 'time' }, formatTime(post.createdAt)),
      ),
    ),
    h('p', { class: 'post-content' }, post.content),
    h('footer', { class: 'post-actions' },
      Button({
        class: post.isLiked ? 'liked' : '',
        onClick: () => toggleLike(post.id),
      }, `${post.isLiked ? '❤️' : '🤍'} ${post.likes}`),
      Button({}, `💬 ${post.comments}`),
      Button({
        onClick: () => sharePost(post.id),
      }, '🔄'),
    ),
  )
}

function renderFeed() {
  return h('div', { class: 'feed' },
    ...posts().map(post => renderPostCard(post)),
  )
}

function renderCreate() {
  const user = currentUser()
  const postContent = state('')

  return h('div', { class: 'create-post' },
    h('div', { class: 'create-header' },
      Avatar({ class: 'avatar' }, user.name.charAt(0)),
      h('span', {}, `@${user.username}`),
    ),
    Input({
      tag: 'textarea',
      placeholder: "What's on your mind?",
      rows: '5',
      onInput: (e: Event) => {
        postContent.set((e.target as HTMLTextAreaElement).value)
      },
    }),
    Button({
      onClick: () => {
        const content = postContent().trim()
        if (content) createPost(content)
      },
    }, 'Post'),
  )
}

function renderProfile() {
  const user = currentUser()
  const myPosts = userPosts()

  return h('div', { class: 'profile' },
    h('div', { class: 'profile-header' },
      Avatar({ class: 'avatar large' }, user.name.charAt(0)),
      h('h2', {}, user.name),
      h('p', {}, `@${user.username}`),
      h('div', { class: 'stats' },
        h('div', { class: 'stat' },
          h('strong', {}, String(user.followers)),
          h('span', {}, 'Followers'),
        ),
        h('div', { class: 'stat' },
          h('strong', {}, String(user.following)),
          h('span', {}, 'Following'),
        ),
      ),
    ),
    h('h3', {}, 'Your Posts'),
    h('div', { class: 'user-posts' },
      ...(myPosts.length > 0
        ? myPosts.map(post =>
            h('article', { class: 'post' },
              h('p', {}, post.content),
              h('span', { class: 'time' }, formatTime(post.createdAt)),
            ),
          )
        : [h('p', { class: 'empty' }, 'No posts yet')]),
    ),
  )
}

function renderNotifications() {
  return h('div', { class: 'notifications' },
    h('div', { class: 'notification' },
      h('span', { class: 'notif-icon' }, '❤️'),
      h('p', {}, h('strong', {}, 'John'), ' liked your post'),
      h('span', { class: 'time' }, '2h'),
    ),
    h('div', { class: 'notification' },
      h('span', { class: 'notif-icon' }, '👤'),
      h('p', {}, h('strong', {}, 'Jane'), ' started following you'),
      h('span', { class: 'time' }, '5h'),
    ),
    h('div', { class: 'notification' },
      h('span', { class: 'notif-icon' }, '💬'),
      h('p', {}, h('strong', {}, 'Bob'), ' commented on your post'),
      h('span', { class: 'time' }, '1d'),
    ),
  )
}

function App() {
  const header = h('header', { class: 'header' },
    h('h1', {}, '{{appName}}'),
  )

  const contentArea = h('main', {})
  effect(() => {
    contentArea.innerHTML = ''
    switch (currentView()) {
      case 'feed': contentArea.appendChild(renderFeed()); break
      case 'create': contentArea.appendChild(renderCreate()); break
      case 'profile': contentArea.appendChild(renderProfile()); break
      case 'notifications': contentArea.appendChild(renderNotifications()); break
    }
  })

  const navBar = h('nav', { class: 'bottom-nav' })

  const navItems: { id: typeof currentView extends () => infer T ? T : never; icon: string }[] = [
    { id: 'feed', icon: '🏠' },
    { id: 'create', icon: '➕' },
    { id: 'notifications', icon: '🔔' },
    { id: 'profile', icon: '👤' },
  ]

  for (const item of navItems) {
    const btn = Button({
      onClick: () => {
        currentView.set(item.id)
        if (isMobile()) impact('light')
      },
    }, item.icon)

    effect(() => {
      btn.className = currentView() === item.id ? 'active' : ''
    })

    navBar.appendChild(btn)
  }

  return h('div', { class: 'app' },
    header,
    contentArea,
    navBar,
  )
}

mount(App, '#app')
