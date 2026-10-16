# Hybrid web navigation fixture

This fixture keeps the app's two web entries in the shared `WKWebView` and
pushes from a red page to a blue page through the hybrid shell's explicit
`craftHybrid.open` path. It does not model a page-router web-to-web navigation:
those remain inside the page's own router and never create a second shell web
slot. Its simulator test samples the outgoing page during the UIKit transition
and the incoming page after it: every observed frame must show the red or blue
page, and a blank source slot fails. XCTest can return from a tap after the
incoming page is already painted; that valid blue frame must not be mistaken
for a blank outgoing page. The fixture deliberately
delays the route report past the shell's page-wait deadline so it exercises the
slow-page fallback rather than passing on an already-updated WebView. The
harness serves the page from a local HTTP origin, matching the trusted
remote-page path used by hybrid apps, and chooses a bounded process-derived
port so parallel harnesses do not depend on Bun's ephemeral-port allocator.

Craft chooses a simulator compatible with the selected Xcode SDK. CI pins
Xcode 26.2 for its iOS 26.2 runtime: mixing Xcode 16.4's XCTest with that runtime
produced tap coordinates outside the button despite a correct accessibility
frame. The suite uses real element taps with the matching toolchain.

The hosted UIKit regression checks the incoming snapshot before the route
arrives and verifies its release when the live page is committed. The shell
keeps that snapshot beyond the push animation and replaces it in one frame,
so neither a pending page nor its reveal fades through an empty slot.

Run `CRAFT_HYBRID_NAVIGATION_ITERATIONS=10 bun packages/ios/scripts/test-hybrid-navigation.ts`
for repeated navigation checks. The HTTP request log and Xcode result bundle
are retained in CI artifacts, including when an assertion fails.
