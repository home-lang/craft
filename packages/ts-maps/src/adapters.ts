/**
 * Pure conversion functions between Craft's Zig-mirrored map types and
 * the runtime objects used by the ts-maps library. These are deliberately
 * side-effect-free so they can be unit-tested without a DOM.
 *
 * @module @craft-native/ts-maps/adapters
 */

import { Circle, Marker, Polygon, Polyline } from 'ts-maps'
import { LatLng, LatLngBounds } from 'ts-maps'
import type {
  BoundingBox,
  Coordinate,
  MapCamera,
  MapCircle,
  MapMarker,
  MapPolygon,
  MapPolyline,
  MapRegion,
} from './types'
import { markerColorHex, strokePatternDashes } from './types'

// ---------------------------------------------------------------------------
// Coordinates
// ---------------------------------------------------------------------------

/** Convert a Craft `Coordinate` to a ts-maps `LatLng`. */
export function craftCoordToLatLng(coord: Coordinate): LatLng {
  return new LatLng(coord.latitude, coord.longitude)
}

/** Convert a ts-maps `LatLng` back to a Craft `Coordinate`. */
export function latLngToCraftCoord(ll: LatLng): Coordinate {
  return { latitude: ll.lat, longitude: ll.lng }
}

// ---------------------------------------------------------------------------
// Regions / bounds
// ---------------------------------------------------------------------------

/** Convert a Craft `MapRegion` (center + span) to a ts-maps `LatLngBounds`. */
export function craftRegionToBounds(region: MapRegion): LatLngBounds {
  const { center, span } = region
  const halfLat = span.latitude_delta / 2
  const halfLng = span.longitude_delta / 2
  const sw = new LatLng(center.latitude - halfLat, center.longitude - halfLng)
  const ne = new LatLng(center.latitude + halfLat, center.longitude + halfLng)
  return new LatLngBounds(sw, ne)
}

/** Convert a Craft `BoundingBox` to a ts-maps `LatLngBounds`. */
export function craftBoundingBoxToBounds(box: BoundingBox): LatLngBounds {
  return new LatLngBounds(
    craftCoordToLatLng(box.south_west),
    craftCoordToLatLng(box.north_east),
  )
}

/**
 * Convert a ts-maps `LatLngBounds` back to a Craft `MapRegion`. Useful when
 * translating `moveend` events into `regionChanged` bridge events.
 */
export function boundsToCraftRegion(bounds: LatLngBounds): MapRegion {
  const sw = bounds._southWest
  const ne = bounds._northEast
  if (!sw || !ne) {
    return {
      center: { latitude: 0, longitude: 0 },
      span: { latitude_delta: 0, longitude_delta: 0 },
    }
  }
  return {
    center: {
      latitude: (sw.lat + ne.lat) / 2,
      longitude: (sw.lng + ne.lng) / 2,
    },
    span: {
      latitude_delta: ne.lat - sw.lat,
      longitude_delta: ne.lng - sw.lng,
    },
  }
}

// ---------------------------------------------------------------------------
// Camera
// ---------------------------------------------------------------------------

/**
 * ts-maps `setView()` / `easeTo()` option shape. Pulled out so the MapView
 * wrapper and consumers can pass the exact object through without guessing
 * field names.
 */
export interface TsMapsCameraOptions {
  center: LatLng
  zoom: number
  bearing: number
  pitch: number
}

/** Convert a Craft `MapCamera` to a ts-maps-style camera options object. */
export function craftCameraToOptions(cam: MapCamera): TsMapsCameraOptions {
  return {
    center: craftCoordToLatLng(cam.center),
    zoom: cam.zoom,
    bearing: cam.heading,
    pitch: cam.pitch,
  }
}

/**
 * Alias matching the name requested in the SDK spec. Kept distinct from
 * `craftCameraToOptions` in case the upstream runtime ever needs a
 * different shape for `cameraTo…` vs `…ToOptions`.
 */
