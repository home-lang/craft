#!/usr/bin/env bun

import { createApp } from './packages/typescript/src/index.ts'

console.log('\n========================================')
console.log('LIQUID GLASS SIDEBAR TEST')
console.log('========================================\n')

const html = `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Liquid Glass Test</title>
  <style>
    body {
      margin: 0;
      padding: 40px;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .content {
      text-align: center;
      max-width: 600px;
    }
    h1 {
      font-size: 48px;
      margin-bottom: 20px;
      font-weight: 700;
    }
    p {
      font-size: 18px;
      line-height: 1.6;
      opacity: 0.9;
    }
  </style>
</head>
<body>
  <div class="content">
    <h1>Liquid Glass Sidebar</h1>
    <p>You should see a translucent Liquid Glass sidebar with native macOS styling</p>
  </div>

  <script>
    // Create native sidebar on load
    if (window.craft && window.craft.nativeUI) {
      const sidebar = window.craft.nativeUI.createSidebar({ id: 'main-sidebar' });

      sidebar.addSection({
        id: 'projects',
        header: 'PROJECTS',
        items: [
          { id: 'project-1', label: 'Website Redesign', icon: '📁' },
          { id: 'project-2', label: 'Mobile App', icon: '📱' },
          { id: 'project-3', label: 'API Service', icon: '⚙️' },
        ]
      });

      sidebar.addSection({
        id: 'tools',
        header: 'TOOLS',
        items: [
          { id: 'terminal', label: 'Terminal', icon: '💻' },
          { id: 'settings', label: 'Settings', icon: '🔧' },
        ]
      });

      console.log('Sidebar created successfully');
    } else {
      console.error('Native UI bridge not available');
    }
  </script>
</body>
</html>
`

createApp({
  html,
  window: {
    title: 'Liquid Glass Test',
    width: 900,
    height: 650,
    titlebarHidden: true,
  }
}).show()

console.log('\n========================================')
console.log('✓ Test window is open!')
console.log('✓ Look for translucent Liquid Glass sidebar')
console.log('✓ Sidebar should have native macOS Tahoe appearance')
console.log('✓ Window should have NO titlebar (hidden)')
console.log('========================================\n')

// Keep running for 20 seconds
await new Promise(resolve => setTimeout(resolve, 20000))

console.log('\n✓ Test complete - window should have shown Liquid Glass sidebar WITHOUT titlebar')
