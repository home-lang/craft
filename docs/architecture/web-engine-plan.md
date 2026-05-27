# Craft Web Engine — "Loom" — Design & AI-Build Plan

> Status: **Proposal / planning**. Working codename: **Loom** (it weaves DOM + style into
> layout and paint — fits the "craft" theme). Rename freely.
>
> Goal: build a *more performant, fully homegrown WebKit alternative* in Zig — including its own
> JavaScript engine — living inside Craft and reusable by [`~/Code/Home/lang`](../../../Home/lang)
> as the basis of its "UI world".
>
> **Hard constraint: everything homegrown.** No JavaScriptCore, no V8, no HarfBuzz, no Skia, no
> external C libraries. Built on Zig + the homegrown `~/Code/Libraries/zig-*` libraries, distributed
> via **pantry**. The only things below us are the OS windowing/GPU primitives (Metal, Cocoa, Win32,
> Wayland/X11) — those are platform targets, not dependencies.
>
> Toolchain: Zig **0.17.0-dev**, pinned via pantry (`deps.yaml` / `pantry.jsonc`:
> `ziglang.org: "^0.17.0-dev"`; `packages/zig/build.zig.zon`: `minimum_zig_version = "0.17.0-dev"`).

---

## 0. TL;DR

- **Don't build a browser. Build an embeddable, app-focused engine** that renders a *curated, modern*
  subset of HTML/CSS/JS. Craft/lang apps are author-controlled content, so we never need quirks
  mode, legacy floats, or 25 years of web-compat hacks. The curated subset is what makes a
  homegrown engine tractable.
- **We are the alternative to *both* WebKit and JavaScriptCore.** Bun reused JSC and won on the
  host runtime; we go further — a **homegrown JS engine in Zig** plus a homegrown render pipeline.
  That's the bigger bet, justified only by (a) ruthless scope curation and (b) the AI build loop below.
  **This has started**: the JS engine lives as the standalone [`zig-js`](../../../Libraries/zig-js)
  library — a pure-Zig **JavaScriptCore C-API drop-in** (it exports `JSGlobalContextCreate`,
  `JSEvaluateScript`, `JSValueMake*`, … so it links in place of `JavaScriptCore.framework`). v1
  (lexer → Pratt parser → tree-walk interpreter) covers a broad subset — objects, arrays, member
  access, `this`, `new`/constructors, `instanceof`, `throw`/`try`/`catch`/`finally`, `for`/`while`,
  `break`/`continue`, `++`/`--`, compound assignment, closures, arrows, and the built-in `Error`
  family — passing 33 unit tests + a 33/33 smoke suite under zig 0.17-dev, and it runs the **real
  tc39/test262** corpus (a vendored submodule) at **~25% of `language/`** today. The tree-walker is
  the correctness bootstrap; the perf endgame (bytecode VM → inline caches → JIT) is §7. Consumed by
  both lang's runtime and craft's Loom (`engine/js/`).
- **Coexist, don't replace.** Ship Loom behind Craft's existing `RenderBackend` abstraction next to
  WKWebView/WebView2/WebKitGTK. Per-window opt-in (`engine: 'webview' | 'loom' | 'auto'`); fall back
  to webview for anything unsupported. Craft never regresses; Loom earns each default-flip by passing
  differential tests.
- **WebKit is now our oracle and conformance corpus** (no longer a blocker — see below). 126,960
  `LayoutTests` with committed `-expected.txt`/`-expected.png` baselines + `JSTests/test262` give us
  millions of executable, baselined tests for free.
- **Built on homegrown libs:** `zig-regex` (RegExp + tokenizers), `zig-tls` (HTTPS), `zig-crosswind`
  (the utility-CSS fast path Craft already uses), `zig-test-framework`, `zig-benchmarks`. Wired via
  `build.zig.zon` + pantry.
- **Reuse in lang for free.** lang is Zig 0.17 self-hosted with no UI today and a Craft hook already
  in its `build.zig`. A pure-Zig, dependency-free engine drops in as a native module + C ABI.

