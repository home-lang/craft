# Hybrid web navigation fixture

This fixture keeps the app's two web entries in the shared `WKWebView` and
pushes from a red page to a blue page through the hybrid shell. Its simulator
test samples the outgoing page during the UIKit transition: a blank source
slot fails the assertion, while the transition snapshot keeps the red page
visible until the destination is shown.
