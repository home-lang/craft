# ts-maps Demo (Craft example)

An interactive, zero-API-key map app built on top of
[`@craft-native/ts-maps`](../../packages/ts-maps). It launches in a Craft
WebView window (desktop, or a Craft mobile shell) and demonstrates the full
`MapView` surface: preset pins, tap-to-drop draggable markers, camera control,
and live basemap swapping.

## What you see

```text
┌────────────────┬──────────────────────────────────────────────────┐
│ ts-maps Demo   │                                                  │
│                │                                                  │
│ [Recenter]     │                  (OSM / Esri tiles)              │
│ [Fit markers]  │                                                  │
│ [Clear user ▸] │           •  Central Park                        │
│ [Toggle ◐ sat] │                                                  │
│                │                •  Empire State Building          │
│ lat  40.7128   │                                                  │
│ lng -74.0060   │                                                  │
│ zoom 11.0      │                                                  │
│ tiles osm      │         •  Statue of Liberty                     │
│                │                                                  │
│ Tap the map    │                                                  │
│ to drop a pin. │                                                  │
└────────────────┴──────────────────────────────────────────────────┘
```

- **Left pane:** sidebar with buttons + a monospaced lat/lng/zoom readout.
- **Right pane:** the full-bleed map.
- On tap anywhere on the map background, a **draggable blue pin** is added

  with a popup showing the tapped coordinates.

- The three preset pins (Statue of Liberty, Central Park, Empire State

  Building) each open a title/subtitle popup when tapped.

- **Toggle satellite** swaps between OpenStreetMap tiles and Esri's free

  World Imagery tiles — no API keys required.

- The readout updates live via the `onCameraChanged` prop on `createMapView`.

## Run it

From anywhere:

```sh
cd /Users/chrisbreuer/Code/Tools/craft && \
  bun install && \
  cd examples/ts-maps-demo && \
  bun run dev
```

What `bun run dev` does:

1. Starts a tiny Bun dev server on `<http://localhost:3000>` (see

   `scripts/serve.ts`) that serves `src/index.html` and transpiles the `.ts`
   entry on the fly.

2. Launches the native Craft WebView pointed at that URL via `craft dev`.

The Craft native binary is produced by `packages/zig` — if it hasn't been
built yet, run `bun run build:core` from the monorepo root first (or just
`zig build` inside `packages/zig/`).

You can also open `<http://localhost:3000>` in any regular browser while `bun
run serve` is running — the demo is WebView-agnostic.

## File layout

```
examples/ts-maps-demo/
├── package.json          # @craft/example-ts-maps-demo, workspace deps
├── tsconfig.json         # extends the monorepo tsconfig, adds DOM libs
├── craft.toml            # native window config (consumed by `craft dev`)
├── craft.config.ts       # SDK-level cross-platform config (iOS/Android/…)
├── README.md             # this file
├── scripts/
│   └── serve.ts          # Bun static server
├── src/
│   ├── index.html        # entry, loads ts-maps CSS + our script
│   ├── index.ts          # bootstraps the MapView, wires the sidebar
│   └── styles.css        # two-pane layout, dark theme
└── assets/               # reserved for future icons / images
```

## How it uses `@craft-native/ts-maps`

```ts
import { createMapView } from '@craft-native/ts-maps'
import type { Coordinate, MapMarker } from '@craft-native/ts-maps'

const view = createMapView({
  initialCamera: { center: { latitude: 40.7128, longitude: -74.006 }, zoom: 11, pitch: 0, heading: 0 },
  markers: presetMarkers,
  onTap: (coord) => dropUserMarker(coord),
  onMarkerTap: (id, coord) => console.log('tap', id, coord),
  onCameraChanged: (camera) => updateReadout(camera.center, camera.zoom),
})
document.getElementById('map-host')!.appendChild(view.container)
```

The basemap toggle uses the re-exported `tileLayer` factory from the same
package (it forwards through to the `ts-maps` runtime).

## Platforms

The demo is built against Craft's cross-platform WebView. The same `src/`
and `craft.config.ts` produce desktop (macOS/Linux/Windows), iOS, and Android
builds via `bun run build:<platform>` — see the monorepo root's `craft` CLI.
