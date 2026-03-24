/**
 * Hello World Example
 * A slightly more advanced example with modern styling
 */

import { createApp } from 'ts-craft'

const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      height: 100vh;
      display: flex;
      justify-content: center;
      align-items: center;
      color: white;
    }

    .container {
      text-align: center;
      padding: 3rem;
      background: rgba(255, 255, 255, 0.1);
      border-radius: 20px;
      backdrop-filter: blur(10px);
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
      max-width: 500px;
    }

    .emoji {
      font-size: 5rem;
      margin-bottom: 1rem;
      animation: float 3s ease-in-out infinite;
    }

    @keyframes float {
      0%, 100% { transform: translateY(0); }
      50% { transform: translateY(-20px); }
    }

    h1 {
      font-size: 2.5rem;
      margin-bottom: 1rem;
      text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.3);
    }

    p {
      font-size: 1.2rem;
      opacity: 0.9;
      line-height: 1.6;
    }

    .stats {
      margin-top: 2rem;
      padding-top: 2rem;
      border-top: 1px solid rgba(255, 255, 255, 0.2);
    }

    .stat {
      display: inline-block;
      margin: 0 1rem;
    }

    .stat-value {
      font-size: 2rem;
      font-weight: bold;
    }

    .stat-label {
      font-size: 0.9rem;
      opacity: 0.7;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="emoji">⚡</div>
    <h1>Welcome to Craft</h1>
    <p>
      Build lightning-fast desktop apps with web languages.<br>
      No Electron. No Chromium. Just pure performance.
    </p>
    <div class="stats">
      <div class="stat">
        <div class="stat-value">~14 KB</div>
        <div class="stat-label">Idle Memory</div>
      </div>
      <div class="stat">
        <div class="stat-value">50ms</div>
        <div class="stat-label">Startup Time</div>
      </div>
      <div class="stat">
        <div class="stat-value">3 MB</div>
        <div class="stat-label">Binary Size</div>
      </div>
    </div>
  </div>
</body>
</html>
`

const app = createApp({
  html,
  window: {
    title: 'Craft - Hello World',
    width: 800,
    height: 600,
    resizable: true,
  },
})

await app.show()
