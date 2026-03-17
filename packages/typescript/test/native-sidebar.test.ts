import { describe, expect, it } from 'bun:test'
import { CraftApp, createApp, type AppConfig } from '../src/index'

describe('Native Sidebar', () => {
  describe('createApp with native sidebar config', () => {
    it('should accept nativeSidebar option', () => {
      const app = createApp({
        url: 'http://localhost:3456/app',
        window: {
          nativeSidebar: true,
          sidebarWidth: 240,
        },
      })
      expect(app).toBeInstanceOf(CraftApp)
    })

    it('should accept sidebarConfig with sections', () => {
      const sidebarConfig = {
        sections: [
          {
            id: 'home',
            title: 'Home',
            items: [
              { id: 'dashboard', label: 'Dashboard', icon: 'house.fill', url: '/dashboard' },
            ],
          },
        ],
        minWidth: 200,
        maxWidth: 280,
      }

      const app = createApp({
        url: 'http://localhost:3456/app',
        window: {
          nativeSidebar: true,
          sidebarWidth: 240,
          sidebarConfig,
        },
      })
      expect(app).toBeInstanceOf(CraftApp)
    })

    it('should work without sidebarConfig', () => {
      const app = createApp({
        url: 'http://localhost:3456/app',
        window: {
          nativeSidebar: true,
        },
      })
      expect(app).toBeInstanceOf(CraftApp)
    })

    it('should default nativeSidebar to false', () => {
      const app = createApp({
        url: 'http://localhost:3456/app',
      })
      expect(app).toBeInstanceOf(CraftApp)
    })
  })

  describe('native sidebar with dashboard-like config', () => {
    it('should handle full dashboard configuration', () => {
      const config: AppConfig = {
        url: 'http://localhost:3456/app?native-sidebar=1',
        window: {
          title: 'Stacks Dashboard',
          width: 1400,
          height: 900,
          titlebarHidden: true,
          nativeSidebar: true,
          sidebarWidth: 240,
          sidebarConfig: {
            sections: [
              {
                id: 'home',
                title: 'Home',
                items: [
                  { id: 'home', label: 'Dashboard', icon: 'house.fill', url: '/pages/index' },
                ],
              },
              {
                id: 'data',
                title: 'Data',
                items: [
                  { id: 'data-dashboard', label: 'Dashboard', icon: 'gauge', url: '/pages/data/dashboard' },
                  { id: 'model-user', label: 'User', icon: 'person.fill', url: '/pages/data/user' },
                ],
              },
            ],
            minWidth: 200,
            maxWidth: 280,
          },
        },
      }

      const app = createApp(config)
      expect(app).toBeInstanceOf(CraftApp)
    })

    it('should handle URL with native-sidebar query param', () => {
      const app = createApp({
        url: 'http://localhost:3456/app?native-sidebar=1',
        window: {
          nativeSidebar: true,
        },
      })
      expect(app).toBeInstanceOf(CraftApp)
    })
  })

  describe('sidebar config validation', () => {
    it('should handle empty sections array', () => {
      const app = createApp({
        url: 'http://localhost:3456/app',
        window: {
          nativeSidebar: true,
          sidebarConfig: {
            sections: [],
          },
        },
      })
      expect(app).toBeInstanceOf(CraftApp)
    })

    it('should handle sections with multiple items', () => {
      const app = createApp({
        url: 'http://localhost:3456/app',
        window: {
          nativeSidebar: true,
          sidebarConfig: {
            sections: [
              {
                id: 'content',
                title: 'Content',
                items: [
                  { id: 'pages', label: 'Pages', icon: 'doc.fill', url: '/pages' },
                  { id: 'posts', label: 'Posts', icon: 'text.bubble.fill', url: '/posts' },
                  { id: 'tags', label: 'Tags', icon: 'tag', url: '/tags' },
                  { id: 'categories', label: 'Categories', icon: 'tag.fill', url: '/categories' },
                ],
              },
            ],
          },
        },
      })
      expect(app).toBeInstanceOf(CraftApp)
    })

    it('should handle custom sidebar widths', () => {
      const narrow = createApp({
        url: 'http://localhost:3456/app',
        window: { nativeSidebar: true, sidebarWidth: 150 },
      })
      const wide = createApp({
        url: 'http://localhost:3456/app',
        window: { nativeSidebar: true, sidebarWidth: 400 },
      })
      expect(narrow).toBeInstanceOf(CraftApp)
      expect(wide).toBeInstanceOf(CraftApp)
    })
  })

  describe('close with native sidebar', () => {
    it('should not throw when closing native sidebar app', () => {
      const app = createApp({
        url: 'http://localhost:3456/app',
        window: {
          nativeSidebar: true,
          sidebarWidth: 240,
          sidebarConfig: {
            sections: [
              {
                id: 'test',
                title: 'Test',
                items: [{ id: 'item', label: 'Item', icon: 'star', url: '/test' }],
              },
            ],
          },
        },
      })
      expect(() => app.close()).not.toThrow()
    })
  })
})
