/**
 * {{APP_NAME}} - Dashboard Template
 */

import { getPlatform, isDesktop } from '@craft-native/craft'

interface NavItem {
  id: string
  label: string
  icon: string
}

interface StatCard {
  title: string
  value: string
  change: string
  positive: boolean
  icon: string
  color: string
}

interface TableRow {
  id: string
  name: string
  email: string
  status: 'active' | 'pending' | 'inactive'
  date: string
}

const navItems: NavItem[] = [
  { id: 'dashboard', label: 'Dashboard', icon: '<path d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"/>' },
  { id: 'analytics', label: 'Analytics', icon: '<path d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>' },
  { id: 'users', label: 'Users', icon: '<path d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"/>' },
  { id: 'settings', label: 'Settings', icon: '<path d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/><path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>' }
]

const stats: StatCard[] = [
  { title: 'Total Revenue', value: '$45,231', change: '+20.1%', positive: true, icon: '💰', color: '#10b981' },
  { title: 'Active Users', value: '2,350', change: '+15.3%', positive: true, icon: '👥', color: '#6366f1' },
  { title: 'Pending Orders', value: '12', change: '-4.5%', positive: false, icon: '📦', color: '#f59e0b' },
  { title: 'Conversion Rate', value: '3.2%', change: '+2.4%', positive: true, icon: '📈', color: '#ec4899' }
]

const recentUsers: TableRow[] = [
  { id: '1', name: 'John Doe', email: 'john@example.com', status: 'active', date: '2024-01-15' },
  { id: '2', name: 'Jane Smith', email: 'jane@example.com', status: 'pending', date: '2024-01-14' },
  { id: '3', name: 'Bob Johnson', email: 'bob@example.com', status: 'active', date: '2024-01-13' },
  { id: '4', name: 'Alice Brown', email: 'alice@example.com', status: 'inactive', date: '2024-01-12' },
  { id: '5', name: 'Charlie Wilson', email: 'charlie@example.com', status: 'active', date: '2024-01-11' }
]

let activeNav = 'dashboard'

function renderIcon(path: string): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">${path}</svg>`
}

function getStatusBadge(status: string): string {
  const classes: Record<string, string> = {
    active: 'badge badge-success',
    pending: 'badge badge-warning',
    inactive: 'badge badge-danger'
  }
  return `<span class="${classes[status] || 'badge'}">${status}</span>`
}

function init(): void {
  const app = document.getElementById('app')!

  app.innerHTML = `
    <div class="app-layout">
      <aside class="sidebar">
        <div class="sidebar-header">
          <h1>{{APP_NAME}}</h1>
        </div>
        <nav>
          ${navItems.map(item => `
            <button class="nav-item ${item.id === activeNav ? 'active' : ''}" data-nav="${item.id}">
              ${renderIcon(item.icon)}
              <span>${item.label}</span>
            </button>
          `).join('')}
        </nav>
      </aside>

      <main class="main-content">
        <div class="page-header">
          <h2>Dashboard</h2>
          <button class="btn btn-primary">
            <span>+ Add New</span>
          </button>
        </div>

        <div class="stats-grid">
          ${stats.map(stat => `
            <div class="stat-card">
              <div class="stat-card-header">
                <span class="stat-card-title">${stat.title}</span>
                <div class="stat-card-icon" style="background: ${stat.color}20; color: ${stat.color};">
                  ${stat.icon}
                </div>
              </div>
              <div class="stat-card-value">${stat.value}</div>
              <div class="stat-card-change ${stat.positive ? 'positive' : 'negative'}">
                ${stat.positive ? '↑' : '↓'} ${stat.change} from last month
              </div>
            </div>
          `).join('')}
        </div>

        <div class="card">
          <div class="card-header">
            <span class="card-title">Recent Users</span>
            <button class="btn btn-primary">View All</button>
          </div>
          <div class="card-body" style="padding: 0;">
            <table class="table">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Email</th>
                  <th>Status</th>
                  <th>Date</th>
                </tr>
              </thead>
              <tbody>
                ${recentUsers.map(user => `
                  <tr>
                    <td>${user.name}</td>
                    <td>${user.email}</td>
                    <td>${getStatusBadge(user.status)}</td>
                    <td>${user.date}</td>
                  </tr>
                `).join('')}
              </tbody>
            </table>
          </div>
        </div>
      </main>
    </div>
  `

  // Navigation click handlers
  document.querySelectorAll('.nav-item').forEach(item => {
    item.addEventListener('click', () => {
      const navId = item.getAttribute('data-nav')
      if (navId) {
        activeNav = navId
        document.querySelectorAll('.nav-item').forEach(i => {
          i.classList.toggle('active', i.getAttribute('data-nav') === navId)
        })
      }
    })
  })
}

// Start app
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init)
} else {
  init()
}
