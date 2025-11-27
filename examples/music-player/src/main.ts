/**
 * Music Player - Cross-platform music player built with Craft
 * Features: Audio playback, playlists, queue, visualizer, media controls
 */

import { fs, db, window, Platform, haptics } from 'ts-craft'

// Types
interface Track {
  id: number
  title: string
  artist: string
  album: string
  duration: number // seconds
  path: string
  artwork?: string
  addedAt: string
}

interface Playlist {
  id: number
  name: string
  trackIds: number[]
  createdAt: string
  updatedAt: string
}

interface PlayerState {
  currentTrack: Track | null
  queue: Track[]
  queueIndex: number
  isPlaying: boolean
  currentTime: number
  volume: number
  shuffle: boolean
  repeat: 'none' | 'one' | 'all'
}

// Initialize database
async function initDatabase(): Promise<void> {
  await db.execute(`
    CREATE TABLE IF NOT EXISTS tracks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      artist TEXT DEFAULT 'Unknown Artist',
      album TEXT DEFAULT 'Unknown Album',
      duration INTEGER DEFAULT 0,
      path TEXT NOT NULL UNIQUE,
      artwork TEXT,
      addedAt TEXT DEFAULT CURRENT_TIMESTAMP
    )
  `)

  await db.execute(`
    CREATE TABLE IF NOT EXISTS playlists (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      trackIds TEXT DEFAULT '[]',
      createdAt TEXT DEFAULT CURRENT_TIMESTAMP,
      updatedAt TEXT DEFAULT CURRENT_TIMESTAMP
    )
  `)

  await db.execute(`
    CREATE TABLE IF NOT EXISTS player_state (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      volume REAL DEFAULT 1.0,
      shuffle INTEGER DEFAULT 0,
      repeat TEXT DEFAULT 'none'
    )
  `)

  // Initialize player state if not exists
  await db.execute(`INSERT OR IGNORE INTO player_state (id) VALUES (1)`)
}

// Audio Player class
class AudioPlayer {
  private audio: HTMLAudioElement
  private state: PlayerState
  private visualizerCanvas: HTMLCanvasElement | null = null
  private analyser: AnalyserNode | null = null
  private audioContext: AudioContext | null = null
  private animationFrame: number | null = null

  constructor() {
    this.audio = new Audio()
    this.state = {
      currentTrack: null,
      queue: [],
      queueIndex: -1,
      isPlaying: false,
      currentTime: 0,
      volume: 1.0,
      shuffle: false,
      repeat: 'none',
    }

    this.setupAudioEvents()
    this.loadPlayerState()
  }

  private setupAudioEvents(): void {
    this.audio.addEventListener('timeupdate', () => {
      this.state.currentTime = this.audio.currentTime
      this.updateProgressUI()
    })

    this.audio.addEventListener('ended', () => {
      this.handleTrackEnd()
    })

    this.audio.addEventListener('play', () => {
      this.state.isPlaying = true
      this.updatePlayButtonUI()
      this.startVisualizer()
    })

    this.audio.addEventListener('pause', () => {
      this.state.isPlaying = false
      this.updatePlayButtonUI()
      this.stopVisualizer()
    })
  }

  private async loadPlayerState(): Promise<void> {
    const result = await db.query<{ volume: number; shuffle: number; repeat: string }>(
      'SELECT * FROM player_state WHERE id = 1'
    )
    if (result.length > 0) {
      this.state.volume = result[0].volume
      this.state.shuffle = result[0].shuffle === 1
      this.state.repeat = result[0].repeat as 'none' | 'one' | 'all'
      this.audio.volume = this.state.volume
    }
  }

  async savePlayerState(): Promise<void> {
    await db.execute(
      `UPDATE player_state SET volume = ?, shuffle = ?, repeat = ? WHERE id = 1`,
      [this.state.volume, this.state.shuffle ? 1 : 0, this.state.repeat]
    )
  }