export function cameraToCamera(cam: MapCamera): TsMapsCameraOptions {
  return craftCameraToOptions(cam)
}

// ---------------------------------------------------------------------------
// Markers & overlays
// ---------------------------------------------------------------------------

/**
 * Convert a Craft `MapMarker` to a ts-maps `Marker`. The returned marker
 * has not yet been added to a map — the caller is responsible for calling
 * `marker.addTo(map)`.
 */
export function craftMarkerToMarker(m: MapMarker): Marker {
  const marker = new Marker(craftCoordToLatLng(m.coordinate), {
    title: m.title ?? undefined,
    draggable: m.is_draggable,
    // Custom icon path is passed through as a string — the runtime can
    // resolve it to a DivIcon or Icon URL as appropriate.
    icon: m.custom_icon ?? undefined,
  } as any)
  // Tag the marker with the Craft-side id so event handlers can round-trip
  // identity back to the Zig core.
  ;(marker as any).__craftMarkerId = m.id
  ;(marker as any).__craftMarkerColor = m.color
  if (m.is_selected)
    (marker as any).__craftSelected = true
  return marker
}

/** Convert a Craft `MapPolyline` to a ts-maps `Polyline`. */
export function craftPolylineToPolyline(pl: MapPolyline): Polyline {
  const latlngs = pl.coordinates.map(craftCoordToLatLng)
  const polyline = new Polyline(latlngs as any, {
    color: markerColorHex[pl.stroke_color],
    weight: pl.stroke_width,
    dashArray: strokePatternDashes[pl.stroke_pattern].join(',') || undefined,
  } as any)
  ;(polyline as any).__craftPolylineId = pl.id
  ;(polyline as any).__craftZIndex = pl.z_index
  return polyline
}

/** Convert a Craft `MapPolygon` to a ts-maps `Polygon`. */
export function craftPolygonToPolygon(pg: MapPolygon): Polygon {
  const rings: LatLng[][] = [pg.exterior_ring.map(craftCoordToLatLng)]
  for (const ring of pg.interior_rings)
    rings.push(ring.map(craftCoordToLatLng))

  const polygon = new Polygon(rings as any, {
    color: markerColorHex[pg.stroke_color],
    weight: pg.stroke_width,
    fillColor: markerColorHex[pg.fill_color],
    fillOpacity: pg.fill_opacity,
  } as any)
  ;(polygon as any).__craftPolygonId = pg.id
  ;(polygon as any).__craftZIndex = pg.z_index
  return polygon
}

/** Convert a Craft `MapCircle` to a ts-maps `Circle`. */
export function craftCircleToCircle(c: MapCircle): Circle {
  const circle = new Circle(craftCoordToLatLng(c.center), {
    radius: c.radius_meters,
    color: markerColorHex[c.stroke_color],
    weight: c.stroke_width,
    fillColor: markerColorHex[c.fill_color],
    fillOpacity: c.fill_opacity,
  } as any)
  ;(circle as any).__craftCircleId = c.id
  return circle
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Build a Craft `MapRegion` from the bounds of an array of coordinates.
 * Mirrors `BoundingBox.fromCoordinates(...).toRegion()` in `maps.zig`.
 */
export function regionFromBounds(coords: Coordinate[]): MapRegion | null {
  if (coords.length === 0)
    return null

  let minLat = 90
  let maxLat = -90
  let minLng = 180
  let maxLng = -180
  for (const c of coords) {
    if (c.latitude < minLat) minLat = c.latitude
    if (c.latitude > maxLat) maxLat = c.latitude
    if (c.longitude < minLng) minLng = c.longitude
    if (c.longitude > maxLng) maxLng = c.longitude
  }

  return {
    center: {
      latitude: (minLat + maxLat) / 2,
      longitude: (minLng + maxLng) / 2,
    },
    span: {
      latitude_delta: maxLat - minLat,
      longitude_delta: maxLng - minLng,
    },
  }
}
