# Hybrid web navigation fixture

This fixture keeps the app's two web entries in the shared `WKWebView` and
pushes from a red page to a blue page through the hybrid shell's explicit
`craftHybrid.open` path. It does not model a page-router web-to-web navigation:
those remain inside the page's own router and never create a second shell web
slot. Its simulator test samples the outgoing page during the UIKit transition:
a blank source slot fails the assertion, while the transition snapshot keeps
the red page visible until the destination is shown. The fixture deliberately
delays the route report past the shell's page-wait deadline so it exercises the
slow-page fallback rather than passing on an already-updated WebView. The
harness serves the page from a local HTTP origin, matching the trusted
remote-page path used by hybrid apps, and chooses a bounded process-derived
port so parallel harnesses do not depend on Bun's ephemeral-port allocator.
