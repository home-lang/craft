/**
 * Shared protocol constants and types for the bridge between the Zig
 * `MapView` core and the ts-maps runtime.
 *
 * @module @craft-native/ts-maps/bridge-protocol
 */

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

/**
 * Namespace used when emitting and listening for bridge messages. Matches
 * the Zig enum tag for `MapProvider.ts_maps`.
 */
export const BRIDGE_NAMESPACE = 'ts_maps' as const

/** Method names the Zig core can invoke on the TypeScript side. */
export type MapBridgeMethod =
  | 'setCamera'
  | 'setRegion'
  | 'addMarker'
  | 'removeMarker'
  | 'addPolyline'
  | 'addPolygon'
  | 'addCircle'
  | 'fitToMarkers'
  | 'selectMarker'
  | 'deselectAll'
  | 'setConfiguration'

/**
 * Typed request envelope. The `method` discriminates the `params` shape.
 * The union below gives per-method type narrowing.
 */
export interface MapBridgeRequest {
  method: MapBridgeMethod
  params: Record<string, unknown>
}

/** Strongly typed request variants for each supported method. */
export type TypedMapBridgeRequest =
  | { method: 'setCamera', params: { camera: MapCamera, animated?: boolean } }
  | { method: 'setRegion', params: { region: MapRegion, animated?: boolean } }
  | { method: 'addMarker', params: { marker: MapMarker } }
  | { method: 'removeMarker', params: { id: number } }
  | { method: 'addPolyline', params: { polyline: MapPolyline } }
  | { method: 'addPolygon', params: { polygon: MapPolygon } }
  | { method: 'addCircle', params: { circle: MapCircle } }
  | { method: 'fitToMarkers', params: { padding?: number } }
  | { method: 'selectMarker', params: { id: number } }
  | { method: 'deselectAll', params: Record<string, never> }
  | { method: 'setConfiguration', params: { configuration: MapConfiguration } }

/** Events emitted by the ts-maps runtime back to the Zig core. */
export type MapBridgeEvent =
  | { type: 'tap', coordinate: Coordinate }
  | { type: 'markerTap', markerId: number, coordinate: Coordinate }
  | { type: 'regionChanged', region: MapRegion }
  | { type: 'cameraChanged', camera: MapCamera }

/**
 * Build the full event name used on the bridge (e.g. `map:tap`).
 * Centralized so both sides agree on the exact string.
 */
export function mapEventName(type: MapBridgeEvent['type']): string {
  return `map:${type}`
}
