/**
 * Social App - Cross-platform social media client built with Craft
 * Features: Feed, posts, stories, profile, notifications, messaging, search
 */

import { db, window, Platform, haptics, camera, share } from 'ts-craft'

// Types
interface User {
  id: string
  username: string
  displayName: string
  avatar?: string
  bio?: string
  followers: number
  following: number
  posts: number
  isVerified: boolean
  isFollowing: boolean
}

interface Post {
  id: string
  userId: string
  content: string
  images: string[]
  likes: number
  comments: number
  shares: number
  isLiked: boolean
  isBookmarked: boolean
  createdAt: string
}

interface Story {
  id: string
  userId: string
  image: string
  viewed: boolean
  createdAt: string
  expiresAt: string
}

interface Comment {
  id: string
  postId: string
  userId: string
  content: string
  likes: number
  isLiked: boolean
  createdAt: string
  replies: Comment[]
}

interface Notification {
  id: string
  type: 'like' | 'comment' | 'follow' | 'mention' | 'repost'
  userId: string
  postId?: string
  content: string
  read: boolean
  createdAt: string
}

// Social Store
class SocialStore {
  private currentUser: User | null = null
  private users: Map<string, User> = new Map()
  private posts: Map<string, Post> = new Map()
  private feed: string[] = []
  private stories: Story[] = []
  private notifications: Notification[] = []
  private currentView: 'feed' | 'search' | 'create' | 'notifications' | 'profile' | 'post' | 'user' = 'feed'
  private selectedPostId: string | null = null
  private selectedUserId: string | null = null
  private searchQuery = ''
  private listeners: Set<() => void> = new Set()

  // Current user
  setCurrentUser(user: User): void {
    this.currentUser = user
    this.users.set(user.id, user)
    this.notify()
  }

  getCurrentUser(): User | null {
    return this.currentUser
  }

  // Users
  setUser(user: User): void {
    this.users.set(user.id, user)
    this.notify()
  }

  getUser(id: string): User | undefined {
    return this.users.get(id)
  }

  toggleFollow(userId: string): void {
    const user = this.users.get(userId)
    if (user && user.id !== this.currentUser?.id) {
      user.isFollowing = !user.isFollowing
      user.followers += user.isFollowing ? 1 : -1
      this.users.set(userId, user)
      this.notify()

      if (Platform.OS === 'ios' || Platform.OS === 'android') {
        haptics.impact('light')
      }
    }
  }

  // Posts
  addPost(post: Post): void {
    this.posts.set(post.id, post)
    this.notify()
  }

  getPost(id: string): Post | undefined {
    return this.posts.get(id)
  }

  setFeed(postIds: string[]): void {
    this.feed = postIds
    this.notify()
  }

  getFeed(): Post[] {
    return this.feed.map((id) => this.posts.get(id)).filter((p): p is Post => p !== undefined)
  }

  getUserPosts(userId: string): Post[] {
    return Array.from(this.posts.values())
      .filter((p) => p.userId === userId)
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
  }

  toggleLike(postId: string): void {
    const post = this.posts.get(postId)
    if (post) {
      post.isLiked = !post.isLiked
      post.likes += post.isLiked ? 1 : -1
      this.posts.set(postId, post)
      this.notify()

      if (Platform.OS === 'ios' || Platform.OS === 'android') {
        haptics.impact('light')
      }
    }
  }

  toggleBookmark(postId: string): void {
    const post = this.posts.get(postId)
    if (post) {
      post.isBookmarked = !post.isBookmarked
      this.posts.set(postId, post)
      this.notify()

      if (Platform.OS === 'ios' || Platform.OS === 'android') {
        haptics.notification('success')
      }
    }
  }

  async createPost(content: string, images: string[] = []): Promise<Post> {
    const post: Post = {
      id: generateId(),
      userId: this.currentUser!.id,
      content,
      images,
      likes: 0,
      comments: 0,
      shares: 0,
      isLiked: false,
      isBookmarked: false,
      createdAt: new Date().toISOString(),
    }

    this.posts.set(post.id, post)
    this.feed.unshift(post.id)

    // Update user post count
    if (this.currentUser) {
      this.currentUser.posts++
    }

    await this.savePost(post)
    this.notify()

    if (Platform.OS === 'ios' || Platform.OS === 'android') {
      haptics.notification('success')
    }

    return post
  }

