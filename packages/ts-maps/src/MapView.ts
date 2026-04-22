/**
 * `MapView` — Craft-native interactive map component backed by the
 * ts-maps runtime. Instances are WebView-hosted; in native Craft apps
 * the Zig core drives them via the `ts_maps` bridge namespace.
 *
 * @module @craft-native/ts-maps/MapView
 */

// Import the bridge directly from its source module rather than the craft
// package root, so we don't pull the entire `@craft-native/craft` surface
// (including unrelated stx-templated sidebar files) through the type
// checker. The public API of the bridge is stable, so this is fine.
import type { NativeBridge } from '../../typescript/src/bridge/core'
import { getBridge } from '../../typescript/src/bridge/core'
import type { TsMap } from 'ts-maps'
import { createMap, tileLayer } from 'ts-maps'
import {
  boundsToCraftRegion,
  craftCameraToOptions,
  craftCircleToCircle,
  craftMarkerToMarker,
  craftPolygonToPolygon,
  craftPolylineToPolyline,
  craftRegionToBounds,
  latLngToCraftCoord,
} from './adapters'
import type {
  MapBridgeEvent,
  TypedMapBridgeRequest,
} from './bridge-protocol'
import { BRIDGE_NAMESPACE, mapEventName } from './bridge-protocol'
import type {
  Coordinate,
  MapCamera,
  MapCircle,
  MapConfiguration,
  MapMarker,
  MapPolygon,
  MapPolyline,
  MapRegion,
} from './types'
import { defaultMapCamera, defaultMapConfiguration } from './types'

// Monotonic counter — same pattern as `components/native.ts` in
// `@craft-native/craft` — so multiple map views created in the same tick
// still get unique ids.
let _mapViewIdCounter = 0
function nextMapViewId(): string {
  _mapViewIdCounter += 1
  return `mapview_${Date.now()}_${_mapViewIdCounter}`
}

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/** Subset of Craft's `ComponentProps` duplicated here to keep runtime deps minimal. */
export interface ComponentProps {
  /** Explicit component id — auto-generated if omitted. */
  id?: string
  /** CSS class applied to the container `<div>`. */
  className?: string
  /** Inline styles applied to the container. */
  style?: Partial<CSSStyleDeclaration>
  /** Hidden state. */
  hidden?: boolean
  /** Accessible tooltip. */
  tooltip?: string
}

/** Props accepted by {@link createMapView}. */
export interface MapViewProps extends ComponentProps {
  /** Map configuration; defaults to {@link defaultMapConfiguration}. */
  configuration?: MapConfiguration
  /** Initial camera position; defaults to {@link defaultMapCamera}. */
  initialCamera?: MapCamera
  /** Markers to render on first mount. */
  markers?: MapMarker[]
  /** Polylines to render on first mount. */
  polylines?: MapPolyline[]
  /** Polygons to render on first mount. */
  polygons?: MapPolygon[]
  /** Circles to render on first mount. */
  circles?: MapCircle[]
  /** Optional tile URL template. Defaults to OSM. */
  tileUrl?: string
  /** Optional tile attribution string. */
  tileAttribution?: string
  /** Called when the user taps the map background. */
  onTap?: (coordinate: Coordinate) => void
  /** Called when a marker is tapped. */
  onMarkerTap?: (markerId: number, coordinate: Coordinate) => void
  /** Called when the visible region changes (after the user pans/zooms). */
  onRegionChanged?: (region: MapRegion) => void
  /** Called when the camera changes (zoom / bearing / pitch). */
  onCameraChanged?: (camera: MapCamera) => void
}

/** Instance returned by {@link createMapView}. */
export interface MapViewInstance {
  /** Unique id — also used as the bridge component id. */
  id: string
  /** DOM container hosting the ts-maps canvas. */
  container: HTMLDivElement
  /** Underlying ts-maps instance. */
  map: TsMap
  /** Current configuration. */
  configuration: MapConfiguration

