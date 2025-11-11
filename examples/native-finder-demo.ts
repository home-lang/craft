#!/usr/bin/env bun
/**
 * Native Finder Demo
 *
 * Demonstrates the complete native UI implementation with:
 * - Native sidebar with sections and items
 * - Native file browser with multiple files
 * - Split view combining both
 *
 * Run: bun examples/native-finder-demo.ts
 */

import { createApp } from '../packages/typescript/src/index.ts'

const html = `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Native Finder Demo</title>
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

    .info {
      background: #2d2d2d;
      padding: 15px;
      border-radius: 8px;
      margin-bottom: 20px;
    }

    .status {
      padding: 8px 0;
      color: #00ff00;
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
      margin-bottom: 10px;
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
      max-height: 400px;
      overflow-y: auto;
    }

    .log-entry {
      padding: 4px 0;
      border-bottom: 1px solid #2d2d2d;
    }

    .log-entry.success {
      color: #00ff00;
    }

    .log-entry.info {
      color: #0a84ff;
    }
  </style>
</head>
<body>
  <h1>Native Finder Demo</h1>

  <div class="info">
    <div class="status" id="status">⏳ Waiting for native UI API...</div>
  </div>

  <div>
    <button onclick="createCompleteFinderUI()">Create Complete Finder UI</button>
    <button onclick="createSidebarOnly()">Create Sidebar Only</button>
    <button onclick="createBrowserOnly()">Create File Browser Only</button>
  </div>

  <div class="log" id="log">
    <div class="log-entry info">Waiting for tests...</div>
  </div>

  <script>
    let sidebar = null;
    let browser = null;
    let splitView = null;

    function log(message, type = 'info') {
      const logDiv = document.getElementById('log');
      const entry = document.createElement('div');
      entry.className = \`log-entry \${type}\`;
      const timestamp = new Date().toLocaleTimeString();
      entry.textContent = \`[\${timestamp}] \${message}\`;
      logDiv.appendChild(entry);
      logDiv.scrollTop = logDiv.scrollHeight;
    }

    function updateStatus(message) {
      document.getElementById('status').textContent = message;
    }

    // Wait for craft native UI API to be ready
    document.addEventListener('craft:nativeui:ready', () => {
      updateStatus('✅ Native UI API Ready');
      log('Craft Native UI API initialized', 'success');
    });

    // Check if API is available immediately
    setTimeout(() => {
      if (window.craft && window.craft.nativeUI) {
        updateStatus('✅ Native UI API Ready');
        log('Craft Native UI API available', 'success');
      } else {
        log('ERROR: Craft Native UI API not available', 'error');
      }
    }, 500);

    function createCompleteFinderUI() {
      log('Creating complete Finder-like UI...', 'info');

      try {
        // Create sidebar
        sidebar = window.craft.nativeUI.createSidebar({ id: 'finder-sidebar' });
        log('✓ Sidebar created', 'success');

        // Add Favorites section
        sidebar.addSection({
          id: 'favorites',
          header: 'Favorites',
          items: [
            { id: 'recents', label: 'Recents', icon: 'clock.arrow.circlepath' },
            { id: 'applications', label: 'Applications', icon: 'app.badge' },
            { id: 'desktop', label: 'Desktop', icon: 'desktopcomputer' },
            { id: 'documents', label: 'Documents', icon: 'doc' },
            { id: 'downloads', label: 'Downloads', icon: 'arrow.down.circle' }
          ]
        });
        log('✓ Added Favorites section', 'success');

        // Add iCloud section
        sidebar.addSection({
          id: 'icloud',
          header: 'iCloud',
          items: [
            { id: 'drive', label: 'iCloud Drive', icon: 'icloud' },
            { id: 'shared', label: 'Shared', icon: 'person.2' }
          ]
        });
        log('✓ Added iCloud section', 'success');

        // Add Locations section
        sidebar.addSection({
          id: 'locations',
          header: 'Locations',
          items: [
            { id: 'macbook', label: 'MacBook Pro', icon: 'laptopcomputer' },
            { id: 'network', label: 'Network', icon: 'network' }
          ]
        });
        log('✓ Added Locations section', 'success');

        // Create file browser
        browser = window.craft.nativeUI.createFileBrowser({ id: 'finder-browser' });
        log('✓ File browser created', 'success');

        // Add sample files
        browser.addFiles([
          {
            id: 'file1',
            name: 'Project Proposal.docx',
            icon: 'doc.text',
            dateModified: 'Yesterday at 2:34 PM',
            size: '2.4 MB',
            kind: 'Microsoft Word document'
          },
          {
            id: 'file2',
            name: 'Budget 2024.xlsx',
            icon: 'tablecells',
            dateModified: 'Jan 15, 2024 at 10:22 AM',
            size: '856 KB',
            kind: 'Microsoft Excel spreadsheet'
          },
          {
            id: 'file3',
            name: 'Team Photo.jpg',
            icon: 'photo',
            dateModified: 'Dec 20, 2023 at 4:15 PM',
            size: '4.2 MB',
            kind: 'JPEG image'
          },
          {
            id: 'file4',
            name: 'Presentation.key',
            icon: 'play.rectangle',
            dateModified: 'Nov 8, 2023 at 9:45 AM',
            size: '12.8 MB',
            kind: 'Keynote presentation'
          },
          {
            id: 'file5',
            name: 'Meeting Notes.txt',
            icon: 'doc.plaintext',
            dateModified: 'Today at 11:30 AM',
            size: '4 KB',
            kind: 'Plain text'
          }
        ]);
        log('✓ Added 5 files to browser', 'success');

        // Create split view
        splitView = window.craft.nativeUI.createSplitView({
          id: 'finder-split',
          sidebar: sidebar,
          browser: browser
        });
        log('✓ Split view created', 'success');

        updateStatus('✅ Complete Finder UI Created!');
        log('=== Finder UI successfully created! ===', 'success');

      } catch (error) {
        log(\`ERROR: \${error.message}\`, 'error');
        updateStatus('❌ Error creating UI');
      }
    }

    function createSidebarOnly() {
      log('Creating sidebar only...', 'info');

      try {
        sidebar = window.craft.nativeUI.createSidebar({ id: 'test-sidebar' });
        log('✓ Sidebar created', 'success');

        sidebar.addSection({
          id: 'test-section',
          header: 'Test Section',
          items: [
            { id: 'item1', label: 'Item 1', icon: 'star' },
            { id: 'item2', label: 'Item 2', icon: 'heart' },
            { id: 'item3', label: 'Item 3', icon: 'bookmark' }
          ]
        });
        log('✓ Added test section', 'success');

        updateStatus('✅ Sidebar Created');
      } catch (error) {
        log(\`ERROR: \${error.message}\`, 'error');
      }
    }

    function createBrowserOnly() {
      log('Creating file browser only...', 'info');

      try {
        browser = window.craft.nativeUI.createFileBrowser({ id: 'test-browser' });
        log('✓ File browser created', 'success');

        browser.addFiles([
          { id: 'f1', name: 'Test File 1.txt', kind: 'Text file' },
          { id: 'f2', name: 'Test File 2.pdf', kind: 'PDF document' },
          { id: 'f3', name: 'Test File 3.jpg', kind: 'Image' }
        ]);
        log('✓ Added 3 test files', 'success');

        updateStatus('✅ File Browser Created');
      } catch (error) {
        log(\`ERROR: \${error.message}\`, 'error');
      }
    }

    log('Page loaded successfully', 'success');
  </script>
</body>
</html>`

createApp({
  html,
  window: {
    title: 'Native Finder Demo',
    width: 1200,
    height: 800,
    resizable: true,
    darkMode: true
  }
}).show()

console.log('✅ Native Finder Demo window ready')
console.log('📝 Click "Create Complete Finder UI" to see native components')
