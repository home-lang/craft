/**
 * Sidebar Showcase Example
 * Demonstrates all three sidebar styles: Tahoe, Arc, and OrbStack
 *
 * This example displays each style side-by-side for comparison
 * and includes interactive elements to test hover/select states.
 */

import { createApp } from '@stacksjs/ts-craft'

const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Sidebar Showcase</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }

    :root {
      --tahoe-bg: rgba(255, 255, 255, 0.7);
      --tahoe-selected: #007AFF;
      --arc-bg: linear-gradient(180deg, #2a2a2e 0%, #1a1a1e 100%);
      --arc-hover: linear-gradient(90deg, rgba(99, 102, 241, 0.15) 0%, rgba(168, 85, 247, 0.15) 100%);
      --arc-selected: linear-gradient(90deg, rgba(99, 102, 241, 0.25) 0%, rgba(168, 85, 247, 0.25) 100%);
      --orbstack-bg: #1a1a1a;
    }

    @media (prefers-color-scheme: dark) {
      :root {
        --tahoe-bg: rgba(30, 30, 30, 0.8);
      }
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      padding: 2rem;
    }

    .showcase {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 2rem;
      max-width: 1400px;
      margin: 0 auto;
    }

    .demo-card {
      background: rgba(0, 0, 0, 0.3);
      border-radius: 16px;
      overflow: hidden;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.4);
    }

    .demo-header {
      padding: 1rem 1.5rem;
      background: rgba(0, 0, 0, 0.2);
      border-bottom: 1px solid rgba(255, 255, 255, 0.1);
    }

    .demo-header h2 {
      color: white;
      font-size: 1rem;
      font-weight: 600;
      margin-bottom: 0.25rem;
    }

    .demo-header p {
      color: rgba(255, 255, 255, 0.6);
      font-size: 0.75rem;
    }

    .demo-content {
      height: 500px;
      overflow: hidden;
    }

    /* ==================== TAHOE STYLE ==================== */
    .tahoe-sidebar {
      width: 100%;
      height: 100%;
      display: flex;
      flex-direction: column;
      background: var(--tahoe-bg);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
    }

    @media (prefers-color-scheme: dark) {
      .tahoe-sidebar {
        background: rgba(30, 30, 30, 0.85);
      }
    }

    .tahoe-section {
      padding: 1rem 0.5rem;
    }

    .tahoe-section-header {
      padding: 0.25rem 0.75rem;
      font-size: 11px;
      font-weight: 600;
      color: rgba(0, 0, 0, 0.45);
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    @media (prefers-color-scheme: dark) {
      .tahoe-section-header {
        color: rgba(255, 255, 255, 0.45);
      }
    }

    .tahoe-item {
      display: flex;
      align-items: center;
      gap: 0.625rem;
      padding: 0.375rem 0.5rem;
      margin: 1px 0.25rem;
      border-radius: 6px;
      cursor: pointer;
      transition: all 0.15s ease;
      font-size: 13px;
      color: #1d1d1f;
    }

    @media (prefers-color-scheme: dark) {
      .tahoe-item {
        color: rgba(255, 255, 255, 0.9);
      }
    }

    .tahoe-item:hover {
      background: rgba(0, 0, 0, 0.05);
    }

    @media (prefers-color-scheme: dark) {
      .tahoe-item:hover {
        background: rgba(255, 255, 255, 0.08);
      }
    }

    .tahoe-item.selected {
      background: #007AFF;
      color: white;
      box-shadow: 0 1px 3px rgba(0, 122, 255, 0.3);
    }

    .tahoe-item .icon {
      font-size: 16px;
    }

    .tahoe-item .badge {
      margin-left: auto;
      background: rgba(0, 0, 0, 0.1);
      padding: 0.125rem 0.5rem;
      border-radius: 10px;
      font-size: 11px;
      font-weight: 500;
    }

    .tahoe-item.selected .badge {
      background: rgba(255, 255, 255, 0.2);
    }

    /* ==================== ARC STYLE ==================== */
    .arc-sidebar {
      width: 100%;
      height: 100%;
      display: flex;
      flex-direction: column;
      background: var(--arc-bg);
      padding: 0.75rem;
    }

    .arc-section {
      margin-bottom: 1rem;
    }

    .arc-section-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0.5rem;
      font-size: 11px;
      font-weight: 600;
      color: rgba(255, 255, 255, 0.4);
      text-transform: uppercase;
      letter-spacing: 0.5px;
      cursor: pointer;
    }

    .arc-section-header:hover {
      color: rgba(255, 255, 255, 0.6);
    }

    .arc-section-header .chevron {
      font-size: 10px;
      transition: transform 0.2s;
    }

    .arc-section.collapsed .chevron {
      transform: rotate(-90deg);
    }

    .arc-section.collapsed .arc-items {
      display: none;
    }

    .arc-item {
      display: flex;
      align-items: center;
      gap: 0.625rem;
      padding: 0.5rem 0.75rem;
      margin: 2px 0;
      border-radius: 8px;
      cursor: pointer;
      transition: all 0.2s ease;
      font-size: 13px;
      color: rgba(255, 255, 255, 0.8);
    }

    .arc-item:hover {
      background: var(--arc-hover);
    }

    .arc-item.selected {
      background: var(--arc-selected);
      color: white;
    }

    .arc-item .icon {
      width: 20px;
      height: 20px;
      border-radius: 4px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 12px;
    }

    .arc-item .close {
      margin-left: auto;
      opacity: 0;
      font-size: 14px;
      color: rgba(255, 255, 255, 0.4);
      transition: opacity 0.15s;
    }

    .arc-item:hover .close {
      opacity: 1;
    }

    .arc-item .close:hover {
      color: white;
    }

    .arc-new-tab {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 0.5rem;
      padding: 0.625rem;
      margin-top: 0.5rem;
      border-radius: 8px;
      border: 1px dashed rgba(255, 255, 255, 0.15);
      color: rgba(255, 255, 255, 0.4);
      font-size: 12px;
      cursor: pointer;
      transition: all 0.2s;
    }

    .arc-new-tab:hover {
      border-color: rgba(99, 102, 241, 0.4);
      color: rgba(255, 255, 255, 0.7);
      background: rgba(99, 102, 241, 0.1);
    }

    /* ==================== ORBSTACK STYLE ==================== */
    .orbstack-sidebar {
      width: 100%;
      height: 100%;
      display: flex;
      flex-direction: column;
      background: #1a1a1a;
      padding: 0.5rem;
    }

    .orbstack-section {
      margin-bottom: 0.75rem;
    }

    .orbstack-section-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0.5rem;
      font-size: 11px;
      font-weight: 500;
      color: rgba(255, 255, 255, 0.35);
      text-transform: uppercase;
      letter-spacing: 0.3px;
    }

    .orbstack-section-header .count {
      background: rgba(255, 255, 255, 0.08);
      padding: 0.125rem 0.375rem;
      border-radius: 4px;
      font-size: 10px;
    }

    .orbstack-item {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      padding: 0.375rem 0.5rem;
      margin: 1px 0;
      border-radius: 4px;
      cursor: pointer;
      transition: background 0.15s ease;
      font-size: 13px;
      color: rgba(255, 255, 255, 0.75);
    }

    .orbstack-item:hover {
      background: rgba(255, 255, 255, 0.06);
    }

    .orbstack-item.selected {
      background: rgba(255, 255, 255, 0.1);
      color: white;
    }

    .orbstack-item .status {
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: #22c55e;
    }

    .orbstack-item .status.stopped {
      background: #6b7280;
    }

    .orbstack-item .status.warning {
      background: #f59e0b;
    }

    .orbstack-item .meta {
      margin-left: auto;
      font-size: 11px;
      color: rgba(255, 255, 255, 0.35);
      font-family: 'SF Mono', 'Menlo', monospace;
    }

    /* Title section */
    h1 {
      text-align: center;
      color: white;
      font-size: 2rem;
      font-weight: 700;
      margin-bottom: 0.5rem;
    }

    .subtitle {
      text-align: center;
      color: rgba(255, 255, 255, 0.7);
      font-size: 1rem;
      margin-bottom: 2rem;
    }

    /* Responsive */
    @media (max-width: 1200px) {
      .showcase {
        grid-template-columns: 1fr;
        max-width: 400px;
      }

      .demo-content {
        height: 400px;
      }
    }
  </style>
