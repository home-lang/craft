/**
 * ts-maps Demo — Craft example app.
 *
 * Demonstrates `@craft-native/ts-maps` running inside a Craft WebView:
 *  - Opens centered on New York City (OSM tiles by default).
 *  - Renders three preset markers with titles + subtitles.
 *  - Lets the user tap-to-drop draggable markers with a coord popup.
 *  - Provides a left sidebar with Recenter / Fit / Clear / Toggle satellite.
 *  - Updates a live lat/lng/zoom readout as the camera moves.
 */

import { createMapView, tileLayer } from '@craft-native/ts-maps'
import type { Coordinate, MapMarker, MapViewInstance } from '@craft-native/ts-maps'

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const NYC: Coordinate = { latitude: 40.7128, longitude: -74.0060 }

const OSM_URL = 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'
const OSM_ATTRIBUTION = '© OpenStreetMap contributors'

const SATELLITE_URL
  = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
const SATELLITE_ATTRIBUTION
  = 'Tiles © Esri — Source: Esri, Maxar, Earthstar Geographics, and the GIS User Community'

/** Preset marker ids start low; user markers use {@link USER_MARKER_ID_BASE}+ so they never collide. */
const PRESET_MARKERS: MapMarker[] = [
  {
    id: 1,
    coordinate: { latitude: 40.6892, longitude: -74.0445 },
    title: 'Statue of Liberty',
    subtitle: 'Liberty Island',
    color: 'green',
    is_draggable: false,
    is_selected: false,
    custom_icon: null,
    anchor_x: 0.5,
    anchor_y: 1,
  },
  {
    id: 2,
    coordinate: { latitude: 40.7829, longitude: -73.9654 },
    title: 'Central Park',
    subtitle: 'Manhattan',
    color: 'green',
    is_draggable: false,
    is_selected: false,
    custom_icon: null,
    anchor_x: 0.5,
    anchor_y: 1,
  },
  {
    id: 3,
    coordinate: { latitude: 40.7484, longitude: -73.9857 },
    title: 'Empire State Building',
    subtitle: '350 Fifth Avenue',
    color: 'red',
    is_draggable: false,
    is_selected: false,
    custom_icon: null,
    anchor_x: 0.5,
    anchor_y: 1,
  },
]

const USER_MARKER_ID_BASE = 1000

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

interface DemoState {
  view: MapViewInstance
  /** Current tile layer attached to the map — we swap it out when toggling. */
  currentTileLayer: ReturnType<typeof tileLayer>
  /** `osm` or `satellite`; mirrors `#readout-tiles`. */
  basemap: 'osm' | 'satellite'
  /** IDs of user-added markers (so we can clear them without touching presets). */
  userMarkerIds: number[]
  /** Monotonic counter for user marker ids. */
  nextUserMarkerId: number
}

let demoState: DemoState | null = null

// ---------------------------------------------------------------------------
// DOM helpers
// ---------------------------------------------------------------------------

function requireEl<T extends HTMLElement>(id: string): T {
  const el = document.getElementById(id)
  if (!el)
    throw new Error(`#${id} not found in DOM`)
  return el as T
}

function formatCoord(n: number): string {
  return n.toFixed(4)
}

function escapeHtml(s: string): string {
  const div = document.createElement('div')
  div.textContent = s
  return div.innerHTML
}

function popupHtml(title: string, subtitle?: string | null, coord?: Coordinate): string {
  const pieces: string[] = [`<strong>${escapeHtml(title)}</strong>`]
  if (subtitle) pieces.push(`<div style="color:#5b6a87">${escapeHtml(subtitle)}</div>`)
  if (coord) {
    pieces.push(
      `<div style="font-family:ui-monospace,Menlo,monospace;margin-top:4px">`
      + `${formatCoord(coord.latitude)}, ${formatCoord(coord.longitude)}`
      + `</div>`,
    )
  }
  return pieces.join('')
}

// ---------------------------------------------------------------------------
// ts-maps introspection
// ---------------------------------------------------------------------------

/** Iterate over the live layers on the underlying ts-maps instance. */
function eachLayer(view: MapViewInstance, fn: (layer: any) => void): void {
  const map = view.map as unknown as {
    eachLayer?: (cb: (layer: any) => void) => void
  }
  map.eachLayer?.(fn)
}

/** Bind popups to the preset markers so tapping them shows title + subtitle. */
function bindPresetPopups(view: MapViewInstance): void {
  eachLayer(view, (layer) => {
    const ll = layer?.getLatLng?.()
    if (!ll) return
    for (const preset of PRESET_MARKERS) {
      if (
        Math.abs(ll.lat - preset.coordinate.latitude) < 1e-6
        && Math.abs(ll.lng - preset.coordinate.longitude) < 1e-6
      ) {
        layer.bindPopup?.(
          popupHtml(preset.title ?? '', preset.subtitle, preset.coordinate),
        )
      }
    }
  })
}

/** Find the currently-attached tile layer (the one `MapView` added at construction). */
function findActiveTileLayer(view: MapViewInstance): ReturnType<typeof tileLayer> | null {
  let found: any = null
  eachLayer(view, (layer) => {
    // TileLayer duck-type: exposes `setUrl`.
    if (typeof layer?.setUrl === 'function' && !found) found = layer
  })
  return found
}