  /** Move the camera. */
  setCamera: (camera: MapCamera, animated?: boolean) => void
  /** Fit the viewport to a region. */
  setRegion: (region: MapRegion, animated?: boolean) => void
  /** Add a marker; returns its id. */
  addMarker: (marker: MapMarker) => number
  /** Remove a marker by id. */
  removeMarker: (id: number) => boolean
  /** Add a polyline; returns its id. */
  addPolyline: (polyline: MapPolyline) => number
  /** Add a polygon; returns its id. */
  addPolygon: (polygon: MapPolygon) => number
  /** Add a circle; returns its id. */
  addCircle: (circle: MapCircle) => number
  /** Fit the map to all currently-rendered markers. */
  fitToMarkers: (paddingPercent?: number) => void
  /** Select a marker by id. */
  selectMarker: (id: number) => void
  /** Deselect all markers. */
  deselectAll: () => void
  /** Update the configuration. */
  setConfiguration: (configuration: MapConfiguration) => void
  /** Detach event listeners and remove the map from the DOM. */
  destroy: () => void
}

// ---------------------------------------------------------------------------
// Safe bridge accessor
// ---------------------------------------------------------------------------

/**
 * `getBridge()` can throw in non-browser or test environments. Callers of
 * this helper treat a missing bridge as "native integration unavailable"
 * and fall back to pure-DOM behavior.
 */
function tryGetBridge(): NativeBridge | null {
  try {
    return getBridge()
  }
  catch {
    return null
  }
}

// ---------------------------------------------------------------------------
// Factory
// ---------------------------------------------------------------------------

const DEFAULT_TILE_URL = 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'
const DEFAULT_TILE_ATTRIBUTION = '© OpenStreetMap contributors'

/**
 * Create a `MapView`. The returned {@link MapViewInstance} owns a DOM
 * container — append it to the page yourself; this factory never mounts it
 * for you so consumers stay in control of layout.
 */