  // Playback controls
  async play(track?: Track): Promise<void> {
    if (track) {
      this.state.currentTrack = track
      this.audio.src = track.path
      this.updateNowPlayingUI()
    }

    if (this.audio.src) {
      await this.audio.play()
      if (Platform.OS === 'ios' || Platform.OS === 'android') {
        haptics.impact('light')
      }
      this.updateMediaSession()
    }
  }

  pause(): void {
    this.audio.pause()
  }

  togglePlayPause(): void {
    if (this.state.isPlaying) {
      this.pause()
    } else {
      this.play()
    }
  }

  async next(): Promise<void> {
    if (this.state.queue.length === 0) return

    if (this.state.shuffle) {
      this.state.queueIndex = Math.floor(Math.random() * this.state.queue.length)
    } else {
      this.state.queueIndex = (this.state.queueIndex + 1) % this.state.queue.length
    }

    await this.play(this.state.queue[this.state.queueIndex])
    if (Platform.OS === 'ios' || Platform.OS === 'android') {
      haptics.impact('medium')
    }
  }

  async previous(): Promise<void> {
    if (this.state.queue.length === 0) return

    // If more than 3 seconds into track, restart it
    if (this.audio.currentTime > 3) {
      this.audio.currentTime = 0
      return
    }

    if (this.state.shuffle) {
      this.state.queueIndex = Math.floor(Math.random() * this.state.queue.length)
    } else {
      this.state.queueIndex =
        (this.state.queueIndex - 1 + this.state.queue.length) % this.state.queue.length
    }

    await this.play(this.state.queue[this.state.queueIndex])
    if (Platform.OS === 'ios' || Platform.OS === 'android') {
      haptics.impact('medium')
    }
  }

  seek(time: number): void {
    this.audio.currentTime = time
  }

  setVolume(volume: number): void {
    this.state.volume = Math.max(0, Math.min(1, volume))
    this.audio.volume = this.state.volume
    this.savePlayerState()
  }

  toggleShuffle(): void {
    this.state.shuffle = !this.state.shuffle
    this.savePlayerState()
    this.updateShuffleUI()
  }

  toggleRepeat(): void {
    const modes: Array<'none' | 'one' | 'all'> = ['none', 'all', 'one']
    const currentIndex = modes.indexOf(this.state.repeat)
    this.state.repeat = modes[(currentIndex + 1) % modes.length]
    this.savePlayerState()
    this.updateRepeatUI()
  }

  // Queue management
  setQueue(tracks: Track[], startIndex = 0): void {
    this.state.queue = tracks
    this.state.queueIndex = startIndex
  }

  addToQueue(track: Track): void {
    this.state.queue.push(track)
  }

  clearQueue(): void {
    this.state.queue = []
    this.state.queueIndex = -1
  }

  private handleTrackEnd(): void {
    if (this.state.repeat === 'one') {
      this.audio.currentTime = 0
      this.play()
    } else if (this.state.repeat === 'all' || this.state.queueIndex < this.state.queue.length - 1) {
      this.next()
    }
  }

  // Visualizer
  setupVisualizer(canvas: HTMLCanvasElement): void {
    this.visualizerCanvas = canvas

    if (!this.audioContext) {
      this.audioContext = new AudioContext()
      const source = this.audioContext.createMediaElementSource(this.audio)
      this.analyser = this.audioContext.createAnalyser()
      this.analyser.fftSize = 256

      source.connect(this.analyser)
      this.analyser.connect(this.audioContext.destination)
    }
  }

  private startVisualizer(): void {
    if (!this.visualizerCanvas || !this.analyser) return

    const canvas = this.visualizerCanvas
    const ctx = canvas.getContext('2d')
    if (!ctx) return

    const bufferLength = this.analyser.frequencyBinCount
    const dataArray = new Uint8Array(bufferLength)

    const draw = () => {
      if (!this.state.isPlaying) return

      this.animationFrame = requestAnimationFrame(draw)
      this.analyser!.getByteFrequencyData(dataArray)

      ctx.fillStyle = 'rgb(20, 20, 30)'
      ctx.fillRect(0, 0, canvas.width, canvas.height)

      const barWidth = (canvas.width / bufferLength) * 2.5
      let x = 0

      for (let i = 0; i < bufferLength; i++) {
        const barHeight = (dataArray[i] / 255) * canvas.height

        const hue = (i / bufferLength) * 360
        ctx.fillStyle = `hsl(${hue}, 70%, 50%)`
        ctx.fillRect(x, canvas.height - barHeight, barWidth, barHeight)

        x += barWidth + 1
      }
    }

    draw()
  }

