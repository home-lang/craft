#!/usr/bin/env bun
/**
 * Clean Pomodoro Timer - Refactored with Craft Utilities
 *
 * This is a cleaner version demonstrating the new Craft utilities:
 * - AudioManager for sound management
 * - Storage for persistent settings
 * - Timer for interval management
 *
 * Run with: bun examples/pomodoro-clean.ts
 */

import { createApp, AudioManager, Storage, Timer } from '../packages/typescript/src/index.ts'

// Configuration
const WORK_DURATION = 25 * 60
const BREAK_DURATION = 5 * 60

// Storage instances
const statsStorage = new Storage('craft_pomodoro_stats', {
  completedToday: 0,
  currentStreak: 0,
  totalCompleted: 0,
  lastSessionDate: null as string | null,
})

const settingsStorage = new Storage('craft_pomodoro_settings', {
  transitionSound: 'bell' as const,
  backgroundNoise: 'none' as const,
  backgroundVolume: 50,
})

// Audio manager
const audio = new AudioManager()

// App state
let isWorkSession = true
let isWindowVisible = true
let timer: Timer

const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>🍅 Pomodoro</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .timer { font-size: 72px; font-weight: 200; }
    .controls { margin-top: 20px; display: flex; gap: 12px; }
    button {
      background: rgba(255, 255, 255, 0.15);
      border: 2px solid rgba(255, 255, 255, 0.3);
      color: white;
      padding: 12px 28px;
      border-radius: 10px;
      font-size: 15px;
      cursor: pointer;
    }
    button:hover { background: rgba(255, 255, 255, 0.25); }
  </style>
</head>
<body>
  <div>
    <div class="timer" id="timer">25:00</div>
    <div class="controls">
      <button id="toggleBtn" onclick="toggleTimer()">Start</button>
      <button onclick="resetTimer()">Reset</button>
    </div>

    <div style="margin-top: 40px;">
      <select id="transitionSound" onchange="updateSettings()">
        <option value="none">No Sound</option>
        <option value="bell" selected>Bell</option>
        <option value="chime">Chime</option>
        <option value="gong">Gong</option>
      </select>

      <select id="backgroundNoise" onchange="updateBackground()" style="margin-left: 10px;">
        <option value="none" selected>No Background</option>
        <option value="ocean">Ocean</option>
        <option value="rain">Rain</option>
        <option value="forest">Forest</option>
        <option value="whitenoise">White Noise</option>
        <option value="brownnoise">Brown Noise</option>
      </select>
    </div>
  </div>

  <script>
    // This would normally use the Craft bridge API
    // For now, simplified for demonstration

    function toggleTimer() {
      window.postMessage({ type: 'toggle-timer' }, '*')
    }

    function resetTimer() {
      window.postMessage({ type: 'reset-timer' }, '*')
    }

    function updateSettings() {
      const sound = document.getElementById('transitionSound').value
      window.postMessage({ type: 'update-settings', sound }, '*')
    }

    function updateBackground() {
      const noise = document.getElementById('backgroundNoise').value
      window.postMessage({ type: 'update-background', noise }, '*')
    }

    // Listen for timer updates
    window.addEventListener('message', (e) => {
      if (e.data.type === 'timer-update') {
        document.getElementById('timer').textContent = e.data.time
        document.getElementById('toggleBtn').textContent = e.data.running ? 'Pause' : 'Start'
      }
    })
  </script>
</body>
</html>
`

async function main() {
  console.log('🍅 Pomodoro Timer (Clean Version)')
  console.log('Using new Craft utilities for cleaner code!\n')

  // Load settings
  const stats = statsStorage.load()
  const settings = settingsStorage.load()

  // Reset daily stats if new day
  if (stats.lastSessionDate) {
    const lastDate = new Date(stats.lastSessionDate)
    const today = new Date()
    if (lastDate.toDateString() !== today.toDateString()) {
      statsStorage.update({ completedToday: 0 })
    }
  }

  // Initialize timer
  timer = new Timer(
    WORK_DURATION,
    (timeRemaining) => {
      // Timer tick callback
      console.log(`⏱️  ${Timer.formatTime(timeRemaining)}`)
    },
    () => {
      // Timer complete callback
      handleSessionComplete()
    },
  )

  // Start audio with saved settings
  if (settings.backgroundNoise !== 'none') {
    audio.playBackgroundNoise(settings.backgroundNoise, settings.backgroundVolume / 100)
  }

  const app = createApp({
    html,
    window: {
      title: '🍅 25:00',
      width: 400,
      height: 300,
      resizable: false,
      systemTray: true,
      hotReload: true,
      devTools: true,
    },
  })

  await app.show()
  console.log('\n✅ Pomodoro closed')
}

function handleSessionComplete() {
  const settings = settingsStorage.load()
  const stats = statsStorage.load()

  // Play transition sound
  if (settings.transitionSound !== 'none') {
    audio.playTone(settings.transitionSound as any)
  }

  // Update stats
  if (isWorkSession) {
    statsStorage.update({
      completedToday: stats.completedToday + 1,
      currentStreak: stats.currentStreak + 1,
      totalCompleted: stats.totalCompleted + 1,
      lastSessionDate: new Date().toISOString(),
    })

    console.log('🎉 Work session complete!')
    isWorkSession = false
    timer.setDuration(BREAK_DURATION)
  }
  else {
    console.log('✨ Break complete!')
    isWorkSession = true
    timer.setDuration(WORK_DURATION)
  }

  timer.reset()
}

main()
