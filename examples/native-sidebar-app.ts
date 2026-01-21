#!/usr/bin/env bun
/**
 * Native macOS Sidebar Example - Full API Demo
 *
 * Demonstrates Craft's configurable native macOS sidebar using:
 * - User-defined sections and items
 * - SF Symbols icons
 * - Selection event handling
 * - Badges and tint colors
 *
 * Run: bun examples/native-sidebar-app.ts
 */

import { createApp } from '../packages/typescript/src/index.ts'
import type { SidebarConfig } from '../packages/typescript/src/types.ts'

// Define sidebar configuration
const sidebarConfig: SidebarConfig = {
  sections: [
    {
      id: 'favorites',
      title: 'Favorites',
      items: [
        { id: 'inbox', label: 'Inbox', icon: 'tray.fill', badge: '12' },
        { id: 'today', label: 'Today', icon: 'calendar' },
        { id: 'starred', label: 'Starred', icon: 'star.fill' },
      ]
    },
    {
      id: 'folders',
      title: 'Folders',
      items: [
        { id: 'documents', label: 'Documents', icon: 'folder.fill' },
        { id: 'projects', label: 'Projects', icon: 'folder.badge.gearshape' },
        { id: 'archive', label: 'Archive', icon: 'archivebox.fill' },
      ]
    },
    {
      id: 'tags',
      title: 'Tags',
      items: [
        { id: 'tag-red', label: 'Important', icon: 'circle.fill', tintColor: '#ef4444' },
        { id: 'tag-blue', label: 'Work', icon: 'circle.fill', tintColor: '#3b82f6' },
        { id: 'tag-green', label: 'Personal', icon: 'circle.fill', tintColor: '#22c55e' },
        { id: 'tag-purple', label: 'Ideas', icon: 'circle.fill', tintColor: '#a855f7' },
      ]
    }
  ],
  minWidth: 180,
  maxWidth: 320,
  canCollapse: true,
}