  private stopVisualizer(): void {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame)
      this.animationFrame = null
    }
  }

  // Media Session API (for system media controls)
  private updateMediaSession(): void {
    if ('mediaSession' in navigator && this.state.currentTrack) {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: this.state.currentTrack.title,
        artist: this.state.currentTrack.artist,
        album: this.state.currentTrack.album,
        artwork: this.state.currentTrack.artwork
          ? [{ src: this.state.currentTrack.artwork, sizes: '512x512', type: 'image/png' }]
          : [],
      })

      navigator.mediaSession.setActionHandler('play', () => this.play())
      navigator.mediaSession.setActionHandler('pause', () => this.pause())
      navigator.mediaSession.setActionHandler('previoustrack', () => this.previous())
      navigator.mediaSession.setActionHandler('nexttrack', () => this.next())
      navigator.mediaSession.setActionHandler('seekto', (details) => {
        if (details.seekTime !== undefined) this.seek(details.seekTime)
      })
    }
  }

  // UI updates (to be connected to actual DOM)
  private updateProgressUI(): void {
    const progressBar = document.getElementById('progress-bar') as HTMLInputElement
    const currentTimeEl = document.getElementById('current-time')
    if (progressBar && this.state.currentTrack) {
      progressBar.value = String((this.audio.currentTime / this.state.currentTrack.duration) * 100)
    }
    if (currentTimeEl) {
      currentTimeEl.textContent = formatTime(this.audio.currentTime)
    }
  }

  private updatePlayButtonUI(): void {
    const playBtn = document.getElementById('play-btn')
    if (playBtn) {
      playBtn.innerHTML = this.state.isPlaying ? '⏸' : '▶'
    }
  }

  private updateNowPlayingUI(): void {
    const titleEl = document.getElementById('track-title')
    const artistEl = document.getElementById('track-artist')
    const artworkEl = document.getElementById('artwork') as HTMLImageElement
    const durationEl = document.getElementById('duration')

    if (this.state.currentTrack) {
      if (titleEl) titleEl.textContent = this.state.currentTrack.title
      if (artistEl) artistEl.textContent = this.state.currentTrack.artist
      if (artworkEl) artworkEl.src = this.state.currentTrack.artwork || 'default-artwork.png'
      if (durationEl) durationEl.textContent = formatTime(this.state.currentTrack.duration)
    }
  }

  private updateShuffleUI(): void {
    const shuffleBtn = document.getElementById('shuffle-btn')
    if (shuffleBtn) {
      shuffleBtn.classList.toggle('active', this.state.shuffle)
    }
  }

  private updateRepeatUI(): void {
    const repeatBtn = document.getElementById('repeat-btn')
    if (repeatBtn) {
      repeatBtn.dataset.mode = this.state.repeat
      repeatBtn.innerHTML =
        this.state.repeat === 'one' ? '🔂' : this.state.repeat === 'all' ? '🔁' : '➡'
    }
  }

  getState(): PlayerState {
    return { ...this.state }
  }
}

// Library management
class MusicLibrary {
  async scanDirectory(path: string): Promise<Track[]> {
    const tracks: Track[] = []
    const files = await fs.readDir(path, { recursive: true })

    for (const file of files) {
      if (file.isFile && isAudioFile(file.name)) {
        const metadata = await this.extractMetadata(file.path)
        const track = await this.addTrack({
          title: metadata.title || file.name.replace(/\.[^/.]+$/, ''),
          artist: metadata.artist || 'Unknown Artist',
          album: metadata.album || 'Unknown Album',
          duration: metadata.duration || 0,
          path: file.path,
          artwork: metadata.artwork,
        })
        if (track) tracks.push(track)
      }
    }

    return tracks
  }