/** Fallback — attach the default OSM tile layer if nothing was found. */
function attachDefaultTileLayer(view: MapViewInstance): ReturnType<typeof tileLayer> {
  const layer = tileLayer(OSM_URL, { attribution: OSM_ATTRIBUTION } as any)
  const addTo = (layer as any).addTo as ((_m: unknown) => void) | undefined
  addTo?.(view.map)
  return layer
}

// ---------------------------------------------------------------------------
// Map event handlers
// ---------------------------------------------------------------------------

function handleMapTap(coord: Coordinate): void {
  if (!demoState) return
  const id = demoState.nextUserMarkerId++
  const marker: MapMarker = {
    id,
    coordinate: coord,
    title: 'Dropped pin',
    subtitle: `${formatCoord(coord.latitude)}, ${formatCoord(coord.longitude)}`,
    color: 'blue',
    is_draggable: true,
    is_selected: false,
    custom_icon: null,
    anchor_x: 0.5,
    anchor_y: 1,
  }
  demoState.view.addMarker(marker)
  demoState.userMarkerIds.push(id)

  // Bind a popup to the newly-added marker so the tapped coords are visible.
  eachLayer(demoState.view, (layer) => {
    const ll = layer?.getLatLng?.()
    if (!ll) return
    if (
      Math.abs(ll.lat - coord.latitude) < 1e-6
      && Math.abs(ll.lng - coord.longitude) < 1e-6
      && typeof layer.bindPopup === 'function'
      && !layer._popup
    ) {
      layer.bindPopup(popupHtml('Dropped pin', null, coord))
      layer.openPopup?.()
    }
  })
}

function handleMarkerTap(id: number, coord: Coordinate): void {
  // ts-maps toggles bound popups automatically on click, so we just log the
  // event here for observability in dev-tools.
  // eslint-disable-next-line no-console
  console.log('[ts-maps-demo] marker tapped', { id, coord })
}

function updateReadout(center: Coordinate, zoom: number): void {
  requireEl('readout-lat').textContent = formatCoord(center.latitude)
  requireEl('readout-lng').textContent = formatCoord(center.longitude)
  requireEl('readout-zoom').textContent = zoom.toFixed(1)
}

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------

function wireSidebar(state: DemoState): void {
  requireEl<HTMLButtonElement>('btn-recenter').addEventListener('click', () => {
    state.view.setCamera({ center: NYC, zoom: 11, pitch: 0, heading: 0 }, true)
  })

  requireEl<HTMLButtonElement>('btn-fit').addEventListener('click', () => {
    state.view.fitToMarkers(50)
  })

  requireEl<HTMLButtonElement>('btn-clear').addEventListener('click', () => {
    for (const id of state.userMarkerIds) state.view.removeMarker(id)
    state.userMarkerIds = []
  })

  requireEl<HTMLButtonElement>('btn-tiles').addEventListener('click', () => {
    toggleBasemap(state)
  })
}

function toggleBasemap(state: DemoState): void {
  const next = state.basemap === 'osm' ? 'satellite' : 'osm'
  const url = next === 'satellite' ? SATELLITE_URL : OSM_URL
  const attribution = next === 'satellite' ? SATELLITE_ATTRIBUTION : OSM_ATTRIBUTION

  const oldLayer = state.currentTileLayer as unknown as { remove?: () => void }
  oldLayer.remove?.()

  const newLayer = tileLayer(url, { attribution } as any)
  const addTo = (newLayer as any).addTo as ((_m: unknown) => void) | undefined
  addTo?.(state.view.map)

  state.currentTileLayer = newLayer
  state.basemap = next
  requireEl('readout-tiles').textContent = next
}

// ---------------------------------------------------------------------------
// Entry
// ---------------------------------------------------------------------------

function main(): void {
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => main(), { once: true })
    return
  }

  const host = requireEl<HTMLElement>('map-host')

  const view = createMapView({
    initialCamera: {
      center: NYC,
      zoom: 11,
      pitch: 0,
      heading: 0,
    },
    markers: PRESET_MARKERS,
    tileUrl: OSM_URL,
    tileAttribution: OSM_ATTRIBUTION,
    onTap: (coord) => handleMapTap(coord),
    onMarkerTap: (id, coord) => handleMarkerTap(id, coord),
    onCameraChanged: (camera) => updateReadout(camera.center, camera.zoom),
  })

  host.appendChild(view.container)

  // ts-maps needs a relayout once inserted into a sized parent.
  setTimeout(() => {
    const mapWithRelayout = view.map as unknown as { invalidateSize?: () => void }
    mapWithRelayout.invalidateSize?.()
  }, 0)

  bindPresetPopups(view)
  updateReadout(NYC, 11)

  demoState = {
    view,
    currentTileLayer: findActiveTileLayer(view) ?? attachDefaultTileLayer(view),
    basemap: 'osm',
    userMarkerIds: [],
    nextUserMarkerId: USER_MARKER_ID_BASE,
  }

  wireSidebar(demoState)
}

main()
