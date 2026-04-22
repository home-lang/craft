/**
 * `@craft-native/ts-maps` — SDK binding that lets Craft apps render
 * interactive maps via the in-house `ts-maps` runtime. Pairs with the
 * `MapProvider.ts_maps` variant in `packages/zig/src/maps.zig`.
 *
 * Re-exports the full ts-maps public API plus Craft-native helpers
 * (`createMapView`, type mirrors, adapters, bridge protocol).
 *
 * @module @craft-native/ts-maps
 */

// Re-export the full ts-maps runtime so consumers only need to install a
// single package. Consumers can `import { TsMap, marker } from '@craft-native/ts-maps'`.
export * from 'ts-maps'

// Craft-native MapView component.
export {
  createMapView,
  type ComponentProps,
  type MapViewInstance,
  type MapViewProps,
} from './MapView'

// Type mirrors of the Zig structs.
export {
  defaultMapCamera,
  defaultMapConfiguration,
  markerColorHex,
  strokePatternDashes,
  type BoundingBox,
  type Coordinate,
  type CoordinateSpan,
  type MapCamera,
  type MapCircle,
  type MapConfiguration,
  type MapEvent,
  type MapMarker,
  type MapPolygon,
  type MapPolyline,
  type MapProvider,
  type MapRegion,
  type MapType,
  type MarkerColor,
  type StrokePattern,
  type UserTrackingMode,
} from './types'

// Adapters (pure fns) for round-tripping between Craft and ts-maps types.
export {
  boundsToCraftRegion,
  cameraToCamera,
  craftBoundingBoxToBounds,
  craftCameraToOptions,
  craftCircleToCircle,
  craftCoordToLatLng,
  craftMarkerToMarker,
  craftPolygonToPolygon,
  craftPolylineToPolyline,
  craftRegionToBounds,
  latLngToCraftCoord,
  regionFromBounds,
  type TsMapsCameraOptions,
} from './adapters'

// Bridge protocol constants/types.
export {
  BRIDGE_NAMESPACE,
  mapEventName,
  type MapBridgeEvent,
  type MapBridgeMethod,
  type MapBridgeRequest,
  type TypedMapBridgeRequest,
} from './bridge-protocol'

// createMap is the underlying ts-maps factory; re-export under its original
// name for parity with the spec which mentions `createMap` as a Craft export.
export { createMap } from 'ts-maps'

/**
 * Provider tag matching `MapProvider.ts_maps` in the Zig core. Useful when
 * building a `MapConfiguration` programmatically without magic strings.
 */
export const tsMapsProvider = 'ts_maps' as const

/**
 * Alias preserved for callers that imported the two helpers by spec name.
 * `coordinateFromLatLng(LatLng) -> Coordinate`, `latLngFromCoordinate(Coordinate) -> LatLng`.
 */
export { latLngToCraftCoord as coordinateFromLatLng } from './adapters'
export { craftCoordToLatLng as latLngFromCoordinate } from './adapters'