  private async savePost(post: Post): Promise<void> {
    await db.execute(
      'INSERT INTO posts (id, userId, content, images, createdAt) VALUES (?, ?, ?, ?, ?)',
      [post.id, post.userId, post.content, JSON.stringify(post.images), post.createdAt]
    )
  }

  // Stories
  setStories(stories: Story[]): void {
    this.stories = stories
    this.notify()
  }

  getStories(): Story[] {
    return this.stories.filter((s) => new Date(s.expiresAt) > new Date())
  }

  markStoryViewed(storyId: string): void {
    const story = this.stories.find((s) => s.id === storyId)
    if (story) {
      story.viewed = true
      this.notify()
    }
  }

  // Notifications
  setNotifications(notifications: Notification[]): void {
    this.notifications = notifications
    this.notify()
  }

  getNotifications(): Notification[] {
    return this.notifications
  }

  getUnreadCount(): number {
    return this.notifications.filter((n) => !n.read).length
  }

  markAllRead(): void {
    this.notifications.forEach((n) => (n.read = true))
    this.notify()
  }

  // Search
  searchUsers(query: string): User[] {
    const q = query.toLowerCase()
    return Array.from(this.users.values()).filter(
      (u) =>
        u.username.toLowerCase().includes(q) ||
        u.displayName.toLowerCase().includes(q)
    )
  }

  searchPosts(query: string): Post[] {
    const q = query.toLowerCase()
    return Array.from(this.posts.values())
      .filter((p) => p.content.toLowerCase().includes(q))
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
  }

  setSearchQuery(query: string): void {
    this.searchQuery = query
    this.notify()
  }

  getSearchQuery(): string {
    return this.searchQuery
  }

  // Navigation
  setView(view: typeof this.currentView, id?: string): void {
    this.currentView = view
    if (view === 'post') this.selectedPostId = id || null
    if (view === 'user') this.selectedUserId = id || null
    this.notify()
  }

  getView(): typeof this.currentView {
    return this.currentView
  }

  getSelectedPostId(): string | null {
    return this.selectedPostId
  }

  getSelectedUserId(): string | null {
    return this.selectedUserId
  }

  // Subscriptions
  subscribe(listener: () => void): () => void {
    this.listeners.add(listener)
    return () => this.listeners.delete(listener)
  }

  private notify(): void {
    this.listeners.forEach((l) => l())
  }
}

// Initialize database
async function initDatabase(): Promise<void> {
  await db.execute(`
    CREATE TABLE IF NOT EXISTS posts (
      id TEXT PRIMARY KEY,
      userId TEXT NOT NULL,
      content TEXT NOT NULL,
      images TEXT DEFAULT '[]',
      createdAt TEXT NOT NULL
    )
  `)

  await db.execute(`CREATE INDEX IF NOT EXISTS idx_posts_user ON posts(userId)`)
}

