# Live Activity layout fixture

This STX screen uses the production Craft ActivityKit service and widget, in an
isolated test app. It exercises long workout and Relax names, emoji and scripts
with different line-breaking rules, and an unbroken name. Its timer starts above
one hour so the compact presentation must also accommodate hour digits.

```sh
STX_CLI=/path/to/stx/packages/stx/bin/cli.ts APPLE_TEAM_ID=YOUR_TEAM \
  bun packages/ios/fixtures/live-activity/prepare.ts /tmp/craft-live-activity-layout
```

Generate the output's `project.yml` with XcodeGen. Build and install the resulting
app normally, with development signing on a physical device. This fixture uses
its own bundle ID and does not alter an installed application's data.

For each name, start the activity, reveal Notification Center or the Lock Screen,
and capture running, paused and resumed screenshots. The timer should meet the
same trailing edge in all three states. Names may use two lines; very long names
truncate within their own column without covering the timer. Also inspect the
compact and expanded Dynamic Island, including the hour digits. Repeat with a
larger system text size. Tap the system card to return, then end the activity and
confirm its removal. End any remaining fixture activities before uninstalling.
