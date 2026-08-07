// window.craft.gestures — real trackpad swipe phases.
//
// A webview's `wheel` stream carries no phase information, so web code has to
// infer a gesture: claim it when the first event looks horizontal, end it on an
// idle gap. That heuristic cannot tell a finger still on the trackpad from
// momentum after it lifted — macOS keeps emitting wheel events for over a
// second of momentum — so a purely web-side swipe settles at the end of
// momentum rather than at finger-up.
//
// The host sees the real NSEvent and its `phase` / `momentumPhase`, and calls
// `_emit` below with begin/change/end. Consumers get the finger, not the tail.
//
// A host that never emits leaves this a dormant registry, which is what makes
// it safe to install unconditionally: `onSwipe` exists everywhere, so callers
// feature-detect once and keep their own wheel fallback bound.
;(function () {
  window.craft = window.craft || {}
  if (window.craft.gestures) return

  var listeners = []

  window.craft.gestures = {
    /**
     * Subscribe to swipe phases. Returns an unsubscribe function.
     *
     * The callback receives:
     *   axis       'horizontal' | 'vertical'
     *   phase      'begin' | 'change' | 'end'
     *   deltaX     points since the previous event; positive scrolls content
     *              left, i.e. advances to the next item. Matches the sign of
     *              a DOM wheel event's deltaX.
     *   deltaY     points, same convention
     *   velocityX  points per second at release; only meaningful on 'end'
     *   momentum   true once the fingers have lifted and the OS is coasting
     */
    onSwipe: function (callback) {
      if (typeof callback !== 'function') return function () {}
      listeners.push(callback)
      return function off() {
        var at = listeners.indexOf(callback)
        if (at !== -1) listeners.splice(at, 1)
      }
    },

    /** Called by the host. Not part of the public surface. */
    _emit: function (swipe) {
      // Iterate a copy: a listener that unsubscribes itself mid-dispatch
      // would otherwise shift the array out from under the loop and skip the
      // next listener.
      var current = listeners.slice()
      for (var i = 0; i < current.length; i++) {
        try {
          current[i](swipe)
        }
        catch (error) {
          // One bad listener must not stop a gesture reaching the others, and
          // must not leave the track mid-swipe.
          console.error('[craft] swipe listener threw', error)
        }
      }
    },
  }
})()