// Mock data
function getMockData(): { users: User[]; posts: Post[]; stories: Story[]; notifications: Notification[] } {
  const users: User[] = [
    {
      id: 'user-1',
      username: 'johndoe',
      displayName: 'John Doe',
      bio: 'Software developer | Coffee enthusiast | Building cool stuff',
      followers: 1234,
      following: 567,
      posts: 89,
      isVerified: true,
      isFollowing: false,
    },
    {
      id: 'user-2',
      username: 'janedoe',
      displayName: 'Jane Doe',
      bio: 'Designer | Photographer | Nature lover',
      followers: 5678,
      following: 432,
      posts: 234,
      isVerified: false,
      isFollowing: true,
    },
    {
      id: 'user-3',
      username: 'techguru',
      displayName: 'Tech Guru',
      bio: 'Tech news and reviews | Gadget enthusiast',
      followers: 45000,
      following: 123,
      posts: 1500,
      isVerified: true,
      isFollowing: true,
    },
    {
      id: 'user-4',
      username: 'artlover',
      displayName: 'Art Lover',
      bio: 'Sharing beautiful art from around the world',
      followers: 8900,
      following: 567,
      posts: 456,
      isVerified: false,
      isFollowing: false,
    },
  ]

  const posts: Post[] = [
    {
      id: 'post-1',
      userId: 'user-2',
      content: 'Just finished this amazing sunset photo shoot! What do you think? 📸✨ #photography #sunset #nature',
      images: ['sunset.jpg'],
      likes: 234,
      comments: 45,
      shares: 12,
      isLiked: false,
      isBookmarked: false,
      createdAt: new Date(Date.now() - 3600000).toISOString(),
    },
    {
      id: 'post-2',
      userId: 'user-3',
      content: 'Breaking: New smartphone just announced with revolutionary camera technology. Here are my first impressions... 📱',
      images: [],
      likes: 1567,
      comments: 234,
      shares: 456,
      isLiked: true,
      isBookmarked: true,
      createdAt: new Date(Date.now() - 7200000).toISOString(),
    },
    {
      id: 'post-3',
      userId: 'user-4',
      content: 'This painting by a local artist completely blew my mind. The detail is incredible! 🎨',
      images: ['art.jpg'],
      likes: 567,
      comments: 89,
      shares: 34,
      isLiked: false,
      isBookmarked: false,
      createdAt: new Date(Date.now() - 10800000).toISOString(),
    },
    {
      id: 'post-4',
      userId: 'user-2',
      content: 'Morning coffee and coding session. Perfect way to start the day! ☕💻',
      images: [],
      likes: 123,
      comments: 23,
      shares: 5,
      isLiked: true,
      isBookmarked: false,
      createdAt: new Date(Date.now() - 86400000).toISOString(),
    },
  ]

  const stories: Story[] = [
    {
      id: 'story-1',
      userId: 'user-2',
      image: 'story1.jpg',
      viewed: false,
      createdAt: new Date(Date.now() - 3600000).toISOString(),
      expiresAt: new Date(Date.now() + 82800000).toISOString(),
    },
    {
      id: 'story-2',
      userId: 'user-3',
      image: 'story2.jpg',
      viewed: true,
      createdAt: new Date(Date.now() - 7200000).toISOString(),
      expiresAt: new Date(Date.now() + 79200000).toISOString(),
    },
    {
      id: 'story-3',
      userId: 'user-4',
      image: 'story3.jpg',
      viewed: false,
      createdAt: new Date(Date.now() - 10800000).toISOString(),
      expiresAt: new Date(Date.now() + 75600000).toISOString(),
    },
  ]

  const notifications: Notification[] = [
    {
      id: 'notif-1',
      type: 'like',
      userId: 'user-2',
      postId: 'post-2',
      content: 'liked your post',
      read: false,
      createdAt: new Date(Date.now() - 1800000).toISOString(),
    },
    {
      id: 'notif-2',
      type: 'follow',
      userId: 'user-4',
      content: 'started following you',
      read: false,
      createdAt: new Date(Date.now() - 3600000).toISOString(),
    },
    {
      id: 'notif-3',
      type: 'comment',
      userId: 'user-3',
      postId: 'post-1',
      content: 'commented on your post',
      read: true,
      createdAt: new Date(Date.now() - 7200000).toISOString(),
    },
    {
      id: 'notif-4',
      type: 'mention',
      userId: 'user-2',
      postId: 'post-3',
      content: 'mentioned you in a post',
      read: true,
      createdAt: new Date(Date.now() - 86400000).toISOString(),
    },
  ]

  return { users, posts, stories, notifications }
}

// Utility functions
function generateId(): string {
  return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
}

function formatTimestamp(timestamp: string): string {
  const date = new Date(timestamp)
  const now = new Date()
  const diff = now.getTime() - date.getTime()

  if (diff < 60000) return 'just now'
  if (diff < 3600000) return `${Math.floor(diff / 60000)}m`
  if (diff < 86400000) return `${Math.floor(diff / 3600000)}h`
  if (diff < 604800000) return `${Math.floor(diff / 86400000)}d`
  return date.toLocaleDateString([], { month: 'short', day: 'numeric' })
}

function formatNumber(num: number): string {
  if (num >= 1000000) return `${(num / 1000000).toFixed(1)}M`
  if (num >= 1000) return `${(num / 1000).toFixed(1)}K`
  return num.toString()
}

