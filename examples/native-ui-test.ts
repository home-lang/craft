#!/usr/bin/env bun
/**
 * Native UI Components Test
 *
 * Tests the native macOS Tahoe-style sidebar and file browser components
 * Run: bun examples/native-ui-test.ts
 */

import { createApp } from '../packages/typescript/src/index.ts'

const html = `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Native UI Test</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'SF Pro', sans-serif;
      background: #1e1e1e;
      color: #e5e5e7;
      padding: 20px;
    }

    h1 {
      margin-bottom: 20px;
      font-size: 24px;
    }

    .status {
      background: #2d2d2d;
      padding: 15px;
      border-radius: 8px;
      margin-bottom: 15px;
    }

    .status-item {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 8px 0;
    }

    .indicator {
      width: 12px;
      height: 12px;
      border-radius: 50%;
      background: #666;
    }

    .indicator.success {
      background: #00ff00;
    }

    .indicator.pending {
      background: #ffaa00;
    }

    button {
      background: #0a84ff;
      color: white;
      border: none;
      padding: 10px 20px;
      border-radius: 6px;
      cursor: pointer;
      font-size: 14px;
      margin-right: 10px;
    }

    button:hover {
      background: #0070e0;
    }

    .log {
      background: #1a1a1a;
      padding: 15px;
      border-radius: 8px;
      margin-top: 20px;
      font-family: 'SF Mono', Menlo, monospace;
      font-size: 12px;
      max-height: 300px;
      overflow-y: auto;
    }

    .log-entry {
      padding: 4px 0;
      border-bottom: 1px solid #2d2d2d;
    }
  </style>
</head>
<body>
  <h1>Native UI Components Test</h1>

  <div class="status">
    <div class="status-item">
      <div class="indicator pending" id="bridge-indicator"></div>
      <span id="bridge-status">Bridge: Initializing...</span>
    </div>
    <div class="status-item">
      <div class="indicator pending" id="sidebar-indicator"></div>
      <span id="sidebar-status">Sidebar: Not created</span>
    </div>
    <div class="status-item">
      <div class="indicator pending" id="browser-indicator"></div>
      <span id="browser-status">File Browser: Not created</span>
    </div>
  </div>

  <div>
    <button onclick="testSidebar()">Create Sidebar</button>
    <button onclick="testFileBrowser()">Create File Browser</button>
    <button onclick="testSplitView()">Create Split View</button>
  </div>

  <div class="log" id="log">
    <div class="log-entry">Waiting for tests...</div>
  </div>

  <script>
    function log(message) {
      const logDiv = document.getElementById('log');
      const entry = document.createElement('div');
      entry.className = 'log-entry';
      const timestamp = new Date().toLocaleTimeString();
      entry.textContent = \`[\${timestamp}] \${message}\`;
      logDiv.appendChild(entry);
      logDiv.scrollTop = logDiv.scrollHeight;
    }

    function updateStatus(type, status, success = false) {
      const indicator = document.getElementById(\`\${type}-indicator\`);
      const statusText = document.getElementById(\`\${type}-status\`);

      if (success) {
        indicator.classList.remove('pending');
        indicator.classList.add('success');
      }

      statusText.textContent = status;
    }

    // Check if bridge is available
    setTimeout(() => {
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.craft) {
        updateStatus('bridge', 'Bridge: Connected ✓', true);
        log('Craft bridge is available');
      } else {
        updateStatus('bridge', 'Bridge: Not available ✗');
        log('ERROR: Craft bridge not available');
      }
    }, 100);

    function testSidebar() {
      log('Testing sidebar creation...');

      try {
        window.webkit.messageHandlers.craft.postMessage({
          type: 'nativeUI',
          action: 'createSidebar',
          data: JSON.stringify({
            id: 'test-sidebar'
          })
        });

        updateStatus('sidebar', 'Sidebar: Created ✓', true);
        log('✓ Sidebar creation message sent');
      } catch (error) {
        log('ERROR: Failed to create sidebar - ' + error.message);
      }
    }

    function testFileBrowser() {
      log('Testing file browser creation...');

      try {
        window.webkit.messageHandlers.craft.postMessage({
          type: 'nativeUI',
          action: 'createFileBrowser',
          data: JSON.stringify({
            id: 'test-browser'
          })
        });

        updateStatus('browser', 'File Browser: Created ✓', true);
        log('✓ File browser creation message sent');
      } catch (error) {
        log('ERROR: Failed to create file browser - ' + error.message);
      }
    }

    function testSplitView() {
      log('Testing split view creation...');

      try {
        window.webkit.messageHandlers.craft.postMessage({
          type: 'nativeUI',
          action: 'createSplitView',
          data: JSON.stringify({
            id: 'test-splitview',
            sidebarId: 'test-sidebar',
            browserId: 'test-browser'
          })
        });

        log('✓ Split view creation message sent');
      } catch (error) {
        log('ERROR: Failed to create split view - ' + error.message);
      }
    }

    log('Page loaded successfully');
  </script>
</body>
</html>`

createApp({
  html,
  window: {
    title: 'Native UI Test',
    width: 800,
    height: 600,
    resizable: true,
    darkMode: true
  }
}).show()

console.log('✅ Native UI Test window ready')
console.log('📝 Click the buttons to test native UI components')
