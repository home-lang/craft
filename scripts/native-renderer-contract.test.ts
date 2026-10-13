import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'bun:test'

const root = join(import.meta.dir, '..')
const ios = readFileSync(join(root, 'packages/ios/templates/CraftNativeScreen.swift'), 'utf8')
const iosHealth = readFileSync(join(root, 'packages/ios/templates/CraftHealth.swift'), 'utf8')
const iosWebAudio = readFileSync(join(root, 'packages/ios/templates/CraftWebAudio.swift'), 'utf8')
const iosFlatList = readFileSync(join(root, 'packages/ios/templates/CraftNativeFlatList.swift'), 'utf8')
const android = readFileSync(join(root, 'packages/android/templates/MainActivityNative.kt.template'), 'utf8')
const androidCapabilities = readFileSync(join(root, 'packages/android/templates/CraftNativeCapabilities.kt.template'), 'utf8')
const androidNative = readFileSync(join(root, 'packages/android/templates/CraftNative.kt.template'), 'utf8')
const androidDispatch = readFileSync(join(root, 'packages/zig/src/android_dispatch.zig'), 'utf8')
const androidFlatList = readFileSync(join(root, 'packages/android/templates/CraftNativeFlatList.kt.template'), 'utf8')
const androidRefreshableFlatList = readFileSync(join(root, 'packages/android/templates/CraftNativeRefreshableFlatList.kt.template'), 'utf8')
const androidNavigationTest = readFileSync(join(root, 'packages/android/fixtures/native-navigation/NativeNavigationTest.kt'), 'utf8')
const androidBuilderTest = readFileSync(join(root, 'packages/android/src/index.test.ts'), 'utf8')
const androidFlatListTest = readFileSync(join(root, 'packages/android/fixtures/native-navigation/NativeFlatListTest.kt'), 'utf8')
const iosNavigationTest = readFileSync(join(root, 'packages/ios/fixtures/native-navigation/NativeNavigationUITests.swift'), 'utf8')
const navigationHome = readFileSync(join(root, 'packages/ios/fixtures/native-navigation/Home.stx'), 'utf8')
const navigationDetails = readFileSync(join(root, 'packages/ios/fixtures/native-navigation/Details.stx'), 'utf8')
const iosNavigationScript = readFileSync(join(root, 'packages/ios/scripts/test-native-navigation.ts'), 'utf8')
const androidNavigationScript = readFileSync(join(root, 'packages/android/scripts/test-native-navigation.ts'), 'utf8')
const iosNativeUnitTests = readFileSync(join(root, 'packages/ios/fixtures/native-screen/NativeRenderUnitTests.swift'), 'utf8')
const iosLayoutUnitTests = readFileSync(join(root, 'packages/ios/fixtures/native-screen/NativeLayoutUnitTests.swift'), 'utf8')
const guide = readFileSync(join(root, 'docs/guides/native-stx.md'), 'utf8')
const migrationGuide = readFileSync(join(root, 'docs/guides/migration/react-native.md'), 'utf8')
const nativeLayout = readFileSync(join(root, 'packages/zig/src/native_layout.zig'), 'utf8')
const componentTypes = readFileSync(join(root, 'packages/typescript/src/components/index.ts'), 'utf8')
const iosReadme = readFileSync(join(root, 'packages/ios/README.md'), 'utf8')
const androidReadme = readFileSync(join(root, 'packages/android/README.md'), 'utf8')
const iosNavigationReadme = readFileSync(join(root, 'packages/ios/fixtures/native-navigation/README.md'), 'utf8')
const androidNavigationReadme = readFileSync(join(root, 'packages/android/fixtures/native-navigation/README.md'), 'utf8')
const iosScreenReadme = readFileSync(join(root, 'packages/ios/fixtures/native-screen/README.md'), 'utf8')
const mobileE2EWorkflow = readFileSync(join(root, '.github/workflows/mobile-e2e.yml'), 'utf8')

/** One host-neutral vocabulary, asserted against every generated renderer. */
const COMPONENTS: Array<[string, string, string]> = [
  ['SafeAreaView', 'case "View", "SafeAreaView":', '"View", "SafeAreaView" ->'],
  ['KeyboardAvoidingView', 'case "KeyboardAvoidingView":', '"KeyboardAvoidingView" ->'],
  ['Text', 'case "Text":', '"Text" ->'],
  ['Button', 'case "Button", "Link":', '"Button" ->'],
  ['Link', 'case "Button", "Link":', '"Link" ->'],
  ['Checkbox', 'case "Checkbox":', '"Checkbox" ->'],
  ['TouchableOpacity', 'case "TouchableOpacity", "TouchableHighlight", "Pressable":', '"TouchableOpacity", "TouchableHighlight", "Pressable" ->'],
  ['TouchableHighlight', 'case "TouchableOpacity", "TouchableHighlight", "Pressable":', '"TouchableOpacity", "TouchableHighlight", "Pressable" ->'],
  ['Pressable', 'case "TouchableOpacity", "TouchableHighlight", "Pressable":', '"TouchableOpacity", "TouchableHighlight", "Pressable" ->'],
  ['Switch', 'case "Switch":', '"Switch" ->'],
  ['Slider', 'case "Slider":', '"Slider" ->'],
  ['TextInput', 'case "TextInput":', '"TextInput" ->'],
  ['Picker', 'case "Picker":', '"Picker" ->'],
  ['DatePicker', 'case "DatePicker":', '"DatePicker" ->'],
  ['Modal', 'case "Modal":', '"Modal" ->'],
  ['ActivityIndicator', 'case "ActivityIndicator":', '"ActivityIndicator" ->'],
  ['Icon', 'case "Icon":', '"Icon" ->'],
  ['Image', 'case "Image":', '"Image" ->'],
  ['ImageBackground', 'case "ImageBackground":', '"ImageBackground" ->'],
  ['Video', 'case "Video":', '"Video" ->'],
  ['ScrollView', 'case "ScrollView"', '"ScrollView"'],
  ['SectionList', 'case "ScrollView", "SectionList":', '"ScrollView", "SectionList" ->'],
  ['FlatList', 'case "FlatList":', '"FlatList" ->'],
]