// UI Rendering
function renderApp(store: SocialStore): void {
  const app = document.getElementById('app')
  if (!app) return

  const view = store.getView()

  let content = ''
  switch (view) {
    case 'feed':
      content = renderFeed(store)
      break
    case 'search':
      content = renderSearch(store)
      break
    case 'create':
      content = renderCreate(store)
      break
    case 'notifications':
      content = renderNotifications(store)
      break
    case 'profile':
      content = renderProfile(store, store.getCurrentUser()!)
      break
    case 'post':
      content = renderPostDetail(store)
      break
    case 'user':
      content = renderProfile(store, store.getUser(store.getSelectedUserId()!)!)
      break
  }

  app.innerHTML = `
    <div class="social-app">
      ${renderHeader(store)}
      <main class="main-content">${content}</main>
      ${renderBottomNav(store)}
    </div>
  `

  setupEventListeners(store)
}

function renderHeader(store: SocialStore): string {
  const view = store.getView()
  const titles: Record<string, string> = {
    feed: 'Feed',
    search: 'Search',
    create: 'Create Post',
    notifications: 'Notifications',
    profile: 'Profile',
    post: 'Post',
    user: 'Profile',
  }

  return `
    <header class="header">
      ${view !== 'feed' ? `<button class="back-btn" data-nav="feed">←</button>` : ''}
      <h1 class="title">${titles[view]}</h1>
      ${view === 'feed' ? `<button class="icon-btn" id="messages-btn">✉</button>` : ''}
    </header>
  `
}

function renderBottomNav(store: SocialStore): string {
  const view = store.getView()
  const unreadCount = store.getUnreadCount()

  return `
    <nav class="bottom-nav">
      <button class="nav-item ${view === 'feed' ? 'active' : ''}" data-nav="feed">
        <span class="nav-icon">🏠</span>
      </button>
      <button class="nav-item ${view === 'search' ? 'active' : ''}" data-nav="search">
        <span class="nav-icon">🔍</span>
      </button>
      <button class="nav-item ${view === 'create' ? 'active' : ''}" data-nav="create">
        <span class="nav-icon create-icon">+</span>
      </button>
      <button class="nav-item ${view === 'notifications' ? 'active' : ''}" data-nav="notifications">
        <span class="nav-icon">🔔</span>
        ${unreadCount > 0 ? `<span class="badge">${unreadCount}</span>` : ''}
      </button>
      <button class="nav-item ${view === 'profile' ? 'active' : ''}" data-nav="profile">
        <span class="nav-icon">👤</span>
      </button>
    </nav>
  `
}

function renderFeed(store: SocialStore): string {
  const stories = store.getStories()
  const posts = store.getFeed()

  return `
    <div class="feed-view">
      ${stories.length > 0 ? `
        <div class="stories-container">
          <div class="story add-story">
            <div class="story-avatar add">+</div>
            <span class="story-name">Add Story</span>
          </div>
          ${stories.map((story) => {
            const user = store.getUser(story.userId)
            return `
              <div class="story ${story.viewed ? 'viewed' : ''}" data-story-id="${story.id}">
                <div class="story-avatar">${user?.displayName.charAt(0) || '?'}</div>
                <span class="story-name">${user?.username || 'Unknown'}</span>
              </div>
            `
          }).join('')}
        </div>
      ` : ''}

      <div class="posts-feed">
        ${posts.map((post) => renderPost(post, store)).join('')}
      </div>
    </div>
  `
}

function renderPost(post: Post, store: SocialStore): string {
  const user = store.getUser(post.userId)

  return `
    <article class="post" data-post-id="${post.id}">
      <header class="post-header">
        <div class="post-user" data-user-id="${post.userId}">
          <div class="avatar">${user?.displayName.charAt(0) || '?'}</div>
          <div class="user-info">
            <span class="display-name">
              ${user?.displayName || 'Unknown'}
              ${user?.isVerified ? '<span class="verified">✓</span>' : ''}
            </span>
            <span class="username">@${user?.username || 'unknown'}</span>
          </div>
        </div>
        <span class="post-time">${formatTimestamp(post.createdAt)}</span>
      </header>

      <div class="post-content" data-view-post="${post.id}">
        <p>${formatContent(post.content)}</p>
        ${post.images.length > 0 ? `
          <div class="post-images ${post.images.length > 1 ? 'grid' : ''}">
            ${post.images.map(() => `<div class="post-image"></div>`).join('')}
          </div>
        ` : ''}
      </div>

      <footer class="post-actions">
        <button class="action-btn ${post.isLiked ? 'liked' : ''}" data-like="${post.id}">
          <span>${post.isLiked ? '❤️' : '🤍'}</span>
          <span>${formatNumber(post.likes)}</span>
        </button>
        <button class="action-btn" data-comment="${post.id}">
          <span>💬</span>
          <span>${formatNumber(post.comments)}</span>
        </button>
        <button class="action-btn" data-share="${post.id}">
          <span>🔄</span>
          <span>${formatNumber(post.shares)}</span>
        </button>
        <button class="action-btn ${post.isBookmarked ? 'bookmarked' : ''}" data-bookmark="${post.id}">
          <span>${post.isBookmarked ? '🔖' : '📑'}</span>
        </button>
      </footer>
    </article>
  `
}