export function createMapView(props: MapViewProps = {}): MapViewInstance {
  const id = props.id ?? nextMapViewId()
  const configuration = { ...defaultMapConfiguration, ...props.configuration }
  const initialCamera = props.initialCamera ?? defaultMapCamera

  // Container div -------------------------------------------------------------
  const container = document.createElement('div')
  container.id = id
  container.className = ['tsmap-craft-view', props.className].filter(Boolean).join(' ')
  // ts-maps requires a non-zero size; a sensible default keeps tests sane.
  container.style.width = '100%'
  container.style.height = '100%'
  if (props.style)
    Object.assign(container.style, props.style)
  if (props.hidden)
    container.style.display = 'none'
  if (props.tooltip)
    container.title = props.tooltip

  // ts-maps instance ----------------------------------------------------------
  const cameraOptions = craftCameraToOptions(initialCamera)
  const map = createMap(container, {
    center: cameraOptions.center as any,
    zoom: cameraOptions.zoom,
    minZoom: configuration.min_zoom,
    maxZoom: configuration.max_zoom,
    zoomControl: configuration.is_zoom_enabled,
    dragging: configuration.is_scroll_enabled,
  } as any)

  // Always add a tile layer so the map actually renders something.
  tileLayer(props.tileUrl ?? DEFAULT_TILE_URL, {
    attribution: props.tileAttribution ?? DEFAULT_TILE_ATTRIBUTION,
    maxZoom: configuration.max_zoom,
  } as any).addTo(map as any)

  // Runtime registries — track the ts-maps objects we created so we can
  // remove/update them by Craft id later.
  const markers = new Map<number, ReturnType<typeof craftMarkerToMarker>>()
  const polylines = new Map<number, ReturnType<typeof craftPolylineToPolyline>>()
  const polygons = new Map<number, ReturnType<typeof craftPolygonToPolygon>>()
  const circles = new Map<number, ReturnType<typeof craftCircleToCircle>>()

  // Bridge wiring -------------------------------------------------------------
  const bridge = tryGetBridge()
  if (bridge) {
    // Some Craft versions expose a `registerComponent`. Call it defensively
    // so we keep working against older bridges that lack it.
    const maybeRegister = (bridge as unknown as {
      registerComponent?: (type: string, componentId: string) => void
    }).registerComponent
    if (typeof maybeRegister === 'function')
      maybeRegister.call(bridge, 'MapView', id)
  }

  const emitBridge = (event: MapBridgeEvent): void => {
    if (!bridge)
      return
    bridge.emit(mapEventName(event.type), { ...event, viewId: id, namespace: BRIDGE_NAMESPACE })
  }

  // Event plumbing ------------------------------------------------------------
  const handleTap = (e: any): void => {
    const coord = e?.latlng ? latLngToCraftCoord(e.latlng) : { latitude: 0, longitude: 0 }
    props.onTap?.(coord)
    emitBridge({ type: 'tap', coordinate: coord })
  }

  const readCamera = (): MapCamera => {
    const center = (map as any).getCenter?.()
    const zoom = (map as any).getZoom?.() ?? initialCamera.zoom
    return {
      center: center ? latLngToCraftCoord(center) : initialCamera.center,
      zoom,
      pitch: initialCamera.pitch,
      heading: initialCamera.heading,
    }
  }

  const handleMoveEnd = (): void => {
    const bounds = (map as any).getBounds?.() as ReturnType<typeof craftRegionToBounds> | undefined
    if (bounds) {
      const region = boundsToCraftRegion(bounds as any)
      props.onRegionChanged?.(region)
      emitBridge({ type: 'regionChanged', region })
    }
    const camera = readCamera()
    props.onCameraChanged?.(camera)
    emitBridge({ type: 'cameraChanged', camera })
  }

  ;(map as any).on?.('click', handleTap)
  ;(map as any).on?.('moveend', handleMoveEnd)

  // Marker click delegation — attach a listener when adding, unwire on remove.
  const wireMarker = (m: ReturnType<typeof craftMarkerToMarker>): void => {
    ;(m as any).on?.('click', () => {
      const ll = (m as any).getLatLng?.()
      const coord = ll ? latLngToCraftCoord(ll) : { latitude: 0, longitude: 0 }
      const markerId = (m as any).__craftMarkerId as number
      props.onMarkerTap?.(markerId, coord)
      emitBridge({ type: 'markerTap', markerId, coordinate: coord })
    })
  }

  // Imperative API ------------------------------------------------------------
  const instance: MapViewInstance = {
    id,
    container,
    map,
    configuration,

    setCamera(camera, animated = false) {
      const opts = craftCameraToOptions(camera)
      if (animated && typeof (map as any).flyTo === 'function')
        (map as any).flyTo(opts.center, opts.zoom)
      else
        (map as any).setView?.(opts.center, opts.zoom)
    },

    setRegion(region, _animated = false) {
      const bounds = craftRegionToBounds(region)
      ;(map as any).fitBounds?.(bounds)
    },

    addMarker(marker) {
      const tsMarker = craftMarkerToMarker(marker)
      ;(tsMarker as any).addTo?.(map)
      wireMarker(tsMarker)
      markers.set(marker.id, tsMarker)
      return marker.id
    },

    removeMarker(markerId) {
      const existing = markers.get(markerId)
      if (!existing)
        return false
      ;(existing as any).remove?.()
      markers.delete(markerId)
      return true
    },

    addPolyline(polyline) {
      const tsLine = craftPolylineToPolyline(polyline)
      ;(tsLine as any).addTo?.(map)
      polylines.set(polyline.id, tsLine)
      return polyline.id
    },

    addPolygon(polygon) {
      const tsPolygon = craftPolygonToPolygon(polygon)
      ;(tsPolygon as any).addTo?.(map)
      polygons.set(polygon.id, tsPolygon)
      return polygon.id
    },

    addCircle(circle) {
      const tsCircle = craftCircleToCircle(circle)
      ;(tsCircle as any).addTo?.(map)
      circles.set(circle.id, tsCircle)
      return circle.id
    },

    fitToMarkers(paddingPercent = 10) {
      if (markers.size === 0)
        return
      const coords: Coordinate[] = []
      for (const m of markers.values()) {
        const ll = (m as any).getLatLng?.()
        if (ll)
          coords.push(latLngToCraftCoord(ll))
      }
      if (coords.length === 0)
        return
      // Expand span by `paddingPercent` so pins aren't flush with the viewport edges.
      let minLat = 90, maxLat = -90, minLng = 180, maxLng = -180
      for (const c of coords) {
        if (c.latitude < minLat) minLat = c.latitude
        if (c.latitude > maxLat) maxLat = c.latitude
        if (c.longitude < minLng) minLng = c.longitude
        if (c.longitude > maxLng) maxLng = c.longitude
      }
      const factor = 1 + paddingPercent / 100
      const latSpan = (maxLat - minLat) * factor
      const lngSpan = (maxLng - minLng) * factor
      instance.setRegion({
        center: {
          latitude: (minLat + maxLat) / 2,
          longitude: (minLng + maxLng) / 2,
        },
        span: { latitude_delta: latSpan, longitude_delta: lngSpan },
      })
    },

    selectMarker(markerId) {
      for (const [, m] of markers)
        (m as any).__craftSelected = false
      const target = markers.get(markerId)
      if (target) {
        ;(target as any).__craftSelected = true
        ;(target as any).openPopup?.()
      }
    },

    deselectAll() {
      for (const m of markers.values()) {
        ;(m as any).__craftSelected = false
        ;(m as any).closePopup?.()
      }
    },

    setConfiguration(next) {
      instance.configuration = next
      // Minimum/maximum zoom are the two cheap knobs we can re-apply live
      // without tearing the map down.
      ;(map as any).setMinZoom?.(next.min_zoom)
      ;(map as any).setMaxZoom?.(next.max_zoom)
    },

    destroy() {
      ;(map as any).off?.('click', handleTap)
      ;(map as any).off?.('moveend', handleMoveEnd)
      ;(map as any).remove?.()
      container.remove()
    },
  }

  // Mount initial overlays ----------------------------------------------------
  for (const m of props.markers ?? []) instance.addMarker(m)
  for (const pl of props.polylines ?? []) instance.addPolyline(pl)
  for (const pg of props.polygons ?? []) instance.addPolygon(pg)
  for (const c of props.circles ?? []) instance.addCircle(c)

  // Subscribe to bridge-originated requests ----------------------------------
  if (bridge) {
    const unbind: Array<() => void> = []
    const on = (method: TypedMapBridgeRequest['method'], handler: (p: any) => void): void => {
      const event = `${BRIDGE_NAMESPACE}:${method}:${id}`
      bridge.on(event, handler)
      unbind.push(() => bridge.off(event, handler))
    }

    on('setCamera', (p) => instance.setCamera(p.camera, p.animated))
    on('setRegion', (p) => instance.setRegion(p.region, p.animated))
    on('addMarker', (p) => instance.addMarker(p.marker))
    on('removeMarker', (p) => instance.removeMarker(p.id))
    on('addPolyline', (p) => instance.addPolyline(p.polyline))
    on('addPolygon', (p) => instance.addPolygon(p.polygon))
    on('addCircle', (p) => instance.addCircle(p.circle))
    on('fitToMarkers', (p) => instance.fitToMarkers(p.padding))
    on('selectMarker', (p) => instance.selectMarker(p.id))
    on('deselectAll', () => instance.deselectAll())
    on('setConfiguration', (p) => instance.setConfiguration(p.configuration))

    const originalDestroy = instance.destroy
    instance.destroy = () => {
      for (const fn of unbind) fn()
      originalDestroy()
    }
  }

  return instance
}