### ✅ Former blocker now resolved
`/Users/chrisbreuer/Code/WebKit` (Bun's WebKit fork) is now fully checked out — **19 GB** of source
+ tests. This is no longer a blocker; it's our most valuable asset (oracle + conformance corpus, §6).

---

## 1. Strategic framing — beyond the Bun playbook

| | Node | Bun | **Loom (this plan)** |
|---|---|---|---|
| JS VM | V8 (reused) | JavaScriptCore (reused) | **Homegrown, in Zig** |
| Render/host | libuv + C++ glue | Zig host runtime | **Homegrown Zig pipeline** |
| Where the win comes from | — | rewrote the *host* around a reused VM | **rewrite the whole stack, no legacy, no FFI tax, comptime everywhere** |

Bun's lesson was "the VM wasn't the moat — the host was," so it reused JSC. **We're making the
harder bet:** the VM *and* the host are both homegrown. That is only sane because:

1. **We don't need web-platform completeness** — a curated subset (§2) is orders of magnitude smaller
   than full WebKit/JSC.
2. **The conformance target is fully baselined and executable** — WebKit's `LayoutTests` and
   `JSTests/test262` tell us exactly when we're correct (§6), so an AI build loop can grind against a
   green/red signal instead of guessing.
3. **Zig changes the economics** — `comptime` code generation, data-oriented design, and no
   C++/FFI boundary mean less code that runs faster, which is the entire reason to do this rather
   than embed an existing engine.

Everything is **Build (homegrown)**:

| Layer | Approach | Foundation |
|---|---|---|
| **JS engine** | Homegrown: lexer → parser → bytecode VM → GC → builtins; RegExp via `zig-regex` | gated by `JSTests/test262` |
| HTML parser | Homegrown WHATWG tokenizer + tree construction | `html5lib-tests` + WebKit baselines |
| CSS parser + cascade | Homegrown tokenizer/parser/selectors; `comptime` property tables | `zig-regex` for selector lexing |
| Utility-CSS fast path | Reuse **`zig-crosswind`** to compile Tailwind-like classes directly | already used by Craft apps |
| Style resolution | Homegrown, data-oriented (SoA) | — |
| Layout (block/inline/flex/grid) | Homegrown | WebKit layout baselines |
| Text shaping | Homegrown OpenType/TrueType parser + shaper (Latin first, complex scripts later) | UAX #14/#9 |
| Font rasterization | Homegrown glyph outline rasterizer (bezier fill + AA) | — |
| Image decode | Homegrown PNG/JPEG decoders + DEFLATE/inflate | — |
| Networking / TLS | Reuse **`zig-tls`** + Craft `http.zig` | — |
| Paint / display list | Homegrown; builds on `renderer.zig` `Canvas` | — |
| Compositor / GPU | Homegrown Metal/Vulkan/D3D; builds on `gpu.zig` | OS GPU APIs (not deps) |
| Allocator | Zig std arenas/allocators | (WebKit uses bmalloc — we don't need it) |

**The single biggest line item is the JS engine** — historically a multi-year effort. The curated
language target + `test262` as a ratchet are what make it approachable; see the risk table (§10).

---

## 2. The one decision that defines everything: scope

| Option | Description | Verdict |
|---|---|---|
| **A. Full browser engine** | Render arbitrary websites, match WebKit on the open web | ❌ Not realistic. The web platform is effectively infinite. |
| **B. Embeddable app-UI engine** | A *curated, modern* HTML/CSS/JS subset for author-controlled apps | ✅ **North star.** Finite, testable, where Craft/lang live. |
| **C. Coexist / hybrid** | Loom alongside WKWebView behind `RenderBackend`; opt-in, fall back for anything unsupported | ✅ **Delivery vehicle.** Zero-regression migration path. |

**Recommendation: pursue B, delivered via C.** With everything homegrown, the curated subset is not
just a strategy — it's a survival requirement.

**Curated subset for v1:**

- **HTML:** the standard parsing algorithm for the common element set; no `document.write` quirks.
- **CSS:** box model; `display: block | inline | inline-block | flex | grid | none`; positioning
  (`static | relative | absolute | fixed | sticky`); color/length/`calc()`/custom properties;
  transforms, transitions, animations; media queries; modern selectors. **Deferred:** floats-as-layout,
  multicol, vertical writing modes, print. **Fast path:** crosswind utility classes compile directly.
- **JS:** a modern ECMAScript subset sized to what app frameworks (the Craft SDK, stx, crosswind
  output) actually emit — full expression/statement/closure/class/module/Promise/async support,
  gated by the `test262` slices that matter; exotic/legacy corners deferred and tracked by failing
  `test262` cases.

Anything outside the subset → Loom reports "unsupported feature X", logs it, and (in `auto` mode)
the window falls back to WKWebView. The unsupported-feature log *is* the backlog.

---

## 3. Where the performance comes from

1. **No legacy.** One modern layout model; one modern JS subset. No quirks, no dead paths.
2. **Data-oriented design.** Style/layout and the JS object model stored as struct-of-arrays;
   cache-friendly linear passes instead of pointer-chasing virtual dispatch.
3. **`comptime`.** CSS property perfect-hashes, keyword tables, selector-matcher specialization,
   and JS bytecode dispatch tables generated at compile time — zero runtime lookup cost.
4. **Retained mode + precise invalidation.** Dirty-bit propagation; re-style/layout/paint only the
   affected subtree.
5. **GPU-first compositing.** Display list → Metal/Vulkan/D3D directly (Craft's `gpu.zig` already
   creates the Metal device).
6. **Zero-copy, in-process, single-language bridge.** JS engine, DOM, and host are *all Zig in one
   address space*. No JSC C-API boundary, no IPC, no JSON marshalling for host calls — direct struct
   passes. This is an advantage even Bun doesn't have (Bun still crosses the Zig↔JSC C-API line).
7. **Arena memory model + a JS GC we control.** Per-frame/per-document arenas for the render side;
   a purpose-built GC for the JS heap tuned for short-lived UI workloads (no general-web pause budget).
8. **Small surface = small binary + fast cold start.** Beat the WKWebView cold-start/per-window-memory
   baselines already tracked in [`benchmarks/`](../../benchmarks).

---

## 4. Architecture

### Pipeline

```
 bytes ─► HTML parse ─► DOM ─► style resolve ─► layout ─► paint (display list) ─► composite (GPU) ─► present
                         ▲           ▲             │              │
                         │           │            hit-test    damage/invalidate
              homegrown JS VM ◄── DOM bindings ◄──┘
                         │
                    event loop / microtasks / timers / fetch (zig-tls + http.zig)
```

### Proposed module layout (`packages/zig/src/engine/`)

| Module | Responsibility | Foundation / replaces |
|---|---|---|
| `engine/loom.zig` | Public engine API; owns a `Document`, drives the frame loop | new |
| `engine/js/` | **Homegrown JS engine** (see below) | `zig-regex` for RegExp |
| `engine/html/` | HTML5 tokenizer + tree construction | new |
| `engine/dom/` | Node tree, mutation, `getElementById`/`querySelector`, ranges | new |
| `engine/css/` | CSS tokenizer, parser, selector engine, `comptime` property tables | `zig-regex` |
| `engine/css/crosswind.zig` | Compile crosswind utility classes → computed style (fast path) | **`zig-crosswind`** |
| `engine/style/` | Cascade, inheritance, custom props, computed style, media queries | new |
| `engine/layout/` | Box tree; block/inline/flex/grid; fragmentation | new |
| `engine/text/` | **Homegrown** OpenType/TrueType parser + shaper + line breaking | new |
| `engine/raster/` | **Homegrown** glyph/path rasterizer (bezier fill + anti-aliasing) | builds on `renderer.zig` |
| `engine/image/` | **Homegrown** PNG/JPEG decoders + DEFLATE/inflate | new |
| `engine/paint/` | Display-list builder; paint commands | builds on `renderer.zig` `Canvas` |
| `engine/compositor/` | Layer tree, tiling, damage, GPU submit | builds on `gpu.zig` (Metal live) |
| `engine/events/` | Event dispatch, hit testing, focus | new |
| `engine/loader/` | Resource fetch, image decode, cache | `zig-tls` + Craft `http.zig` |
| `engine/a11y/` | Accessibility tree → platform a11y APIs | bridges existing a11y |
| `engine/devtools/` | Minimal Chrome DevTools Protocol server | new |

### The homegrown JS engine — `zig-js` (the JSC drop-in)

> **Now exists** at [`~/Code/Libraries/zig-js`](../../../Libraries/zig-js): a pure-Zig
> JavaScriptCore **C-API drop-in**. It implements the exact `extern "c"` surface that
> `~/Code/Home/lang`'s `packages/runtime/src/jsc/extern_fns.zig` declares against the system
> `JavaScriptCore.framework`, so lang links `libzig-js.a` instead with zero call-site changes.
> v1 (lexer → Pratt parser → tree-walk interpreter → JSC C-API) builds and passes 33 unit tests
> on zig 0.17-dev — including `JSEvaluateScript("1+1") == 2`, lang's M3 number/string round-trips,
> functions/closures/arrows, **objects, arrays, member access, `this`, `new`/constructors,
> `instanceof`, `throw`/`try`/`catch`/`finally`, `for`/`while`, `break`/`continue`, `++`/`--`,
> compound assignment, and the built-in `Error` family** — plus a 33/33 smoke suite
> (`zig build conformance`). It runs the **real tc39/test262** corpus (vendored as a git submodule)
> via `zig build test262`: **3590/14385 (~25%) of `language/`** pass today through a subset harness
> shim. Next: template literals, `switch`, `for-of`/`for-in`, then the `Object`/`Array`/`String`/
> `JSON` builtins; the perf rewrite (bytecode VM → shapes/inline caches → JIT) follows. craft's
> `engine/js/` is a thin consumer of this library, not a separate engine.

The largest subsystem; built as its own internal pipeline, gated end-to-end by `test262`:

| Submodule | Responsibility |
|---|---|
| `js/lexer.zig` | ECMAScript tokenizer (`zig-regex` for numeric/identifier classes where useful) |
| `js/parser.zig` | Recursive-descent → AST (ESTree-shaped) |
| `js/bytecode.zig` | AST → register/stack bytecode (start simple; design for later inline caches) |
| `js/vm.zig` | Bytecode interpreter; call frames; exceptions |
| `js/values.zig` | NaN-boxed `Value`, object model (hidden classes/shapes for fast property access) |
| `js/gc.zig` | Garbage collector (start: mark-sweep; evolve to generational for UI churn) |
| `js/builtins/` | `Object`, `Array`, `String`, `Math`, `JSON`, `Promise`, `Map`/`Set`, `RegExp` (→ `zig-regex`) |
| `js/event_loop.zig` | Microtask/macrotask queues, timers — integrates with the render frame loop |
| `js/dom_bindings.zig` | Bind DOM/CSSOM/events into the VM with **zero-copy** native calls |

Sequencing inside the JS track: **lexer/parser (→ test262 parse pass) → tree-walk interpreter
(→ test262 language semantics) → bytecode VM (→ perf) → builtins (→ test262 built-ins) → shapes +
inline caches → optional baseline JIT (later, optional).** A correct tree-walker that passes test262
beats a fast VM that's wrong; correctness first, speed second.

> **Status:** the pipeline through tier-3 exists and is the default execution path. zig-js has a
> lexer/parser, a tree-walk interpreter (the correctness oracle + fallback), and a bytecode VM
> (`bytecode.zig`/`compiler.zig`/`vm.zig`) with **tier-1** (lowers nearly the whole language),
> **tier-2** slot-allocated locals + frame-linked closures (`Frame{slots,parent}`), and **tier-3**
> object shapes/hidden classes (`shape.zig`) + monomorphic inline caches. `zig build bench` shows
> ~1.6–1.85× over the tree-walker; the fallback keeps test262 flat at ~25% across every tier. Next:
> NaN-boxed values, a generational GC (replaces the arena), then a baseline JIT — plus widening
> test262 via breadth features (template literals, `switch`, the `Object`/`Array`/`String`/`Math`/
> `JSON` builtins).

### What already exists to build on

- `packages/zig/src/renderer.zig` — real CPU `Canvas` (`drawRect/Circle/Line`, pixel buffer) +
  retained `Component` tree. **`drawText` is a stub** → replaced by `engine/text/` + `engine/raster/`.
  `RenderBackend` enum is `{ webview, native, hybrid }` → **add `loom`**.
- `packages/zig/src/gpu.zig` — `GPUBackend { auto, metal, vulkan, opengl, software }`, live
  `MTLCreateSystemDefaultDevice()` handle. No pipeline yet → `engine/compositor/`.
- `packages/zig/src/macos.zig` (5.8k LOC) — WKWebView host; Loom renders into the same
  `NSView`/`CAMetalLayer`.
- `packages/zig/src/http.zig` + **`zig-tls`** → `engine/loader/`.
- `packages/zig/src/js/craft-bridge.js` + `BRIDGE_PROTOCOL.md` — the wire protocol Loom must keep
  working (§5), now running inside *our* VM.

---

## 5. Integration into Craft (zero-regression)

1. **`RenderBackend.loom`.** Extend the enum in `renderer.zig`; thread a per-window choice through
   `createWindowWithStyle` so a window hosts WKWebView *or* Loom in the same native view.
2. **Surface.** Loom renders to the platform GPU surface already available: `CAMetalLayer` (macOS),
   DXGI swapchain (Windows), GL/Vulkan surface (Linux) — attached to the same `NSView`/`HWND`/`GtkWidget`.
3. **Keep `BRIDGE_PROTOCOL` byte-for-byte.** Implement `window.webkit.messageHandlers.craft.postMessage`
   and `window.__craftBridgeResult` *inside Loom's homegrown JS global*. Result: all 50+ `bridge_*.zig`
   modules and the entire TypeScript SDK (`packages/typescript`) work under Loom with **no changes**.
4. **Config flag.** `craft.config.ts` gains `engine?: 'webview' | 'loom' | 'auto'` (default `webview`).
   `auto` = try Loom, fall back to webview on any unsupported feature.
5. **DevTools.** Minimal **CDP** endpoint in `engine/devtools/` so existing inspectors attach.
6. **Distribution.** Honor the pantry contract (`CLAUDE.md`): Loom links into the `craft` binary
   shipped via the pantry registry. No new runtime path probing in `binary-resolver.ts`.

---

## 6. How AI builds this — the methodology (the core of the request)

The engine is built by AI agents in a **spec-anchored, oracle-gated, test-first loop**. With WebKit
on disk, the oracle and corpus are enormous and *already baselined*. Rule: **code advances only when
executable tests are green** — never on visual plausibility or model confidence.

### 6.1 The oracle is now free (committed baselines)

WebKit's `LayoutTests` ship `-expected.txt` (render-tree/text dumps) and `-expected.png` (pixel
baselines) **committed alongside each test** — 126,960 tests. So for most conformance we **don't even
need to build WebKit**: run the test in Loom, diff against WebKit's own committed expected output.

```
LayoutTests/foo.html ──► Loom ──► {render-tree dump, pixel raster}
                                        │ diff (tolerances)
   WebKit committed foo-expected.txt ───┤
   WebKit committed foo-expected.png ───┘
                                   AI triages divergence ─► fix ─► re-run
```

For dynamic/interactive cases, optionally build **headless WebKit** (`WebKitTestRunner`/
`DumpRenderTree`) from the 19 GB tree for live diffing, but the committed baselines cover the bulk.

### 6.2 Conformance corpora (all on disk now)

| Corpus | Location | Gates |
|---|---|---|
| **WebKit LayoutTests** | `~/Code/WebKit/LayoutTests` (126,960, baselined) | HTML/CSS/layout/paint |
| **test262** | `~/Code/WebKit/JSTests/test262` | **JS engine** (official ECMAScript suite) |
| **es6 / stress** | `~/Code/WebKit/JSTests/{es6,stress}` | JS semantics + edge cases |
| **html5lib-tests** | import | HTML tokenizer/tree construction |

Build a `loom-conformance` runner (extend [`benchmarks/`](../../benchmarks) + use
`zig-test-framework`) reporting **pass % per subsystem**. These percentages are the project's
North-Star progress metric — one for the render pipeline, one for the JS engine.

### 6.3 Spec-anchored generation, decomposed for parallel agents

The hard algorithms are precisely specified — ideal for AI + a green/red test loop:

- HTML tokenizer & tree construction → WHATWG HTML spec (a literal state machine).
- CSS cascade & specificity → CSS Cascading spec.
- Flexbox / Grid → their W3C algorithms (deterministic).
- **ECMAScript** → the spec's step-by-step abstract operations, gated by `test262`.

Each subsystem has a crisp contract (`input struct → output struct`), so agents work in parallel:

| Agent | Contract | Gated by |
|---|---|---|
| HTML parser | `bytes → DOM` | html5lib-tests + WebKit dumps |
| CSS parser | `text → stylesheet AST` | WebKit css baselines |
| Selector/cascade | `(DOM, sheets) → computed styles` | WebKit `-expected.txt` |
| Flexbox / Grid | `box tree → geometry` | WebKit layout baselines |
| Text/raster | `(runs, font) → glyphs → pixels` | WebKit `-expected.png` |
| **JS lexer/parser** | `source → AST` | `test262` (parse phase) |
| **JS VM/builtins** | `AST/bytecode → result` | `test262` (semantics + built-ins) |

Each agent's loop: **read spec section + failing tests → write/patch Zig → `zig build test` +
conformance + oracle diff → red/green → commit.** Wire into the repo's `/code-review` and test steps.

### 6.4 Fuzzing & property tests

- **Differential fuzzing:** generate random *valid* HTML/CSS/JS; diff Loom vs WebKit baselines (or
  headless WebKit); auto-file divergences. WebKit's `JSTests/stress` and existing fuzz corpora seed this.
- **Property tests:** layout idempotence; style order-independence; JS — `eval(uneval(x)) == x` style
  round-trips; GC invariants (no live object collected, no leak after N cycles).

### 6.5 Performance gates (non-negotiable, in CI)

Use **`zig-benchmarks`** to track, per commit, vs WKWebView/JSC baselines: cold-start ms, per-window
memory, **style+layout ms for N nodes**, frame time (16.6 ms / 8.3 ms), **JS throughput on the
SunSpider/JetStream-style micro-suites bundled in WebKit**, binary-size delta. **CI fails on regression.**

### 6.6 License discipline (clean-room)

WebKit is **LGPL/BSD**; JavaScriptCore likewise. We **reference behavior** (via baselines/specs) and
**reimplement in Zig** — we do **not** copy WebKit/JSC source into Loom. The oracle observes *outputs*,
not source. Reading the spec and observing test baselines is clean; copying code is not. Keep a
provenance note per module.

### 6.7 Guardrail against AI over-claiming

Every "done" claim must cite: (a) a conformance pass % (LayoutTests or test262), (b) a green oracle
diff for the feature, (c) no perf regression. The harness — not the model — is the source of truth.

---

## 7. Reuse in `~/Code/Home/lang` (the end goal)

Why this is clean:

- lang is **Zig 0.17.0-dev self-hosted** — same compiler as Craft. No ABI mismatch.
- lang's `build.zig` **already has a Craft integration flag** + per-platform webview linking.
- lang has **no UI today** — only `packages/graphics/` *stubs*. Its roadmap explicitly wants a
  "comptime web framework" and "type-safe HTML templates." **Loom fills a stated gap.**
- Because Loom is **pure Zig with zero external/C deps**, vendoring it into lang is trivial — no
  third-party build systems, no FFI shims, no JSC to cross-compile.

Plan:

1. **Factor Loom into a standalone pantry package** (`loom`, à la the other `zig-*` libs:
   `build.zig.zon` + pantry naming), consumed by *both* Craft and lang.
2. **Two surfaces:** native Zig module (`import ui { Window, View, Document }`) and a stable **C ABI**.
3. **comptime web framework, realized:** lang's type-safe templates compile *directly* to Loom's
   retained box/DOM tree — skipping the HTML-string → parse round-trip. Something WKWebView cannot do.
4. Share one GPU abstraction between lang's `packages/graphics/` and Loom's `engine/compositor/`.
5. Because the JS engine is ours, lang could even share VM infrastructure (its roadmap mentions a Bun
   runtime port) — a single homegrown JS engine across lang's runtime *and* Loom's DOM scripting is a
   strategic option worth evaluating early.

---

## 8. Phased roadmap with conformance gates

Two parallel tracks — **Render** and **JS** — converge at Phase 3. Each phase exits only on a green
(executable) gate.

### Phase 0 — Foundations & harness
- Wire homegrown deps into `packages/zig/build.zig.zon`: `zig_regex`, `zig_tls`, `zig_crosswind`,
  `zig_test_framework`, `zig_bench`.
- Build the **oracle/conformance runner** against WebKit committed baselines + `test262` (§6.1–6.2),
  and the **perf bench** (§6.5).
- Scaffold `packages/zig/src/engine/` skeleton (both tracks) with empty contracts + golden stubs.
- **Gate:** runner executes one `LayoutTests` case and one `test262` case end-to-end, reporting pass/fail
  against committed baselines; empty conformance % published to CI.

### Render track

- **R1 — Static render MVP (no JS):** HTML parse → DOM; CSS parse → cascade → computed style;
  block + inline layout; homegrown **text + raster** (replacing `renderer.zig` `drawText` stub);
  GPU paint via `gpu.zig`. **Gate:** Craft's static docs/example pages match WebKit baselines (SSIM ≥ target).
- **R2 — Layout completeness:** flexbox, grid, full box model, positioning, `calc()`, transforms +
  crosswind fast path. **Gate:** WebKit flex/grid LayoutTests pass % ≥ target.
- **R4 — Compositing & motion:** layer tree, GPU compositing, scrolling, transitions/animations.
  **Gate:** frame-time budget met on the perf bench; no jank on stress fixtures.
- **R5 — Platform completeness:** image codecs, font fallback, a11y tree, **CDP DevTools**,
  Windows/Linux compositor parity. **Gate:** a11y audit passes; DevTools attaches; cross-platform raster parity.

### JS track

- **J1 — Lexer + parser:** **Gate:** `test262` parse-phase pass % ≥ target.
- **J2 — Tree-walk interpreter + core semantics:** closures, classes, exceptions, prototype chain.
  **Gate:** `test262` language-semantics slice ≥ target.
- **J2b — Bytecode VM + shapes/inline caches:** **Gate:** J2 still green + JS micro-bench targets.
- **J3 — Builtins + Promise/async + event loop:** `RegExp` via `zig-regex`. **Gate:** `test262`
  built-ins + async slices ≥ target.

### Phase 3 — Convergence (dynamic apps)
- DOM bindings (`js/dom_bindings.zig`); event dispatch + hit testing; mutation → precise invalidation
  → re-layout/paint; the `postMessage`/`__craftBridgeResult` bridge shim inside our VM (§5).
- **Gate:** an existing Craft example app (e.g. `examples/todo-app`) runs end-to-end under
  `engine: 'loom'`, bridge calls working, no WKWebView involved.

### Phase 6 — Harden & adopt
- Flip `auto` → Loom-default for curated apps passing their differential suite; security hardening
  (curated surface = threat-model advantage); package Loom for pantry; **wire into lang**.
- **Gate:** Craft default-flip with zero differential regressions on the example corpus; lang renders
  a Loom window via `import ui`.

---

## 9. Success metrics

| Metric | Baseline | Target |
|---|---|---|
| Cold start (per window) | WKWebView (from `benchmarks/`) | **≤ baseline** |
| Memory per window | WKWebView | **< baseline** |
| Style+layout for N nodes | WKWebView | **< baseline** |
| Frame time | 16.6 ms | **≤ 16.6 ms (≤ 8.3 ms where supported)** |
| JS throughput | JSC on bundled micro-suites | **competitive, then ≥ on UI workloads** |
| Binary-size delta | WKWebView linked | **smaller for curated subset** |
| LayoutTests pass % | 0 | **rising per phase; gate per subsystem** |
| test262 pass % | 0 | **rising per phase; gate the JS track** |

---

## 10. Risks & mitigations

| Risk | Mitigation |
|---|---|
| **Homegrown JS engine is a multi-year sink** | Curated language subset; `test262` as a correctness ratchet; tree-walker first (correct) then VM (fast); it's the dominant risk — staff/sequence it as the critical path, and keep WKWebView fallback so Craft ships value before the VM is done |
| Scope explosion (the web is infinite) | Curated subset (§2) + WKWebView coexistence/fallback (§5) |
| Text shaping / font raster is brutal | Homegrown but **curated**: Latin/LTR + basic OpenType first; complex scripts (bidi/Indic/CJK shaping) deferred and tracked by failing tests; never block R1 on full Unicode |
| Image codecs / DEFLATE from scratch | Standard, well-specified formats; PNG+JPEG first; gated by decode-correctness fixtures |
| AI claims compliance it doesn't have | LayoutTests/test262 pass % + oracle diff + perf gates are the only definition of "done" (§6.7) |
| WebKit security-patch cadence | Curated, author-content-only surface drastically shrinks attack surface; document threat model; WKWebView fallback for untrusted content |
| License contamination (LGPL) | Clean-room: observe outputs/specs, reimplement; never copy source (§6.6) |
| 19 GB WebKit build is slow | We mostly don't build it — committed baselines cover the bulk (§6.1); build headless only when needed |
| Perf wins don't materialize | CI perf gates (`zig-benchmarks`) fail the build on regression (§6.5) |

---

## 11. Immediate next steps

1. **Wire homegrown deps** into `packages/zig/build.zig.zon` (`zig_regex`, `zig_tls`, `zig_crosswind`,
   `zig_test_framework`, `zig_bench`) and confirm they resolve via pantry.
2. **Stand up the oracle/conformance runner** against WebKit committed baselines + `test262` (Phase 0).
3. **Confirm scope** = B via C (curated app engine, coexisting with WKWebView). *(JS-engine decision
   is settled: homegrown.)*
4. **Scaffold** `packages/zig/src/engine/` for both tracks.
5. **First vertical slices, in parallel:**
   - Render: parse + cascade + block layout + GPU-painted text for one fixture, diffed against a
     WebKit `-expected.png`.
   - JS: lexer + parser passing a first `test262` parse slice.

---

### Appendix: decision points

- **Scope:** Browser-grade (A) vs **curated app engine (B)** vs phased coexistence (C). *Rec: B via C.*
- **JS engine:** **Homegrown in Zig** — settled per your direction (no JSC/V8).
- **Codename:** keep **Loom** or pick another.
- **Home location:** in-tree (`packages/zig/src/engine/`) now → extract to a standalone pantry package
  (`loom`) at Phase 6, consumed by Craft *and* lang. *Rec: in-tree now, extract later.*
- **Shared VM with lang:** evaluate early whether lang's runtime and Loom's DOM scripting share one
  homegrown JS engine. *Rec: keep the option open; design `engine/js/` to be embeddable standalone.*
