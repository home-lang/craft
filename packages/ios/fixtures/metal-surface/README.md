# UIKit Metal fixture

This fixture compiles `metal_surface.zig` with Craft's pinned compiler and calls
its public `Surface` interface through a test-only C boundary. A native UIKit
application displays the result without a WebView or JavaScript renderer.

```sh
CRAFT_ZIG=/absolute/path/to/pinned/zig bun packages/ios/scripts/test-metal-surface.ts \
  --runtime com.apple.CoreSimulator.SimRuntime.iOS-26-2 \
  --xcodegen /absolute/path/to/managed/xcodegen \
  --output artifacts/native-metal-ios
```

The runtime must already be installed. The runner creates its own simulator,
retains logs and an XCTest result bundle under a fresh evidence directory, and
deletes only that simulator and its temporary project. It verifies simulator
deletion by reading the simulator's own UUID back. Command and test budgets are
bounded; missing tools, failed assertions, empty selections and skips fail.

The unit test compares every pixel copied back from the actual Metal drawable
across 60 frames, a native resize and resume. It verifies the window's backing
scale, rejection from a background thread and removal of the owned layer.

The UI application presents 61 frames and then becomes idle for inspection.
The UI test requires completion of frame 60, samples all four displayed color
quadrants from a real screen capture, resizes, backgrounds and resumes the app,
and samples again. Its retained screenshots contain only first-party test colors.
No animation, accessibility or idle-detection gate is disabled.

`mobile-e2e.yml` requires this job in complete mobile runs and includes it in
the focused `ios-render` scope. It uses Xcode 26.2 and iOS 26.2. Local execution
on the available iOS 27 beta passed the unit case, but the UI runner timed out
before a UI case began. A later local attempt also timed out during simulator
data migration. These failures remain evidence, and neither establishes visual
acceptance. The complete fixture must pass before claiming that acceptance.
