#!/usr/bin/env bash
set -euo pipefail

: "${CRAFT_NATIVE_TEST_PROJECT:?Compile the native fixture before booting Android}"

check_platform_events() {
  local phase="$1"
  adb logcat -b events -d -v threadtime > "artifacts/android-navigation/platform-events-$phase.log"
  if grep -Eq 'am_(anr|crash)' "artifacts/android-navigation/platform-events-$phase.log"; then
    echo '::error::Android platform ANR/crash; native acceptance is invalid'
    exit 1
  fi
}

launcher_ready() {
  local phase="$1"
  check_platform_events "$phase"
  timeout 30s adb shell am start -W -a android.intent.action.MAIN -c android.intent.category.HOME > "artifacts/android-navigation/launcher-$phase.txt"
  local attempt
  for attempt in 1 2 3; do
    check_platform_events "$phase"
    adb shell rm -f /sdcard/craft-native-launcher.xml
    rm -f "artifacts/android-navigation/launcher-$phase.xml"
    if timeout 25s adb shell uiautomator dump --compressed /sdcard/craft-native-launcher.xml > "artifacts/android-navigation/launcher-dump-$phase-$attempt.log" 2>&1 \
      && adb pull /sdcard/craft-native-launcher.xml "artifacts/android-navigation/launcher-$phase.xml" \
      && bun --eval '
        const xml = await Bun.file(process.argv[1]).text();
        const active = xml.match(/<node\b[^>]*\bpackage="([^"]+)"/);
        if (active?.[1] !== "com.android.launcher3" || /responding/i.test(xml)) throw new Error("Android launcher is not responsive; rejecting platform state");
      ' "artifacts/android-navigation/launcher-$phase.xml"; then
      check_platform_events "$phase"
      return
    fi
    check_platform_events "$phase"
  done
  echo '::error::Android launcher did not produce fresh responsive UI; native acceptance is invalid'
  exit 1
}

adb shell settings put global animator_duration_scale 1
launcher_ready before
native_test_args=()
if [[ -n "${CRAFT_ANDROID_TEST_CLASS:-}" ]]; then
  native_test_args+=("-Pandroid.testInstrumentationRunnerArguments.class=$CRAFT_ANDROID_TEST_CLASS")
fi
set +e
gradle --no-daemon -p "$CRAFT_NATIVE_TEST_PROJECT" :app:connectedDebugAndroidTest "${native_test_args[@]}"
native_test_status=$?
set -e
launcher_ready after
exit "$native_test_status"
