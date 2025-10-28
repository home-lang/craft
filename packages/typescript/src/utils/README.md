# Craft Utilities

Helper utilities to make building Craft apps easier and cleaner.

## 📦 What's Included

### AudioManager

Simplified audio management with Web Audio API.

```typescript
import { AudioManager } from 'ts-craft'

const audio = new AudioManager()

// Play tone sounds
audio.playTone('bell')      // Bell sound
audio.playTone('chime')     // Chime sound
audio.playTone('gong')      // Gong sound
audio.playTone('gentle')    // Gentle alert

// Play background noise
audio.playBackgroundNoise('ocean', 0.5)      // Ocean waves at 50% volume
audio.playBackgroundNoise('rain', 0.3)       // Rain at 30% volume
audio.playBackgroundNoise('forest', 0.4)     // Forest ambience
audio.playBackgroundNoise('whitenoise', 0.5) // White noise
audio.playBackgroundNoise('brownnoise', 0.5) // Brown noise

// Control playback
audio.setVolume(0.7)        // Adjust volume
audio.stopBackgroundNoise() // Stop all background audio
```

**Features:**
- Procedurally generated realistic ambient sounds
- No external audio files required
- Adjustable volume control
- Automatic cleanup

### Storage

Type-safe localStorage abstraction.

```typescript
import { Storage } from 'ts-craft'

interface Settings {
  theme: 'light' | 'dark'
  volume: number
  enabled: boolean
}

const storage = new Storage<Settings>('app_settings', {
  theme: 'dark',
  volume: 50,
  enabled: true,
})

// Load with defaults
const settings = storage.load()

// Save complete object
storage.save({ theme: 'light', volume: 75, enabled: true })

// Update partial data
storage.update({ volume: 80 })

// Clear storage
storage.clear()
```

**Features:**
- TypeScript type safety
- Automatic defaults
- Partial updates
- Error handling

### Timer

Simple interval-based timer with callbacks.

```typescript
import { Timer } from 'ts-craft'

const timer = new Timer(
  60,  // 60 seconds
  (timeRemaining) => {
    console.log(`Time left: ${Timer.formatTime(timeRemaining)}`)
  },
  () => {
    console.log('Timer complete!')
  }
)

// Control timer
timer.start()
timer.pause()
timer.reset()

// Get state
const remaining = timer.getTimeRemaining()  // Get seconds left
const running = timer.running()             // Check if running

// Update duration
timer.setDuration(120) // Change to 2 minutes

// Format time
Timer.formatTime(90)  // Returns "1:30"
```

**Features:**
- Simple callback-based API
- Automatic cleanup
- State tracking
- Time formatting

## 🎯 Example: Clean Pomodoro Timer

Compare the code reduction:

**Before utilities (1195 lines):**
```typescript
// Manual audio generation
const audioContext = new AudioContext()
const oscillator = audioContext.createOscillator()
const gainNode = audioContext.createGain()
// ... 100+ lines of audio code

// Manual localStorage
try {
  const saved = localStorage.getItem('key')
  if (saved) {
    const data = JSON.parse(saved)
    // ... validation logic
  }
} catch (e) { /* error handling */ }

// Manual timer
let interval = setInterval(() => {
  time--
  if (time <= 0) {
    clearInterval(interval)
    // completion logic
  }
}, 1000)
```

**After utilities (~200 lines):**
```typescript
import { AudioManager, Storage, Timer } from 'ts-craft'

const audio = new AudioManager()
const storage = new Storage('settings', defaults)
const timer = new Timer(duration, onTick, onComplete)

// That's it! Clean and simple.
audio.playTone('bell')
storage.save(data)
timer.start()
```

See `examples/pomodoro-clean.ts` for a complete example.

## 📚 Benefits

- **Less Code**: Reduce boilerplate by 80%+
- **Type Safe**: Full TypeScript support
- **Reusable**: Use across all your Craft apps
- **Tested**: Battle-tested utilities
- **Simple API**: Intuitive and easy to learn

## 🚀 Getting Started

```bash
# Install Craft
bun add ts-craft

# Use utilities
import { AudioManager, Storage, Timer } from 'ts-craft'
```

All utilities are automatically exported from the main package!
