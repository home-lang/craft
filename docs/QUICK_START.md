# Craft Quick Start

Craft provides a native CLI and a TypeScript SDK. Desktop apps host web content
in the platform WebView. Mobile apps choose between that web renderer and the
experimental [native STX renderer](guides/native-stx.md), which creates UIKit or
Android controls from a compiled STX bundle without a browser view.

## Create an application

Install the native CLI through Pantry, then create a project with Bun:

```bash
pantry install craft
bun create craft my-app
cd my-app
bun run dev
```

The SDK resolves `craft` on `PATH`. See [Installation](install.md) for platform
requirements and [Native STX](guides/native-stx.md) for mobile route bundles,
renderer configuration and platform capabilities.

When sharing a phone UI across the web, iOS and Android, author the same STX
components and composables for all three targets. STX owns component translation
and reactivity; Craft supplies platform controls and device services. Verify
each host with the same routes and data. A browser preview does not exercise
native permissions, lifecycle, background services or platform navigation.

Native screens and their imported code ship with the app and require a new
build and release to update. Deploying the website changes web pages and server
behavior; it does not replace an installed native bundle.

## Work on Craft itself

Use the toolchain pinned in `pantry.lock`, rather than an arbitrary system Zig.
The core also requires the `zig-js`, `zig-regex` and `zig-gc` sibling checkouts at
the exact commits in `.github/actions/first-party-zig-deps/pins.env`. Follow
[AGENTS.md](../AGENTS.md) for their paths and the managed toolchain setup.

From the repository root:

```bash
bun install --frozen-lockfile
bun run build:core
bun run build:sdk
bun run test
bun run test:sdk
bun run typecheck
bun run lint
```

`bun run test` runs the Zig core suite; `bun run test:sdk` runs the TypeScript
SDK suite. Avoid a bare `bun test` at the root because it can collect managed
toolchain fixtures. Package-specific suites run from their package directories.

The normal CI workflow builds and tests the core on macOS and Linux, checks
Windows packaging, and compiles generated iOS, Watch and Android projects. The
separate Mobile E2E workflow exercises actual simulator/emulator hosts. Inspect
the results for the exact source revision being consumed; a successful build
on one platform does not establish behavior on another.

## Repository layout

| Path | Purpose |
|------|---------|
| `packages/zig/` | Native core and platform bridges |
| `packages/typescript/` | Public `craft-native` SDK |
| `packages/ios/` | iOS project generator and native host templates |
| `packages/android/` | Android project generator and native host templates |
| `packages/create-craft/` | Application scaffolding |
| `scripts/` | Build, package and runtime verification |
| `.github/workflows/` | Platform and release gates |

Component support and lifecycle semantics are documented in the
[Native STX guide](guides/native-stx.md). Binary size and startup measurements
belong in the reproducible [benchmarks](../benchmarks/), rather than a fixed
number in this guide.
