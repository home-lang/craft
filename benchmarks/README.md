# Zyte Performance Benchmarks

Comprehensive performance benchmarks comparing Zyte against Electron and Tauri using [Mitata](https://github.com/evanwashere/mitata).

## Overview

This benchmark suite compares three desktop application frameworks across multiple dimensions:

- **Zyte**: Native Zig-based desktop framework with GPU acceleration
- **Electron**: Chromium + Node.js based framework
- **Tauri**: Rust + native WebView framework

## Installation

```bash
cd benchmarks
bun install
```

## Running Benchmarks

### Run All Benchmarks
```bash
bun run bench
```

### Run Individual Framework Benchmarks
```bash
# Zyte benchmarks
bun run bench:zyte

# Electron benchmarks
bun run bench:electron

# Tauri benchmarks
bun run bench:tauri
```

### Run Specific Category Benchmarks
```bash
# Startup performance
bun run bench:startup

# Memory benchmarks
bun run bench:memory

# Rendering performance
bun run bench:render
```

## Benchmark Categories

### 1. Application Startup
Measures cold start time from process launch to ready state.

**Expected Results:**
- **Zyte**: ~50ms (native binary, minimal runtime)
- **Tauri**: ~140ms (Rust + WebView initialization)
- **Electron**: ~230ms (Chromium + Node.js startup)

### 2. Memory Footprint
Compares memory usage for 1000 component instances.

**Expected Results:**
- **Zyte**: ~150 KB (lightweight structs)
- **Tauri**: ~300 KB (JS objects + some overhead)
- **Electron**: ~500 KB (React fiber + VDOM overhead)

### 3. IPC Performance
Measures inter-process communication throughput for 10,000 messages.

**Expected Results:**
- **Zyte**: Fastest (direct struct passing, no serialization)
- **Tauri**: Medium (JSON serialization)
- **Electron**: Slowest (JSON + Node.js IPC overhead)

### 4. Rendering Performance
GPU/Canvas rendering command throughput.

**Expected Results:**
- **Zyte**: Fastest (direct GPU commands via Metal/Vulkan)
- **Tauri**: Medium (WebView canvas/WebGL)
- **Electron**: Slower (Chromium WebGL with validation overhead)

### 5. Component Lifecycle
Create/destroy performance for 1000 component cycles.

**Expected Results:**
- **Zyte**: Fastest (simple struct allocation/deallocation)
- **Tauri**: Medium (JS object lifecycle + GC)
- **Electron**: Slowest (React component + fiber overhead + GC)

### 6. Binary Size
Application distribution size comparison.

**Expected Results:**
- **Zyte**: ~3 MB (compact native binary)
- **Tauri**: ~17 MB (Rust binary + frontend assets)
- **Electron**: ~135 MB (full Chromium + Node runtime)

## Performance Advantages of Zyte

### 1. Native Compilation
- No JavaScript runtime overhead
- Direct system calls
- Optimal CPU instruction usage

### 2. Memory Management
- Arena allocators for bulk operations
- Object pooling for component reuse
- No garbage collection pauses
- Deterministic memory cleanup

### 3. GPU Acceleration
- Direct Metal (macOS) / Vulkan (Linux/Windows) access
- No WebGL translation layer
- Hardware-accelerated rendering by default

### 4. Zero-Copy IPC
- Direct memory sharing between processes
- No JSON serialization overhead
- Typed message passing

### 5. Small Binary Size
- Statically linked dependencies
- Dead code elimination
- Optimized for release builds

## Methodology

All benchmarks use Mitata for accurate performance measurement with:
- Warm-up iterations to stabilize JIT/optimization
- Multiple runs for statistical significance
- Percentile analysis (p50, p95, p99)
- Automatic outlier detection

## Understanding the Results

### Reading Benchmark Output

```
Application Startup Time
  Zyte (native binary)            50.23 ms/iter
  Tauri (Rust + WebView)         142.15 ms/iter
  Electron (Chromium + Node)     228.47 ms/iter
```

Lower numbers are better. The results show:
- Zyte is **2.8x faster** than Tauri at startup
- Zyte is **4.5x faster** than Electron at startup

### Statistical Significance

Mitata reports:
- **Mean**: Average performance
- **Min/Max**: Best and worst cases
- **p95/p99**: 95th and 99th percentile (useful for SLA)

## Extending Benchmarks

To add new benchmarks:

1. Create a new file in the appropriate framework folder
2. Import mitata: `import { bench, group, run } from 'mitata';`
3. Define benchmark groups and cases
4. Add to package.json scripts

Example:

```typescript
import { bench, group, run } from 'mitata';

group('My Benchmark Category', () => {
  bench('Test Case', () => {
    // Your test code
  });
});

await run();
```

## CI Integration

These benchmarks can be integrated into CI/CD pipelines:

```yaml
# .github/workflows/benchmarks.yml
- name: Run benchmarks
  run: |
    cd benchmarks
    bun install
    bun run bench
```

## Contributing

When adding benchmarks:
1. Ensure fair comparison (equivalent operations)
2. Include warm-up iterations
3. Document expected results
4. Test on multiple platforms
5. Add to this README

## License

MIT