</head>
<body>
  <h1>Sidebar Styles</h1>
  <p class="subtitle">Click items to see selection states</p>

  <div class="showcase">
    <!-- Tahoe Style -->
    <div class="demo-card">
      <div class="demo-header">
        <h2>Tahoe Style</h2>
        <p>macOS Finder / Apple Apps</p>
      </div>
      <div class="demo-content">
        <div class="tahoe-sidebar">
          <div class="tahoe-section">
            <div class="tahoe-section-header">Favorites</div>
            <div class="tahoe-item selected" data-style="tahoe">
              <span class="icon">🖥️</span>
              <span>Desktop</span>
            </div>
            <div class="tahoe-item" data-style="tahoe">
              <span class="icon">📄</span>
              <span>Documents</span>
              <span class="badge">12</span>
            </div>
            <div class="tahoe-item" data-style="tahoe">
              <span class="icon">⬇️</span>
              <span>Downloads</span>
              <span class="badge">3</span>
            </div>
            <div class="tahoe-item" data-style="tahoe">
              <span class="icon">🎵</span>
              <span>Music</span>
            </div>
            <div class="tahoe-item" data-style="tahoe">
              <span class="icon">🖼️</span>
              <span>Pictures</span>
            </div>
          </div>
          <div class="tahoe-section">
            <div class="tahoe-section-header">iCloud</div>
            <div class="tahoe-item" data-style="tahoe">
              <span class="icon">☁️</span>
              <span>iCloud Drive</span>
            </div>
            <div class="tahoe-item" data-style="tahoe">
              <span class="icon">📱</span>
              <span>Shared</span>
            </div>
          </div>
          <div class="tahoe-section">
            <div class="tahoe-section-header">Tags</div>
            <div class="tahoe-item" data-style="tahoe">
              <span class="icon" style="color: #ff3b30;">●</span>
              <span>Red</span>
            </div>
            <div class="tahoe-item" data-style="tahoe">
              <span class="icon" style="color: #007aff;">●</span>
              <span>Blue</span>
            </div>
            <div class="tahoe-item" data-style="tahoe">
              <span class="icon" style="color: #34c759;">●</span>
              <span>Green</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Arc Style -->
    <div class="demo-card">
      <div class="demo-header">
        <h2>Arc Style</h2>
        <p>Arc Browser / Vertical Tabs</p>
      </div>
      <div class="demo-content">
        <div class="arc-sidebar">
          <div class="arc-section">
            <div class="arc-section-header" onclick="this.parentElement.classList.toggle('collapsed')">
              <span>Pinned</span>
              <span class="chevron">▼</span>
            </div>
            <div class="arc-items">
              <div class="arc-item selected" data-style="arc">
                <span class="icon" style="background: #ea4335;">G</span>
                <span>Gmail</span>
                <span class="close">×</span>
              </div>
              <div class="arc-item" data-style="arc">
                <span class="icon" style="background: #1da1f2;">𝕏</span>
                <span>Twitter</span>
                <span class="close">×</span>
              </div>
              <div class="arc-item" data-style="arc">
                <span class="icon" style="background: #5865f2;">D</span>
                <span>Discord</span>
                <span class="close">×</span>
              </div>
            </div>
          </div>
          <div class="arc-section">
            <div class="arc-section-header" onclick="this.parentElement.classList.toggle('collapsed')">
              <span>Today</span>
              <span class="chevron">▼</span>
            </div>
            <div class="arc-items">
              <div class="arc-item" data-style="arc">
                <span class="icon" style="background: #333;">📝</span>
                <span>Notion - Project Notes</span>
                <span class="close">×</span>
              </div>
              <div class="arc-item" data-style="arc">
                <span class="icon" style="background: #0a66c2;">in</span>
                <span>LinkedIn</span>
                <span class="close">×</span>
              </div>
              <div class="arc-item" data-style="arc">
                <span class="icon" style="background: #ff4500;">r/</span>
                <span>Reddit - r/programming</span>
                <span class="close">×</span>
              </div>
              <div class="arc-item" data-style="arc">
                <span class="icon" style="background: #1db954;">🎵</span>
                <span>Spotify</span>
                <span class="close">×</span>
              </div>
            </div>
          </div>
          <div class="arc-new-tab">
            <span>+</span>
            <span>New Tab</span>
          </div>
        </div>
      </div>
    </div>

    <!-- OrbStack Style -->
    <div class="demo-card">
      <div class="demo-header">
        <h2>OrbStack Style</h2>
        <p>Minimal Dark / DevTools</p>
      </div>
      <div class="demo-content">
        <div class="orbstack-sidebar">
          <div class="orbstack-section">
            <div class="orbstack-section-header">
              <span>Machines</span>
              <span class="count">3</span>
            </div>
            <div class="orbstack-item selected" data-style="orbstack">
              <span class="status"></span>
              <span>ubuntu</span>
              <span class="meta">arm64</span>
            </div>
            <div class="orbstack-item" data-style="orbstack">
              <span class="status"></span>
              <span>debian</span>
              <span class="meta">arm64</span>
            </div>
            <div class="orbstack-item" data-style="orbstack">
              <span class="status stopped"></span>
              <span>fedora</span>
              <span class="meta">arm64</span>
            </div>
          </div>
          <div class="orbstack-section">
            <div class="orbstack-section-header">
              <span>Containers</span>
              <span class="count">5</span>
            </div>
            <div class="orbstack-item" data-style="orbstack">
              <span class="status"></span>
              <span>postgres-dev</span>
              <span class="meta">5432</span>
            </div>
            <div class="orbstack-item" data-style="orbstack">
              <span class="status"></span>
              <span>redis-cache</span>
              <span class="meta">6379</span>
            </div>
            <div class="orbstack-item" data-style="orbstack">
              <span class="status warning"></span>
              <span>nginx-proxy</span>
              <span class="meta">80</span>
            </div>
            <div class="orbstack-item" data-style="orbstack">
              <span class="status stopped"></span>
              <span>mongo-test</span>
              <span class="meta">27017</span>
            </div>
            <div class="orbstack-item" data-style="orbstack">
              <span class="status"></span>
              <span>api-server</span>
              <span class="meta">3000</span>
            </div>
          </div>
          <div class="orbstack-section">
            <div class="orbstack-section-header">
              <span>Kubernetes</span>
              <span class="count">1</span>
            </div>
            <div class="orbstack-item" data-style="orbstack">
              <span class="status"></span>
              <span>minikube</span>
              <span class="meta">k8s</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>

  <script>
    // Handle item selection for each style
    document.querySelectorAll('[data-style]').forEach(item => {
      item.addEventListener('click', (e) => {
        const style = item.dataset.style;
        const className = style === 'tahoe' ? 'tahoe-item' :
                         style === 'arc' ? 'arc-item' : 'orbstack-item';

        // Remove selected from siblings
        item.closest('.demo-content')
          .querySelectorAll('.' + className)
          .forEach(el => el.classList.remove('selected'));

        // Add selected to clicked item
        item.classList.add('selected');
      });
    });

    console.log('[Sidebar Showcase] Interactive demo loaded');
  </script>
</body>
</html>
`

const app = createApp({
  html,
  window: {
    title: 'Sidebar Showcase',
    width: 1400,
    height: 700,
    minWidth: 800,
    minHeight: 500,
    vibrancy: 'fullscreen-ui',
  },
})

await app.show()