function formatContent(content: string): string {
  // Format hashtags and mentions
  return content
    .replace(/#(\w+)/g, '<span class="hashtag">#$1</span>')
    .replace(/@(\w+)/g, '<span class="mention">@$1</span>')
}

function renderSearch(store: SocialStore): string {
  const query = store.getSearchQuery()
  const users = query ? store.searchUsers(query) : []
  const posts = query ? store.searchPosts(query) : []

  return `
    <div class="search-view">
      <div class="search-bar">
        <input type="search" id="search-input" placeholder="Search users and posts..."
               value="${query}" class="search-input" autofocus />
      </div>

      ${query ? `
        ${users.length > 0 ? `
          <section class="search-section">
            <h2>People</h2>
            <div class="user-list">
              ${users.slice(0, 5).map((user) => renderUserCard(user, store)).join('')}
            </div>
          </section>
        ` : ''}

        ${posts.length > 0 ? `
          <section class="search-section">
            <h2>Posts</h2>
            ${posts.slice(0, 10).map((post) => renderPost(post, store)).join('')}
          </section>
        ` : ''}

        ${users.length === 0 && posts.length === 0 ? `
          <div class="empty-state">
            <p>No results for "${query}"</p>
          </div>
        ` : ''}
      ` : `
        <div class="search-suggestions">
          <h2>Trending</h2>
          <div class="trending-tags">
            <span class="trending-tag" data-search="#technology">#technology</span>
            <span class="trending-tag" data-search="#photography">#photography</span>
            <span class="trending-tag" data-search="#design">#design</span>
            <span class="trending-tag" data-search="#art">#art</span>
          </div>
        </div>
      `}
    </div>
  `
}

function renderUserCard(user: User, store: SocialStore): string {
  const isCurrentUser = user.id === store.getCurrentUser()?.id

  return `
    <div class="user-card" data-user-id="${user.id}">
      <div class="avatar large">${user.displayName.charAt(0)}</div>
      <div class="user-details">
        <span class="display-name">
          ${user.displayName}
          ${user.isVerified ? '<span class="verified">✓</span>' : ''}
        </span>
        <span class="username">@${user.username}</span>
        <span class="follower-count">${formatNumber(user.followers)} followers</span>
      </div>
      ${!isCurrentUser ? `
        <button class="follow-btn ${user.isFollowing ? 'following' : ''}" data-follow="${user.id}">
          ${user.isFollowing ? 'Following' : 'Follow'}
        </button>
      ` : ''}
    </div>
  `
}

function renderCreate(store: SocialStore): string {
  return `
    <div class="create-view">
      <form id="create-post-form" class="create-form">
        <div class="create-header">
          <div class="avatar">${store.getCurrentUser()?.displayName.charAt(0)}</div>
          <span class="username">@${store.getCurrentUser()?.username}</span>
        </div>

        <textarea id="post-content" placeholder="What's on your mind?" class="post-textarea" rows="6"></textarea>

        <div class="create-actions">
          <div class="media-actions">
            <button type="button" class="media-btn" id="add-image">📷 Photo</button>
            <button type="button" class="media-btn" id="add-gif">🎬 GIF</button>
            <button type="button" class="media-btn" id="add-poll">📊 Poll</button>
          </div>
          <button type="submit" class="post-btn" id="submit-post" disabled>Post</button>
        </div>
      </form>
    </div>
  `
}

function renderNotifications(store: SocialStore): string {
  const notifications = store.getNotifications()

  if (notifications.length === 0) {
    return `
      <div class="empty-state">
        <div class="empty-icon">🔔</div>
        <h2>No notifications yet</h2>
        <p>When you get notifications, they'll show up here</p>
      </div>
    `
  }

  return `
    <div class="notifications-view">
      <button class="mark-read-btn" id="mark-all-read">Mark all as read</button>
      <div class="notifications-list">
        ${notifications.map((notif) => {
          const user = store.getUser(notif.userId)
          const icons: Record<string, string> = {
            like: '❤️',
            comment: '💬',
            follow: '👤',
            mention: '@',
            repost: '🔄',
          }

          return `
            <div class="notification ${notif.read ? '' : 'unread'}" data-notif-post="${notif.postId || ''}">
              <div class="notif-icon">${icons[notif.type]}</div>
              <div class="avatar">${user?.displayName.charAt(0) || '?'}</div>
              <div class="notif-content">
                <span class="notif-user">${user?.displayName || 'Unknown'}</span>
                <span class="notif-text">${notif.content}</span>
                <span class="notif-time">${formatTimestamp(notif.createdAt)}</span>
              </div>
            </div>
          `
        }).join('')}
      </div>
    </div>
  `
}

function renderProfile(store: SocialStore, user: User): string {
  const isCurrentUser = user.id === store.getCurrentUser()?.id
  const posts = store.getUserPosts(user.id)

  return `
    <div class="profile-view">
      <div class="profile-header">
        <div class="avatar xlarge">${user.displayName.charAt(0)}</div>
        <h1 class="display-name">
          ${user.displayName}
          ${user.isVerified ? '<span class="verified">✓</span>' : ''}
        </h1>
        <p class="username">@${user.username}</p>
        ${user.bio ? `<p class="bio">${user.bio}</p>` : ''}

        <div class="profile-stats">
          <div class="stat">
            <span class="stat-value">${formatNumber(user.posts)}</span>
            <span class="stat-label">Posts</span>
          </div>
          <div class="stat">
            <span class="stat-value">${formatNumber(user.followers)}</span>
            <span class="stat-label">Followers</span>
          </div>
          <div class="stat">
            <span class="stat-value">${formatNumber(user.following)}</span>
            <span class="stat-label">Following</span>
          </div>
        </div>

        ${isCurrentUser ? `
          <button class="edit-profile-btn">Edit Profile</button>
        ` : `
          <button class="follow-btn large ${user.isFollowing ? 'following' : ''}" data-follow="${user.id}">
            ${user.isFollowing ? 'Following' : 'Follow'}
          </button>
        `}
      </div>

      <div class="profile-tabs">
        <button class="tab active">Posts</button>
        <button class="tab">Media</button>
        <button class="tab">Likes</button>
      </div>

      <div class="profile-posts">
        ${posts.length > 0 ? posts.map((post) => renderPost(post, store)).join('') : `
          <div class="empty-state">
            <p>No posts yet</p>
          </div>
        `}
      </div>
    </div>
  `
}

function renderPostDetail(store: SocialStore): string {
  const postId = store.getSelectedPostId()
  if (!postId) return '<div>Post not found</div>'

  const post = store.getPost(postId)
  if (!post) return '<div>Post not found</div>'

  return `
    <div class="post-detail-view">
      ${renderPost(post, store)}

      <div class="comments-section">
        <h3>Comments</h3>
        <form class="comment-form" id="comment-form">
          <input type="text" placeholder="Add a comment..." class="comment-input" />
          <button type="submit" class="comment-submit">Post</button>
        </form>

        <div class="comments-list">
          <div class="empty-state">
            <p>No comments yet. Be the first to comment!</p>
          </div>
        </div>
      </div>
    </div>
  `
}

function setupEventListeners(store: SocialStore): void {
  // Navigation
  document.querySelectorAll('[data-nav]').forEach((el) => {
    el.addEventListener('click', () => {
      const view = el.getAttribute('data-nav') as any
      store.setView(view)
      renderApp(store)
    })
  })

  // User profiles
  document.querySelectorAll('[data-user-id]').forEach((el) => {
    el.addEventListener('click', (e) => {
      if ((e.target as HTMLElement).closest('[data-follow]')) return
      const userId = el.getAttribute('data-user-id')
      if (userId) {
        store.setView('user', userId)
        renderApp(store)
      }
    })
  })

  // View post
  document.querySelectorAll('[data-view-post]').forEach((el) => {
    el.addEventListener('click', () => {
      const postId = el.getAttribute('data-view-post')
      if (postId) {
        store.setView('post', postId)
        renderApp(store)
      }
    })
  })

  // Like
  document.querySelectorAll('[data-like]').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation()
      const postId = btn.getAttribute('data-like')
      if (postId) {
        store.toggleLike(postId)
        renderApp(store)
      }
    })
  })

  // Bookmark
  document.querySelectorAll('[data-bookmark]').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation()
      const postId = btn.getAttribute('data-bookmark')
      if (postId) {
        store.toggleBookmark(postId)
        renderApp(store)
      }
    })
  })

  // Share
  document.querySelectorAll('[data-share]').forEach((btn) => {
    btn.addEventListener('click', async (e) => {
      e.stopPropagation()
      const postId = btn.getAttribute('data-share')
      if (postId) {
        const post = store.getPost(postId)
        if (post) {
          await share.share({
            text: post.content,
            url: `https://example.com/post/${postId}`,
          })
        }
      }
    })
  })

  // Follow
  document.querySelectorAll('[data-follow]').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation()
      const userId = btn.getAttribute('data-follow')
      if (userId) {
        store.toggleFollow(userId)
        renderApp(store)
      }
    })
  })

  // Search
  document.getElementById('search-input')?.addEventListener('input', (e) => {
    const query = (e.target as HTMLInputElement).value
    store.setSearchQuery(query)
    renderApp(store)
  })

  document.querySelectorAll('[data-search]').forEach((el) => {
    el.addEventListener('click', () => {
      const query = el.getAttribute('data-search')
      if (query) {
        store.setSearchQuery(query)
        renderApp(store)
      }
    })
  })

  // Create post
  const postContent = document.getElementById('post-content') as HTMLTextAreaElement
  const submitBtn = document.getElementById('submit-post') as HTMLButtonElement

  postContent?.addEventListener('input', () => {
    submitBtn.disabled = postContent.value.trim().length === 0
  })

  document.getElementById('create-post-form')?.addEventListener('submit', async (e) => {
    e.preventDefault()
    const content = postContent?.value.trim()
    if (content) {
      await store.createPost(content)
      store.setView('feed')
      renderApp(store)
    }
  })

  document.getElementById('add-image')?.addEventListener('click', async () => {
    try {
      const result = await camera.pickImage()
      console.log('Image selected:', result)
    } catch (err) {
      console.error('Failed to pick image:', err)
    }
  })

  // Mark all notifications read
  document.getElementById('mark-all-read')?.addEventListener('click', () => {
    store.markAllRead()
    renderApp(store)
  })

  // Story click
  document.querySelectorAll('[data-story-id]').forEach((el) => {
    el.addEventListener('click', () => {
      const storyId = el.getAttribute('data-story-id')
      if (storyId) {
        store.markStoryViewed(storyId)
        // Would open story viewer modal
        renderApp(store)
      }
    })
  })
}

// Main app initialization
async function main(): Promise<void> {
  await initDatabase()

  window.setTitle('Social')
  window.setSize(400, 800)
  window.setMinSize(320, 568)

  const store = new SocialStore()

  // Load mock data
  const { users, posts, stories, notifications } = getMockData()

  // Set current user
  store.setCurrentUser({
    id: 'current-user',
    username: 'you',
    displayName: 'You',
    bio: 'This is your profile!',
    followers: 100,
    following: 50,
    posts: 10,
    isVerified: false,
    isFollowing: false,
  })

  // Load users
  users.forEach((user) => store.setUser(user))

  // Load posts
  posts.forEach((post) => store.addPost(post))
  store.setFeed(posts.map((p) => p.id))

  // Load stories
  store.setStories(stories)

  // Load notifications
  store.setNotifications(notifications)

  // Subscribe to store updates
  store.subscribe(() => renderApp(store))

  // Initial render
  renderApp(store)

  // Expose for debugging
  ;(globalThis as any).socialStore = store
}

main().catch(console.error)
