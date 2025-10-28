/**
 * Minimal Craft Example
 * The simplest possible desktop app
 */

import { show } from 'ts-craft'

const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body {
      margin: 0;
      height: 100vh;
      display: flex;
      justify-content: center;
      align-items: center;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    }
    h1 { font-size: 3rem; text-shadow: 2px 2px 4px rgba(0,0,0,0.3); }
  </style>
</head>
<body>
  <h1>⚡ Hello from Craft!</h1>
</body>
</html>
`

// That's it! Just one line to show a desktop window
await show(html, {
  title: 'Minimal Example',
  width: 600,
  height: 400,
})
