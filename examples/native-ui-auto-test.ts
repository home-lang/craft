#!/usr/bin/env bun
/**
 * Auto-triggering Native UI Test
 * Automatically creates components on page load
 */

import { createApp } from '../packages/typescript/src/index.ts'

const html = `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Auto Test</title>
</head>
<body>
  <h1>Auto Test - Check Console</h1>
  <script>
    console.log('[Test] Page loaded, waiting for Craft API...');

    document.addEventListener('craft:nativeui:ready', () => {
      console.log('[Test] Craft Native UI ready!');

      setTimeout(() => {
        try {
          console.log('[Test] Creating sidebar...');
          const sidebar = window.craft.nativeUI.createSidebar({ id: 'auto-test-sidebar' });
          console.log('[Test] Sidebar created successfully');

          console.log('[Test] Adding section...');
          sidebar.addSection({
            id: 'test',
            header: 'Test',
            items: [
              { id: 'item1', label: 'Item 1' }
            ]
          });
          console.log('[Test] Section added successfully');

        } catch (error) {
          console.error('[Test] ERROR:', error);
        }
      }, 500);
    });
  </script>
</body>
</html>`

createApp({ html, window: { title: 'Auto Test', width: 800, height: 600 } }).show()

console.log('Auto test running...')