describe('native renderer component contract', () => {
  it('delivers HealthKit completions on the main queue for native screens', () => {
    expect(iosHealth).toContain('private func completeOnMain(_ completion: @escaping Completion) -> Completion')
    expect(iosHealth).toContain('DispatchQueue.main.async { completion(result) }')
    expect(iosHealth.match(/let completion = completeOnMain\(rawCompletion\)/g)?.length).toBe(11)
  })

  it('exports the flat flex ABI for mobile hosts', () => {
    expect(nativeLayout).toContain('pub const FlexItem = extern struct')
    expect(nativeLayout).toContain('pub const JustifyContent = enum')
    expect(nativeLayout).toContain('pub const AlignItems = enum')
    expect(nativeLayout).toContain('pub const AlignContent = enum')
    expect(nativeLayout).toContain('justify_content: JustifyContent')
    expect(nativeLayout).toContain('align_items: AlignItems')
    expect(nativeLayout).toContain('align_self: ?AlignItems')
    expect(nativeLayout).toContain('flex_wrap: bool')
    expect(nativeLayout).toContain('align_content: AlignContent')
    expect(nativeLayout).toContain('const vertical_offset = switch (alignment)')
    expect(nativeLayout).toContain('test "aligns wrapped children using align self"')
    expect(nativeLayout).toContain('test "sanitizes non-finite tree dimensions"')
    expect(nativeLayout).toContain('finiteNonNegative(node.style.width orelse available.width)')
    expect(nativeLayout).toContain('.space_evenly =>')
    expect(nativeLayout).toContain('pub const FlexLineItem = extern struct')
    expect(nativeLayout).toContain('pub export fn craft_native_flex_row(')
    expect(nativeLayout).toContain('pub export fn craft_native_flex_line_breaks(')
    expect(nativeLayout).toContain('pub export fn craft_native_flex_line_distribution(')
    expect(nativeLayout).toContain('pub const GridItem = extern struct')
    expect(nativeLayout).toContain('pub const Frame = extern struct')
    expect(nativeLayout).toContain('pub export fn craft_native_grid(')
    expect(nativeLayout).toContain('pub export fn craft_native_grid_aligned(')
    expect(nativeLayout).toContain('pub export fn craft_native_grid_auto_rows(')
    expect(nativeLayout).toContain('pub export fn craft_native_grid_auto_rows_aligned(')
    expect(nativeLayout).toContain('pub export fn craft_native_cross_axis_position(')
    expect(nativeLayout).toContain('margin_start: f32')
    expect(nativeLayout).toContain('shrink_total')
    expect(nativeLayout).toContain('clampBounds')
    expect(ios).toContain('import Darwin')
    expect(ios).toContain('craft_native_flex_row')
    expect(ios).toContain('CraftNativeFlexBridge.widths')
    expect(ios).toContain('CraftNativeFlexLineBridge.lines')
    expect(ios).toContain('CraftNativeFlexLineDistributionBridge.distribute')
    expect(ios).toContain('craft_native_grid')
    expect(ios).toContain('craft_native_grid_auto_rows')
    expect(ios).toContain('CraftNativeGridBridge.frames')
    expect(ios).toContain('CraftNativeCrossAxisBridge.position')
    expect(androidNative).toContain('crossAxisPosition(')
    expect(androidNative).toContain('flexLines(')
    expect(androidNative).toContain('flexLineDistribution(')
    expect(android).toContain('CraftNative.crossAxisPosition(')
    expect(android).toContain('CraftNative.flexLines(')
    expect(android).toContain('CraftNative.flexLineDistribution(')
    expect(androidDispatch).toContain('nativeCrossAxisPosition')
    expect(androidDispatch).toContain('nativeFlexLineBreaks')
    expect(androidDispatch).toContain('nativeFlexLineDistribution')
    expect(androidDispatch).toContain('nativeGridAutoRows')
    expect(androidDispatch).toContain('signature = "(FFIFFF[F[F[F[F[F[F[F[F[F[F)[F"')
    expect(ios).toContain('UnsafeMutableRawPointer')
    expect(android).toContain('CraftNative.flexRow(')
    expect(android).toContain('sharedPrimary?.get(index)')
    expect(android).toContain('sharedPrimary?.takeIf { it.size == line.entries.size * 2 }')
    expect(androidDispatch).toContain('@memcpy(flattened[count..], positions)')
    expect(ios).toContain('sharedLine?[offset].position')
    expect(ios).toContain('let useSharedPositions = !reverse && sharedLine != nil')
    expect(android).toContain('Shared positions cover every non-reverse justification')
    expect(androidNative).toContain('?.takeIf { it.size >= basis.size && it.all { value -> value.isFinite() } }')
    expect(androidNative).toContain('?.takeIf { it.size >= intrinsicWidth.size * 4 && it.all { value -> value.isFinite() } }')
    expect(androidNative).toContain('nativeGridAutoRows(')
    expect(android).toContain('Float.NaN')
    expect(android).toContain('CraftNative.grid(')
    expect(android).toContain('sharedFrames[offset + 3]')
  })

  it('keeps device navigation tests independent of global field order and viewport position', () => {
    expect(iosNavigationTest).toContain('private func reveal(_ element: XCUIElement, in scroll: XCUIElement')
    expect(iosNavigationTest).toContain('app.textFields["navigation-input-b"]')
    expect(iosNavigationTest).not.toContain('app.textFields.element(boundBy: 1)')
    expect(iosNavigationTest).toContain('let svg = app.otherElements["native-svg"]')
    expect(iosNavigationTest).toContain('svg.waitForExistence(timeout: 5)')
    expect(iosNavigationTest).toContain('let link = app.staticTexts["native-link"]')
    expect(androidNavigationTest).toContain('assertEquals("CraftNativeSvgView", svg.javaClass.simpleName)')
  })

  it('keeps the same host-neutral controls on iOS and Android', () => {
    for (const [name, iosMarker, androidMarker] of COMPONENTS) {
      expect(ios, `${name} missing from iOS renderer`).toContain(iosMarker)
      expect(android, `${name} missing from Android renderer`).toContain(androidMarker)
    }
  })

  it('keeps SVG drawing primitives available on both native hosts', () => {
    for (const [name, iosMarker, androidMarker] of [
      ['Svg', 'case "Svg":', '"Svg" ->'],
      ['G', 'case "G":', '"G" ->'],
      ['SvgText', 'case "SvgText":', '"SvgText" ->'],
    ] as const) {
      expect(ios, `${name} missing from iOS renderer`).toContain(iosMarker)
      expect(android, `${name} missing from Android renderer`).toContain(androidMarker)
    }
    expect(navigationHome).toContain('<g stroke="#2563eb">')
    expect(navigationHome).toContain('<text x="12" y="21"')
    expect(navigationHome).toContain('testID="native-video"')
    expect(navigationHome).toContain('source={{"uri":""}}')
    expect(iosNavigationTest).toContain('SVG accessibility metadata did not survive native mounting')
    expect(androidNavigationTest).toContain('SVG accessibility metadata did not survive native mounting')
    expect(iosNavigationTest).toContain('Video fixture did not mount as a native view')
    expect(androidNavigationTest).toContain('CraftNativeVideoView')
    expect(navigationHome).toContain('<Icon testID="native-icon" symbol="sun.max"')
    expect(iosNavigationTest).toContain('let icon = app.images["native-icon"]')
    expect(androidNavigationTest).toContain('CraftNativeIconView')
  })

  it('keeps SVG stroke semantics aligned across hosts', () => {
    expect(ios).toContain('line.lineCapStyle')
    expect(ios).toContain('line.lineJoinStyle')
    expect(ios).toContain('line.setLineDash')
    expect(android).toContain('strokeCap = when (props.optString("strokeLinecap"))')
    expect(android).toContain('strokeJoin = when (props.optString("strokeLinejoin"))')
    expect(android).toContain('val dashes: List<Float>')
    expect(android).toContain('DashPathEffect(pattern, 0f)')
    expect(android).toContain('val pattern: FloatArray')
    expect(android).toContain('SvgPaint().merge(drawing)')
    expect(guide).toContain('`Svg` is DOM-free in native mode')
    expect(guide).toContain('line\ncaps, joins, and dash patterns')
  })

  it('gives computed SVG opacity precedence over the raw prop on both hosts', () => {
    expect(ios).toContain('if let opacity = style["opacity"] as? NSNumber ?? props["opacity"] as? NSNumber')
    expect(android).toContain('val ownOpacity = value("opacity")?.toFloatOrNull() ?: 1f')
    expect(android).toContain('opacity = ownOpacity * opacity')
  })

  it('keeps Android SVG text sizes as Kotlin floats in both prop branches', () => {
    expect(android).toContain(
      'val size = (if (props.has("fontSize")) props.optDouble("fontSize", 12.0) else nodeStyle.optDouble("fontSize", 12.0))',
    )
    expect(android).toContain('textSize = size')
  })

  it('keeps native video playback available on both hosts', () => {
    expect(ios).toContain('CraftNativeVideoView')
    expect(ios).toContain('case "video": return "Video"')
    expect(android).toContain('"video" -> "Video"')
    expect(ios).toContain('AVPlayerViewController')
    expect(ios).toContain('host.addChild(playerController)')
    expect(ios).toContain('playerController.removeFromParent()')
    expect(ios).toContain('"Video", "TextInput"')
    expect(ios).toContain('AVPlayerItemDidPlayToEndTime')
    expect(android).toContain('CraftNativeVideoView')
    expect(android).toContain('VideoView')
    expect(android).toContain('mediaPlayer.isLooping = shouldLoop')
    expect(guide).toContain('`Video` uses the platform player')
  })

  it('keeps Icon host fallbacks explicit and DOM-free', () => {
    expect(guide).toContain('`Icon` is a native leaf with the shared `symbol`/`name` contract')
    expect(guide).toContain('| `Icon` | `CraftNativeIconView` (`UIImageView`) | `CraftNativeIconView` (`TextView`) |')
    expect(guide).toContain('Android uses the maintained dependency-free\nglyph map')
    expect(iosNavigationReadme).toContain('Icon/Video/SVG accessibility survives native mounting')
    expect(androidNavigationReadme).toContain('`CraftNativeIconView`')
  })

  it('keeps Web Audio wired to both hosts', () => {
    // iOS renders the whole Web Audio graph (CraftWebAudio.swift).
    expect(iosWebAudio).toContain('final class CraftWebAudio')
    expect(iosWebAudio).toContain('let source = AVAudioSourceNode(format: format)')
    expect(iosWebAudio).toContain('globalThis.AudioContext = AudioContext;')
    expect(iosWebAudio).toContain("BaseAudioContext.prototype.createConvolver = function()")
    expect(ios).toContain('audio.install(in: jsContext)')
    expect(ios).toContain('audio.close()')
    // Android mixes oscillators and gains.
    expect(android).toContain('private class CraftNativeAudio')
    expect(android).toContain('"frequencyAtTime", "frequencyRampToTime"')
    expect(android).toContain('"gainAtTime", "gainRampToTime"')
    expect(android).toContain("param.linearRampToValueAtTime = function(value, when)")
    expect(android).toContain('AudioTrack')
    expect(android).toContain('globalThis.AudioContext = AudioContext')
    expect(android).toContain('"AUDIO" -> screen.audio.handle(payload)')
    expect(android).toContain('audio.close()')
    expect(guide).toContain('Native screens have Web Audio')
    expect(guide).toContain('Android still mixes\nonly oscillators and gains')
  })

  it('keeps the shared layout core explicit', () => {
    expect(nativeLayout).toContain('pub const Axis = enum')
    expect(nativeLayout).toContain('flex_shrink: f32')
    expect(nativeLayout).toContain('min_width: ?f32')
    expect(nativeLayout).toContain('max_height: ?f32')
    expect(nativeLayout).toContain('gap: f32')
    expect(nativeLayout).toContain('margin_left: f32')
    expect(nativeLayout).toContain('margin_bottom: f32')
    expect(nativeLayout).toContain('grid_columns: u32')
    expect(nativeLayout).toContain('column_gap: f32')
    expect(nativeLayout).toContain('padding_left: f32')
    expect(nativeLayout).toContain('padding_bottom: f32')
    expect(nativeLayout).toContain('const content_width = @max(0, width - node.style.padding_left - node.style.padding_right)')
    expect(nativeLayout).toContain('fn layoutGrid(')
    expect(guide).toContain('host-neutral layout contract')
    expect(guide).toContain('platform-specific measurement')
    expect(guide).toContain('must not fork the distribution rules')
    expect(guide).toContain('craft_native_flex_line_breaks')
    expect(guide).toContain('craft_native_flex_line_distribution')
    expect(guide).toContain('non-finite widths, positions, and frames')
  })

  it('keeps Android flex justification aligned across the Kotlin and JNI seams', () => {
    expect(androidNative).toContain('private external fun nativeFlexRow(\n        available: Float,\n        gap: Float,\n        justify: Int,')
    expect(androidDispatch).toContain('.signature = "(FFI[F[F[F[F[F[F)[F"')
    expect(androidNative).toContain('it.all { value -> value.isFinite() }')
    expect(ios).toContain('output.allSatisfy({ $0.isFinite })')
    expect(androidNative).toContain('it.size >= intrinsicWidth.size * 4 && it.all { value -> value.isFinite() }')
    expect(ios).toContain('frame.x.isFinite && frame.y.isFinite && frame.width.isFinite && frame.height.isFinite')
  })

  it('keeps the Android flex bridge fallback typed as a JNI object', () => {
    expect(androidDispatch).toContain('fellThrough("flexRow", err, @as(jni.jobject, null))')
    expect(androidDispatch).not.toContain('fellThrough("flexRow", err, null)')
  })

  it('reads Android shared flex positions from the result position half', () => {
    expect(android).toContain('sharedPositions?.get(line.entries.size + index)')
    expect(android).toContain('The shared result stores widths in the first half')
  })

  it('keeps platform README primitive inventories complete', () => {
    for (const component of COMPONENTS.map(([name]) => `\`${name}\``)) {
      expect(iosReadme, `${component} missing from iOS README`).toContain(component)
      expect(androidReadme, `${component} missing from Android README`).toContain(component)
    }
  })

  it('documents native support as part of the shared stx package', () => {
    for (const readme of [iosNavigationReadme, androidNavigationReadme, iosScreenReadme]) {
      expect(readme).toContain('@stacksjs/stx')
      expect(readme).toContain('historical `stx-native` package')
      expect(readme).toContain('compiler')
    }
  })

  it('documents the native keyboard fallback alongside the WebView path', () => {
    expect(migrationGuide).toContain('<KeyboardAvoidingView behavior="padding"')
    expect(migrationGuide).toContain('The WebView fallback remains CSS-driven.')
  })

  it('pins one @stacksjs/stx compiler revision across mobile E2E hosts', () => {
    const refs = [...mobileE2EWorkflow.matchAll(/repository: stacksjs\/stx\s+ref: ([0-9a-f]{40})/g)].map(match => match[1])
    expect(refs).toHaveLength(2)
    expect(new Set(refs).size).toBe(1)
    expect(mobileE2EWorkflow).toContain('stx native compile')
    expect(mobileE2EWorkflow).not.toContain('stx-native')
  })

  it('uses image alt text as the native accessibility fallback', () => {
    expect(ios).toContain('((type == "Image" || type == "ImageBackground") ? props["alt"] as? String : nil)')
    expect(android).toContain('props.optString("alt").takeIf { (type == "Image" || type == "ImageBackground") && it.isNotBlank() }')
    expect(guide).toContain('`Image.alt` supplies the native accessibility label')
  })

  it('renders ImageBackground as an image-backed native container', () => {
    expect(ios).toContain('private final class CraftNativeImageBackgroundView: UIImageView')
    expect(ios).toContain('configureStack(background.contentStack, style: style)')
    expect(android).toContain('private class CraftNativeImageBackgroundView(context: Context) : FrameLayout(context)')
    expect(android).toContain('configureContainer(content, style)')
    expect(android).toContain('imageViews(views)')
    expect(guide).toContain('`ImageBackground` uses the shared image source')
    expect(navigationHome).toContain('<ImageBackground')
    expect(navigationHome).toContain('testID="native-image-background-label"')
    expect(iosNavigationTest).toContain('native-image-background')
    expect(androidNavigationTest).toContain('CraftNativeImageBackgroundView')
  })

  it('keeps KeyboardAvoidingView behavior and IME propagation aligned', () => {
    expect(ios).toContain('private final class CraftNativeKeyboardAvoidingView: CraftNativeFlowView')
    expect(ios).toContain('UIResponder.keyboardWillChangeFrameNotification')
    expect(ios).toContain('keyboard.setKeyboardInset(keyboardSafeAreaInset)')
    expect(ios).toContain('let globalInset = containsKeyboardAvoidingView() ? 0 : inset')
    expect(ios).toContain('private func syncGlobalKeyboardSafeArea()')
    expect(android).toContain('private class CraftNativeKeyboardAvoidingView(context: Context) : FrameLayout(context)')
    expect(android).toContain('WindowInsetsCompat.Type.ime()')
    expect(android).toContain('keyboardInset = max(0, ime.bottom - safe.bottom)')
    expect(android).toContain('behavior == "height"')
    expect(navigationHome).toContain('<KeyboardAvoidingView')
    expect(navigationHome).toContain('testID="native-keyboard-avoiding-input"')
    expect(iosNavigationTest).toContain('native-keyboard-avoiding')
    expect(androidNavigationTest).toContain('CraftNativeKeyboardAvoidingView')
  })

  it('applies text transforms to native action labels on both hosts', () => {
    expect(ios).toContain('let transformedTitle = transformedText(title, style: style)')
    expect(ios).toContain('private func transformedText(_ text: String, style: [String: Any])')
    expect(ios).toContain('buttonTitleAttributes(style, color: titleColor, font: font, forceUnderline: type == "Link")')
    expect(ios).toContain('let titleColor = color(props["color"]) ?? color(style["color"]) ?? .systemBlue')
    expect(ios).toContain('button.contentHorizontalAlignment = buttonAlignment(style["textAlign"])')
    expect(android).toContain('configureText(this, title, style)')
    expect(android).toContain('props.optString("color").takeIf { it.isNotBlank() }?.let { setTextColor(color(it, defaultTextColor)) }')
    expect(android).toContain('val linkColor = props.optString("color").takeIf { it.isNotBlank() } ?: style.optString("color")')
    expect(android).toContain('setTextColor(color(linkColor, Color.rgb(33, 150, 243)))')
    expect(android).toContain('(previous as? TextView)?.takeUnless { it is Button } ?: TextView(this)')
  })

  it('keeps capitalize semantics aligned across hosts', () => {
    expect(ios).toContain('text.split(separator: " ", omittingEmptySubsequences: false)')
    expect(ios).toContain('String(first).uppercased() + String(word.dropFirst())')
    expect(android).toContain('value.split(\' \').joinToString(" ")')
  })

  it('keeps native text truncation props aligned across hosts', () => {
    expect(ios).toContain('label.numberOfLines = max(0, (props["numberOfLines"] as? NSNumber)?.intValue ?? 0)')
    expect(ios).toContain('label.lineBreakMode = textLineBreakMode(props["ellipsizeMode"])')
    expect(ios).toContain('case "middle": return .byTruncatingMiddle')
    expect(android).toContain('maxLines = props.optInt("numberOfLines", 0).takeIf { it > 0 } ?: Int.MAX_VALUE')
    expect(android).toContain('"middle" -> TextUtils.TruncateAt.MIDDLE')
    expect(android).toContain('"tail" -> TextUtils.TruncateAt.END')
    expect(guide).toContain('`Text` supports positive `numberOfLines` values')
  })

  it('preserves authored button label casing across hosts', () => {
    expect(ios).toContain('buttonTitleAttributes(style, color: titleColor, font: font, forceUnderline: type == "Link")')
    expect(android).toContain('isAllCaps = false')
  })

  it('keeps native text intrinsic height free of Android font padding', () => {
    expect(ios).toContain('case let label as UILabel:')
    expect(android).toContain('includeFontPadding = false')
    expect(android).toContain('is String -> TextView(this).apply {')
  })

  it('measures shrink-to-fit text from max-content before wrapping on both hosts', () => {
    expect(android).toContain('val intrinsicSpec = if (child is TextView && child !is EditText) 1_000_000 else base')
    expect(android).toContain('longest-word (min-content) width')
    expect(ios).toContain('let maxContent = label.sizeThatFits(CGSize(width: unbounded, height: unbounded))')
    expect(ios).toContain('let resolvedWidth = width ?? min(ceil(maxContent.width), limit)')
    expect(ios).toContain('collapses shrink-to-fit bubbles and pills')
    expect(navigationHome).toContain('testID="max-content-bubble"')
    expect(navigationHome).toContain('testID="max-content-bubble-text"')
    expect(iosNavigationTest).toContain('text took min-content width and wrapped unexpectedly')
    expect(androidNavigationTest).toContain('text took min-content width and wrapped unexpectedly')
  })

  it('keeps justified text alignment active across hosts', () => {
    expect(ios).toContain('case "justify": return .justified')
    expect(android).toContain('import android.text.Layout')
    expect(android).toContain('Layout.JUSTIFICATION_MODE_INTER_WORD')
    expect(android).toContain('Layout.JUSTIFICATION_MODE_NONE')
    expect(navigationHome).toContain('testID="justified-text"')
  })

  it('keeps native slider controls and completion events aligned', () => {
    expect(ios).toContain('slider.value = snappedSliderValue(value, for: slider)')
    expect(ios).toContain('events["onSlidingComplete"]')
    expect(android).toContain('val requested = props.optDouble("value", minimum)')
    expect(android).toContain('val progressMax = step?.let {')
    expect(android).toContain('onSlidingComplete')
    expect(guide).toContain('`Slider` accepts `minimumTrackTintColor`')
  })

  it('keeps Picker option selection aligned across hosts and fixtures', () => {
    expect(ios).toContain('UIPickerViewDataSource, UIPickerViewDelegate')
    expect(ios).toContain('picker.selectRow(row, inComponent: 0, animated: false)')
    expect(ios).toContain('"nativeEvent": ["value": option.value, "index": row]')
    expect(android).toContain('"Picker" -> (previous as? Spinner ?: Spinner(this)).apply')
    expect(android).toContain('setSelection(selected, false)')
    expect(android).toContain('onItemSelectedListener = null')
    expect(android).toContain('Both operations can synchronously dispatch an Android selection')
    expect(android).not.toContain('if (type == "Modal" && !props.optBoolean("visible", false)) control.visibility = View.GONE')
    expect(android).toContain('style.has("display") && style.optString("display") != "none"')
    expect(android).toContain('if (view !is CraftNativeModalView)')
    expect(android).toContain('var suppressInitialSelection = true')
    expect(android).toContain('if (suppressInitialSelection) return')
    expect(android).toContain('post { suppressInitialSelection = false }')
    expect(android).toContain('.put("value", option.first).put("index", position)')
    expect(navigationHome).toContain('<select testID="native-picker"')
    expect(navigationHome).toContain('<option value="one">One</option>')
    expect(navigationHome).toContain('@request-close="modalRequested()"')
    expect(navigationHome).toContain('@show="modalShown()"')
    expect(navigationHome).toContain('testID="clear-image-source"')
    expect(navigationHome).toContain('testID="image-error-count"')
    expect(navigationHome).toContain('testID="native-audio-context"')
    expect(navigationHome).toContain('const context = new AudioContext()')
    expect(navigationHome).toContain('oscillator.frequency.linearRampToValueAtTime')
    expect(navigationHome).toContain('gain.gain.setValueAtTime')
    expect(iosNavigationTest).toContain('app.buttons["native-audio-context"].tap()')
    expect(androidNavigationTest).toContain('click(activity, "native-audio-context")')
    expect(navigationHome).toContain('<svg\n        testID="native-svg"')
    expect(navigationHome).toContain('<g stroke="#2563eb">')
    expect(navigationHome).toContain('<text x="12" y="21" text-anchor="middle"')
    expect(navigationHome).toContain('testID="hidden-indicator"')
    expect(navigationHome).toContain('testID="display-none-indicator"')
    expect(androidNavigationTest).toContain('hidesWhenStopped should hide a stopped indicator')
    expect(androidNavigationTest).toContain('display:none should hide an activity indicator')
    expect(iosNavigationTest).toContain('app.activityIndicators["hidden-indicator"].isHittable')
    expect(iosNavigationTest).toContain('app.activityIndicators["display-none-indicator"].isHittable')
    expect(androidNavigationTest).toContain('missing image errors should be deduplicated')
    expect(iosNavigationTest).toContain('app.staticTexts["image-error-count"].label, "2"')
    expect(navigationHome).toContain('style={{"opacity": modalOpacity}}')
    expect(navigationHome).toContain('testID="toggle-modal-opacity"')
    expect(androidNavigationTest).toContain('assertEquals("1", (awaitView(activity, "modal-opacity") as TextView).text.toString())')
    expect(androidNavigationTest).toContain('visible modal opacity should update in place')
    expect(iosNavigationTest).toContain('waitForLabel(app.staticTexts["modal-opacity"], "0.45")')
    expect(iosNavigationTest).toContain('app.staticTexts["modal-opacity"].label, "1"')
    expect(guide).toContain('| `Picker` | `UIPickerView` | `Spinner` |')
  })

  it('keeps native Checkbox state and change events aligned across hosts', () => {
    expect(ios).toContain('private final class CraftNativeCheckboxButton: UIButton')
    expect(ios).toContain('let uncheckedImage = UIImage(systemName: indeterminate ? "minus.square" : "square")')
    expect(ios).toContain('UIImage(systemName: indeterminate ? "minus.square" : "checkmark.square.fill")')
    expect(ios).toContain('nativeEvent": ["value": sender.isSelected]')
    expect(android).toContain('"Checkbox" -> (previous as? CheckBox ?: CheckBox(this)).apply')
    expect(android).toContain('props.optBoolean("indeterminate", false)')
    expect(android).toContain('isActivated = props.optBoolean("indeterminate", false)')
    expect(android).toContain('ViewCompat.setStateDescription(')
    expect(android).toContain('if (type == "Checkbox" && props.optBoolean("indeterminate", false)) "mixed" else null')
    expect(android).toContain('nativeEvent", JSONObject().put("value", value)')
    expect(guide).toContain('| `Checkbox` |')
  })

  it('keeps DatePicker values and change events aligned across hosts', () => {
    expect(ios).toContain('case "DatePicker":')
    expect(ios).toContain('UIDatePicker.Mode')
    expect(ios).toContain('"timestamp": (date.timeIntervalSince1970 * 1000).rounded()')
    expect(android).toContain('private class CraftNativeDatePickerView(context: Context) : FrameLayout(context)')
    expect(android).toContain('PickerMode.DATE_TIME')
    expect(android).toContain('"timestamp", current.timeInMillis')
    expect(android).toContain('events.optString("onValueChange").ifBlank { events.optString("onChange") }')
    expect(guide).toContain('| `DatePicker` | `UIDatePicker` | `DatePicker` / `TimePicker` |')
    expect(navigationHome).toContain('<DatePicker testID="native-date-picker"')
    expect(navigationHome).toContain('<DatePicker testID="native-time-picker" mode="time"')
    expect(navigationHome).toContain('<DatePicker testID="native-countdown" mode="countdown"')
    expect(androidNavigationTest).toContain('date picker minimum bound')
    expect(androidNavigationTest).toContain('time picker should contain an Android TimePicker')
    expect(androidNavigationTest).toContain('native countdown should contain an Android TimePicker')
    expect(iosNavigationTest).toContain('countdown DatePicker did not mount natively')
    expect(ios).toContain('if picker.datePickerMode == .countDownTimer { return countdownEvent(picker.countDownDuration) }')
    expect(ios).toContain('static func countdownDuration(_ value: Any?) -> TimeInterval?')
    expect(android).toContain('if (pickerMode == PickerMode.COUNTDOWN)')
    expect(android).toContain('private var countdownSecond = 0')
    expect(android).toContain('countdownSecond = seconds % 60')
    expect(android).toContain('+ countdownSecond')
    expect(android).toContain('"iso", "PT${seconds}S"')
    expect(androidNavigationTest).toContain('"01:31:45"')
    expect(android).toContain('val hours = parts[0].toDoubleOrNull() ?: return null')
    expect(ios).toContain('let parts = text.split(separator: ":")')
    expect(ios).toContain('let seconds = parts.count == 3 ? (Double(parts[2]) ?? -1) : 0')
    expect(guide).toContain('Countdown values are durations')
  })

  it('keeps Modal visibility and parent blocking aligned across hosts', () => {
    expect(ios).toContain('private final class CraftNativeModalView: UIView')
    expect(ios).toContain('if renderedVisible == visible && isHidden == !visible')
    expect(ios).toContain('if visible, alpha != opacity { alpha = opacity }')
    expect(ios).toContain('func resetForTeardown()')
    expect(ios).toContain('onRequestClose = nil')
    expect(ios).toContain('modal.setVisible(visible, opacity: number(style["opacity"]) ?? 1, animationType: props["animationType"] as? String)')
    expect(ios).toContain('if let propVisible = props["visible"] as? Bool')
    expect(ios).toContain('visible = display != nil && display != "none"')
    expect(ios).toContain('modal.transparent = props["transparent"] as? Bool == true')
    expect(ios).toContain('self.transform = CGAffineTransform(translationX: 0, y: distance)')
    expect(ios).toContain('UIView.animate(withDuration: 0.24) { self.transform = .identity }')
    expect(ios).toContain('events["onShow"]')
    expect(ios).toContain('modal.onRequestClose =')
    expect(ios).toContain('dismissSuppressedByRequest')
    expect(ios).toContain('isUserInteractionEnabled = false')
    expect(ios).toContain('guard let onRequestClose else { return }')
    expect(ios).toContain('let suppressDismiss = !visible && modal.consumeDismissSuppression()')
    expect(ios).toContain('let flowChildren = next.filter { $0.type != "Modal" }')
    expect(ios).toContain('stack.bringSubviewToFront(modal)')
    expect(ios).toContain('!($0 is CraftNativeModalView)')
    expect(android).toContain('private class CraftNativeModalView(context: Context) : FrameLayout(context)')
    expect(android).toContain('if (renderedVisible == visible && visibility == if (visible) View.VISIBLE else View.GONE)')
    expect(android).toContain('if (visible && alpha != opacity) alpha = opacity')
    expect(android).toContain('fun resetForTeardown()')
    expect(android).toContain('released.filterIsInstance<CraftNativeModalView>().forEach { it.resetForTeardown() }')
    expect(android).toContain('setVisible(visible, style.optDouble("opacity", 1.0).toFloat(), props.optString("animationType").ifBlank { null })')
    expect(android).toContain('val visible = if (props.has("visible"))')
    expect(android).toContain('props.optBoolean("visible", false)')
    expect(android).toContain('props.has("visible")')
    expect(android).toContain('if (screen.active && screen.modalVisibility[this] == visible)')
    expect(android).toContain('animate().translationY(0f).setDuration(240L).start()')
    expect(android).toContain('animate().translationY(distance).alpha(0f).setDuration(240L)')
    expect(android).toContain('if (event.action == MotionEvent.ACTION_UP) requestClose()')
    expect(android).toContain('private var dismissSuppressedByRequest = false')
    expect(android).toContain('blocker.isEnabled = false')
    expect(android).toContain('val handler = onRequestClose ?: return')
    expect(android).toContain('val suppressDismiss = !visible && consumeDismissSuppression()')
    expect(android).toContain('(modal.key as? CraftNativeModalView)?.requestClose()')
    expect(android).toContain('if (requestClose.isNotBlank()) screen.modalCloseHandlers[this] = requestClose')
    expect(android).toContain('onRequestClose = if (requestClose.isNotBlank())')
    expect(android).toContain('events.optString("onShow")')
    expect(android).toContain('if (child is CraftNativeModalView)')
    expect(android).toContain('entry.view.bringToFront()')
  })

  it('keeps pressable container disabled behavior aligned across hosts', () => {
    expect(ios).toContain('pressable.pressActiveOpacity = props["disabled"] as? Bool == true')
    expect(ios).toContain('let disabled = props["disabled"] as? Bool == true')
    expect(ios).toContain('pressable.pressBaseOpacity = number(style["opacity"]) ?? 1')
    expect(ios).toContain('pressable.pressBaseOpacity * activeOpacity')
    expect(android).toContain('screen.pressActiveOpacities[this] = props.optDouble("activeOpacity", 0.5).toFloat()')
    expect(android).toContain('view.alpha = base * active')
    expect(android).toContain('if ((handler.isNotBlank() || (type in setOf("TouchableOpacity", "TouchableHighlight", "Pressable") && hasPressLifecycle)) && !disabled)')
    expect(guide).toContain('`Pressable`')
  })

  it('delivers Pressable press-in and press-out callbacks on both hosts', () => {
    expect(ios).toContain('events["onPressIn"]')
    expect(ios).toContain('events["onPressOut"]')
    expect(ios).toContain('private func updatePressFeedback')
    expect(ios).toContain('viewPressFeedback')
    expect(android).toContain('val pressInHandler = events.optString("onPressIn")')
    expect(android).toContain('val pressOutHandler = events.optString("onPressOut")')
    expect(android).toContain('screen.pressInHandlers[view]')
    expect(android).toContain('screen.pressOutHandlers[view]')
  })

  it('keeps TextInput text styles aligned across hosts', () => {
    expect(ios).toContain('field.defaultTextAttributes = inputTextAttributes(')
    expect(ios).toContain('textView.typingAttributes = attributes')
    expect(ios).toContain('updateAuxiliaryHandler(events["onSubmitEditing"], in: &submitHandlers, for: textView)')
    expect(ios).toContain('if text == "\\n", let handler = submitHandlers[ObjectIdentifier(textView)]')
    expect(ios).toContain('textView.keyboardType = keyboardType(props["keyboardType"])')
    expect(ios).toContain('case "numeric", "number-pad": return .numberPad')
    expect(ios).toContain('case "web-search": return .webSearch')
    expect(ios).toContain('case "visible-password": return .asciiCapable')
    expect(ios).toContain('textView.returnKeyType = returnKeyType(props["returnKeyType"])')
    expect(ios).toContain('textView.isSecureTextEntry = props["secureTextEntry"] as? Bool == true')
    expect(android).toContain('configureTextStyle(this, style)')
    expect(android).toContain('"numeric", "number-pad" -> InputType.TYPE_CLASS_NUMBER')
    expect(android).toContain('"web-search" -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_WEB_EDIT_TEXT')
    expect(android).toContain('"visible-password" -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD')
    expect(android).toContain('if (props.optBoolean("autoFocus", false) && !isFocused) post')
    expect(android).toContain('if (!isFocused) {\n                        requestFocus()')
    expect(android).toContain('reusableInput?.takeIf { it.isSingleLine == !props.optBoolean("multiline", false) }')
    expect(android).toContain('val controlledValue = props.opt("value")?.takeUnless { it == JSONObject.NULL }?.toString()')
    expect(android).toContain('setTextPreservingSelection(this, controlledValue)')
    expect(android).toContain('!props.isNull("defaultValue")')
    expect(android).toContain('screen.suppressedTextChanges.add(this)')
    expect(android).toContain('if (screen.suppressedTextChanges.remove(this@apply)) return')
    expect(android).toContain('screen.suppressedTextChanges.remove(it)')
    expect(android).toContain('val requestedValue = props.opt("value")')
    expect(android).toContain('props.optBoolean("checked", false)')
    expect(android).toContain('val tint = style.opt("tintColor") as? String')
    expect(android).toContain('style.optDouble("lineHeight", Double.NaN)')
    expect(android).toContain('field.setSelection(minOf(boundedStart, boundedEnd), maxOf(boundedStart, boundedEnd))')
    expect(ios).toContain('private var inputDrafts: [String: String] = [:]')
    expect(ios).toContain('inputDrafts[current.identity] ?? props["defaultValue"] as? String')
    expect(ios).toContain('inputIdentities[id].map { inputDrafts[$0] = textView.text ?? "" }')
  })

  it('uses the shared 16-point default text size across hosts', () => {
    expect(ios).toContain('textFont(style, default: .systemFont(ofSize: 16))')
    expect(ios).toContain('field.font = textFont(style, default: .systemFont(ofSize: 16))')
    expect(ios).toContain('textView.font = textFont(style, default: .systemFont(ofSize: 16))')
    expect(android).toContain('style.optDouble("fontSize", 16.0)')
  })

  it('keeps TextInput keyboard traits aligned across hosts', () => {
    expect(ios).toContain('case "email-address": return .emailAddress')
    expect(ios).toContain('case "decimal-pad": return .decimalPad')
    expect(ios).toContain('case "done": return .done')
    expect(ios).toContain('case "characters": return .allCharacters')
    expect(android).toContain('"email-address" -> InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS')
    expect(android).toContain('"decimal-pad" -> InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL')
    expect(android).toContain('"done" -> EditorInfo.IME_ACTION_DONE')
    expect(android).toContain('"characters" -> InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS')
  })

  it('keeps blur and end-editing callbacks independent across hosts', () => {
    expect(ios).toContain('"nativeEvent": ["text": textView.text ?? ""]')
    expect(ios).toContain('"nativeEvent": ["text": sender.text ?? ""]')
    expect(android).toContain('val nativeEvent = JSONObject().put("text", text.toString())')
    expect(ios).toContain('updateAuxiliaryHandler(events["onBlur"], in: &blurHandlers, for: field)')
    expect(ios).toContain('updateAuxiliaryHandler(events["onEndEditing"], in: &endEditingHandlers, for: field)')
    expect(ios).toContain('if let handler = endEditingHandlers[id]')
    expect(android).toContain('val onBlur = events.optString("onBlur")')
    expect(android).toContain('val onEndEditing = events.optString("onEndEditing")')
    expect(android).toContain('screen.endEditingHandlers[view]?.let')
  })

  it('initializes uncontrolled text inputs from defaultValue only once', () => {
    expect(ios).toContain('defaultValue: previous?.view === textView')
    expect(ios).toContain('updateTextView(textView, value: (props["value"] as? String) ?? defaultValue)')
    expect(ios).toContain('else if previous?.view !== field {\n                updateField(field, value: inputDrafts[current.identity] ?? props["defaultValue"] as? String)')
    expect(android).toContain('else if (this !== previous && props.has("defaultValue") && !props.isNull("defaultValue")) setText(props.optString("defaultValue"))')
    expect(guide).toContain('`defaultValue` initializes an uncontrolled')
  })

  it('keeps native capability and WebView fallback gates intact', () => {
    expect(ios).toContain('mutationProtocolVersion: 1')
    expect(android).toContain('mutationProtocolVersion: 1')
    expect(ios).toContain('Missing dist/native-screen.js')
    expect(android).toContain('Missing native-screen.js')
  })

  it('keeps native teardown isolated from the WebView fallback', () => {
    // Native routes own their timers, image requests, capability requests, and
    // observers. A route must release those resources when it disappears, but
    // the fallback path remains a separate WebView host in the app shell.
    for (const marker of [
      'imageTasks.values.forEach { $0.cancel() }',
      'pendingCapabilityDeadlines.values.forEach { $0.cancel() }',
      'pendingTimers.values.forEach { $0.cancel() }',
      'pendingCapabilityRequests.forEach { CraftNativeActions.cancel(requestToken: $0) }',
      'lifecycleObservers.forEach(NotificationCenter.default.removeObserver)',
      'jsContext.objectForKeyedSubscript("__stxNativeUnmount")?.call(withArguments: [])',
      'let inStack = navigationController?.viewControllers.contains(where: { $0 === self }) ?? false',
      'if !inStack {',
      'disposeRuntime()\n                navigation.setViewControllers',
    ]) expect(ios, `${marker} missing from iOS teardown`).toContain(marker)

    for (const marker of [
      'screen.capabilityTimeouts.values.forEach(capabilityHandler::removeCallbacks)',
      'screen.pendingCapabilities.forEach(capabilities::cancel)',
      'screen.close()',
      'imageJobs.values.forEach { it.cancel(true) }',
      'imageExecutor.shutdownNow()',
      'capabilities.close()',
      'globalThis.__stxNativeUnmount && globalThis.__stxNativeUnmount()',
      'teardown.addListener',
    ]) expect(android, `${marker} missing from Android teardown`).toContain(marker)

    expect(ios).toContain('showError("Missing dist/native-screen.js. Compile a .stx screen with `stx native compile` first.")')
    expect(android).toContain('showError("Missing native-screen.js. Build with --native-bundle after compiling STX.")')
    expect(ios).not.toContain('WKWebView')
    expect(android).not.toContain('WebView(')
    expect(android).toContain('closeScreen(screens.removeAt(screens.lastIndex))\n                }\n                openScreen(route, payload.optJSONObject("params") ?: JSONObject())')
    expect(iosNavigationScript).toContain("source.includes('__stxNativeUnmount') || source.includes('mutationProtocolVersion')")
    expect(androidNavigationScript).toContain("source.includes('__stxNativeUnmount') || source.includes('mutationProtocolVersion')")
  })

  it('keeps responsive layout events aligned across hosts', () => {
    expect(ios).toContain('events["onLayout"]')
    expect(ios).toContain('lastLayoutFrames[id] != frame')
    expect(ios).toContain('for child in node["children"] as? [[String: Any]] ?? []')
    expect(android).toContain('private fun authoredKey(node: JSONObject, props: JSONObject): String?')
    expect(android).toContain('events.optString("onLayout")')
    expect(android).toContain('lastLayoutBounds[view] != bounds')
    expect(android).toContain('ViewTreeObserver.OnPreDrawListener')
    expect(android).toContain('observer.removeOnPreDrawListener(this)')
    expect(android).toContain('observer.addOnPreDrawListener(listener)')
    expect(android).toContain('screen.view.postOnAnimation { if (screen.active) emitLayoutEvents(screen) }')
    expect(android).toContain('screen.view.forceLayout()')
    expect(android).toContain('parent.forceLayout()')
    expect(android).toContain('is CraftNativeScrollView')
    expect(android).toContain('View.OnLayoutChangeListener')
    expect(android).toContain('view.addOnLayoutChangeListener(listener)')
    expect(android).toContain('view.removeOnLayoutChangeListener(listener)')
    expect(android).toContain('control.onLayoutChanged = { if (screen.active) emitLayoutEvents(screen) }')
    expect(android).toContain('released.filterIsInstance<CraftNativeFlexLayout>().forEach { it.onLayoutChanged = null }')
    expect(ios).toContain('"nativeEvent": ["layout": [')
    expect(android).toContain('.put("layout", JSONObject()')
  })

  it('rebinds Android targeted style mutations to the parent layout', () => {
    expect(android).toContain('val nodeViews = mutableMapOf<String, View>()')
    expect(android).toContain('val nodePaths = mutableMapOf<String, String>()')
    expect(android).toContain('val path = screen.nodePaths[target] ?: return false')
    expect(android).toContain('makeView(screen, document, path, screen.controls)')
    expect(android).toContain('val updated = screen.nodeViews[target] ?: return false')
    expect(android).toContain('updateParentLayoutStyle(updated, document.optJSONObject("style") ?: JSONObject())')
    expect(android).toContain('view.forceLayout()\n        view.requestLayout()\n        while (parent != null)')
    expect(android).toContain('parent.setChildStyle(view, style, resources.displayMetrics.density)')
    expect(android).toContain('parent.requestLayout()')
    expect(android).toContain('(parent as? View)?.let')
    expect(android).toContain('screen.view.setChildStyle(tree, document.optJSONObject("style") ?: JSONObject(), resources.displayMetrics.density)\n        // A full render can change a view\'s custom layout style')
    expect(android).toContain('A reused View may still carry a')
    expect(android).toContain('val requestedChecked = props.opt("checked")')
    expect(android).toContain('requestedChecked is String -> requestedChecked.isBlank()')
    expect(android).not.toContain('(child.layoutParams?.width ?: ViewGroup.LayoutParams.WRAP_CONTENT).takeIf { it >= 0 }')
    expect(android).not.toContain('(child.layoutParams?.height ?: ViewGroup.LayoutParams.WRAP_CONTENT).takeIf { it >= 0 }')
  })

  it('keeps the native root inside each host safe area', () => {
    expect(ios).toContain('view.safeAreaLayoutGuide.topAnchor')
    expect(ios).toContain('view.safeAreaLayoutGuide.bottomAnchor')
    expect(ios).toContain('if rootStyle["flex"] == nil, rootStyle["height"] == nil { rootStyle["flex"] = 1 }')
    expect(android).toContain('setOnApplyWindowInsetsListener(root)')
    expect(android).toContain('WindowInsetsCompat.Type.systemBars()')
    expect(android).toContain('view.requestLayout()')
    expect(android).toContain('view.post { screens.lastOrNull()?.takeIf { it.active }?.let(::emitLayoutEvents) }')
    expect(ios).toContain('UIResponder.keyboardWillChangeFrameNotification')
    expect(ios).toContain('self.additionalSafeAreaInsets.bottom = globalInset')
    expect(iosLayoutUnitTests).toContain('testKeyboardFrameUpdatesAndRestoresTheAdditionalSafeArea')
    expect(iosReadme).toContain("Keyboard frame changes update the native controller's additional safe area")
  })

  it('keeps reverse row scroll containers horizontal on both hosts', () => {
    expect(ios).toContain('|| flexDirection == "row-reverse"')
    expect(android).toContain('in setOf("row", "row-reverse")')
  })

  it('applies ScrollView content container styles on both hosts', () => {
    expect(ios).toContain('var contentStyle = style')
    expect(ios).toContain('props["contentContainerStyle"] as? [String: Any]')
    expect(ios).toContain('reconcileChildren(children, in: scroll.contentStack, parent: current, path: path, style: contentStyle)')
    expect(android).toContain('val contentStyle = JSONObject(style.toString()).apply')
    expect(android).toContain('props.optJSONObject("contentContainerStyle")')
    expect(android).toContain('reconcileChildren(screen, content, children, path, next, contentStyle, previousControls)')
  })

  it('keeps ScrollView pull-to-refresh controlled on both hosts', () => {
    expect(ios).toContain('scroll.setRefreshHandler(nonEmptyHandler(events["onRefresh"]).map')
    expect(ios).toContain('refreshing: props["refreshing"] as? Bool == true')
    expect(android).toContain('private class CraftNativeScrollView(context: Context) : SwipeRefreshLayout(context)')
    expect(android).toContain('fun setRefreshHandler(handler: (() -> Unit)?, refreshing: Boolean)')
    expect(android).toContain('setRefreshHandler(refreshHandler, props.optBoolean("refreshing", false))')
    expect(android).toContain('released.filterIsInstance<CraftNativeScrollView>().forEach { it.setRefreshHandler(null, false) }')
  })

  it('applies FlatList content container padding on both hosts', () => {
    expect(iosFlatList).toContain('func setContentContainerStyle(_ raw: [String: Any]?)')
    expect(ios).toContain('list.setContentContainerStyle(props["contentContainerStyle"] as? [String: Any])')
    expect(androidFlatList).toContain('fun setContentContainerStyle(style: JSONObject?, density: Float)')
    expect(android).toContain('setContentContainerStyle(props.optJSONObject("contentContainerStyle"), resources.displayMetrics.density)')
  })

  it('applies the shared gap fallback on both flex axes', () => {
    expect(ios).toContain('stack.rowGap = number(style["rowGap"]) ?? gap')
    expect(ios).toContain('stack.columnGap = number(style["columnGap"]) ?? gap')
    expect(android).toContain('private var rowGap = 0f')
    expect(android).toContain('rowGap = style.optDouble("rowGap", gap / density.toDouble()).toFloat() * density')
    expect(android).toContain('val crossGap = if (orientation == HORIZONTAL) rowGap else columnGap')
    expect(android).toContain('val crossFree = max(0f, availableCross.toFloat() - totalCross)')
    expect(android).toContain('var crossLeading = 0f')
    expect(android).toContain('crossFree / (lines.size + 1).toFloat()')
    expect(android).toContain('val stretchExtra = if (sharedCross == null && wrap && lines.size > 1 && alignContent == "stretch")')
    expect(android).toContain('val lineCross = line.cross.toFloat() + stretchExtra')
    expect(android).toContain('crossOffset += lineCross + crossBetween')
  })

  it('keeps intrinsic grid tracks equal across hosts', () => {
    expect(ios).toContain('let width = innerWidth ?? (CGFloat(columns) * cellWidth + gaps)')
    expect(ios).toContain('gridAutoRows = CraftNativeLength(raw["gridAutoRows"])')
    expect(ios).toContain('private enum CraftNativeLength: Equatable')
    expect(ios).toContain('var gridAutoRows: CraftNativeLength?')
    expect(ios).toContain('autoRowHeight: gridAutoRows.map { $0.resolve(innerHeight) ?? 0 }')
    expect(android).toContain('val cellWidth = max(0f, (availableWidth.toFloat() - max(0, gridColumns - 1) * gap) / max(1, gridColumns).toFloat())')
    expect(android).toContain('private data class GridLayout(val rows: List<List<Entry>>, val absolute: List<Entry>, val cellWidth: Float, val rowHeights: List<Float>)')
    expect(android).toContain('cellWidth * columns')
    expect(android).toContain('gridAutoRows = CraftNativeLength.from(style.opt("gridAutoRows"), density)')
    expect(android).toContain('gridAutoRows?.resolve(contentHeight)?.toFloat()')
    expect(android).toContain('gridAutoRows?.resolve(height - paddingTop - paddingBottom)')
  })

  it('derives ratio-constrained flex dimensions on both hosts', () => {
    expect(ios).toContain('let aspectRatio: CGFloat?')
    expect(ios).toContain('authoredCross.map { horizontal ? $0 * ratio : $0 / ratio }')
    expect(android).toContain('val aspectRatio: Double? = null')
    expect(android).toContain('style.aspectRatio?.let { ratio -> style.width?.resolve(base)?.div(ratio)')
    expect(android).toContain('style.aspectRatio?.let { ratio -> style.height?.resolve(base)?.times(ratio)')
    expect(nativeLayout).toContain('aspect_ratio: ?f32 = null')
    expect(nativeLayout).toContain('test "derives aspect ratio dimensions in flex and grid trees"')
    expect(guide).toContain('`aspectRatio` derives a missing width or height')
  })

  it('keeps grid alignContent in the shared layout core', () => {
    expect(nativeLayout).toContain('test "distributes leftover grid rows with align content"')
    expect(nativeLayout).toContain('test "distributes grid rows evenly with align content"')
    expect(nativeLayout).toContain('test "distributes auto rows with grid align content"')
    expect(nativeLayout).toContain('switch (align_content)')
    expect(nativeLayout).toContain('row_extra = free_rows')
    expect(ios).toContain('craft_native_grid_aligned')
    expect(ios).toContain('alignContent: craftNativeAlignContentCode(alignContent)')
    expect(ios).toContain('case "space-evenly":\n                rowLeading = gridFree / CGFloat(rowHeights.count + 1)')
    expect(android).toContain('alignContentCode(),')
    expect(androidNative).toContain('nativeGridAutoRowsAligned(')
    expect(androidNative).toContain('nativeGridAligned(')
    expect(androidDispatch).toContain('.name = "nativeGridAligned"')
    expect(androidDispatch).toContain('.name = "nativeGridAutoRowsAligned"')
    expect(androidDispatch).toContain('expectEqual(@as(usize, 111), natives.len)')
    expect(ios).toContain('var rowExtra: CGFloat = 0')
    expect(android).toContain('var rowLeading = 0f')
    expect(android).toContain('rowBetween += freeRows / (rowCount + 1).toFloat()')
    expect(android).toContain('var rowTop = paddingTop.toFloat() + rowLeading')
    expect(android).toContain('val freeRows = max(0f, contentHeight.toFloat() - totalRows - rowGaps)')
    expect(android).toContain('private fun distribution(free: Float, count: Int): Pair<Float, Float>')
    expect(android).toContain('available / (count + 1).toFloat()')
  })

  it('keeps per-edge margins in native flex and grid layout', () => {
    expect(ios).toContain('marginTop: CGFloat')
    expect(ios).toContain('let horizontalMargin = number(raw["marginHorizontal"]) ?? margin')
    expect(ios).toContain('let mainLeading = horizontal ? style.marginLeft : style.marginTop')
    expect(ios).toContain('let crossTrailing = horizontal ? style.marginBottom : style.marginRight')
    expect(ios).toContain('var mainMargins: CGFloat { mainLeading + mainTrailing }')
    expect(android).toContain('style.optDouble("marginLeft", horizontal)')
    expect(android).toContain('setMargins(')
    expect(android).toContain('entry.height + (lp?.topMargin ?: 0) + (lp?.bottomMargin ?: 0)')
    expect(android).toContain('val availableWidth = max(0f, layout.cellWidth - marginLeft - marginRight)')
    expect(android).toContain('val crossLeading = (if (orientation == HORIZONTAL)')
  })

  it('keeps flex distribution inside declared min and max bounds', () => {
    expect(nativeLayout).toContain('fn flexLambda(')
    expect(nativeLayout).toContain('fn nodeFlexUsed(')
    expect(nativeLayout).toContain('water-fill')
    expect(ios).toContain('let minMain = (horizontal ? style.minWidth : style.minHeight)?.resolve(definiteMain)')
    expect(ios).toContain('let maxMain = (horizontal ? style.maxWidth : style.maxHeight)?.resolve(definiteMain)')
    expect(ios).toContain('func fallbackWidths(for line: Range<Int>, available: CGFloat, gap: CGFloat)')
    expect(ios).toContain('frozen.insert(offset)')
    expect(ios).toContain('items[index].cross = clamp(measured.cross, item.minCross, item.maxCross)')
    expect(android).toContain('private fun fallbackFlexWidths(line: Line, available: Int, gap: Float): IntArray')
    expect(android).toContain('var bounded = raw')
    expect(android).toContain('val distributedPrimary = sharedPrimary?.get(index)?.roundToInt() ?: fallbackWidths[index]')
    expect(navigationHome).toContain('testID="flex-bound-first"')
    expect(navigationHome).toContain('"maxWidth":64')
    expect(iosNavigationTest).toContain('remaining flex space was not redistributed')
    expect(androidNavigationTest).toContain('remaining flex space was not redistributed')
  })

  it('inherits parent alignment when alignSelf is auto on both hosts', () => {
    expect(ios).toContain('alignSelf = align == "auto" ? nil : align')
    expect(android).toContain('it.isNotBlank() && it != "auto"')
    expect(android).toContain('entry.style.alignSelf ?: alignItems')
  })

  it('uses a zero basis for positive flex shorthand on both hosts', () => {
    expect(ios).toContain('flexBasis = CraftNativeLength(raw["flexBasis"]) ?? flex.flatMap { $0 > 0 ? .points(0) : nil }')
    expect(android).toContain('flex?.takeIf { it > 0.0 }?.let { CraftNativeLength(points = 0) }')
  })

  it('clamps negative flex growth to zero on both hosts', () => {
    expect(ios).toContain('flexGrow = number(raw["flexGrow"]) ?? flex.map { max(0, $0) } ?? 0')
    expect(android).toContain('flex?.coerceAtLeast(0.0) ?: 0.0')
  })

  it('aligns omitted flex-shrink defaults for labels and scroll hosts', () => {
    expect(ios).toContain('defaultShrink = horizontal ? 1 : 0')
    expect(android).toContain('val flexShrink: Double? = null')
    expect(android).toContain('it.style.flexShrink ?: defaultFlexShrink(it.view)')
    expect(android).toContain('view is TextView && view !is Button && view !is EditText && orientation == HORIZONTAL')
  })

  it('distributes wrapped flex lines with alignContent on both hosts', () => {
    expect(ios).toContain('var alignContent = "flex-start"')
    expect(ios).toContain('case "space-between": crossBetween = free / CGFloat(lineCrosses.count - 1) + crossGap')
    expect(ios).toContain('case "space-evenly":')
    expect(ios).toContain('case "space-evenly": 6')
    expect(ios).toContain('crossBetween = free / CGFloat(lineCrosses.count + 1) + crossGap')
    expect(android).toContain('private var alignContent = "flex-start"')
    expect(android).toContain('"space-between" -> crossBetween = crossFree / (lines.size - 1).toFloat() + crossGap')
    expect(android).toContain('"space-evenly" -> {')
    expect(android).toContain('crossBetween = crossFree / (lines.size + 1).toFloat() + crossGap')
    expect(nativeLayout).toContain('6=space-evenly')
    expect(nativeLayout).toContain('test "exports evenly distributed wrapped flex lines"')
    expect(componentTypes).toContain("'space-evenly'")
    expect(android).toContain('alignContent == "stretch"')
    expect(android).toContain('ids.indices.drop(1).all { index -> ids[index] >= ids[index - 1] }')
    expect(navigationHome).toContain('testID="align-content-wrap"')
    expect(navigationHome).toContain('testID="align-content-stretch-wrap"')
    expect(navigationHome).toContain('testID="align-content-evenly-wrap"')
    expect(iosNavigationTest).toContain('alignContent did not distribute wrapped lines')
    expect(navigationHome).toContain('testID="grid-align-wrap"')
    expect(navigationHome).toContain('testID="grid-aspect-ratio-box" style={{"width":80,"aspectRatio":2')
    expect(navigationHome).toContain('testID="grid-align-evenly-wrap"')
    expect(navigationHome).toContain('testID="aspect-ratio-box"')
    expect(iosNavigationTest).toContain('grid aspectRatio did not derive height from width')
    expect(iosNavigationTest).toContain('aspectRatio did not derive height from width')
    expect(androidNavigationTest).toContain('gridAspect.height')
    expect(iosNavigationTest).toContain('grid space-evenly missed the inter-row slot')
    expect(androidNavigationTest).toContain('grid space-evenly missed the inter-row slot')
    expect(androidNavigationTest).toContain('aspectRatioBox.height')
    expect(iosNavigationTest).toContain('grid alignContent did not center its rows')
    expect(androidNavigationTest).toContain('grid alignContent did not center its rows')
    expect(androidNavigationTest).toContain('alignContent did not distribute wrapped lines')
    expect(iosNavigationTest).toContain('alignContent space-evenly missed the leading slot')
    expect(androidNavigationTest).toContain('alignContent space-evenly missed the inter-line slot')
    expect(iosNavigationTest).toContain('alignContent stretch did not expand the first line')
    expect(androidNavigationTest).toContain('alignContent stretch did not expand the first line')
    expect(ios).toContain('items[index].cross = clamp(lineCrosses[lineIndex] - item.crossMargins, item.minCross, item.maxCross)')
    expect(iosLayoutUnitTests).toContain('testAlignContentStretchExpandsAutoCrossSizes')
    expect(ios).toContain('if reverse && wrap && lines.count > 1 { lines.reverse() }')
    expect(android).toContain('if (reverse && wrap && lines.size > 1) lines.reverse()')
    expect(ios).toContain('let physicalLineOffset = crossReversed ? contentCross - lineOffset - lineCross : lineOffset')
    expect(android).toContain('val physicalLineOffset = if (wrapReverse && wrap)')
    expect(ios).toContain('stack.wrapReverse = flexWrap == "wrap-reverse"')
    expect(android).toContain('wrapReverse = flexWrap == "wrap-reverse"')
    expect(iosNavigationTest).toContain('row-reverse reversed wrapped line order')
    expect(androidNavigationTest).toContain('row-reverse reversed wrapped line order')
  })

  it('resolves percentage lengths against the native parent on both hosts', () => {
    expect(navigationHome).toContain('style={{"width":"50%","height":20}}')
    expect(ios).toContain('case .percent(let fraction): return base.map { max(0, $0 * fraction) }')
    expect(android).toContain('val fraction: Double? = null')
    expect(android).toContain('style.width?.resolve(base)')
  })

  it('treats null layout values as unset on both hosts', () => {
    expect(ios).toContain('func number(_ value: Any?) -> CGFloat?')
    expect(android).toContain('if (value == null || value == JSONObject.NULL) return null')
    expect(android).toContain('fun number(name: String): Int?')
    expect(android).toContain('raw.optDouble(name, Double.NaN)')
    expect(android).toContain('style.has("backgroundColor") && !style.isNull("backgroundColor")')
    expect(android).toContain('style.width?.resolve(base)')
    expect(android).toContain('ViewGroup.LayoutParams.WRAP_CONTENT')
    expect(android).toContain('gridAutoRows = CraftNativeLength.from(style.opt("gridAutoRows"), density)')
    expect(android).toContain('raw.opt("alignSelf")')
    expect(android).toContain('raw.opt("position")')
    expect(navigationHome).toContain('style={{"width":textWidthUnset ? null : 160')
    expect(navigationHome).toContain('testID="toggle-null-width"')
  })

  it('keeps elevation visible on both native hosts', () => {
    expect(ios).toContain('let elevation = max(0, number(style["elevation"]) ?? 0)')
    expect(ios).toContain('view.layer.shadowOpacity = elevation > 0')
    expect(android).toContain('view.elevation = dp(style.optDouble("elevation", 0.0)).toFloat()')
  })

  it('applies the public zIndex style on both native hosts', () => {
    expect(ios).toContain('view.layer.zPosition = number(style["zIndex"]) ?? 0')
    expect(android).toContain('view.z = style.optDouble("zIndex", 0.0).toFloat()')
  })

  it('applies and clears text shadows on both native hosts', () => {
    expect(ios).toContain('if let shadow = textShadow(style) { attributes[.shadow] = shadow }')
    expect(ios).toContain('shadow.shadowBlurRadius = max(0, number(style["textShadowRadius"]) ?? 0)')
    expect(android).toContain('view.paint.clearShadowLayer()')
    expect(android).toContain('view.setShadowLayer(')
    expect(android).toContain('style.optString("textShadowColor")')
  })

  it('maps text decoration style and color on both native hosts', () => {
    expect(ios).toContain('addTextDecorationAttributes(style, to: &attributes)')
    expect(ios).toContain('attributes[.underlineColor] = decorationColor')
    expect(ios).toContain('case "dotted": return [.single, .patternDot]')
    expect(android).toContain('CraftTextDecorationSpan(')
    expect(android).toContain('style.optString("textDecorationStyle").ifBlank { "solid" }')
    expect(android).toContain('style.optString("textDecorationColor")')
  })

  it('keeps horizontal list rows intrinsically sized across hosts', () => {
    expect(iosFlatList).toContain('flowLayout.scrollDirection = horizontal ? .horizontal : .vertical')
    expect(iosFlatList).toContain('maxWidth: CraftNativeFlexLayout.unbounded,')
    expect(iosFlatList).toContain('attributes.size = CGSize(width: max(1, ceil(measured.width)), height: max(1, height))')
    expect(iosFlatList).not.toContain('bounds.width * 0.8')
    expect(androidFlatList).toContain('if (horizontal) LayoutParams.WRAP_CONTENT else LayoutParams.MATCH_PARENT')
    expect(androidFlatList).toContain('updateVisibleHolderLayoutParams()')
    expect(androidFlatList).toContain('holder.host.layoutParams = holderLayoutParams()')
  })

  it('keeps vertical list rows intrinsically sized across hosts', () => {
    expect(iosFlatList).toContain('let width = fittingExtent ?? layoutAttributes.size.width')
    expect(iosFlatList).toContain('maxHeight: CraftNativeFlexLayout.unbounded')
    expect(iosFlatList).toContain('attributes.size = CGSize(width: max(1, width), height: max(1, ceil(measured.height)))')
    expect(androidFlatList).toContain('renderedLayout?.height ?: LayoutParams.WRAP_CONTENT')
    expect(androidFlatList).toContain('holder.host.addView(view, hostedLayout)')
  })

  it('keeps image source lifecycles and resize modes aligned', () => {
    expect(ios).toContain('imageTasks.removeValue(forKey: id)?.cancel()')
    expect(ios).toContain('guard self.imageSources[ObjectIdentifier(view)] == uri else { return }')
    expect(ios).toContain('image.withRenderingMode(tintedImages.contains(ObjectIdentifier(view)) ? .alwaysTemplate : .alwaysOriginal)')
    expect(ios).toContain('case "cover": return .scaleAspectFill')
    expect(android).toContain('imageJobs.remove(view)?.cancel(true)')
    expect(android).toContain('if (imageSources[view] != uri) return@runOnUiThread')
    expect(android).toContain('private fun loadsImage(uri: Uri): Boolean')
    expect(android).toContain('host == "10.0.2.2"')
    expect(android).toContain('host.endsWith(".localhost")')
    expect(android).toContain('if (!loadsImage(Uri.parse(uri)))')
    expect(android).toContain('"cover" -> ImageView.ScaleType.CENTER_CROP')
    expect(android).toContain('val tint = style.opt("tintColor") as? String')
    expect(android).toContain('tint == "null" || tint == "undefined"')
    expect(android).toContain('view.clearColorFilter()')
  })

  it('lets stopped Android activity indicators leave the indeterminate-only spinner style', () => {
    expect(android).toContain('private class CraftNativeActivityIndicator(context: Context)')
    expect(android).toContain('android.R.attr.progressBarStyleHorizontal')
    expect(android).toContain('progressDrawable = spinner?.constantState?.newDrawable()?.mutate() ?: spinner')
    expect(android).toContain('previous as? CraftNativeActivityIndicator ?: CraftNativeActivityIndicator(this)')
    expect(android).toContain('isIndeterminate = animating')
  })

  it('keeps account navigation buttons compatible with the release SDK', () => {
    expect(ios).toContain('let item = UIBarButtonItem(customView: button)')
    // iOS 26 bar-item APIs only behind a compiler guard: older SDKs in the
    // release matrix lack them, and without them iOS 26 draws the two
    // circles as tinted ovals on one glass platter.
    const guarded = '#if compiler(>=6.2)\n        if #available(iOS 26.0, *) { item.hidesSharedBackground = true; item.sharesBackground = false }\n        #endif'
    expect(ios).toContain(guarded)
    expect(ios.split('hidesSharedBackground').length - 1).toBe(1)
    expect(ios.split('sharesBackground').length - 1).toBe(1)
    // The unread dot and count are tinted symbols: iOS 26 drew a bar
    // item's plain backgroundColor white.
    expect(ios).toContain('let fill = UIImageView(image: UIImage(systemName: "circle.fill"))')
    expect(ios).toContain('fill.tintColor = dot ? .systemRed : .systemBlue')
  })

  it('lets the keyboard cover the tab bar rather than carry it up', () => {
    const app = readFileSync(join(root, 'packages/ios/templates/CraftApp.swift'), 'utf8')
    expect(app.split('.ignoresSafeArea(.keyboard, edges: .bottom)').length - 1).toBe(2)
  })

  it('ends the hybrid web view at the keyboard, so sticky headers stay on screen', () => {
    const hybrid = readFileSync(join(root, 'packages/ios/templates/CraftHybrid.swift'), 'utf8')
    const app = readFileSync(join(root, 'packages/ios/templates/CraftApp.swift'), 'utf8')
    expect(hybrid).toContain('webHost.safeAreaRegions = [.keyboard]')
    expect(hybrid).toContain('CraftWebView(config: config).ignoresSafeArea(.container)')
    // The tab bar is covered while the keyboard is up, so the page stops leaving room for it.
    expect(app).toContain('let height = tabBarVisible && !keyboardUp ? Int(occupied) : 0')
  })

  it('moves the page to a native root\'s path when it has no history left to go back through', () => {
    const hybrid = readFileSync(join(root, 'packages/ios/templates/CraftHybrid.swift'), 'utf8')
    expect(hybrid).toContain('hybrid.pageReset(to: rootPath)')
    expect(hybrid).toContain('hybrid.pageDepth == 0')
  })

  it('keeps FlatList gesture callbacks on the shared scroll payload', () => {
    for (const callback of ['onScroll', 'onScrollBeginDrag', 'onScrollEndDrag', 'onMomentumScrollBegin', 'onMomentumScrollEnd']) {
      const iosCallback = callback === 'onScroll' ? 'onScrollEvent' : callback
      expect(ios, `${callback} missing iOS FlatList payload`).toContain(`list.${iosCallback} =`)
      expect(android, `${callback} missing Android FlatList payload`).toContain(`list.${iosCallback} =`)
    }
    expect(ios).toContain('self?.scrollEvent(scrollView) ?? [:]')
    expect(android).toContain('flatListScrollEvent(list)')
    expect(guide).toContain('including the same')
  })

  it('treats a null image style resize mode as unset', () => {
    expect(ios).toContain('let requestedResizeMode = style["resizeMode"] as? String ?? props["resizeMode"] as? String')
    expect(ios).toContain('image.contentMode = imageContentMode(requestedResizeMode)')
    expect(android).toContain('style.optString("resizeMode").ifBlank { props.optString("resizeMode") }')
  })

  it('preserves image failure accessibility details across reconciliation', () => {
    expect(ios).toContain('private var imageErrors: [ObjectIdentifier: String] = [:]')
    expect(ios).toContain('imageErrors[ObjectIdentifier(view)] = message')
    expect(ios).toContain('if (type == "Image" || type == "ImageBackground"), let message = imageErrors[ObjectIdentifier(view)]')
    expect(ios).toContain('if imageSources[id] == "" { return }')
    expect(ios).toContain('imageSources[id] = ""')
    expect(android).toContain('if (control is ImageView) imageErrors[control]?.let')
    expect(android).toContain('if (!current.contains(message))')
    expect(android).toContain('current.ifBlank { view.tag?.toString() ?: "Image" }')
    expect(android).toContain('joinToString(", ")')
    expect(android).toContain('if (imageSources[view] == "") return')
    expect(android).toContain('imageSources[view] = ""')
  })

  it('keeps activity indicator visibility and sizing props aligned', () => {
    expect(ios).toContain('if let numericSize = requestedSize as? NSNumber')
    expect(ios).toContain('indicator.transform = CGAffineTransform(scaleX: scale, y: scale)')
    expect(ios).toContain('indicator.hidesWhenStopped = props["hidesWhenStopped"] as? Bool ?? true')
    expect(ios).toContain('indicator.stopAnimating()')
    expect(android).toContain('val requestedSize = props.opt("size")')
    expect(android).toContain('is Number -> (requestedSize.toDouble() / 24.0).toFloat().coerceAtLeast(0.5f)')
    expect(android).toContain('isIndeterminate = animating')
    expect(android).toContain('props.optBoolean("hidesWhenStopped", true)')
    expect(android).toContain('if (style.optString("display") == "none" || (!animating && hidesWhenStopped))')
  })

  it('snaps controlled slider values on initial render across hosts', () => {
    expect(ios).toContain('slider.value = snappedSliderValue(value, for: slider)')
    expect(android).toContain('val requested = props.optDouble("value", minimum)')
    expect(android).toContain('if (step != null) minimum + ((requested - minimum) / step).roundToInt() * step else requested')
    expect(android).toContain('val progressMax = step?.let {')
    expect(android).toContain('ceil((maximum - minimum) / it).toLong()')
    expect(android).toContain('.coerceIn(1L, Int.MAX_VALUE.toLong())')
    expect(android).toContain('((value - minimum) / step).roundToInt().coerceIn(0, max)')
  })

  it('preserves exact Android slider step values for large ranges', () => {
    expect(android).toContain('minimum + progress * step else')
    expect(android).toContain('minimum + seekBar.progress * step else')
    expect(android).toContain('.coerceIn(minimum, maximum)')
    expect(android).not.toContain('val snappedProgress = (((value - minimum) / (maximum - minimum)) * max)')
  })

  it('resets removed accessibility metadata on both hosts', () => {
    expect(ios).toContain('} else if type != "TextInput" {\n            view.accessibilityValue = nil')
    expect(android).toContain('view.contentDescription = when {')
    expect(android).toContain('else -> null')
    expect(android).toContain('view.tooltipText = props.optString("accessibilityHint").takeIf { it.isNotBlank() }')
    expect(android).toContain('info.hintText = host.tooltipText')
    expect(android).toContain('info.isEnabled = host.isEnabled && !disabled')
  })

  it('keeps generic pressable views interactive without disabling scroll containers', () => {
    expect(ios).toContain('if !(view is UIScrollView) { view.isUserInteractionEnabled = handler != nil || longPressHandlers[id] != nil || view is CraftNativeFlowView }')
    expect(ios).toContain('if let handler, !handler.isEmpty { handlers[id] = handler }')
    expect(ios).toContain('let handler = handler?.isEmpty == false ? handler : nil')
    expect(ios).toContain('list.onMomentumScrollEnd = nonEmptyHandler(events["onMomentumScrollEnd"]).map')
    expect(ios).toContain('private func nonEmptyHandler(_ handler: String?) -> String?')
    expect(ios).toContain('nonEmptyHandler(events["onPress"]) ?? nonEmptyHandler(events["onClick"])')
    expect(ios).toContain('nonEmptyHandler(events["onChange"]) ?? nonEmptyHandler(events["onChangeText"])')
    expect(ios).toContain('nonEmptyHandler(events["onValueChange"]) ?? nonEmptyHandler(events["onChange"])')
    expect(android).toContain('control.isClickable = true')
    expect(android).toContain('control.setOnClickListener {')
  })

  it('delivers long-press events and releases their native handlers', () => {
    expect(ios).toContain('private var longPressHandlers: [ObjectIdentifier: String] = [:]')
    expect(ios).toContain('UILongPressGestureRecognizer(target: self, action: #selector(viewLongPressed(_:)))')
    expect(ios).toContain('guard sender.state == .began')
    expect(ios).toContain('longPressRecognizers.removeValue(forKey: id)')
    expect(ios).toContain('handlers[ObjectIdentifier(view)] != nil || longPressHandlers[ObjectIdentifier(view)] != nil')
    expect(android).toContain('val longPressHandlers = mutableMapOf<View, String>()')
    expect(android).toContain('events.optString("onLongPress").takeUnless { longPressDisabled } ?: ""')
    expect(android).toContain('val longPressDisabled = props.optBoolean("disabled", false) ||')
    expect(android).toContain('control.setOnLongClickListener {')
    expect(android).toContain('screen.longPressHandlers.keys.removeAll(released)')
    expect(guide).toContain('`onLongPress`')
    expect(ios).toContain('if !(view is UIScrollView) { view.isUserInteractionEnabled = true }')
    expect(ios).toContain('view.isUserInteractionEnabled = handlers[id] != nil || view is CraftNativeFlowView')
  })

  it('lets accessibility disabled state disable controls without re-enabling them', () => {
    expect(ios).toContain('if let control = view as? UIControl {')
    expect(ios).toContain('else if handlers[ObjectIdentifier(view)] != nil || longPressHandlers[ObjectIdentifier(view)] != nil {')
    expect(android).toContain('} else if (disabled) {\n            view.isEnabled = false')
    expect(android).not.toContain('if (state != null && state.has("disabled")) view.isEnabled = !disabled')
  })

  it('restores generic Android pressables when accessibility disabled clears', () => {
    expect(android).toContain('if (type !in setOf("Button", "Link", "Checkbox", "TextInput", "Picker", "DatePicker", "Modal", "Switch", "Slider", "ActivityIndicator")) {\n            view.isEnabled = !disabled')
  })

  it('dismisses the keyboard from native scroll containers on drag', () => {
    expect(ios).toContain('scroll.keyboardDismissMode = keyboardDismissMode(props["keyboardDismissMode"])')
    expect(ios).toContain('case "interactive": return .interactive')
    expect(android).toContain('keyboardDismissMode: String')
    expect(android).toContain('keyboardDismissMode in setOf("on-drag", "interactive")')
    expect(android).toContain('hideSoftInputFromWindow(nativeScroll.windowToken, 0)')
    expect(ios).toContain('list.keyboardDismissMode = keyboardDismissMode(props["keyboardDismissMode"])')
    expect(android).toContain('setKeyboardDismissMode(props.optString("keyboardDismissMode"))')
    expect(androidFlatList).toContain('fun setKeyboardDismissMode(mode: String, dismissKeyboard: () -> Unit)')
    expect(androidFlatList).toContain('android.view.MotionEvent.ACTION_MOVE')
    expect(navigationHome).toContain('<ScrollView testID="native-scroll" keyboardDismissMode="on-drag"')
    expect(navigationHome).toContain('<ScrollView testID="native-root-scroll" style={{"flex":1}}>')
    expect(navigationHome).toContain('keyboardShouldPersistTaps="handled"')
    expect(navigationDetails).toContain('keyboardShouldPersistTaps="handled"')
    expect(guide).toContain('both hosts, including keyboard and return-key traits on multiline inputs')
    expect(guide).toContain('`ScrollView` and `FlatList` emit the scroll callbacks described above, accept')
  })

  it('keeps keyboard tap persistence aligned across scroll hosts', () => {
    expect(ios).toContain('scroll.setKeyboardShouldPersistTaps(props["keyboardShouldPersistTaps"])')
    expect(ios).toContain('private var keyboardShouldPersistTaps = "never"')
    expect(iosFlatList).toContain('func setKeyboardShouldPersistTaps(_ value: Any?)')
    expect(ios).toContain('list.setKeyboardShouldPersistTaps(props["keyboardShouldPersistTaps"])')
    expect(android).toContain('setKeyboardShouldPersistTaps(props.optString("keyboardShouldPersistTaps", "never"))')
    expect(android).toContain('"handled" -> (scroller as? ViewGroup)')
    expect(androidFlatList).toContain('fun setKeyboardShouldPersistTaps(value: String?)')
    expect(androidFlatList).toContain('shouldDismissKeyboard(event)')
    expect(guide).toContain('keyboardShouldPersistTaps')
  })

  it('delivers ScrollView momentum callbacks on both hosts', () => {
    expect(ios).toContain('events["onMomentumScrollBegin"]')
    expect(ios).toContain('scrollViewWillBeginDecelerating')
    expect(ios).toContain('scrollViewDidEndDecelerating')
    expect(android).toContain('scrollMomentumBeginHandlers')
    expect(android).toContain('onMomentumBegin: (() -> Unit)?')
    expect(android).toContain('if (moved && !momentumActive)')
    expect(guide).toContain('`onMomentumScrollBegin` and `onMomentumScrollEnd`')
  })

  it('forwards FlatList scroll and momentum callbacks through virtualized hosts', () => {
    expect(ios).toContain('list.onScrollEvent = nonEmptyHandler(events["onScroll"])')
    expect(iosFlatList).toContain('var onMomentumScrollBegin: ((UIScrollView) -> Void)?')
    expect(iosFlatList).toContain('func scrollViewDidEndDecelerating')
    expect(android).toContain('list.onScrollEvent = events.optString("onScroll")')
    expect(androidFlatList).toContain('var onMomentumScrollEnd: (() -> Unit)? = null')
    expect(androidFlatList).toContain('RecyclerView.SCROLL_STATE_SETTLING')
  })

  it('keeps the maintained navigation fixture on the host-neutral keyed ScrollView path', () => {
    expect(android).toContain('props.opt("onEndReachedThreshold")')
    expect(android).toContain('takeUnless { it == JSONObject.NULL }')
    expect(android).toContain('props.optDouble("threshold", 0.1)')
    expect(navigationDetails).toContain('<ScrollView')
    expect(navigationDetails).toContain(':for="(item, index) in people"')
    expect(navigationDetails).toContain(':key="item.id"')
    expect(navigationDetails).toContain(':text="\'People: \' + people().length + \'; events: \' + listEvents"')
    expect(navigationDetails).toContain('testID="load-more-people"')
  })

  it('keeps SectionList on the maintained native scroll path', () => {
    expect(navigationHome).toContain('<SectionList testID="native-section-list"')
    expect(ios).toContain('case "ScrollView", "SectionList":')
    expect(android).toContain('"ScrollView", "SectionList" ->')
    expect(androidBuilderTest).toContain('"ScrollView", "SectionList" -> (previous as? CraftNativeScrollView')
    expect(guide).toContain('`SectionList` currently follows the same native scroll host')
    expect(navigationHome).toContain('@scroll="captureSectionScroll()"')
    expect(navigationHome).toContain('testID="native-section-footer"')
    expect(iosNavigationTest).toContain('sectionList.swipeUp()')
    expect(iosNavigationTest).toContain('section-scroll-status')
    expect(androidNavigationTest).toContain('awaitText(activity, "section-scroll-status", "Section scrolls: 1")')
  })

  it('keeps picker initialization assertions aligned with the shared status baseline', () => {
    expect(androidNavigationTest).toContain('initial picker selection must not emit onChange", "button style accented"')
    expect(iosNavigationTest).toContain('app.staticTexts["native-link-status"].label, "button style accented"')
  })

  it('keeps FlatList pull-to-refresh aligned across hosts', () => {
    expect(iosFlatList).toContain('UIRefreshControl')
    expect(iosFlatList).toContain('func setRefreshHandler(_ handler: (() -> Void)?, refreshing: Bool)')
    expect(ios).toContain('events["onRefresh"]')
    expect(ios).toContain('list.setRefreshHandler(nil, refreshing: false)')
    expect(android).toContain('CraftNativeRefreshableFlatList')
    expect(android).toContain('events.optString("onRefresh")')
    expect(androidRefreshableFlatList).toContain('SwipeRefreshLayout')
    expect(androidRefreshableFlatList).toContain('isRefreshing = handler != null && refreshing')
    expect(androidRefreshableFlatList).toContain('isRefreshing = false')
    expect(guide).toContain('pull-to-refresh')
  })

  it('tests the iOS refresh control callback and controlled state', () => {
    expect(iosNativeUnitTests).toContain('testFlatListRefreshControlForwardsAndTracksControlledState')
    expect(iosNativeUnitTests).toContain('control.sendActions(for: .valueChanged)')
    expect(iosNativeUnitTests).toContain('XCTAssertTrue(control.isRefreshing)')
  })

  it('emits onLayout for virtualized rows on both hosts', () => {
    expect(ios).toContain('flatListRows[ObjectIdentifier(list)]?.values.forEach { emitLayoutEvents(for: $0) }')
    expect(android).toContain('private fun emitLayoutEvents(screen: Screen, view: View)')
    expect(androidFlatList).toContain('var onLayoutChanged: (() -> Unit)? = null')
    expect(androidFlatList).toContain('onLayoutChanged?.invoke()')
    expect(androidFlatList).toContain('override fun onScrolled(recyclerView: RecyclerView, dx: Int, dy: Int)')
    expect(android).toContain('list.onLayoutChanged = {')
    expect(iosFlatList).toContain('onLayoutChanged?()')
  })

  it('keeps the native navigation fixture honest about recycled row layouts', () => {
    const details = readFileSync(join(root, 'packages/ios/fixtures/native-navigation/Details.stx'), 'utf8')
    const iosTests = readFileSync(join(root, 'packages/ios/fixtures/native-navigation/NativeNavigationUITests.swift'), 'utf8')
    const androidTests = readFileSync(join(root, 'packages/android/fixtures/native-navigation/NativeNavigationTest.kt'), 'utf8')
    expect(details).toContain('@layout="captureRowLayout()"')
    expect(details).toContain('@refresh="refreshPeople()"')
    expect(details).toContain('refreshing={peopleRefreshing}')
    expect(iosTests).toContain('ScrollView pull-to-refresh did not invoke onRefresh')
    expect(androidTests).toContain('pullToRefresh(peopleHost)')
    expect(details).toContain('testID="people-layout-status"')
    expect(iosTests).toContain('ScrollView did not report a row layout after insertion')
    expect(androidTests).toContain('awaitLayoutIncrease(activity, "people-layout-status", initialRowLayouts)')
    expect(androidTests).not.toContain('Rows laid out: ${initialRowLayouts + 1}')
    expect(iosNavigationScript).toContain("const prepareOnly = process.argv.includes('--prepare-only')")
    expect(iosNavigationScript).toContain("console.log('iOS native navigation fixture prepared')")
  })

  it('proves shared-runtime keyed rows through the maintained iOS host', () => {
    expect(navigationHome).toContain("globalThis.craft.storage.remove('native-navigation-details-destroyed')")
    expect(navigationHome).toContain('const navigationRows = state([')
    expect(navigationHome).toContain('navigationRows.set([')
    expect(navigationDetails).toContain('const people = state(')
    expect(navigationDetails).toContain('onDestroy(() => globalThis.craft.storage.set(')
    expect(navigationHome).toContain('<View :for="row in navigationRows" :key="row.id"')
      expect(navigationHome).toContain(":testID=\"'navigation-input-' + row.id\"")
    expect(navigationHome).toContain('@input="updateNavigationDraft(row.id, $event)"')
    expect(navigationHome).toContain('@click="selectNavigationRow(row.id)"')
    expect(iosNavigationTest).toContain('testSharedRuntimeKeyedForPreservesNativeRowState')
      expect(iosNavigationTest).toContain('app.textFields["navigation-input-b"]')
    expect(iosNavigationTest).toContain('beaInput.typeText("!")')
    expect(iosNavigationTest).toContain('value as? String, "draft!"')
    expect(iosNavigationTest).toContain('keyed reconciliation replaced the list scroll host')
  })

  it('keeps reverse flex directions covered on both native hosts', () => {
    expect(navigationHome).toContain('testID="reverse-column"')
    expect(navigationHome).toContain('flexDirection":"column-reverse"')
    expect(navigationHome).toContain('tintColor":imageTinted ? "#2563eb" : null')
    expect(iosNavigationTest).toContain('column-reverse did not invert the main axis')
    expect(androidNavigationTest).toContain('column-reverse did not invert the main axis')
    expect(android).toContain('if (style.optString("flexDirection").endsWith("-reverse")) desired.reverse()')
    expect(ios).toContain('if (style["flexDirection"] as? String)?.hasSuffix("-reverse") == true')
  })

  it('exercises shared non-reverse justify positions in the maintained fixture', () => {
    expect(navigationHome).toContain('testID="justify-center-wrap"')
    expect(navigationHome).toContain('"justifyContent":"center"')
    expect(navigationHome).toContain('testID="justify-between-wrap"')
    expect(navigationHome).toContain('"justifyContent":"space-between"')
    expect(iosNavigationTest).toContain('shared justify-center position was not applied')
    expect(androidNavigationTest).toContain('shared justify-center position was not applied')
    expect(iosNavigationTest).toContain('shared space-between trailing position was not applied')
    expect(androidNavigationTest).toContain('shared space-between trailing position was not applied')
  })

  it('exercises cross-axis alignItems and alignSelf in the maintained fixture', () => {
    expect(navigationHome).toContain('testID="cross-axis-wrap"')
    expect(navigationHome).toContain('"alignItems":"center"')
    expect(navigationHome).toContain('"alignSelf":"flex-end"')
    expect(iosNavigationTest).toContain('alignItems center did not center the child')
    expect(androidNavigationTest).toContain('alignSelf flex-end did not move the child to the line end')
  })

  it('retains keyed iOS input drafts while FlatList rows recycle', () => {
    expect(ios).toContain('self.forgetHandlers(row, preservingInputDrafts: true)')
    expect(ios).toContain('private func forgetHandlers(_ node: RenderedNode, preservingInputDrafts: Bool = false)')
    expect(android).toContain('screen.drafts[identity] = updated')
    expect(android).toContain('val inputIdentities = mutableMapOf<EditText, String>()')
    expect(android).toContain('if (!preservingInputDrafts) identity?.let(screen.drafts::remove)')
    expect(android).toContain('releaseViewState(screen, controls.values.toList(), preservingInputDrafts = true)')
  })

  it('prefers authored keys over compiler ids when reconciling native rows', () => {
    expect(ios).toContain('let direct = [node["key"], props["key"], props["testID"]]')
    expect(ios).toContain('for child in node["children"] as? [[String: Any]] ?? []')
    expect(iosFlatList).toContain('[node["key"], props["key"], props["testID"], node["id"]]')
    expect(android).toContain('screen.lastLayoutBounds.remove(updated)')
  })

  it('releases replaced iOS row roots when a keyed identity changes type', () => {
    expect(ios).toContain('if let previous, previous.view !== next.view {')
    expect(ios).toContain('self.forgetHandlers(previous)')
    expect(ios).toContain('for child in rootStack.arrangedSubviews where child !== next.view')
    expect(ios).toContain('if next.view.superview !== rootStack { rootStack.addArrangedSubview(next.view) }')
  })

  it('waits for asynchronous Android native fixture updates before asserting', () => {
    expect(androidFlatListTest).toContain('list.smoothScrollToPosition(99)')
    expect(androidFlatListTest).toContain('ActivityScenario.launch(MainActivity::class.java)')
    expect(androidNavigationTest).toContain('awaitText(activity, "input-style-status", "input colors on")')
    expect(androidNavigationTest).toContain('awaitText(activity, "native-link-status", "link pressed")')
    expect(androidNavigationTest).toContain('awaitText(activity, "modal-status", "modal shown")')
    expect(androidNavigationTest).toContain('awaitText(activity, "native-link-status", "panel pressed")')
    expect(androidNavigationTest).toContain('awaitText(activity, "native-link-status", "pressable pressed")')
    expect(androidNavigationTest).toContain('awaitText(activity, "native-link-status", "button style accented")')
    expect(androidNavigationTest).toContain('awaitText(activity, "long-press-status", "panel long pressed")')
    expect(androidNavigationTest).toContain('awaitText(activity, "long-press-status", "long press disabled")')
    expect(androidNavigationTest).toContain('awaitText(activity, "long-press-status", "long press enabled")')
    expect(androidNavigationTest).toContain('awaitText(activity, "image-status", "image tint off")')
    expect(androidNavigationTest).toContain('SystemClock.uptimeMillis()')
    expect(iosNavigationTest).toContain('reveal(panelStyleToggle, in: rootScroll)')
    expect(android).toContain('control.setOnClickListener {')
    expect(android).toContain('val disabled = props.optBoolean("disabled", false) || state?.optBoolean("disabled", false) == true')
    expect(iosLayoutUnitTests).toContain('private func waitForSnapshotFile(')
  })

  it('resets FlatList end-reached state when any data row changes', () => {
    expect(iosFlatList).toContain('private var dataContentSignature = ""')
    expect(iosFlatList).toContain('dataContentSignature = contentSignature')
    expect(iosFlatList).toContain('let signature = dataContentSignature')
    expect(iosFlatList).not.toContain('let signature = "\\(dataIndices.count):\\(lastIdentity)"')
    expect(androidFlatList).toContain('private var dataContentSignature = ""')
    expect(androidFlatList).toContain('dataContentSignature = contentSignature')
    expect(androidFlatList).toContain('val signature = dataContentSignature')
    expect(androidFlatList).not.toContain('val signature = "${dataPositions.size}:$lastIdentity"')
  })

  it('resets removed text-input colors to each host theme', () => {
    expect(ios).toContain('field.attributedPlaceholder = nil')
    expect(ios).toContain('field.tintColor = color(props["selectionColor"])')
    expect(android).toContain('inputHintDefaults.getOrPut(this)')
    expect(android).toContain('inputHighlightDefaults.getOrPut(this)')
    expect(android).toContain('inputHintDefaults.remove(it)')
  })

  it('restores native backgrounds when custom styles are removed', () => {
    expect(ios).toContain('view.backgroundColor = color(style["backgroundColor"]) ?? .clear')
    expect(android).toContain('if (defaultBackgrounds.containsKey(view))')
    expect(android).toContain('} else view.background = defaultBackground')
    expect(android).toContain('released.forEach(defaultBackgrounds::remove)')
  })

  it('refreshes theme-default native controls when traits change', () => {
    expect(ios).toContain('mutationDocument.node("root")')
    expect(ios).toContain('renderCommitted(document)')
    expect(ios).toContain('private func refreshTraitDefaults()')
    expect(ios).toContain('refreshTraitDefaults()')
    expect(ios).toContain('override func viewWillAppear(_ animated: Bool)')
    expect(android).toContain('override fun onConfigurationChanged(newConfig: Configuration)')
    expect(android).toContain('screen.mutations.node("root")?.let { renderCommitted(screen, it) }')
    expect(android).toContain('private fun refreshScreenTheme(screen: Screen)')
    expect(android).toContain('refreshScreenTheme(screen)')
    expect(android).toContain('private fun refreshThemeDefaults()')
    expect(android).toContain('refreshThemeDefaults()')
    expect(android).toContain('refreshInputDefaultsForTraitChange()')
    expect(android).toContain('val probe = EditText(this)')
  })

  it('exercises theme trait refresh in both maintained native fixtures', () => {
    expect(navigationHome).toContain('testID="theme-probe" class="bg-white dark:bg-slate-950"')
    expect(navigationHome).toContain('testID="theme-probe-label" class="text-slate-900 dark:text-white"')
    expect(androidNavigationTest).toContain('activity.onConfigurationChanged(changed)')
    expect(androidNavigationTest).toContain('native theme probe did not change background')
    expect(iosNavigationTest).toContain('testNativeAppearanceReconcilesTraitDefaults')
    expect(iosNavigationTest).toContain('device.appearance = original == .dark ? .light : .dark')
  })

  it('keeps fractional grid geometry covered by both maintained fixtures', () => {
    expect(navigationHome).toContain('testID="grid-fractional-wrap"')
    expect(navigationHome).toContain('gridTemplateColumns":"repeat(3, 1fr)"')
    expect(androidNavigationTest).toContain('fractional grid columns overlapped')
    expect(iosNavigationTest).toContain('fractional grid tracks diverged')
  })

  it('publishes dynamic color-scheme changes to the native runtime on both hosts', () => {
    expect(ios).toContain('send(type: "APPEARANCE", payload: ["colorScheme": colorScheme])')
    expect(android).toContain('send(screen, "APPEARANCE", JSONObject().put("colorScheme", colorScheme()))')
    expect(android).toContain('Configuration.UI_MODE_NIGHT_MASK')
    expect(android).toContain('colorScheme: ${JSONObject.quote(colorScheme())}')
  })

  it('rebinds unchanged virtualized rows when theme traits change', () => {
    expect(iosFlatList).toContain('func refreshThemeDefaults()')
    expect(iosFlatList).toContain('snapshot.reconfigureItems(identities)')
    expect(iosFlatList).toContain('private var pendingThemeRefresh = false')
    expect(iosFlatList).toContain('pendingThemeRefresh = true')
    expect(iosFlatList).toContain('if self.pendingThemeRefresh')
    expect(iosFlatList).toContain('isApplyingSnapshot = true')
    expect(ios).toContain('refreshTraitDefaults(in: renderedRoot)')
    expect(androidFlatList).toContain('fun refreshThemeDefaults()')
    expect(androidFlatList).toContain('notifyItemRangeChanged(0, listAdapter.itemCount)')
    expect(androidFlatList).toContain('private var pendingThemeRefresh = false')
    expect(androidFlatList).toContain('if (isSubmittingList)')
    expect(androidFlatList).toContain('if (pendingThemeRefresh)')
    expect(android).toContain('is CraftNativeRefreshableFlatList -> it.list')
    expect(android).toContain('is CraftNativeFlatList -> it')
    expect(android).toContain('val nestedLists = refreshableLists.map { it.list }.toSet()')
    expect(android).toContain('released.addAll(nestedLists)')
  })

  it('keeps scroll bounce behavior aligned across hosts', () => {
    expect(ios).toContain('scroll.bounces = props["bounces"] as? Bool ?? true')
    expect(ios).toContain('list.bounces = props["bounces"] as? Bool ?? true')
    expect(android).toContain('fun setBounces(value: Boolean)')
    expect(android).toContain('setBounces(props.optBoolean("bounces", true))')
    expect(android).toContain('private fun applyBounceModes()')
    expect(android).toContain('if (bounces && alwaysBounceVertical) View.OVER_SCROLL_ALWAYS')
    expect(guide).toContain('`bounces`, `alwaysBounceVertical`, and `alwaysBounceHorizontal` to control the')
  })

  it('keeps ScrollView paging behavior aligned across hosts', () => {
    expect(ios).toContain('scroll.isPagingEnabled = props["pagingEnabled"] as? Bool ?? false')
    expect(android).toContain('fun setPagingEnabled(value: Boolean)')
    expect(android).toContain('if (pagingEnabled) snapToPage(scroller)')
    expect(android).toContain('setPagingEnabled(props.optBoolean("pagingEnabled", false))')
    expect(guide).toContain('`pagingEnabled` snaps `ScrollView` content')
  })

  it('keeps ScrollView bounce axes aligned across hosts', () => {
    expect(ios).toContain('scroll.alwaysBounceVertical = props["alwaysBounceVertical"] as? Bool ?? (direction == .vertical)')
    expect(ios).toContain('scroll.alwaysBounceHorizontal = props["alwaysBounceHorizontal"] as? Bool ?? (direction == .horizontal)')
    expect(android).toContain('fun setAlwaysBounce(vertical: Boolean, horizontal: Boolean)')
    expect(android).toContain('alwaysBounceVertical')
    expect(android).toContain('alwaysBounceHorizontal')
    expect(android).toContain('setAlwaysBounce(')
  })

  it('keeps native horizontal scroll gestures ahead of iOS content back-swipe', () => {
    const hybrid = readFileSync(join(root, 'packages/ios/templates/CraftHybrid.swift'), 'utf8')
    const nativeScreen = readFileSync(join(root, 'packages/ios/templates/CraftNativeScreen.swift'), 'utf8')
    expect(hybrid).toContain('nativeScreenContainsHorizontalScroll')
    expect(hybrid).toContain('scroll.alwaysBounceHorizontal || scroll.contentSize.width > scroll.bounds.width + 1')
    expect(hybrid).toContain('hit.isDescendant(of: webView) || webView.isDescendant(of: hit)')
    expect(hybrid).toContain('!native.tabSwipeEnabled || !native.contentSwipeBack')
    expect(nativeScreen).toContain('if let tabSwipeEnabled = options["tabSwipeEnabled"] as? Bool {')
    expect(hybrid).toContain('gestureRecognizer !== nav.interactivePopGestureRecognizer')
    expect(hybrid).toContain('if gestureRecognizer.location(in: nav.view).x - moved > 32 { return false }')
  })

  it('documents the hybrid tab-swipe opt-out', () => {
    expect(guide).toContain('craft.tabBar.set(tabs, { swipeEnabled: false })')
    expect(iosReadme).toContain('craft.tabBar.set(tabs, { swipeEnabled: false })')
  })

  it('keeps Android native file uploads on the owned-file multipart path', () => {
    expect(androidCapabilities).toContain('listOf("device", "clipboard", "haptics", "storage", "lifecycle", "fetch", "files")')
    expect(androidCapabilities).toContain('private fun multipart(parts: JSONArray): FileResult')
    expect(androidCapabilities).toContain('A form file must be one craft.files made, and still there')
    expect(androidCapabilities).not.toContain('form files are limited to $CRAFT_NATIVE_FETCH_MAX_RESPONSE_BYTES bytes')
    expect(androidCapabilities).toContain('Intent.ACTION_OPEN_DOCUMENT')
    expect(androidCapabilities).toContain('private fun ownedFile(path: String): File?')
    expect(androidCapabilities).toContain("files.write encoding is 'utf8' or 'base64'")
    expect(androidCapabilities).toContain('private fun files(requestToken: String, method: String, args: JSONArray): CraftNativeCapabilityResult {')
    expect(androidCapabilities).toContain('return when (method)')
    expect(androidCapabilities).toContain("files.pickImage source is 'library' or 'camera'")
    expect(androidCapabilities).toContain('fetchConnections[requestToken] = connection')
    expect(androidCapabilities).toContain('File download was cancelled')
    expect(androidCapabilities).toContain('private fun refusedDownload(')
    expect(androidCapabilities).toContain('CRAFT_NATIVE_FILE_ERROR_BODY_BYTES = 64 * 1024')
    expect(androidCapabilities).toContain('private fun sweepFiles()')
    expect(androidCapabilities).not.toContain('fileRoot.deleteRecursively()')
    expect(androidCapabilities).toContain('private fun writeImage(bitmap: Bitmap, maxPixels: Int, quality: Float, name: String): JSONObject?')
    expect(androidCapabilities).toContain('CRAFT_NATIVE_FILE_DEFAULT_MAX_PIXELS = 2048')
    expect(android).toContain('capabilities.onActivityResult(requestCode, resultCode, data)')
  })
})