  private async extractMetadata(
    _path: string
  ): Promise<{ title?: string; artist?: string; album?: string; duration?: number; artwork?: string }> {
    // In a real implementation, this would use a native module to read ID3 tags
    // For now, return empty metadata
    return {}
  }

  async addTrack(
    track: Omit<Track, 'id' | 'addedAt'>
  ): Promise<Track | null> {
    try {
      const result = await db.execute(
        `INSERT INTO tracks (title, artist, album, duration, path, artwork)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [track.title, track.artist, track.album, track.duration, track.path, track.artwork || null]
      )

      return {
        id: result.lastInsertRowId,
        ...track,
        addedAt: new Date().toISOString(),
      }
    } catch {
      // Track already exists
      return null
    }
  }

  async getAllTracks(): Promise<Track[]> {
    return db.query<Track>('SELECT * FROM tracks ORDER BY artist, album, title')
  }

  async searchTracks(query: string): Promise<Track[]> {
    return db.query<Track>(
      `SELECT * FROM tracks
       WHERE title LIKE ? OR artist LIKE ? OR album LIKE ?
       ORDER BY title`,
      [`%${query}%`, `%${query}%`, `%${query}%`]
    )
  }

  async getTracksByArtist(artist: string): Promise<Track[]> {
    return db.query<Track>('SELECT * FROM tracks WHERE artist = ? ORDER BY album, title', [artist])
  }

  async getTracksByAlbum(album: string): Promise<Track[]> {
    return db.query<Track>('SELECT * FROM tracks WHERE album = ? ORDER BY title', [album])
  }

  async getArtists(): Promise<string[]> {
    const result = await db.query<{ artist: string }>('SELECT DISTINCT artist FROM tracks ORDER BY artist')
    return result.map((r) => r.artist)
  }

  async getAlbums(): Promise<{ album: string; artist: string; artwork?: string }[]> {
    return db.query<{ album: string; artist: string; artwork?: string }>(
      `SELECT DISTINCT album, artist, artwork FROM tracks ORDER BY artist, album`
    )
  }

  async deleteTrack(id: number): Promise<void> {
    await db.execute('DELETE FROM tracks WHERE id = ?', [id])
  }
}

// Playlist management
class PlaylistManager {
  async createPlaylist(name: string): Promise<Playlist> {
    const result = await db.execute('INSERT INTO playlists (name) VALUES (?)', [name])

    return {
      id: result.lastInsertRowId,
      name,
      trackIds: [],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    }
  }

  async getAllPlaylists(): Promise<Playlist[]> {
    const results = await db.query<{ id: number; name: string; trackIds: string; createdAt: string; updatedAt: string }>(
      'SELECT * FROM playlists ORDER BY name'
    )

    return results.map((r) => ({
      ...r,
      trackIds: JSON.parse(r.trackIds),
    }))
  }

  async getPlaylist(id: number): Promise<Playlist | null> {
    const results = await db.query<{ id: number; name: string; trackIds: string; createdAt: string; updatedAt: string }>(
      'SELECT * FROM playlists WHERE id = ?',
      [id]
    )

    if (results.length === 0) return null

    return {
      ...results[0],
      trackIds: JSON.parse(results[0].trackIds),
    }
  }

  async addTrackToPlaylist(playlistId: number, trackId: number): Promise<void> {
    const playlist = await this.getPlaylist(playlistId)
    if (!playlist) return

    if (!playlist.trackIds.includes(trackId)) {
      playlist.trackIds.push(trackId)
      await db.execute('UPDATE playlists SET trackIds = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?', [
        JSON.stringify(playlist.trackIds),
        playlistId,
      ])
    }
  }

  async removeTrackFromPlaylist(playlistId: number, trackId: number): Promise<void> {
    const playlist = await this.getPlaylist(playlistId)
    if (!playlist) return

    playlist.trackIds = playlist.trackIds.filter((id) => id !== trackId)
    await db.execute('UPDATE playlists SET trackIds = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?', [
      JSON.stringify(playlist.trackIds),
      playlistId,
    ])
  }

  async deletePlaylist(id: number): Promise<void> {
    await db.execute('DELETE FROM playlists WHERE id = ?', [id])
  }

  async renamePlaylist(id: number, name: string): Promise<void> {
    await db.execute('UPDATE playlists SET name = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?', [name, id])
  }
}

// Utility functions
function formatTime(seconds: number): string {
  const mins = Math.floor(seconds / 60)
  const secs = Math.floor(seconds % 60)
  return `${mins}:${secs.toString().padStart(2, '0')}`
}

function isAudioFile(filename: string): boolean {
  const audioExtensions = ['.mp3', '.m4a', '.wav', '.flac', '.ogg', '.aac', '.wma']
  return audioExtensions.some((ext) => filename.toLowerCase().endsWith(ext))
}

// Main app initialization
async function main(): Promise<void> {
  await initDatabase()

  const player = new AudioPlayer()
  const library = new MusicLibrary()
  const playlists = new PlaylistManager()

  // Set up window
  window.setTitle('Music Player')
  window.setSize(1000, 700)
  window.setMinSize(600, 400)

  // Expose to global for UI
  ;(globalThis as any).player = player
  ;(globalThis as any).library = library
  ;(globalThis as any).playlists = playlists

  // Set up keyboard shortcuts
  document.addEventListener('keydown', (e) => {
    if (e.target instanceof HTMLInputElement) return

    switch (e.code) {
      case 'Space':
        e.preventDefault()
        player.togglePlayPause()
        break
      case 'ArrowRight':
        if (e.metaKey || e.ctrlKey) {
          player.next()
        } else {
          player.seek(player.getState().currentTime + 10)
        }
        break
      case 'ArrowLeft':
        if (e.metaKey || e.ctrlKey) {
          player.previous()
        } else {
          player.seek(player.getState().currentTime - 10)
        }
        break
      case 'ArrowUp':
        player.setVolume(player.getState().volume + 0.1)
        break
      case 'ArrowDown':
        player.setVolume(player.getState().volume - 0.1)
        break
      case 'KeyS':
        player.toggleShuffle()
        break
      case 'KeyR':
        player.toggleRepeat()
        break
    }
  })

  // Load initial library
  const tracks = await library.getAllTracks()
  console.log(`Loaded ${tracks.length} tracks from library`)

  // Render initial UI
  renderApp(tracks)
}

function renderApp(tracks: Track[]): void {
  const app = document.getElementById('app')
  if (!app) return

  app.innerHTML = `
    <div class="music-player">
      <aside class="sidebar">
        <div class="sidebar-section">
          <h3>Library</h3>
          <nav>
            <a href="#" class="nav-item active" data-view="all">All Songs</a>
            <a href="#" class="nav-item" data-view="artists">Artists</a>
            <a href="#" class="nav-item" data-view="albums">Albums</a>
          </nav>
        </div>
        <div class="sidebar-section">
          <h3>Playlists</h3>
          <nav id="playlists-nav"></nav>
          <button id="new-playlist-btn" class="btn-secondary">+ New Playlist</button>
        </div>
      </aside>

      <main class="main-content">
        <header class="top-bar">
          <input type="search" id="search" placeholder="Search music..." class="search-input" />
        </header>

        <div id="content" class="track-list">
          ${tracks.map((track) => renderTrackItem(track)).join('')}
        </div>
      </main>

      <footer class="now-playing">
        <div class="track-info">
          <img id="artwork" src="default-artwork.png" alt="Album Art" class="artwork" />
          <div class="track-details">
            <div id="track-title" class="track-title">No track playing</div>
            <div id="track-artist" class="track-artist">-</div>
          </div>
        </div>

        <div class="player-controls">
          <div class="control-buttons">
            <button id="shuffle-btn" class="control-btn">🔀</button>
            <button id="prev-btn" class="control-btn">⏮</button>
            <button id="play-btn" class="control-btn play-btn">▶</button>
            <button id="next-btn" class="control-btn">⏭</button>
            <button id="repeat-btn" class="control-btn" data-mode="none">➡</button>
          </div>
          <div class="progress-container">
            <span id="current-time">0:00</span>
            <input type="range" id="progress-bar" min="0" max="100" value="0" class="progress-bar" />
            <span id="duration">0:00</span>
          </div>
        </div>

        <div class="volume-controls">
          <button id="visualizer-btn" class="control-btn">📊</button>
          <span>🔊</span>
          <input type="range" id="volume-slider" min="0" max="100" value="100" class="volume-slider" />
        </div>
      </footer>

      <div id="visualizer-modal" class="modal hidden">
        <div class="modal-content">
          <canvas id="visualizer" width="800" height="300"></canvas>
          <button id="close-visualizer" class="btn-secondary">Close</button>
        </div>
      </div>
    </div>
  `

  setupEventListeners()
}

function renderTrackItem(track: Track): string {
  return `
    <div class="track-item" data-id="${track.id}">
      <div class="track-number">${track.id}</div>
      <div class="track-info">
        <div class="track-title">${track.title}</div>
        <div class="track-artist">${track.artist}</div>
      </div>
      <div class="track-album">${track.album}</div>
      <div class="track-duration">${formatTime(track.duration)}</div>
      <button class="track-menu-btn">⋮</button>
    </div>
  `
}

function setupEventListeners(): void {
  const player = (globalThis as any).player as AudioPlayer

  // Play/pause
  document.getElementById('play-btn')?.addEventListener('click', () => player.togglePlayPause())
  document.getElementById('prev-btn')?.addEventListener('click', () => player.previous())
  document.getElementById('next-btn')?.addEventListener('click', () => player.next())
  document.getElementById('shuffle-btn')?.addEventListener('click', () => player.toggleShuffle())
  document.getElementById('repeat-btn')?.addEventListener('click', () => player.toggleRepeat())

  // Volume
  document.getElementById('volume-slider')?.addEventListener('input', (e) => {
    const value = parseInt((e.target as HTMLInputElement).value)
    player.setVolume(value / 100)
  })

  // Progress
  document.getElementById('progress-bar')?.addEventListener('input', (e) => {
    const value = parseInt((e.target as HTMLInputElement).value)
    const state = player.getState()
    if (state.currentTrack) {
      player.seek((value / 100) * state.currentTrack.duration)
    }
  })

  // Visualizer
  document.getElementById('visualizer-btn')?.addEventListener('click', () => {
    const modal = document.getElementById('visualizer-modal')
    const canvas = document.getElementById('visualizer') as HTMLCanvasElement
    if (modal && canvas) {
      modal.classList.remove('hidden')
      player.setupVisualizer(canvas)
    }
  })

  document.getElementById('close-visualizer')?.addEventListener('click', () => {
    document.getElementById('visualizer-modal')?.classList.add('hidden')
  })

  // Track click to play
  document.querySelectorAll('.track-item').forEach((item) => {
    item.addEventListener('dblclick', async () => {
      const id = parseInt(item.getAttribute('data-id') || '0')
      const library = (globalThis as any).library as MusicLibrary
      const tracks = await library.getAllTracks()
      const track = tracks.find((t) => t.id === id)
      if (track) {
        player.setQueue(tracks, tracks.indexOf(track))
        player.play(track)
      }
    })
  })

  // Search
  document.getElementById('search')?.addEventListener('input', async (e) => {
    const query = (e.target as HTMLInputElement).value
    const library = (globalThis as any).library as MusicLibrary
    const tracks = query ? await library.searchTracks(query) : await library.getAllTracks()
    const content = document.getElementById('content')
    if (content) {
      content.innerHTML = tracks.map((track) => renderTrackItem(track)).join('')
    }
  })
}

// Start the app
main().catch(console.error)