// Content HTML with selection handling
const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Sidebar Demo</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }

    :root {
      --font: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      --bg: #ffffff;
      --bg-dark: #1e1e1e;
      --text: #1a1a1a;
      --text-dark: #f0f0f0;
      --text-muted: #666;
      --text-muted-dark: #999;
      --accent: #0066cc;
      --border: rgba(0,0,0,0.1);
      --border-dark: rgba(255,255,255,0.1);
    }

    @media (prefers-color-scheme: dark) {
      :root {
        --bg: var(--bg-dark);
        --text: var(--text-dark);
        --text-muted: var(--text-muted-dark);
        --border: var(--border-dark);
      }
    }

    body {
      font-family: var(--font);
      background: var(--bg);
      color: var(--text);
      height: 100vh;
      overflow: hidden;
    }

    .container {
      display: flex;
      flex-direction: column;
      height: 100%;
    }

    .header {
      padding: 20px 24px;
      border-bottom: 1px solid var(--border);
    }

    .header h1 {
      font-size: 24px;
      font-weight: 600;
      margin-bottom: 4px;
    }

    .header p {
      font-size: 14px;
      color: var(--text-muted);
    }

    .content {
      flex: 1;
      padding: 24px;
      overflow-y: auto;
    }

    .selection-display {
      padding: 20px;
      background: rgba(0, 102, 204, 0.08);
      border-radius: 12px;
      margin-bottom: 24px;
      border-left: 4px solid var(--accent);
    }

    @media (prefers-color-scheme: dark) {
      .selection-display {
        background: rgba(0, 102, 204, 0.15);
      }
    }

    .selection-display h3 {
      font-size: 14px;
      font-weight: 600;
      margin-bottom: 8px;
      color: var(--accent);
    }

    .selection-display .item-info {
      font-size: 16px;
      font-weight: 500;
    }

    .selection-display .section-info {
      font-size: 13px;
      color: var(--text-muted);
      margin-top: 4px;
    }

    .api-section {
      margin-top: 24px;
    }

    .api-section h2 {
      font-size: 18px;
      font-weight: 600;
      margin-bottom: 12px;
    }

    pre {
      background: rgba(0, 0, 0, 0.04);
      padding: 16px;
      border-radius: 10px;
      overflow-x: auto;
      font-size: 13px;
      line-height: 1.5;
      font-family: 'SF Mono', Menlo, Monaco, monospace;
    }

    @media (prefers-color-scheme: dark) {
      pre {
        background: rgba(255, 255, 255, 0.06);
      }
    }

    .feature-list {
      list-style: none;
      margin-top: 16px;
    }

    .feature-list li {
      padding: 12px 16px;
      background: rgba(0, 0, 0, 0.03);
      border-radius: 8px;
      margin-bottom: 8px;
      font-size: 14px;
    }

    @media (prefers-color-scheme: dark) {
      .feature-list li {
        background: rgba(255, 255, 255, 0.05);
      }
    }

    .feature-list li strong {
      color: var(--accent);
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1 id="title">Inbox</h1>
      <p id="subtitle">Select an item from the sidebar</p>
    </div>
    <div class="content">
      <div class="selection-display">
        <h3>Current Selection</h3>
        <div class="item-info" id="selected-item">No item selected</div>
        <div class="section-info" id="selected-section"></div>
      </div>

      <div class="api-section">
        <h2>Sidebar Configuration API</h2>
        <pre>const sidebarConfig: SidebarConfig = {
  sections: [
    {
      id: 'favorites',
      title: 'Favorites',
      items: [
        { id: 'inbox', label: 'Inbox', icon: 'tray.fill', badge: '12' },
        { id: 'today', label: 'Today', icon: 'calendar' },
      ]
    },
    {
      id: 'tags',
      title: 'Tags',
      items: [
        { id: 'tag-red', label: 'Important', icon: 'circle.fill', tintColor: '#ef4444' },
      ]
    }
  ]
}

createApp({
  html,
  window: {
    nativeSidebar: true,
    sidebarConfig
  }
}).show()</pre>
      </div>

      <div class="api-section">
        <h2>Features</h2>
        <ul class="feature-list">
          <li><strong>User-defined sections</strong> - Configure sidebar structure from TypeScript</li>
          <li><strong>SF Symbols icons</strong> - Use any SF Symbol name for icons</li>
          <li><strong>Badges</strong> - Show counts or labels on items</li>
          <li><strong>Tint colors</strong> - Custom colors for tags and indicators</li>
          <li><strong>Selection events</strong> - Handle selection changes in JavaScript</li>
          <li><strong>Native vibrancy</strong> - Real macOS blur effect</li>
        </ul>
      </div>
    </div>
  </div>

  <script>
    // Register sidebar selection handler
    window.craft = window.craft || {};
    window.craft._sidebarSelectHandler = function(event) {
      console.log('Sidebar selection:', event);

      // Update UI
      document.getElementById('title').textContent = event.item.label;
      document.getElementById('subtitle').textContent = 'Section: ' + event.sectionId;
      document.getElementById('selected-item').textContent = event.item.label + ' (' + event.itemId + ')';
      document.getElementById('selected-section').textContent = 'From section: ' + event.sectionId;
    };

    console.log('Sidebar demo loaded');
    console.log('Click items in the sidebar to see selection events');
  </script>
</body>
</html>`

createApp({
  html,
  window: {
    title: 'Native Sidebar Demo',
    width: 950,
    height: 700,
    nativeSidebar: true,
    sidebarWidth: 220,
    sidebarConfig,
  }
}).show()

console.log('')
console.log('Native macOS Sidebar - Full API Demo')
console.log('====================================')
console.log('')
console.log('Sidebar Configuration:')
console.log('  - 3 sections: Favorites, Folders, Tags')
console.log('  - Badges on Inbox item')
console.log('  - Tint colors on Tag items')
console.log('')
console.log('Selection events will be logged when you click sidebar items.')
console.log('')
