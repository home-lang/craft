#!/usr/bin/env bun
/**
 * Direct Native UI Test
 * Tests native UI components by sending messages directly from JavaScript after page load
 */

import { createApp } from '../packages/typescript/src/index.ts'

const html = `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Direct Native UI Test</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      padding: 20px;
      background: #f5f5f5;
    }
    .controls {
      background: white;
      padding: 20px;
      border-radius: 8px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }
    button {
      background: #007AFF;
      color: white;
      border: none;
      padding: 10px 20px;
      border-radius: 6px;
      cursor: pointer;
      font-size: 14px;
      margin: 5px;
    }
    button:hover {
      background: #0051D5;
    }
    #status {
      margin-top: 15px;
      padding: 10px;
      background: #f0f0f0;
      border-radius: 4px;
      font-size: 13px;
    }
  </style>
</head>
<body>
  <div class="controls">
    <h1>Native UI Test Controls</h1>
    <p>Click buttons to create native macOS components</p>

    <button onclick="createTestSidebar()">Create Sidebar</button>
    <button onclick="createTestFileBrowser()">Create File Browser</button>
    <button onclick="createTestSplitView()">Create Split View</button>

    <div id="status">Waiting for Craft Native UI to load...</div>
  </div>

  <script>
    let sidebarInstance = null;
    let browserInstance = null;
    let splitViewInstance = null;

    function updateStatus(message) {
      document.getElementById('status').textContent = message;
      console.log('[Status]', message);
    }

    document.addEventListener('craft:nativeui:ready', () => {
      updateStatus('Craft Native UI is ready! Click buttons to test.');
      console.log('[Test] Native UI API available:', window.craft.nativeUI);
    });

    function createTestSidebar() {
      try {
        updateStatus('Creating sidebar...');

        sidebarInstance = window.craft.nativeUI.createSidebar({
          id: 'test-sidebar-' + Date.now()
        });

        updateStatus('Adding sections to sidebar...');

        sidebarInstance.addSection({
          id: 'favorites',
          header: 'FAVORITES',
          items: [
            { id: 'docs', label: 'Documents' },
            { id: 'downloads', label: 'Downloads' },
            { id: 'desktop', label: 'Desktop' }
          ]
        });

        sidebarInstance.addSection({
          id: 'locations',
          header: 'LOCATIONS',
          items: [
            { id: 'home', label: 'Home' },
            { id: 'applications', label: 'Applications' }
          ]
        });

        updateStatus('Sidebar created successfully! Check the window.');
      } catch (error) {
        updateStatus('ERROR creating sidebar: ' + error.message);
        console.error('[Test] Sidebar error:', error);
      }
    }

    function createTestFileBrowser() {
      try {
        updateStatus('Creating file browser...');

        browserInstance = window.craft.nativeUI.createFileBrowser({
          id: 'test-browser-' + Date.now()
        });

        updateStatus('Adding files to browser...');

        browserInstance.addFiles([
          { id: 'f1', name: 'Document.pdf', kind: 'PDF Document', size: '2.4 MB', dateModified: 'Today' },
          { id: 'f2', name: 'Image.jpg', kind: 'JPEG Image', size: '4.2 MB', dateModified: 'Yesterday' },
          { id: 'f3', name: 'Spreadsheet.xlsx', kind: 'Excel Document', size: '856 KB', dateModified: 'Nov 10' },
          { id: 'f4', name: 'Presentation.pptx', kind: 'PowerPoint', size: '12.3 MB', dateModified: 'Nov 9' },
          { id: 'f5', name: 'Video.mp4', kind: 'Video', size: '156 MB', dateModified: 'Nov 8' }
        ]);

        updateStatus('File browser created successfully! Check the window.');
      } catch (error) {
        updateStatus('ERROR creating file browser: ' + error.message);
        console.error('[Test] File browser error:', error);
      }
    }

    function createTestSplitView() {
      try {
        updateStatus('Creating split view (sidebar + file browser)...');

        if (!sidebarInstance) {
          createTestSidebar();
        }

        if (!browserInstance) {
          createTestFileBrowser();
        }

        setTimeout(() => {
          splitViewInstance = window.craft.nativeUI.createSplitView({
            id: 'test-splitview-' + Date.now(),
            sidebar: sidebarInstance,
            browser: browserInstance
          });

          updateStatus('Split view created! You should see a Finder-like layout.');
        }, 100);

      } catch (error) {
        updateStatus('ERROR creating split view: ' + error.message);
        console.error('[Test] Split view error:', error);
      }
    }
  </script>
</body>
</html>`

createApp({
  html,
  window: {
    title: 'Native UI Direct Test',
    width: 1000,
    height: 700,
    resizable: true
  }
}).show()

console.log('Direct test running - click buttons in the window to create native components')
