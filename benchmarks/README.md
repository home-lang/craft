# Craft Benchmarks

Hello World benchmarks comparing **Craft**, **Electron**, and **Tauri** using [Bun](https://bun.sh) and [Mitata](https://github.com/evanwashere/mitata).

All three frameworks render the same Hello World HTML. No synthetic simulations — every measurement comes from real processes, real binaries, and real serialization.

## Quick Start

```bash
cd benchmarks
bun install

# Set up all three frameworks
bun run setup

# Run the full suite
bun run bench
```

## Results

Measured on Apple M3 Pro, macOS:

### Startup Time

| Framework | p50 | Method |
|-----------|-----|--------|
| **Craft** | **175 ms** | `--benchmark` flag: create window, print "ready", exit |
| Tauri | 258 ms | Auto-quit after setup + 50ms event loop |
| Electron | 404 ms | Auto-quit after `did-finish-load` |

Craft is **1.5x** faster than Tauri and **2.3x** faster than Electron at startup.

### Bundle Size

| Framework | Binary Size | Distributable |
|-----------|-------------|---------------|
| **Craft** | **4.26 MB** | **4.26 MB** |
| Tauri | 7.69 MB | 7.69 MB |
| Electron | 392.37 MB | 392.37 MB |

Craft is **1.8x** smaller than Tauri and **92.2x** smaller than Electron.

### Process Memory (RSS)

Measured as total RSS across the entire process tree (parent + child processes).

| Framework | Median RSS |
|-----------|-----------|
| **Craft** | **89 MB** |
| Tauri | 105 MB |
| Electron | 369 MB |

Craft uses **1.2x** less memory than Tauri and **4.2x** less than Electron.

### IPC Protocol Overhead

All three use JSON serialization — this measures the overhead of each framework's message envelope format.

| Framework | Single message | 1k messages |
|-----------|---------------|-------------|
| **Craft** | **672 ns** | **228 us** |
| Tauri | 778 ns | 297 us |
| Electron | 844 ns | 330 us |

Craft's minimal envelope is **1.16x** faster than Tauri and **1.26x** faster than Electron.

## What's Measured

| Benchmark | File | What it measures | Method |
|-----------|------|-----------------|--------|
| **Bundle Size** | `size.bench.ts` | Real binary/distributable sizes on disk | `fs.statSync` + recursive `dirSize` |
| **IPC Overhead** | `ipc.bench.ts` | JSON serialization with each framework's message format | mitata micro-benchmark |
| **Memory** | `memory.bench.ts` | RSS of entire process tree after 3s stabilization | `ps -o rss=` across all child PIDs |
| **Startup** | `startup.bench.ts` | Cold-start time (spawn → ready → exit) | `performance.now()` across 10 iterations |

## Run Individual Benchmarks

```bash
bun run bench:size      # Bundle/binary size comparison
bun run bench:ipc       # IPC protocol micro-benchmarks
bun run bench:memory    # Process memory (RSS)
bun run bench:startup   # Startup time
```

## Hello World Apps

Each framework runs the same minimal HTML (`apps/hello.html`):

```
apps/
├── hello.html              # Shared HTML — identical for all 3
├── craft.ts                # Craft: CraftApp + show()
├── electron/
│   ├── main.js             # Electron: BrowserWindow + did-finish-load
│   └── package.json
└── tauri/
    ├── src/index.html
    └── src-tauri/
        ├── src/main.rs     # Tauri: Builder + setup()
        ├── Cargo.toml
        └── tauri.conf.json
```

## Fairness Notes

- **IPC**: All three benchmarks do `JSON.stringify` + `JSON.parse`. The only variable is the message envelope structure each framework uses. Craft does NOT get a free pass — it uses the same serialization mechanism.
- **Memory**: RSS is measured for the **entire process tree**, not just the main process. This is critical for Electron which spawns renderer + GPU helper processes.
- **Startup**: All three frameworks auto-quit in benchmark mode. Craft uses `--benchmark` flag, Electron and Tauri use `BENCHMARK=1` env var. Electron quits after `did-finish-load` (full page load), Tauri quits ~50ms after `setup()`, and Craft quits immediately after window creation.
- **Size**: Measures actual files on disk. Electron's size includes the full Chromium + Node.js runtime that gets bundled into distributed apps.

## Prerequisites

| Framework | Required | Install |
|-----------|----------|---------|
| **Craft** | Zig binary | `cd packages/zig && zig build` |
| **Electron** | npm package | `cd benchmarks/apps/electron && bun install` |
| **Tauri** | Rust binary | `cd benchmarks/apps/tauri/src-tauri && cargo build --release` |

Benchmarks gracefully skip any framework that isn't installed.
