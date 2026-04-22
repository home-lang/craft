/**
 * TypeScript mirrors of the Craft Zig map types defined in
 * `packages/zig/src/maps.zig`. Field names match the Zig struct field names
 * exactly so a straight `JSON.stringify` round-trips cleanly across the
 * bridge without a renaming layer.
 *
 * @module @craft-native/ts-maps/types
 */

// ---------------------------------------------------------------------------
// Providers & map types
// ---------------------------------------------------------------------------

/**
 * Matches `MapProvider` in `maps.zig`. String-literal union so JSON
 * serialization emits the Zig enum tag name directly.
 */
export type MapProvider =
  | 'apple_maps'
  | 'google_maps'
  | 'mapbox'
  | 'openstreetmap'
  | 'here_maps'
  | 'ts_maps'

/** Matches `MapType` in `maps.zig`. */
export type MapType =
  | 'standard'
  | 'satellite'
  | 'hybrid'
  | 'terrain'
  | 'muted_standard'
  | 'satellite_flyover'
  | 'hybrid_flyover'

/** Matches `UserTrackingMode` in `maps.zig`. */
export type UserTrackingMode = 'none' | 'follow' | 'follow_with_heading'

/** Matches `MarkerColor` in `maps.zig`. */
export type MarkerColor =
  | 'red'
  | 'green'
  | 'blue'
  | 'yellow'
  | 'orange'
  | 'purple'
  | 'cyan'
  | 'magenta'

/** Matches `StrokePattern` in `maps.zig`. */
export type StrokePattern = 'solid' | 'dashed' | 'dotted' | 'dash_dot'

/** Matches `MapEvent` in `maps.zig`. */
export type MapEvent =
  | 'region_changed'
  | 'region_will_change'
  | 'did_finish_loading'
  | 'did_fail_loading'
  | 'annotation_selected'
  | 'annotation_deselected'
  | 'annotation_drag_started'
  | 'annotation_dragged'
  | 'annotation_drag_ended'
  | 'user_location_updated'
  | 'camera_changed'
  | 'tap'
  | 'long_press'
  | 'poi_selected'

// ---------------------------------------------------------------------------
// Geographic primitives
// ---------------------------------------------------------------------------

/** Matches `Coordinate` in `maps.zig`. */
export interface Coordinate {
  latitude: number
  longitude: number
}

/** Matches `CoordinateSpan` in `maps.zig`. */
export interface CoordinateSpan {
  latitude_delta: number
  longitude_delta: number
}

/** Matches `MapRegion` in `maps.zig`. */
export interface MapRegion {
  center: Coordinate
  span: CoordinateSpan
}

/** Matches `BoundingBox` in `maps.zig`. */
export interface BoundingBox {
  south_west: Coordinate
  north_east: Coordinate
}

/** Matches `MapCamera` in `maps.zig`. */
export interface MapCamera {
  center: Coordinate
  zoom: number
  pitch: number
  heading: number
}

// ---------------------------------------------------------------------------
// Overlays
// ---------------------------------------------------------------------------

/** Matches `MapMarker` in `maps.zig`. */
export interface MapMarker {
  id: number
  coordinate: Coordinate
  title: string | null
  subtitle: string | null
  color: MarkerColor
  is_draggable: boolean
  is_selected: boolean
  custom_icon: string | null
  anchor_x: number
  anchor_y: number
}

/** Matches `MapPolyline` in `maps.zig` (flattened: `coordinates` is a plain array). */
export interface MapPolyline {
  id: number
  coordinates: Coordinate[]
  stroke_color: MarkerColor
  stroke_width: number
  stroke_pattern: StrokePattern
  is_geodesic: boolean
  z_index: number
}

/** Matches `MapPolygon` in `maps.zig`. */
export interface MapPolygon {
  id: number
  exterior_ring: Coordinate[]
  interior_rings: Coordinate[][]
  fill_color: MarkerColor
  fill_opacity: number
  stroke_color: MarkerColor
  stroke_width: number
  z_index: number
}

/** Matches `MapCircle` in `maps.zig`. */
export interface MapCircle {
  id: number
  center: Coordinate
  radius_meters: number
  fill_color: MarkerColor
  fill_opacity: number
  stroke_color: MarkerColor
  stroke_width: number
}

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/** Matches `MapConfiguration` in `maps.zig`. */
export interface MapConfiguration {
  provider: MapProvider
  map_type: MapType
  shows_user_location: boolean
  user_tracking_mode: UserTrackingMode
  shows_compass: boolean
  shows_scale: boolean
  shows_traffic: boolean
  shows_buildings: boolean
  is_rotate_enabled: boolean
  is_scroll_enabled: boolean
  is_zoom_enabled: boolean
  is_pitch_enabled: boolean
  min_zoom: number
  max_zoom: number
}

/**
 * Sensible defaults matching `MapConfiguration.defaults()` in `maps.zig`,
 * but with the provider set to `ts_maps` — the whole point of this package.
 */
export const defaultMapConfiguration: MapConfiguration = {
  provider: 'ts_maps',
  map_type: 'standard',
  shows_user_location: false,
  user_tracking_mode: 'none',
  shows_compass: true,
  shows_scale: true,
  shows_traffic: false,
  shows_buildings: true,
  is_rotate_enabled: true,
  is_scroll_enabled: true,
  is_zoom_enabled: true,
  is_pitch_enabled: true,
  min_zoom: 0,
  max_zoom: 22,
}

/** Default camera — matches `MapCamera.init(Coordinate.zero)`. */
export const defaultMapCamera: MapCamera = {
  center: { latitude: 0, longitude: 0 },
  zoom: 15,
  pitch: 0,
  heading: 0,
}

// ---------------------------------------------------------------------------
// Hex colors
// ---------------------------------------------------------------------------

/**
 * Hex string map for each `MarkerColor`, derived from `MarkerColor.toRGB()`
 * in `maps.zig`. Used when passing stroke/fill colors to ts-maps.
 */
export const markerColorHex: Record<MarkerColor, string> = {
  red: '#ff3b30',
  green: '#34c759',
  blue: '#007aff',
  yellow: '#ffcc00',
  orange: '#ff9500',
  purple: '#af52de',
  cyan: '#32ade6',
  magenta: '#ff2d55',
}

/**
 * Dash pattern (in pixels) for each stroke pattern. Matches
 * `StrokePattern.dashLengths()` in `maps.zig`.
 */
export const strokePatternDashes: Record<StrokePattern, number[]> = {
  solid: [],
  dashed: [10, 5],
  dotted: [2, 2],
  dash_dot: [10, 5, 2, 5],
}
