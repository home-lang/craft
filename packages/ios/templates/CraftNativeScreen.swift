import Foundation
import AVFoundation
import AVKit
import CryptoKit
import Darwin
import JavaScriptCore
import MapKit
import OSLog
import Security
import SwiftUI
import UIKit

private let craftNativeCapabilityTimeoutMilliseconds = 30_000

/// A finite number from a prop, for the views outside the screen controller,
/// which has its own: the keyboard-avoiding view and SVG text read theirs
/// with it, and without it the template did not compile.
private func number(_ value: Any?) -> CGFloat? {
    guard let number = value as? NSNumber else { return nil }
    let value = CGFloat(truncating: number)
    return value.isFinite ? value : nil
}

private func craftNativeGridColumnCount(_ value: Any?) -> Int {
    if let number = value as? NSNumber { return max(1, number.intValue) }
    guard let text = value as? String else { return 1 }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("repeat(") {
        let digits = trimmed.dropFirst("repeat(".count).prefix { $0.isNumber }
        if let count = Int(digits) { return max(1, count) }
    }
    let tracks = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
    return max(1, tracks.count)
}

/// Optional bridge to the shared Zig flex rule. Native hosts retain their
/// local implementation when no Craft runtime is linked (the normal SDK
/// fallback), while runtime-backed apps get one cross-platform calculation.
private enum CraftNativeFlexBridge {
    private struct Item {
        var basis: Float
        var grow: Float
        var shrink: Float
        var min: Float
        var max: Float
        var marginStart: Float
        var marginEnd: Float
    }

    private typealias Function = @convention(c) (
        Float, Float, UInt32, UnsafeRawPointer, Int, UnsafeMutableRawPointer, UnsafeMutableRawPointer
    ) -> Int32

    private static let function: Function? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "craft_native_flex_row_justified") else { return nil }
        return unsafeBitCast(symbol, to: Function.self)
    }()

    static func widths(available: CGFloat, gap: CGFloat, justify: UInt32, items: [(basis: CGFloat, grow: CGFloat, shrink: CGFloat, min: CGFloat?, max: CGFloat?, leading: CGFloat, trailing: CGFloat)]) -> [(width: CGFloat, position: CGFloat)]? {
        guard let function, !items.isEmpty else { return nil }
        var input = items.map { item in
            Item(
                basis: Float(item.basis), grow: Float(item.grow), shrink: Float(item.shrink),
                min: item.min.map(Float.init) ?? .nan, max: item.max.map(Float.init) ?? .nan,
                marginStart: Float(item.leading), marginEnd: Float(item.trailing)
            )
        }
        var output = [Float](repeating: 0, count: input.count)
        var positions = [Float](repeating: 0, count: input.count)
        let status = input.withUnsafeBufferPointer { inputBuffer in
            output.withUnsafeMutableBufferPointer { outputBuffer in
                positions.withUnsafeMutableBufferPointer { positionBuffer in
                    function(Float(available), Float(gap), justify, UnsafeRawPointer(inputBuffer.baseAddress!), input.count, UnsafeMutableRawPointer(outputBuffer.baseAddress!), UnsafeMutableRawPointer(positionBuffer.baseAddress!))
                }
            }
        }
        guard status == 0, output.allSatisfy({ $0.isFinite }), positions.allSatisfy({ $0.isFinite }) else { return nil }
        return zip(output, positions).map { (width: CGFloat($0), position: CGFloat($1)) }
    }
}

private func craftNativeJustifyCode(_ value: String) -> UInt32 {
    switch value {
    case "center": return 1
    case "flex-end": return 2
    case "space-between": return 3
    case "space-around": return 4
    case "space-evenly": return 5
    default: return 0
    }
}

/// Optional bridge to the host-neutral tree layout ABI. The host still owns
/// intrinsic measurement and keeps its local implementation for unsupported
/// trees or runtimes built before this symbol was exported.
private enum CraftNativeTreeLayoutBridge {
    private struct StyleInput {
        var direction: UInt32 = 0
        var width: Float = .nan
        var height: Float = .nan
        var intrinsicWidth: Float = .nan
        var intrinsicHeight: Float = .nan
        var baseline: Float = .nan
        var aspectRatio: Float = .nan
        var flexBasis: Float = .nan
        var flexGrow: Float = 0
        var flexShrink: Float = 0
        var minWidth: Float = .nan
        var maxWidth: Float = .nan
        var minHeight: Float = .nan
        var maxHeight: Float = .nan
        var gap: Float = 0
        var justifyContent: UInt32 = 0
        var alignItems: UInt32 = 3
        var alignSelf: UInt32 = 0
        var flexWrap: UInt32 = 0
        var alignContent: UInt32 = 6
        var marginTop: Float = 0
        var marginRight: Float = 0
        var marginBottom: Float = 0
        var marginLeft: Float = 0
        var paddingTop: Float = 0
        var paddingRight: Float = 0
        var paddingBottom: Float = 0
        var paddingLeft: Float = 0
        var grid: UInt32 = 0
        var gridColumns: UInt32 = 1
        var rowGap: Float = 0
        var columnGap: Float = 0
    }

    private struct NodeInput {
        var style: StyleInput
        var firstChild: UInt32
        var childCount: UInt32
    }

    private struct Frame {
        var x: Float
        var y: Float
        var width: Float
        var height: Float
    }

    private typealias Function = @convention(c) (
        Float, Float, UnsafeRawPointer, Int, UnsafeMutableRawPointer, Int
    ) -> Int32

    private static let function: Function? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "craft_native_layout_tree") else { return nil }
        return unsafeBitCast(symbol, to: Function.self)
    }()

    private static func finite(_ value: CGFloat?) -> Float {
        guard let value, value.isFinite else { return .nan }
        return Float(value)
    }

    private static func length(_ value: CraftNativeLength?, base: CGFloat?) -> Float {
        guard let value else { return .nan }
        return finite(value.resolve(base))
    }

    private static func alignment(_ value: String?) -> UInt32 {
        switch value {
        case "center": return 1
        case "flex-end": return 2
        case "stretch": return 3
        case "baseline": return 4
        default: return 0
        }
    }

    private static func alignSelf(_ value: String?) -> UInt32 {
        switch value {
        case "flex-start": return 1
        case "center": return 2
        case "flex-end": return 3
        case "stretch": return 4
        case "baseline": return 5
        default: return 0
        }
    }

    private static func justify(_ value: String) -> UInt32 {
        craftNativeJustifyCode(value)
    }

    static func frames(
        width: CGFloat,
        height: CGFloat,
        direction: NSLayoutConstraint.Axis,
        gap: CGFloat,
        rowGap: CGFloat?,
        columnGap: CGFloat?,
        wrap: Bool,
        justifyContent: String,
        alignItems: String,
        padding: UIEdgeInsets,
        children: [(UIView, CraftNativeLayoutStyle, CGSize, CGFloat)]
    ) -> [(UIView, CGRect)]? {
        guard let function, width.isFinite, height.isFinite, width >= 0, height >= 0, !children.isEmpty else { return nil }
        let mainGap = direction == .horizontal ? (columnGap ?? gap) : (rowGap ?? gap)
        let crossGap = direction == .horizontal ? (rowGap ?? gap) : (columnGap ?? gap)
        var root = StyleInput(
            direction: direction == .horizontal ? 0 : 1,
            width: Float(width), height: Float(height), gap: Float(max(0, mainGap)),
            justifyContent: justify(justifyContent), alignItems: alignment(alignItems), flexWrap: wrap ? 1 : 0,
            paddingTop: Float(max(0, padding.top)), paddingRight: Float(max(0, padding.right)),
            paddingBottom: Float(max(0, padding.bottom)), paddingLeft: Float(max(0, padding.left))
        )
        root.rowGap = Float(max(0, rowGap ?? 0))
        root.columnGap = Float(max(0, columnGap ?? 0))
        let contentWidth = max(0, width - padding.left - padding.right)
        let contentHeight = max(0, height - padding.top - padding.bottom)
        let mainSize = direction == .horizontal ? contentWidth : contentHeight
        var nodes = [NodeInput(style: root, firstChild: 1, childCount: UInt32(children.count))]
        for (view, style, intrinsic, baseline) in children {
            let shrink: CGFloat
            if let authored = style.flexShrink {
                shrink = authored
            } else if view is UIScrollView {
                shrink = 1
            } else if view is UILabel, direction == .horizontal {
                shrink = 1
            } else {
                shrink = 0
            }
            var input = StyleInput(
                width: length(style.width, base: contentWidth), height: length(style.height, base: contentHeight),
                intrinsicWidth: Float(max(0, intrinsic.width)), intrinsicHeight: Float(max(0, intrinsic.height)),
                baseline: Float(max(0, baseline)), aspectRatio: finite(style.aspectRatio),
                flexBasis: length(style.flexBasis, base: mainSize), flexGrow: Float(max(0, style.flexGrow)), flexShrink: Float(max(0, shrink)),
                minWidth: length(style.minWidth, base: contentWidth), maxWidth: length(style.maxWidth, base: contentWidth),
                minHeight: length(style.minHeight, base: contentHeight), maxHeight: length(style.maxHeight, base: contentHeight),
                alignSelf: alignSelf(style.alignSelf),
                marginTop: Float(max(0, style.marginTop)), marginRight: Float(max(0, style.marginRight)),
                marginBottom: Float(max(0, style.marginBottom)), marginLeft: Float(max(0, style.marginLeft))
            )
            input.direction = 0
            nodes.append(NodeInput(style: input, firstChild: 0, childCount: 0))
        }
        var output = [Frame](repeating: Frame(x: 0, y: 0, width: 0, height: 0), count: nodes.count)
        let frameCount = output.count
        let status = nodes.withUnsafeBufferPointer { nodeBuffer in
            output.withUnsafeMutableBufferPointer { frameBuffer in
                function(
                    Float(width), Float(height), UnsafeRawPointer(nodeBuffer.baseAddress!), nodes.count,
                    UnsafeMutableRawPointer(frameBuffer.baseAddress!), frameCount
                )
            }
        }
        guard status == 0 else { return nil }
        let childFrames = output.dropFirst()
        guard childFrames.allSatisfy({ frame in
            frame.x.isFinite && frame.y.isFinite && frame.width.isFinite && frame.height.isFinite &&
                frame.width >= 0 && frame.height >= 0
        }) else { return nil }
        return zip(children, childFrames).map { child, frame in
            (child.0, CGRect(x: CGFloat(frame.x), y: CGFloat(frame.y), width: CGFloat(frame.width), height: CGFloat(frame.height)))
        }
    }
}

private enum CraftNativeFlexLineBridge {
    private struct Item {
        var basis: Float
        var marginStart: Float
        var marginEnd: Float
    }

    private typealias Function = @convention(c) (
        Float, Float, UInt32, UnsafeRawPointer, Int, UnsafeMutableRawPointer
    ) -> Int32

    private static let function: Function? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "craft_native_flex_line_breaks") else { return nil }
        return unsafeBitCast(symbol, to: Function.self)
    }()

    static func lines(available: CGFloat, gap: CGFloat, wrap: Bool, items: [(basis: CGFloat, leading: CGFloat, trailing: CGFloat)]) -> [Int]? {
        guard let function, !items.isEmpty else { return nil }
        var input = items.map { Item(basis: Float($0.basis), marginStart: Float($0.leading), marginEnd: Float($0.trailing)) }
        var output = [Int32](repeating: 0, count: input.count)
        let status = input.withUnsafeBufferPointer { inputBuffer in
            output.withUnsafeMutableBufferPointer { outputBuffer in
                function(Float(available), Float(gap), wrap ? 1 : 0, UnsafeRawPointer(inputBuffer.baseAddress!), input.count, UnsafeMutableRawPointer(outputBuffer.baseAddress!))
            }
        }
        guard status > 0 else { return nil }
        return output.map(Int.init)
    }
}

private enum CraftNativeFlexLineDistributionBridge {
    private typealias Function = @convention(c) (
        Float, Float, UInt32, UnsafeRawPointer, Int, UnsafeMutableRawPointer, UnsafeMutableRawPointer
    ) -> Int32

    private static let function: Function? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "craft_native_flex_line_distribution") else { return nil }
        return unsafeBitCast(symbol, to: Function.self)
    }()

    static func distribute(available: CGFloat, gap: CGFloat, alignment: UInt32, lineCrosses: [CGFloat]) -> (offsets: [CGFloat], sizes: [CGFloat])? {
        guard let function, !lineCrosses.isEmpty else { return nil }
        var input = lineCrosses.map(Float.init)
        var offsets = [Float](repeating: 0, count: input.count)
        var sizes = [Float](repeating: 0, count: input.count)
        let status = input.withUnsafeBufferPointer { inputBuffer in
            offsets.withUnsafeMutableBufferPointer { offsetBuffer in
                sizes.withUnsafeMutableBufferPointer { sizeBuffer in
                    function(Float(available), Float(gap), alignment, UnsafeRawPointer(inputBuffer.baseAddress!), input.count, UnsafeMutableRawPointer(offsetBuffer.baseAddress!), UnsafeMutableRawPointer(sizeBuffer.baseAddress!))
                }
            }
        }
        guard status == 0, offsets.allSatisfy({ $0.isFinite }), sizes.allSatisfy({ $0.isFinite }) else { return nil }
        return (offsets.map { CGFloat($0) }, sizes.map { CGFloat($0) })
    }
}

/// Optional bridge to the shared cross-axis alignment rule. The local rule is
/// retained for runtimes built before this symbol was exported.
private enum CraftNativeCrossAxisBridge {
    private typealias Function = @convention(c) (Float, Float, Float, Float, UInt32) -> Float

    private static let function: Function? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "craft_native_cross_axis_position") else { return nil }
        return unsafeBitCast(symbol, to: Function.self)
    }()

    static func position(available: CGFloat, size: CGFloat, leading: CGFloat, trailing: CGFloat, alignment: UInt32) -> CGFloat? {
        guard let function else { return nil }
        let result = function(Float(available), Float(size), Float(leading), Float(trailing), alignment)
        return result.isFinite ? CGFloat(result) : nil
    }
}

private enum CraftNativeGridBridge {
    private struct Item {
        var intrinsicWidth: Float
        var intrinsicHeight: Float
        var explicitWidth: Float
        var explicitHeight: Float
        var minWidth: Float
        var maxWidth: Float
        var minHeight: Float
        var maxHeight: Float
        var marginLeft: Float
        var marginRight: Float
        var marginTop: Float
        var marginBottom: Float
        var stretch: UInt32
        var alignment: UInt32
    }

    private struct Frame {
        var x: Float
        var y: Float
        var width: Float
        var height: Float
    }

    private typealias Function = @convention(c) (
        Float, Float, UInt32, Float, Float, UnsafeRawPointer, Int, UnsafeMutableRawPointer
    ) -> Int32
    private typealias AutoRowsFunction = @convention(c) (
        Float, Float, UInt32, Float, Float, Float, UnsafeRawPointer, Int, UnsafeMutableRawPointer
    ) -> Int32
    private typealias AlignedFunction = @convention(c) (
        Float, Float, UInt32, Float, Float, UInt32, UnsafeRawPointer, Int, UnsafeMutableRawPointer
    ) -> Int32
    private typealias AutoRowsAlignedFunction = @convention(c) (
        Float, Float, UInt32, Float, Float, UInt32, Float, UnsafeRawPointer, Int, UnsafeMutableRawPointer
    ) -> Int32

    private static let function: Function? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "craft_native_grid") else { return nil }
        return unsafeBitCast(symbol, to: Function.self)
    }()
    private static let autoRowsFunction: AutoRowsFunction? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "craft_native_grid_auto_rows") else { return nil }
        return unsafeBitCast(symbol, to: AutoRowsFunction.self)
    }()
    private static let alignedFunction: AlignedFunction? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "craft_native_grid_aligned") else { return nil }
        return unsafeBitCast(symbol, to: AlignedFunction.self)
    }()
    private static let autoRowsAlignedFunction: AutoRowsAlignedFunction? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "craft_native_grid_auto_rows_aligned") else { return nil }
        return unsafeBitCast(symbol, to: AutoRowsAlignedFunction.self)
    }()

    static func frames(
        availableWidth: CGFloat,
        availableHeight: CGFloat,
        columns: Int,
        columnGap: CGFloat,
        rowGap: CGFloat,
        items: [(intrinsicWidth: CGFloat, intrinsicHeight: CGFloat, explicitWidth: CGFloat?, explicitHeight: CGFloat?, minWidth: CGFloat?, maxWidth: CGFloat?, minHeight: CGFloat?, maxHeight: CGFloat?, marginLeft: CGFloat, marginRight: CGFloat, marginTop: CGFloat, marginBottom: CGFloat, stretch: Bool, alignment: UInt32)],
        autoRowHeight: CGFloat? = nil,
        alignContent: UInt32 = 0
    ) -> [(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)]? {
        guard !items.isEmpty else { return nil }
        if autoRowHeight != nil, autoRowsFunction == nil { return nil }
        if autoRowHeight == nil, function == nil { return nil }
        var input = items.map { item in
            Item(
                intrinsicWidth: Float(item.intrinsicWidth), intrinsicHeight: Float(item.intrinsicHeight),
                explicitWidth: item.explicitWidth.map(Float.init) ?? .nan, explicitHeight: item.explicitHeight.map(Float.init) ?? .nan,
                minWidth: item.minWidth.map(Float.init) ?? .nan, maxWidth: item.maxWidth.map(Float.init) ?? .nan,
                minHeight: item.minHeight.map(Float.init) ?? .nan, maxHeight: item.maxHeight.map(Float.init) ?? .nan,
                marginLeft: Float(item.marginLeft), marginRight: Float(item.marginRight),
                marginTop: Float(item.marginTop), marginBottom: Float(item.marginBottom),
                stretch: item.stretch ? 1 : 0, alignment: item.alignment
            )
        }
        var output = [Frame](repeating: Frame(x: 0, y: 0, width: 0, height: 0), count: input.count)
        let status = input.withUnsafeBufferPointer { inputBuffer in
            output.withUnsafeMutableBufferPointer { outputBuffer in
                if let autoRowHeight, let autoRowsFunction {
                    if alignContent != 0, let autoRowsAlignedFunction {
                        return autoRowsAlignedFunction(Float(availableWidth), Float(availableHeight), UInt32(max(1, columns)), Float(columnGap), Float(rowGap), alignContent, Float(autoRowHeight), UnsafeRawPointer(inputBuffer.baseAddress!), input.count, UnsafeMutableRawPointer(outputBuffer.baseAddress!))
                    }
                    return autoRowsFunction(Float(availableWidth), Float(availableHeight), UInt32(max(1, columns)), Float(columnGap), Float(rowGap), Float(autoRowHeight), UnsafeRawPointer(inputBuffer.baseAddress!), input.count, UnsafeMutableRawPointer(outputBuffer.baseAddress!))
                }
                if alignContent != 0, let alignedFunction {
                    return alignedFunction(Float(availableWidth), Float(availableHeight), UInt32(max(1, columns)), Float(columnGap), Float(rowGap), alignContent, UnsafeRawPointer(inputBuffer.baseAddress!), input.count, UnsafeMutableRawPointer(outputBuffer.baseAddress!))
                }
                guard let function else { return Int32(-1) }
                return function(Float(availableWidth), Float(availableHeight), UInt32(max(1, columns)), Float(columnGap), Float(rowGap), UnsafeRawPointer(inputBuffer.baseAddress!), input.count, UnsafeMutableRawPointer(outputBuffer.baseAddress!))
            }
        }
        guard status == 0, output.allSatisfy({ frame in
            frame.x.isFinite && frame.y.isFinite && frame.width.isFinite && frame.height.isFinite
        }) else { return nil }
        return output.map { (CGFloat($0.x), CGFloat($0.y), CGFloat($0.width), CGFloat($0.height)) }
    }
}

private func craftNativeAlignContentCode(_ value: String) -> UInt32 {
    switch value {
    case "center": return 1
    case "flex-end": return 2
    case "space-between": return 3
    case "space-around": return 4
    case "stretch": return 5
    case "space-evenly": return 6
    default: return 0
    }
}

private final class CraftNativeVideoView: UIView {
    private let playerController = AVPlayerViewController()
    private var player: AVPlayer?
    private var sourceURI = ""
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var playingObservation: NSKeyValueObservation?
    private var timeObserver: Any?
    private var loops = false
    private var wasPlaying: Bool?
    /// The screen's handlers by event name (`onEnd`, `onPlay`, `onPause`,
    /// `onProgress`, `onLoad`, `onError`), and how an event reaches them.
    var handlers: [String: String] = [:]
    var emit: ((_ handler: String, _ nativeEvent: [String: Any]) -> Void)?

    init(host: UIViewController) {
        super.init(frame: .zero)
        clipsToBounds = true
        host.addChild(playerController)
        addSubview(playerController.view)
        playerController.didMove(toParent: host)
        // Expose the host view as the native Video node. The player controller
        // owns an accessibility subtree of its own, which otherwise masks the
        // host's testID and makes the component look like a WebView-backed view
        // to UI tests and assistive technology.
        playerController.view.isAccessibilityElement = false
        playerController.view.accessibilityElementsHidden = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        clipsToBounds = true
        addSubview(playerController.view)
        playerController.view.isAccessibilityElement = false
        playerController.view.accessibilityElementsHidden = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerController.view.frame = bounds
    }

    private func fire(_ event: String, _ nativeEvent: [String: Any] = [:]) {
        guard let handler = handlers[event], !handler.isEmpty else { return }
        emit?(handler, nativeEvent)
    }

    private func seconds(_ time: CMTime?) -> Double {
        guard let time, time.isNumeric else { return 0 }
        let value = CMTimeGetSeconds(time)
        return value.isFinite ? value : 0
    }

    private func detachPlayer() {
        if let observer = endObserver { NotificationCenter.default.removeObserver(observer) }
        endObserver = nil
        statusObservation?.invalidate()
        statusObservation = nil
        playingObservation?.invalidate()
        playingObservation = nil
        if let timeObserver, let player { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        wasPlaying = nil
        player?.pause()
        player = nil
    }

    func configure(source: Any?, autoplay: Bool, paused: Bool, loop: Bool, muted: Bool, controls: Bool, resizeMode: String?) {
        let uri = (source as? String) ?? (source as? [String: Any])?["uri"] as? String ?? ""
        if uri != sourceURI {
            detachPlayer()
            sourceURI = uri
            loops = false
            // The copy `craft.media.keep` put on the phone plays in place of
            // the address, so a kept video plays with no signal.
            let kept = CraftNativeMedia.local(uri)
            guard let url = kept ?? URL(string: uri), !uri.isEmpty, kept != nil || url.scheme != nil else {
                playerController.player = nil
                // A path with no scheme ("/videos/a.mp4") has nowhere to load
                // from on a native screen. Say so rather than stay black.
                if !uri.isEmpty {
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.sourceURI == uri else { return }
                        self.fire("onError", ["message": "The video address is not a full URL: \(uri)"])
                    }
                }
                return
            }
            let next = AVPlayer(url: url)
            player = next
            playerController.player = next
            observe(next)
        }
        guard let player else { return }
        player.isMuted = muted
        playerController.showsPlaybackControls = controls
        playerController.videoGravity = resizeMode == "cover" ? .resizeAspectFill
            : resizeMode == "stretch" ? .resize
            : .resizeAspect
        loops = loop
        if paused || !autoplay { player.pause() } else { player.play() }
    }

    /// Load, play and pause, time, the end and failure, as the web's video
    /// element reports them, so `@ended` and `@timeupdate` work as on the page.
    private func observe(_ player: AVPlayer) {
        if let item = player.currentItem {
            statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                DispatchQueue.main.async {
                    guard let self, self.player?.currentItem === item else { return }
                    switch item.status {
                    case .readyToPlay: self.fire("onLoad", ["duration": self.seconds(item.duration)])
                    case .failed: self.fire("onError", ["message": item.error?.localizedDescription ?? "The video could not be played"])
                    default: break
                    }
                }
            }
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self, weak player] _ in
                guard let self else { return }
                self.fire("onEnd")
                if self.loops { player?.seek(to: .zero) { _ in player?.play() } }
            }
        }
        playingObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                guard let self, self.player === player, player.timeControlStatus != .waitingToPlayAtSpecifiedRate else { return }
                let playing = player.timeControlStatus == .playing
                guard playing != self.wasPlaying else { return }
                // Paused before it ever played is where it starts, not news.
                if self.wasPlaying == nil && !playing { self.wasPlaying = false; return }
                self.wasPlaying = playing
                self.fire(playing ? "onPlay" : "onPause")
            }
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self, weak player] time in
            guard let self, let player, player.timeControlStatus == .playing else { return }
            self.fire("onProgress", ["currentTime": self.seconds(time), "duration": self.seconds(player.currentItem?.duration)])
        }
    }

    func stop() {
        detachPlayer()
        playerController.player = nil
        sourceURI = ""
        if playerController.parent != nil {
            playerController.willMove(toParent: nil)
            playerController.view.removeFromSuperview()
            playerController.removeFromParent()
        }
    }

    deinit { stop() }
}

private final class CraftNativeMapView: MKMapView, MKMapViewDelegate {
    private var annotationsByID: [String: MKPointAnnotation] = [:]
    private var overlaysByID: [String: MKPolyline] = [:]
    private var overlayCoordinatesByID: [String: [CLLocationCoordinate2D]] = [:]
    private var overlayColors: [ObjectIdentifier: UIColor] = [:]
    private var overlayWidths: [ObjectIdentifier: CGFloat] = [:]
    private(set) var markerHandlers: [String: String] = [:]
    var onMarkerTap: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        showsCompass = false
        showsScale = false
        isRotateEnabled = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        delegate = self
    }

    func configure(props: [String: Any], children: [Any], markerHandler: @escaping (String) -> Void) {
        onMarkerTap = markerHandler
        isScrollEnabled = props["scrollEnabled"] as? Bool ?? true
        isZoomEnabled = props["zoomEnabled"] as? Bool ?? true
        isRotateEnabled = props["rotateEnabled"] as? Bool ?? false
        mapType = Self.mapType(props["mapType"] as? String)
        // Showing the user dot must not trigger a permission prompt from a
        // renderer pass. The app's existing location capability owns that
        // prompt; a map only opts in after authorization is already granted.
        showsUserLocation = props["showsUserLocation"] as? Bool == true && Self.locationPermissionGranted()

        var nextMarkers: [String: (coordinate: CLLocationCoordinate2D, title: String?)] = [:]
        var nextHandlers: [String: String] = [:]
        var nextPolylines: [String: (coordinates: [CLLocationCoordinate2D], color: UIColor, width: CGFloat)] = [:]
        for (index, child) in children.enumerated() {
            guard let node = child as? [String: Any], let rawType = node["type"] as? String else { continue }
            let type = rawType.lowercased()
            let childProps = node["props"] as? [String: Any] ?? [:]
            let childEvents = node["events"] as? [String: String] ?? [:]
            let id = (childProps["id"] as? CustomStringConvertible)?.description
                ?? (node["id"] as? String)
                ?? "overlay-\(index)"
            let points = Self.coordinates(childProps["geometry"])
            if type == "mapmarker" || type == "marker" {
                guard let point = points.first else { continue }
                nextMarkers[id] = (point, childProps["title"] as? String)
                if let handler = childEvents["onPress"] ?? childEvents["onMarkerPress"], !handler.isEmpty {
                    nextHandlers[id] = handler
                }
            } else if type == "mappolyline" || type == "polyline" {
                guard points.count > 1 else { continue }
                let authoredWidth = (childProps["strokeWidth"] as? NSNumber)?.doubleValue ?? 3
                let width = CGFloat(authoredWidth)
                guard authoredWidth.isFinite, width.isFinite, width > 0 else { continue }
                nextPolylines[id] = (points, Self.color(childProps["strokeColor"] as? String), width)
            }
        }

        let staleMarkers = annotationsByID.keys.filter { nextMarkers[$0] == nil }
        removeAnnotations(staleMarkers.compactMap { annotationsByID.removeValue(forKey: $0) })
        for (id, value) in nextMarkers {
            if let annotation = annotationsByID[id] {
                annotation.coordinate = value.coordinate
                annotation.title = value.title
            } else {
                let annotation = MKPointAnnotation()
                annotation.coordinate = value.coordinate
                annotation.title = value.title
                annotationsByID[id] = annotation
                addAnnotation(annotation)
            }
        }
        markerHandlers = nextHandlers

        let staleOverlays = overlaysByID.keys.filter { nextPolylines[$0] == nil }
        for id in staleOverlays {
            if let overlay = overlaysByID.removeValue(forKey: id) {
                removeOverlay(overlay)
                overlayColors.removeValue(forKey: ObjectIdentifier(overlay))
                overlayWidths.removeValue(forKey: ObjectIdentifier(overlay))
            }
            overlayCoordinatesByID.removeValue(forKey: id)
        }
        for (id, value) in nextPolylines {
            if let overlay = overlaysByID[id],
               let coordinates = overlayCoordinatesByID[id],
               Self.coordinatesEqual(coordinates, value.coordinates),
               overlayColors[ObjectIdentifier(overlay)]?.isEqual(value.color) == true,
               overlayWidths[ObjectIdentifier(overlay)] == value.width {
                continue
            }
            if let previous = overlaysByID.removeValue(forKey: id) {
                removeOverlay(previous)
                overlayColors.removeValue(forKey: ObjectIdentifier(previous))
                overlayWidths.removeValue(forKey: ObjectIdentifier(previous))
            }
            let overlay = MKPolyline(coordinates: value.coordinates, count: value.coordinates.count)
            overlaysByID[id] = overlay
            overlayCoordinatesByID[id] = value.coordinates
            overlayColors[ObjectIdentifier(overlay)] = value.color
            overlayWidths[ObjectIdentifier(overlay)] = value.width
            addOverlay(overlay)
        }

        if let region = Self.region(props["region"] ?? props["initialRegion"]) {
            setRegion(region, animated: false)
        } else if props["fitToBounds"] as? Bool == true {
            fitToOverlays()
        }
    }

    private func fitToOverlays() {
        var rect = MKMapRect.null
        for overlay in overlaysByID.values { rect = rect.union(overlay.boundingMapRect) }
        for annotation in annotationsByID.values {
            let point = MKMapPoint(annotation.coordinate)
            rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
        }
        guard !rect.isNull else { return }
        let inset = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        setVisibleMapRect(rect, edgePadding: inset, animated: false)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let id = annotationsByID.first(where: { $0.value === annotation })?.key else { return nil }
        let view = (dequeueReusableAnnotationView(withIdentifier: "craft-native-marker") as? MKMarkerAnnotationView)
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "craft-native-marker")
        view.annotation = annotation
        view.markerTintColor = .systemRed
        view.accessibilityIdentifier = id
        return view
    }

    func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
        guard let id = annotationsByID.first(where: { $0.value === annotation })?.key else { return }
        onMarkerTap?(id)
        deselectAnnotation(annotation, animated: false)
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = overlayColors[ObjectIdentifier(overlay)] ?? .systemBlue
        renderer.lineWidth = overlayWidths[ObjectIdentifier(overlay)] ?? 3
        return renderer
    }

    private static func coordinates(_ value: Any?) -> [CLLocationCoordinate2D] {
        let numbers = (value as? [Any])?.compactMap { ($0 as? NSNumber)?.doubleValue }
            ?? (value as? [NSNumber])?.map(\.doubleValue)
            ?? []
        return stride(from: 0, to: numbers.count - 1, by: 2).compactMap {
            let latitude = numbers[$0]
            let longitude = numbers[$0 + 1]
            guard latitude.isFinite, longitude.isFinite,
                  (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    private static func coordinatesEqual(_ lhs: [CLLocationCoordinate2D], _ rhs: [CLLocationCoordinate2D]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { left, right in
            left.latitude == right.latitude && left.longitude == right.longitude
        }
    }

    private static func region(_ value: Any?) -> MKCoordinateRegion? {
        guard let value = value as? [String: Any],
              let center = value["center"] as? [String: Any],
              let span = value["span"] as? [String: Any],
              let latitude = (center["latitude"] as? NSNumber)?.doubleValue,
              let longitude = (center["longitude"] as? NSNumber)?.doubleValue,
              let latitudeDelta = (span["latitudeDelta"] as? NSNumber)?.doubleValue ?? (span["latitude_delta"] as? NSNumber)?.doubleValue,
              let longitudeDelta = (span["longitudeDelta"] as? NSNumber)?.doubleValue ?? (span["longitude_delta"] as? NSNumber)?.doubleValue,
              latitude.isFinite, longitude.isFinite, latitudeDelta.isFinite, longitudeDelta.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude),
              latitudeDelta > 0, latitudeDelta <= 180, longitudeDelta > 0, longitudeDelta <= 360,
              latitude - latitudeDelta / 2 >= -90, latitude + latitudeDelta / 2 <= 90 else { return nil }
        return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta))
    }

    private static func color(_ value: String?) -> UIColor {
        switch value?.lowercased() {
        case "red": return .systemRed
        case "green": return .systemGreen
        case "orange": return .systemOrange
        case "purple": return .systemPurple
        case "yellow": return .systemYellow
        default: return .systemBlue
        }
    }

    private static func mapType(_ value: String?) -> MKMapType {
        switch value?.lowercased() {
        case "satellite": return .satellite
        case "hybrid": return .hybrid
        case "muted_standard": return .mutedStandard
        default: return .standard
        }
    }

    private static func locationPermissionGranted() -> Bool {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = CLLocationManager().authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        return status == .authorizedAlways || status == .authorizedWhenInUse
    }
}

/// A WebView-free host for the first stx native vertical slice. The bundled
/// JavaScript sends whole, compiled view trees to UIKit and receives control
/// events and Craft API replies through JavaScriptCore.
struct CraftNativeScreen: UIViewControllerRepresentable {
    let config: CraftConfig

    func makeUIViewController(context: Context) -> UINavigationController {
        let screen = CraftNativeScreenController(config: config)
        // The shell hears the first frame (the app script starts after it)
        // and `craft.navigation.open`, which has no paths to open here but
        // web addresses, in the in-app browser.
        screen.hybridEvents = CraftHybrid.shared
        return UINavigationController(rootViewController: screen)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}
}

/// A length as a style gives it: points, or a percentage of the parent's
/// content box. A percentage against a size that is not known yet (a column
/// whose height comes from its content) resolves to nothing, as on the web.
private enum CraftNativeLength: Equatable {
    case points(CGFloat)
    case percent(CGFloat)

    init?(_ value: Any?) {
        if let number = value as? NSNumber {
            let points = CGFloat(truncating: number)
            guard points.isFinite else { return nil }
            self = .points(points)
            return
        }
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        if text.hasSuffix("%"), let fraction = Double(text.dropLast()), fraction.isFinite {
            self = .percent(CGFloat(fraction) / 100)
        } else if text.hasSuffix("px"), let points = Double(text.dropLast(2)), points.isFinite {
            self = .points(CGFloat(points))
        } else if let points = Double(text), points.isFinite {
            self = .points(CGFloat(points))
        } else {
            return nil
        }
    }

    func resolve(_ base: CGFloat?) -> CGFloat? {
        switch self {
        case .points(let value): return max(0, value)
        case .percent(let fraction): return base.map { max(0, $0 * fraction) }
        }
    }
}

/// How a parent lays a child out, read once from the child's style.
private struct CraftNativeLayoutStyle {
    let width: CraftNativeLength?
    let height: CraftNativeLength?
    let aspectRatio: CGFloat?
    let minWidth: CraftNativeLength?
    let maxWidth: CraftNativeLength?
    let minHeight: CraftNativeLength?
    let maxHeight: CraftNativeLength?
    let position: String
    let top: CGFloat?
    let right: CGFloat?
    let bottom: CGFloat?
    let left: CGFloat?
    let alignSelf: String?
    let flexGrow: CGFloat
    /// Nil when the style does not say: the parent picks the default for the
    /// kind of view (text shrinks along a row, a box does not).
    let flexShrink: CGFloat?
    let flexBasis: CraftNativeLength?
    let marginTop: CGFloat
    let marginRight: CGFloat
    let marginBottom: CGFloat
    let marginLeft: CGFloat
    let display: String
    let gridColumns: Int
    let gridAutoRows: CraftNativeLength?

    static let empty = CraftNativeLayoutStyle([:])

    init(_ raw: [String: Any]) {
        func number(_ value: Any?) -> CGFloat? {
            guard let number = value as? NSNumber else { return nil }
            let value = CGFloat(truncating: number)
            return value.isFinite ? value : nil
        }
        width = CraftNativeLength(raw["width"])
        height = CraftNativeLength(raw["height"])
        let ratio = number(raw["aspectRatio"])
        aspectRatio = ratio.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        minWidth = CraftNativeLength(raw["minWidth"])
        maxWidth = CraftNativeLength(raw["maxWidth"])
        minHeight = CraftNativeLength(raw["minHeight"])
        maxHeight = CraftNativeLength(raw["maxHeight"])
        position = raw["position"] as? String ?? "relative"
        top = number(raw["top"])
        right = number(raw["right"])
        bottom = number(raw["bottom"])
        left = number(raw["left"])
        let align = raw["alignSelf"] as? String
        alignSelf = align == "auto" ? nil : align
        // `flex: n` is the web's and React Native's shorthand: a positive
        // number grows by n, shrinks, and starts from nothing, so `flex-1`
        // siblings share a row equally whatever their content.
        let flex = number(raw["flex"])
        flexGrow = number(raw["flexGrow"]) ?? flex.map { max(0, $0) } ?? 0
        flexShrink = number(raw["flexShrink"]) ?? flex.map { $0 != 0 ? 1 : 0 }
        flexBasis = CraftNativeLength(raw["flexBasis"]) ?? flex.flatMap { $0 > 0 ? .points(0) : nil }
        let margin = number(raw["margin"]) ?? 0
        let horizontalMargin = number(raw["marginHorizontal"]) ?? margin
        let verticalMargin = number(raw["marginVertical"]) ?? margin
        marginTop = number(raw["marginTop"]) ?? verticalMargin
        marginRight = number(raw["marginRight"]) ?? horizontalMargin
        marginBottom = number(raw["marginBottom"]) ?? verticalMargin
        marginLeft = number(raw["marginLeft"]) ?? horizontalMargin
        display = raw["display"] as? String ?? "flex"
        gridColumns = craftNativeGridColumnCount(raw["gridTemplateColumns"] ?? raw["gridColumns"])
        gridAutoRows = CraftNativeLength(raw["gridAutoRows"])
    }
}

private final class CraftNativeLayoutStyleBox {
    let style: CraftNativeLayoutStyle
    init(_ style: CraftNativeLayoutStyle) { self.style = style }
}

private var craftNativeLayoutStyleKey: UInt8 = 0
private var craftNativeCornerRadiusKey: UInt8 = 0
private var craftNativeCornerRadiiKey: UInt8 = 0
private var craftNativeBorderLayerKey: UInt8 = 0
private var craftNativeSideBorderLayersKey: UInt8 = 0

private func craftRoundedPath(_ rect: CGRect, _ rawRadii: [CGFloat]) -> CGPath {
    let limit = min(rect.width, rect.height) / 2
    let radii = (0..<4).map { min(max(0, rawRadii.count > $0 ? rawRadii[$0] : 0), limit) }
    let path = CGMutablePath()
    let minX = rect.minX, maxX = rect.maxX, minY = rect.minY, maxY = rect.maxY
    path.move(to: CGPoint(x: minX + radii[0], y: minY))
    path.addLine(to: CGPoint(x: maxX - radii[1], y: minY))
    path.addArc(center: CGPoint(x: maxX - radii[1], y: minY + radii[1]), radius: radii[1], startAngle: -.pi / 2, endAngle: 0, clockwise: false)
    path.addLine(to: CGPoint(x: maxX, y: maxY - radii[2]))
    path.addArc(center: CGPoint(x: maxX - radii[2], y: maxY - radii[2]), radius: radii[2], startAngle: 0, endAngle: .pi / 2, clockwise: false)
    path.addLine(to: CGPoint(x: minX + radii[3], y: maxY))
    path.addArc(center: CGPoint(x: minX + radii[3], y: maxY - radii[3]), radius: radii[3], startAngle: .pi / 2, endAngle: .pi, clockwise: false)
    path.addLine(to: CGPoint(x: minX, y: minY + radii[0]))
    path.addArc(center: CGPoint(x: minX + radii[0], y: minY + radii[0]), radius: radii[0], startAngle: .pi, endAngle: .pi * 1.5, clockwise: false)
    path.closeSubpath()
    return path
}

extension UIView {
    /// The layout style this view's parent reads. It lives on the view, so an
    /// in-place style update reaches the parent's next layout pass without the
    /// parent being reconciled too.
    fileprivate var craftLayoutStyle: CraftNativeLayoutStyle {
        get { (objc_getAssociatedObject(self, &craftNativeLayoutStyleKey) as? CraftNativeLayoutStyleBox)?.style ?? .empty }
        set { objc_setAssociatedObject(self, &craftNativeLayoutStyleKey, CraftNativeLayoutStyleBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// The corner radius the style asked for. The layer gets at most half the
    /// shortest side: Core Animation draws nothing at all for a radius larger
    /// than the view (`rounded-full` is 9999).
    var craftRequestedCornerRadius: CGFloat? {
        get { (objc_getAssociatedObject(self, &craftNativeCornerRadiusKey) as? NSNumber).map { CGFloat(truncating: $0) } }
        set {
            objc_setAssociatedObject(self, &craftNativeCornerRadiusKey, newValue.map { NSNumber(value: Double($0)) }, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            craftApplyCornerRadius()
        }
    }

    var craftRequestedCornerRadii: [CGFloat]? {
        get { (objc_getAssociatedObject(self, &craftNativeCornerRadiiKey) as? [NSNumber])?.map { CGFloat(truncating: $0) } }
        set {
            objc_setAssociatedObject(self, &craftNativeCornerRadiiKey, newValue?.map { NSNumber(value: Double($0)) }, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            craftApplyCornerRadius()
        }
    }

    func craftApplyCornerRadius() {
        let requested = craftRequestedCornerRadius ?? 0
        let limit = min(bounds.width, bounds.height) / 2
        let radius = limit > 0 ? min(requested, limit) : min(requested, 9_998)
        if let radii = craftRequestedCornerRadii {
            let mask = (layer.mask as? CAShapeLayer) ?? CAShapeLayer()
            mask.frame = bounds
            mask.path = craftRoundedPath(bounds, radii)
            layer.mask = mask
            layer.cornerRadius = 0
        } else {
            layer.mask = nil
            if layer.cornerRadius != radius { layer.cornerRadius = radius }
        }
        if let border = objc_getAssociatedObject(self, &craftNativeBorderLayerKey) as? CAShapeLayer {
            border.frame = bounds
            let inset = border.lineWidth / 2
            border.path = UIBezierPath(
                roundedRect: bounds.insetBy(dx: inset, dy: inset),
                cornerRadius: max(0, radius - inset)
            ).cgPath
        }
        if let sides = objc_getAssociatedObject(self, &craftNativeSideBorderLayersKey) as? [CALayer], sides.count == 4 {
            let top = sides[0].frame.height
            let right = sides[1].frame.width
            let bottom = sides[2].frame.height
            let left = sides[3].frame.width
            sides[0].frame = CGRect(x: 0, y: 0, width: bounds.width, height: top)
            sides[1].frame = CGRect(x: max(0, bounds.width - right), y: 0, width: right, height: bounds.height)
            sides[2].frame = CGRect(x: 0, y: max(0, bounds.height - bottom), width: bounds.width, height: bottom)
            sides[3].frame = CGRect(x: 0, y: 0, width: left, height: bounds.height)
        }
    }

    fileprivate func craftApplyBorderStyle(_ style: String?, width: CGFloat, color: UIColor) {
        guard width > 0, style == "dashed" || style == "dotted" else {
            (objc_getAssociatedObject(self, &craftNativeBorderLayerKey) as? CAShapeLayer)?.removeFromSuperlayer()
            objc_setAssociatedObject(self, &craftNativeBorderLayerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            layer.borderWidth = width
            layer.borderColor = color.cgColor
            return
        }
        layer.borderWidth = 0
        let border = (objc_getAssociatedObject(self, &craftNativeBorderLayerKey) as? CAShapeLayer) ?? CAShapeLayer()
        border.strokeColor = color.cgColor
        border.fillColor = nil
        border.lineWidth = width
        border.lineDashPattern = style == "dotted"
            ? [NSNumber(value: Double(width)), NSNumber(value: Double(width * 1.5))]
            : [NSNumber(value: Double(width * 3)), NSNumber(value: Double(width * 2))]
        border.contentsScale = window?.screen.scale ?? traitCollection.displayScale
        if border.superlayer !== layer { layer.addSublayer(border) }
        objc_setAssociatedObject(self, &craftNativeBorderLayerKey, border, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        craftApplyCornerRadius()
    }

    fileprivate func craftApplySideBorders(_ hasSideBorders: Bool, style: String?, widths: [CGFloat], colors: [UIColor]) {
        guard hasSideBorders else {
            (objc_getAssociatedObject(self, &craftNativeSideBorderLayersKey) as? [CALayer])?.forEach { $0.removeFromSuperlayer() }
            objc_setAssociatedObject(self, &craftNativeSideBorderLayersKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            craftApplyBorderStyle(style, width: widths.first ?? 0, color: colors.first ?? .clear)
            return
        }
        (objc_getAssociatedObject(self, &craftNativeBorderLayerKey) as? CAShapeLayer)?.removeFromSuperlayer()
        objc_setAssociatedObject(self, &craftNativeBorderLayerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        layer.borderWidth = 0
        let top = max(0, widths.count > 0 ? widths[0] : 0)
        let right = max(0, widths.count > 1 ? widths[1] : 0)
        let bottom = max(0, widths.count > 2 ? widths[2] : 0)
        let left = max(0, widths.count > 3 ? widths[3] : 0)
        let frames = [
            CGRect(x: 0, y: 0, width: bounds.width, height: top),
            CGRect(x: max(0, bounds.width - right), y: 0, width: right, height: bounds.height),
            CGRect(x: 0, y: max(0, bounds.height - bottom), width: bounds.width, height: bottom),
            CGRect(x: 0, y: 0, width: left, height: bounds.height),
        ]
        let layers = frames.enumerated().map { index, frame in
            let side = CALayer()
            side.frame = frame
            side.backgroundColor = (colors.count > index ? colors[index] : .clear).cgColor
            layer.addSublayer(side)
            return side
        }
        objc_setAssociatedObject(self, &craftNativeSideBorderLayersKey, layers, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

/// Measures any native-screen view the way its parent's flex layout needs:
/// at a width (or height) the parent fixes, or at its natural size within the
/// room there is. Shared by the flow views, the scroll view and FlatList rows.
enum CraftNativeFlexLayout {
    static let unbounded: CGFloat = 1_000_000

    static func measure(_ view: UIView, width: CGFloat?, height: CGFloat?, maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        let maxWidth = max(0, maxWidth)
        let maxHeight = max(0, maxHeight)
        switch view {
        case let flow as CraftNativeFlowView:
            return flow.measure(width: width, height: height, maxWidth: maxWidth, maxHeight: maxHeight)
        case let scroll as CraftNativeScrollView:
            return scroll.measure(width: width, height: height, maxWidth: maxWidth, maxHeight: maxHeight)
        case let list as CraftNativeFlatList:
            let listWidth = width ?? maxWidth
            return CGSize(width: listWidth, height: height ?? list.fittingHeight(width: listWidth))
        case let label as UILabel:
            // Text takes the width it needs up to the room there is, and
            // wraps or truncates inside it rather than widening its parent.
            let limit = width ?? maxWidth
            // Ask for max-content before asking for the wrapped height. A
            // constrained sizeThatFits call can return min-content (the
            // longest word), which collapses shrink-to-fit bubbles and pills.
            let maxContent = label.sizeThatFits(CGSize(width: unbounded, height: unbounded))
            let resolvedWidth = width ?? min(ceil(maxContent.width), limit)
            // Narrower than max-content (it met the limit): the wrapped height.
            let resolvedHeight = height ?? ceil(resolvedWidth < ceil(maxContent.width)
                ? label.sizeThatFits(CGSize(width: resolvedWidth, height: unbounded)).height
                : maxContent.height)
            return CGSize(width: resolvedWidth, height: resolvedHeight)
        case let image as UIImageView where image.image == nil:
            return CGSize(width: width ?? 0, height: height ?? 0)
        default:
            let intrinsic = view.intrinsicContentSize
            let fitted = view.sizeThatFits(CGSize(width: width ?? maxWidth, height: height ?? maxHeight))
            let naturalWidth = intrinsic.width > 0 && intrinsic.width != UIView.noIntrinsicMetric ? intrinsic.width : fitted.width
            let naturalHeight = intrinsic.height > 0 && intrinsic.height != UIView.noIntrinsicMetric ? intrinsic.height : fitted.height
            return CGSize(width: width ?? min(max(0, naturalWidth), maxWidth), height: height ?? max(0, naturalHeight))
        }
    }

    /// Marks every flex container above `view` for measuring again, after a
    /// change inside it that may change its size. A FlatList row stops the
    /// walk: the list measures its rows itself.
    static func invalidateAncestors(of view: UIView) {
        var current = view.superview
        while let ancestor = current, !(ancestor is UICollectionViewCell) {
            if let flow = ancestor as? CraftNativeFlowView { flow.invalidateMeasurements() }
            if let scroll = ancestor as? CraftNativeScrollView { scroll.setContentNeedsLayout() }
            current = ancestor.superview
        }
    }

    /// A size rounded up to whole pixels, never below `atLeast`.
    static func ceiled(_ size: CGSize, scale: CGFloat, atLeast floor: CGSize) -> CGSize {
        let scale = max(1, scale)
        // Less a hair, so a size already on the pixel grid stays put.
        func up(_ value: CGFloat) -> CGFloat { (value * scale - 0.001).rounded(.up) / scale }
        return CGSize(width: max(floor.width, up(size.width)), height: max(floor.height, up(size.height)))
    }

    /// A frame snapped to the screen's pixels edge by edge, so neighbours
    /// neither overlap nor leave a hairline between them.
    static func snapped(_ rect: CGRect, scale: CGFloat) -> CGRect {
        let scale = max(1, scale)
        func snap(_ value: CGFloat) -> CGFloat { (value * scale).rounded() / scale }
        let minX = snap(rect.minX), minY = snap(rect.minY)
        return CGRect(x: minX, y: minY, width: max(0, snap(rect.maxX) - minX), height: max(0, snap(rect.maxY) - minY))
    }
}

/// A flexbox container: rows and columns with grow, shrink and basis, wrap,
/// gaps, alignment, margins, percentages, absolute children and a simple
/// grid. It is a UIStackView in name only, so existing callers and tests keep
/// `axis`, `alignment` and `arrangedSubviews`; the stack view's own
/// constraints are never created, and every frame comes from `layout`.
extension UIView {
    /// The native screen this view is drawn on, through the responder chain.
    var craftScreenController: CraftNativeScreenController? {
        var responder: UIResponder? = next
        while let current = responder {
            if let screen = current as? CraftNativeScreenController { return screen }
            responder = current.next
        }
        return nil
    }
}

private class CraftNativeFlowView: UIStackView {
    var pressActiveOpacity: CGFloat?
    var pressBaseOpacity: CGFloat = 1
    var wrap = false { didSet { if wrap != oldValue { invalidateMeasurements() } } }
    var alignItems = "stretch" { didSet { alignment = alignmentValue; if alignItems != oldValue { invalidateMeasurements() } } }
    var alignContent = "flex-start" { didSet { if alignContent != oldValue { invalidateMeasurements() } } }
    var justifyContent = "flex-start" { didSet { distribution = distributionValue; if justifyContent != oldValue { invalidateMeasurements() } } }
    var gap: CGFloat = 0 { didSet { spacing = gap; if gap != oldValue { invalidateMeasurements() } } }
    var rowGap: CGFloat? { didSet { if rowGap != oldValue { invalidateMeasurements() } } }
    var columnGap: CGFloat? { didSet { if columnGap != oldValue { invalidateMeasurements() } } }
    var grid = false { didSet { if grid != oldValue { invalidateMeasurements() } } }
    var gridColumns = 1 { didSet { if gridColumns != oldValue { invalidateMeasurements() } } }
    var gridAutoRows: CraftNativeLength? { didSet { if gridAutoRows != oldValue { invalidateMeasurements() } } }
    var reverse = false { didSet { if reverse != oldValue { invalidateMeasurements() } } }
    var wrapReverse = false { didSet { if wrapReverse != oldValue { invalidateMeasurements() } } }
    var padding = UIEdgeInsets.zero {
        didSet {
            layoutMargins = effectivePadding
            isLayoutMarginsRelativeArrangement = true
            if padding != oldValue { invalidateMeasurements() }
        }
    }
    /// Insets contributed by a native SafeAreaView root. Authored padding
    /// remains separate so a reconciliation can remove either source without
    /// leaving stale safe-area space behind.
    var safeAreaPadding = UIEdgeInsets.zero {
        didSet {
            layoutMargins = effectivePadding
            if safeAreaPadding != oldValue { invalidateMeasurements() }
        }
    }
    var effectivePadding: UIEdgeInsets {
        UIEdgeInsets(
            top: padding.top + safeAreaPadding.top,
            left: padding.left + safeAreaPadding.left,
            bottom: padding.bottom + safeAreaPadding.bottom,
            right: padding.right + safeAreaPadding.right
        )
    }
    override var axis: NSLayoutConstraint.Axis {
        didSet { if axis != oldValue { invalidateMeasurements() } }
    }

    private var flowChildren: [UIView] = []
    private var measurements: [MeasureKey: CGSize] = [:]
    /// The screen's rendered root gets a definite viewport from the host. A
    /// root with `flex: 1` must keep that height even when its first child is
    /// a ScrollView whose content is taller than the screen; otherwise an
    /// absolute sibling is positioned against the scroll content and moves
    /// with it.
    private weak var viewportChild: UIView?
    private var viewportChildFillsHeight = false

    private struct MeasureKey: Hashable {
        let width: CGFloat?
        let height: CGFloat?
        let maxWidth: CGFloat
        let maxHeight: CGFloat
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        alignment = .fill
        distribution = .fill
        isLayoutMarginsRelativeArrangement = true
        insetsLayoutMarginsFromSafeArea = false
    }

    required init(coder: NSCoder) { super.init(coder: coder) }

    /// A view made one accessibility element (a row with `accessibilityRole`)
    /// hides its children from VoiceOver, so with no label of its own it reads
    /// what they say, in order, as React Native's accessible View does. A
    /// label given in props always wins.
    override var accessibilityLabel: String? {
        get {
            if let own = super.accessibilityLabel, !own.isEmpty { return own }
            guard isAccessibilityElement else { return nil }
            // An avatar labelled with the name beside it is said once.
            var spoken: [String] = []
            for part in CraftNativeFlowView.spokenText(in: self) where !spoken.contains(part) { spoken.append(part) }
            return spoken.isEmpty ? nil : spoken.joined(separator: ", ")
        }
        set { super.accessibilityLabel = newValue }
    }

    private static func spokenText(in view: UIView) -> [String] {
        var parts: [String] = []
        for child in view.subviews where !child.isHidden && child.alpha > 0.01 {
            if child.isAccessibilityElement {
                // A Text's label is its text (applyAccessibility leaves accessibilityLabel nil).
                let said = child.accessibilityLabel ?? (child as? UILabel)?.text
                if let label = said?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty { parts.append(label) }
            } else {
                parts.append(contentsOf: spokenText(in: child))
            }
        }
        return parts
    }

    private var alignmentValue: UIStackView.Alignment {
        switch alignItems {
        case "flex-start": return .leading
        case "center": return .center
        case "flex-end": return .trailing
        case "baseline": return .firstBaseline
        default: return .fill
        }
    }

    private var distributionValue: UIStackView.Distribution {
        switch justifyContent {
        case "center": return .equalCentering
        case "space-between", "space-around", "space-evenly": return .equalSpacing
        default: return .fill
        }
    }

    // MARK: Touches

    /// A child drawn outside this view's bounds still takes its touches, as an
    /// overflowing element is clickable on the web, unless the view clips
    /// (`overflow: hidden`). UIKit only asks a view's children when the point
    /// is inside the view, so a floating button absolutely positioned out of a
    /// zero-height parent (a component's wrapper) drew but could not be tapped.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let hit = super.hitTest(point, with: event) { return hit }
        guard !clipsToBounds, !isHidden, alpha > 0.01, isUserInteractionEnabled else { return nil }
        for child in subviews.reversed() where !child.isHidden && child.alpha > 0.01 && child.isUserInteractionEnabled {
            if let hit = child.hitTest(child.convert(point, from: self), with: event) { return hit }
        }
        return nil
    }

    // MARK: Children

    override var arrangedSubviews: [UIView] { flowChildren }

    override func addArrangedSubview(_ view: UIView) {
        insertArrangedSubview(view, at: flowChildren.count)
    }

    override func insertArrangedSubview(_ view: UIView, at stackIndex: Int) {
        flowChildren.removeAll { $0 === view }
        let index = min(max(0, stackIndex), flowChildren.count)
        flowChildren.insert(view, at: index)
        if view.superview !== self {
            view.removeFromSuperview()
            addSubview(view)
        }
        // Stacking follows the tree, as on the web: a later sibling draws and
        // takes touches above an earlier one. Appending a child inserted
        // before its siblings put it on top of all of them, so a ScrollView
        // re-created under a floating button (absolute, after it) took the
        // button's taps for whatever lay beneath while the button still drew.
        if let next = flowChildren[(index + 1)...].first(where: { $0.superview === self }) {
            insertSubview(view, belowSubview: next)
        }
        view.translatesAutoresizingMaskIntoConstraints = true
        invalidateMeasurements()
    }

    override func removeArrangedSubview(_ view: UIView) {
        flowChildren.removeAll { $0 === view }
        invalidateMeasurements()
    }

    override func willRemoveSubview(_ subview: UIView) {
        flowChildren.removeAll { $0 === subview }
        super.willRemoveSubview(subview)
        invalidateMeasurements()
    }

    func setLayoutStyle(_ raw: [String: Any], for view: UIView) {
        view.craftLayoutStyle = CraftNativeLayoutStyle(raw)
        invalidateMeasurements()
    }

    func setViewportChild(_ view: UIView?, fillsHeight: Bool) {
        viewportChild = view
        viewportChildFillsHeight = fillsHeight
        invalidateMeasurements()
    }

    func removeLayoutStyle(for view: UIView) {
        view.craftLayoutStyle = .empty
    }

    /// Forgets measured sizes and lays out again on the next pass.
    func invalidateMeasurements() {
        measurements.removeAll(keepingCapacity: true)
        setNeedsLayout()
    }

    // MARK: Measuring and layout

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        measure(width: nil, height: nil, maxWidth: size.width, maxHeight: size.height)
    }

    func measure(width: CGFloat?, height: CGFloat?, maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        let key = MeasureKey(width: width, height: height, maxWidth: maxWidth, maxHeight: maxHeight)
        if let cached = measurements[key] { return cached }
        let size = layout(width: width, height: height, maxWidth: maxWidth, maxHeight: maxHeight, place: false).size
        measurements[key] = size
        return size
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        craftApplyCornerRadius()
        let scale = window?.screen.scale ?? traitCollection.displayScale
        let result = layout(width: bounds.width, height: bounds.height, maxWidth: bounds.width, maxHeight: bounds.height, place: true)
        var moved = false
        defer {
            // The screen reports onLayout from its own layout pass, which a
            // change deep in a scroll view's content never runs: a view that
            // went from 240 to 180 wide kept saying 240.
            if moved { craftScreenController?.scheduleLayoutEvents() }
        }
        for (child, frame) in result.frames {
            var viewportFrame = frame
            if child === viewportChild, viewportChildFillsHeight {
                viewportFrame.origin.y = 0
                viewportFrame.size.height = bounds.height
            }
            var snapped = CraftNativeFlexLayout.snapped(viewportFrame, scale: scale)
            // Snapping each edge can take a pixel off a label (15.83…33.83
            // becomes 16…33.67), and a label a pixel narrower than its text
            // truncates it ("13" drew as "…"). Text keeps its whole size.
            if child is UILabel {
                snapped.size = CraftNativeFlexLayout.ceiled(frame.size, scale: scale, atLeast: snapped.size)
            }
            if child.transform.isIdentity {
                if child.frame != snapped { child.frame = snapped; moved = true }
            } else {
                // A transformed child (a sticky header, a scaled spinner) is
                // placed by bounds and center: its frame is undefined then.
                let size = CGRect(origin: child.bounds.origin, size: snapped.size)
                let center = CGPoint(x: snapped.midX, y: snapped.midY)
                if child.bounds != size { child.bounds = size; moved = true }
                if child.center != center { child.center = center; moved = true }
            }
            child.craftApplyCornerRadius()
        }
    }

    private struct Item {
        let view: UIView
        let style: CraftNativeLayoutStyle
        let align: String
        let mainLeading: CGFloat
        let mainTrailing: CGFloat
        let crossLeading: CGFloat
        let crossTrailing: CGFloat
        let minMain: CGFloat?
        let maxMain: CGFloat?
        let minCross: CGFloat?
        let maxCross: CGFloat?
        let fixedCross: CGFloat?
        let grow: CGFloat
        let shrink: CGFloat
        var basis: CGFloat
        var main: CGFloat = 0
        var cross: CGFloat = 0

        var mainMargins: CGFloat { mainLeading + mainTrailing }
        var crossMargins: CGFloat { crossLeading + crossTrailing }
    }

    private func clamp(_ value: CGFloat, _ lower: CGFloat?, _ upper: CGFloat?) -> CGFloat {
        var result = value
        if let upper { result = min(result, upper) }
        if let lower { result = max(result, lower) }
        return max(0, result)
    }

    /// The first baseline is the cross-axis anchor for a horizontal baseline
    /// flex line. Views without a baseline participate at their bottom edge,
    /// matching the CSS fallback for replaced and non-text elements.
    private static func firstBaseline(_ view: UIView, cross: CGFloat) -> CGFloat {
        let baseline: CGFloat?
        if let label = view as? CraftNativeLabel {
            // CraftNativeLabel draws inside its inset rect, so include the
            // authored top padding before the font's own baseline (UIKit's
            // labels expose no measured first-baseline offset).
            baseline = label.insets.top + label.font.ascender
        } else if let label = view as? UILabel {
            baseline = label.font.ascender
        } else if let field = view as? UITextField {
            baseline = field.font?.ascender
        } else if let textView = view as? UITextView {
            baseline = textView.font?.ascender
        } else {
            baseline = nil
        }
        guard let baseline, baseline.isFinite else { return cross }
        return min(max(0, baseline), cross)
    }

    /// Children that take part in the flow: shown, not a modal overlay.
    private var visibleChildren: [UIView] {
        flowChildren.filter { $0.superview === self && !$0.isHidden && !($0 is CraftNativeModalView) }
    }

    /// The flexbox algorithm, single pass. `width`/`height` are this view's
    /// outer size when its parent fixes it, nil when it sizes to its content
    /// within `maxWidth`/`maxHeight`. Returns its outer size and, when
    /// placing, every child's frame in its own coordinates.
    private func sharedDirectFrames(_ children: [UIView], width: CGFloat?, height: CGFloat?) -> [(UIView, CGRect)]? {
        guard let width, let height, !grid, !reverse, !wrapReverse,
              width.isFinite, height.isFinite, width >= 0, height >= 0,
              children.allSatisfy({ child in
                  let style = child.craftLayoutStyle
                  return style.position != "absolute" && style.display != "none"
              }) else { return nil }

        let intrinsic = children.map { child in
            CraftNativeFlexLayout.measure(child, width: nil, height: nil, maxWidth: width, maxHeight: height)
        }
        let baselines = children.enumerated().map { index, child in
            CraftNativeFlowView.firstBaseline(child, cross: intrinsic[index].height)
        }
        let payload = zip(children, zip(intrinsic, baselines)).map { child, measured in
            (child, child.craftLayoutStyle, measured.0, measured.1)
        }
        return CraftNativeTreeLayoutBridge.frames(
            width: width, height: height, direction: axis, gap: gap, rowGap: rowGap, columnGap: columnGap, wrap: wrap,
            justifyContent: justifyContent, alignItems: alignItems, padding: effectivePadding, children: payload
        )
    }

    private func layout(
        width: CGFloat?,
        height: CGFloat?,
        maxWidth: CGFloat,
        maxHeight: CGFloat,
        place: Bool
    ) -> (size: CGSize, frames: [(UIView, CGRect)]) {
        let children = visibleChildren
        let flow = children.filter { $0.craftLayoutStyle.position != "absolute" }
        let horizontal = axis == .horizontal
        let contentPadding = effectivePadding
        let paddingWidth = contentPadding.left + contentPadding.right
        let paddingHeight = contentPadding.top + contentPadding.bottom
        let innerWidth = width.map { max(0, $0 - paddingWidth) }
        let innerHeight = height.map { max(0, $0 - paddingHeight) }
        let roomWidth = max(0, (width ?? maxWidth) - paddingWidth)
        let roomHeight = max(0, (height ?? maxHeight) - paddingHeight)

        var frames: [(UIView, CGRect)] = []
        var contentSize: CGSize
        if grid {
            contentSize = layoutGrid(flow, innerWidth: innerWidth, roomWidth: roomWidth, innerHeight: innerHeight, place: place, frames: &frames)
        } else {
            contentSize = layoutFlex(
                flow,
                horizontal: horizontal,
                innerWidth: innerWidth,
                innerHeight: innerHeight,
                roomWidth: roomWidth,
                roomHeight: roomHeight,
                place: place,
                frames: &frames
            )
        }
        if place, flow.count == children.count, let shared = sharedDirectFrames(flow, width: width, height: height) {
            frames = shared
        }
        let size = CGSize(width: width ?? contentSize.width + paddingWidth, height: height ?? contentSize.height + paddingHeight)

        if place {
            let content = CGRect(x: contentPadding.left, y: contentPadding.top, width: max(0, size.width - paddingWidth), height: max(0, size.height - paddingHeight))
            for child in children where child.craftLayoutStyle.position == "absolute" {
                let style = child.craftLayoutStyle
                var fixedWidth = style.left != nil && style.right != nil
                    ? max(0, content.width - (style.left ?? 0) - (style.right ?? 0))
                    : style.width?.resolve(content.width)
                var fixedHeight = style.top != nil && style.bottom != nil
                    ? max(0, content.height - (style.top ?? 0) - (style.bottom ?? 0))
                    : style.height?.resolve(content.height)
                (fixedWidth, fixedHeight) = aspectDimensions(style, width: fixedWidth, height: fixedHeight)
                let measured = CraftNativeFlexLayout.measure(child, width: fixedWidth, height: fixedHeight, maxWidth: content.width, maxHeight: content.height)
                let x = style.left ?? (style.right.map { content.width - $0 - measured.width } ?? 0)
                let y = style.top ?? (style.bottom.map { content.height - $0 - measured.height } ?? 0)
                frames.append((child, CGRect(x: content.minX + x, y: content.minY + y, width: measured.width, height: measured.height)))
            }
        }
        return (size, frames)
    }

    /// Resolves the missing side of an aspect-ratio box after its parent has
    /// supplied any definite width or height. Keeping this at the host edge
    /// lets grid and absolute children follow the same rule as flex items
    /// without adding platform-specific measurement behavior to native views.
    private func aspectDimensions(
        _ style: CraftNativeLayoutStyle,
        width: CGFloat?,
        height: CGFloat?
    ) -> (width: CGFloat?, height: CGFloat?) {
        guard let ratio = style.aspectRatio else { return (width, height) }
        if let width, height == nil { return (width, width / ratio) }
        if let height, width == nil { return (height * ratio, height) }
        return (width, height)
    }

    private func layoutFlex(
        _ children: [UIView],
        horizontal: Bool,
        innerWidth: CGFloat?,
        innerHeight: CGFloat?,
        roomWidth: CGFloat,
        roomHeight: CGFloat,
        place: Bool,
        frames: inout [(UIView, CGRect)]
    ) -> CGSize {
        let contentPadding = effectivePadding
        let definiteMain = horizontal ? innerWidth : innerHeight
        let definiteCross = horizontal ? innerHeight : innerWidth
        let roomMain = horizontal ? roomWidth : roomHeight
        let roomCross = horizontal ? roomHeight : roomWidth
        let mainGap = horizontal ? (columnGap ?? gap) : (rowGap ?? gap)
        let crossGap = horizontal ? (rowGap ?? 0) : (columnGap ?? 0)

        func measure(_ view: UIView, main: CGFloat?, cross: CGFloat?, mainLimit: CGFloat, crossLimit: CGFloat) -> (main: CGFloat, cross: CGFloat) {
            let size = horizontal
                ? CraftNativeFlexLayout.measure(view, width: main, height: cross, maxWidth: mainLimit, maxHeight: crossLimit)
                : CraftNativeFlexLayout.measure(view, width: cross, height: main, maxWidth: crossLimit, maxHeight: mainLimit)
            return horizontal ? (size.width, size.height) : (size.height, size.width)
        }

        var items: [Item] = []

        func fallbackWidths(for line: Range<Int>, available: CGFloat, gap: CGFloat) -> [CGFloat] {
            let hypothetical = line.reduce(0) { $0 + items[$1].basis + items[$1].mainMargins } + CGFloat(max(0, line.count - 1)) * gap
            let free = available - hypothetical
            let growTotal = line.reduce(0) { $0 + items[$1].grow }
            let shrinkTotal = line.reduce(0) { $0 + items[$1].shrink * items[$1].basis }
            let growing = free > 0 && growTotal > 0
            let shrinking = free < 0 && shrinkTotal > 0
            var widths = line.map { items[$0].basis }
            guard growing || shrinking else { return widths }

            var frozen = Set<Int>()
            for _ in 0...line.count {
                var fixed = CGFloat(max(0, line.count - 1)) * gap
                var activeBasis: CGFloat = 0
                var factor: CGFloat = 0
                for (offset, index) in line.enumerated() {
                    let item = items[index]
                    fixed += item.mainMargins
                    if frozen.contains(offset) {
                        fixed += widths[offset]
                    } else {
                        activeBasis += item.basis
                        factor += growing ? item.grow : item.shrink * item.basis
                    }
                }
                guard factor > 0 else { break }
                let remaining = available - fixed - activeBasis
                var froze = false
                for (offset, index) in line.enumerated() where !frozen.contains(offset) {
                    let item = items[index]
                    let share = growing
                        ? remaining * item.grow / factor
                        : -remaining * item.shrink * item.basis / factor
                    let raw = growing ? item.basis + share : item.basis - share
                    let clamped = clamp(raw, item.minMain, item.maxMain)
                    widths[offset] = clamped
                    if abs(clamped - raw) > 0.0001 {
                        frozen.insert(offset)
                        froze = true
                    }
                }
                if !froze { break }
            }
            return widths
        }

        items = children.map { view in
            let style = view.craftLayoutStyle
            let mainLeading = horizontal ? style.marginLeft : style.marginTop
            let mainTrailing = horizontal ? style.marginRight : style.marginBottom
            let crossLeading = horizontal ? style.marginTop : style.marginLeft
            let crossTrailing = horizontal ? style.marginBottom : style.marginRight
            let align = style.alignSelf ?? alignItems
            let authoredMain = (horizontal ? style.width : style.height)?.resolve(definiteMain)
            let authoredCross = (horizontal ? style.height : style.width)?.resolve(definiteCross)
            let explicitMain = authoredMain ?? style.aspectRatio.flatMap { ratio in
                authoredCross.map { horizontal ? $0 * ratio : $0 / ratio }
            }
            let explicitCross = authoredCross ?? style.aspectRatio.flatMap { ratio in
                authoredMain.map { horizontal ? $0 / ratio : $0 * ratio }
            }
            let minMain = (horizontal ? style.minWidth : style.minHeight)?.resolve(definiteMain)
            let maxMain = (horizontal ? style.maxWidth : style.maxHeight)?.resolve(definiteMain)
            let minCross = (horizontal ? style.minHeight : style.minWidth)?.resolve(definiteCross)
            let maxCross = (horizontal ? style.maxHeight : style.maxWidth)?.resolve(definiteCross)
            var fixedCross = explicitCross
            if fixedCross == nil, align == "stretch", !wrap, let definiteCross {
                fixedCross = definiteCross - crossLeading - crossTrailing
            }
            fixedCross = fixedCross.map { clamp($0, minCross, maxCross) }
            let defaultShrink: CGFloat
            if view is UIScrollView {
                defaultShrink = 1
            } else if view is UILabel {
                defaultShrink = horizontal ? 1 : 0
            } else {
                defaultShrink = 0
            }

            // The basis: a flex-basis, else the explicit size, else the
            // content's size. A zero basis (`flex-1`) means "share the free
            // space" only when there is a free space to share; in a container
            // sized by its content, the content is the basis, as on the web.
            let basis: CGFloat
            if let flexBasis = style.flexBasis?.resolve(definiteMain), definiteMain != nil || flexBasis > 0 {
                basis = flexBasis
            } else if let explicitMain {
                basis = explicitMain
            } else {
                basis = measure(
                    view,
                    main: nil,
                    cross: fixedCross,
                    mainLimit: max(0, (maxMain ?? roomMain) - mainLeading - mainTrailing),
                    crossLimit: max(0, (fixedCross ?? (maxCross ?? roomCross - crossLeading - crossTrailing)))
                ).main
            }
            return Item(
                view: view,
                style: style,
                align: align,
                mainLeading: mainLeading,
                mainTrailing: mainTrailing,
                crossLeading: crossLeading,
                crossTrailing: crossTrailing,
                minMain: minMain,
                maxMain: maxMain,
                minCross: minCross,
                maxCross: maxCross,
                fixedCross: fixedCross,
                grow: style.flexGrow,
                shrink: style.flexShrink ?? defaultShrink,
                basis: clamp(basis, minMain, maxMain)
            )
        }

        // Lines: one, or as many as wrapping needs.
        var lines: [Range<Int>] = []
        let lineLimit = definiteMain ?? roomMain
        if let lineIds = CraftNativeFlexLineBridge.lines(
            available: lineLimit,
            gap: mainGap,
            wrap: wrap,
            items: items.map { ($0.basis, $0.mainLeading, $0.mainTrailing) }
        ) {
            var start = 0
            for index in 1..<items.count where lineIds[index] != lineIds[index - 1] {
                lines.append(start..<index)
                start = index
            }
            lines.append(start..<items.count)
        } else {
            var start = 0
            var used: CGFloat = 0
            for index in items.indices {
                let size = items[index].basis + items[index].mainMargins
                let next = index == start ? size : used + mainGap + size
                if wrap, index > start, next > lineLimit {
                    lines.append(start..<index)
                    start = index
                    used = size
                } else {
                    used = next
                }
            }
            if start < items.count { lines.append(start..<items.count) }
        }
        // Reconciliation reverses the child order for the requested main
        // axis. A wrapped flex container must keep its lines in cross-axis
        // order, so restore the groups without changing each line's order.
        if reverse && wrap && lines.count > 1 { lines.reverse() }

        var lineMains: [CGFloat] = []
        var lineCrosses: [CGFloat] = []
        var sharedLines: [[(width: CGFloat, position: CGFloat)]?] = []
        for line in lines {
            let gaps = CGFloat(max(0, line.count - 1)) * mainGap
            let hypothetical = line.reduce(0) { $0 + items[$1].basis + items[$1].mainMargins } + gaps
            // A row sized by its content is as wide as that content, up to the
            // room it has; a column sized by its content is as tall as it is.
            let lineMain = definiteMain ?? (horizontal ? min(hypothetical, roomMain) : hypothetical)
            let sharedWidths = CraftNativeFlexBridge.widths(
                available: lineMain,
                gap: mainGap,
                justify: craftNativeJustifyCode(justifyContent),
                items: line.map { index in
                    let item = items[index]
                    return (item.basis, item.grow, item.shrink, item.minMain, item.maxMain, item.mainLeading, item.mainTrailing)
                }
            )
            sharedLines.append(sharedWidths)
            if let sharedWidths {
                for (offset, index) in line.enumerated() { items[index].main = sharedWidths[offset].width }
            } else {
                let fallback = fallbackWidths(for: line, available: lineMain, gap: mainGap)
                for (offset, index) in line.enumerated() { items[index].main = fallback[offset] }
            }

            var lineCross: CGFloat = 0
            for index in line {
                let item = items[index]
                if let fixedCross = item.fixedCross {
                    items[index].cross = fixedCross
                } else {
                    let measured = measure(
                        item.view,
                        main: item.main,
                        cross: nil,
                        mainLimit: item.main,
                        crossLimit: max(0, (item.maxCross ?? roomCross) - item.crossMargins)
                    )
                    items[index].cross = clamp(measured.cross, item.minCross, item.maxCross)
                }
                lineCross = max(lineCross, items[index].cross + item.crossMargins)
            }
            // A single line is as thick as the container when the container's
            // size is known: stretched children fill it, others align in it.
            if !wrap, let definiteCross { lineCross = definiteCross }
            for index in line where items[index].fixedCross == nil && items[index].align == "stretch" {
                let item = items[index]
                if case .some = (horizontal ? item.style.height : item.style.width) { continue }
                items[index].cross = clamp(lineCross - item.crossMargins, item.minCross, item.maxCross)
            }
            lineMains.append(line.reduce(0) { $0 + items[$1].main + items[$1].mainMargins } + gaps)
            lineCrosses.append(lineCross)
        }

        let contentMain = definiteMain ?? (lineMains.max() ?? 0)
        var contentCross = definiteCross
            ?? (lineCrosses.reduce(0, +) + CGFloat(max(0, lineCrosses.count - 1)) * crossGap)
        var crossLeading: CGFloat = 0
        var crossBetween = crossGap
        var sharedCrossOffsets: [CGFloat]? = nil
        if wrap, let definiteCross, lineCrosses.count > 1 {
            let alignment: UInt32 = switch alignContent {
            case "center": 1
            case "flex-end": 2
            case "space-between": 3
            case "space-around": 4
            case "space-evenly": 6
            case "stretch": 5
            default: 0
            }
            if let distributed = CraftNativeFlexLineDistributionBridge.distribute(
                available: definiteCross,
                gap: crossGap,
                alignment: alignment,
                lineCrosses: lineCrosses
            ) {
                sharedCrossOffsets = distributed.offsets
                lineCrosses = distributed.sizes
                for (lineIndex, line) in lines.enumerated() {
                    for index in line where items[index].fixedCross == nil && items[index].align == "stretch" {
                        let item = items[index]
                        items[index].cross = clamp(lineCrosses[lineIndex] - item.crossMargins, item.minCross, item.maxCross)
                    }
                }
            } else {
                let free = max(0, definiteCross - (lineCrosses.reduce(0, +) + CGFloat(lineCrosses.count - 1) * crossGap))
                switch alignContent {
                case "center": crossLeading = free / 2
                case "flex-end": crossLeading = free
                case "space-between": crossBetween = free / CGFloat(lineCrosses.count - 1) + crossGap
                case "space-around":
                    crossBetween = free / CGFloat(lineCrosses.count) + crossGap
                    crossLeading = free / CGFloat(lineCrosses.count * 2)
                case "space-evenly":
                    crossBetween = free / CGFloat(lineCrosses.count + 1) + crossGap
                    crossLeading = free / CGFloat(lineCrosses.count + 1)
                case "stretch":
                    let extra = free / CGFloat(lineCrosses.count)
                    lineCrosses = lineCrosses.map { $0 + extra }
                    for (lineIndex, line) in lines.enumerated() {
                        for index in line where items[index].fixedCross == nil && items[index].align == "stretch" {
                            let item = items[index]
                            items[index].cross = clamp(lineCrosses[lineIndex] - item.crossMargins, item.minCross, item.maxCross)
                        }
                    }
                default: break
                }
            }
            contentCross = definiteCross
        }

        if place {
            var crossOffset = crossLeading
            for (lineIndex, line) in lines.enumerated() {
                let free = max(0, contentMain - lineMains[lineIndex])
                let count = line.count
                let leading: CGFloat
                let between: CGFloat
                switch justifyContent {
                case "center": leading = free / 2; between = 0
                case "flex-end": leading = free; between = 0
                case "space-between": leading = 0; between = count > 1 ? free / CGFloat(count - 1) : 0
                case "space-around": leading = free / CGFloat(count * 2); between = free / CGFloat(count)
                case "space-evenly": leading = free / CGFloat(count + 1); between = free / CGFloat(count + 1)
                default: leading = 0; between = 0
                }
                let lineCross = lineCrosses[lineIndex]
                let lineOffset = sharedCrossOffsets?[lineIndex] ?? crossOffset
                let crossReversed = wrapReverse && wrap
                let physicalLineOffset = crossReversed ? contentCross - lineOffset - lineCross : lineOffset
                let sharedLine = sharedLines[lineIndex]
                    let useSharedPositions = !reverse && sharedLine != nil
                let baseline = horizontal
                    ? line.compactMap { index -> CGFloat? in
                        let item = items[index]
                        guard item.align == "baseline" else { return nil }
                        return item.crossLeading + Self.firstBaseline(item.view, cross: item.cross)
                    }.max()
                    : nil
                var mainOffset = leading
                for (offset, index) in line.enumerated() {
                    let item = items[index]
                    let crossPosition: CGFloat
                    if item.align == "baseline", let baseline {
                        let childBaseline = Self.firstBaseline(item.view, cross: item.cross)
                        crossPosition = CraftNativeCrossAxisBridge.position(
                            available: baseline,
                            size: childBaseline,
                            leading: item.crossLeading,
                            trailing: item.crossTrailing,
                            alignment: 3
                        ) ?? max(item.crossLeading, baseline - childBaseline)
                    } else {
                        let alignment = item.align == "center" ? UInt32(1) : item.align == "flex-end" ? UInt32(2) : UInt32(0)
                        crossPosition = CraftNativeCrossAxisBridge.position(
                            available: lineCross,
                            size: item.cross,
                            leading: item.crossLeading,
                            trailing: item.crossTrailing,
                            alignment: alignment
                        ) ?? {
                            switch alignment {
                            case 1: return item.crossLeading + (lineCross - item.crossMargins - item.cross) / 2
                            case 2: return lineCross - item.crossTrailing - item.cross
                            default: return item.crossLeading
                            }
                        }()
                    }
                    let physicalCrossPosition = crossReversed ? lineCross - crossPosition - item.cross : crossPosition
                    let mainPosition = useSharedPositions
                        ? (sharedLine?[offset].position ?? (mainOffset + item.mainLeading))
                        : mainOffset + item.mainLeading
                    let frame = horizontal
                        ? CGRect(x: contentPadding.left + mainPosition, y: contentPadding.top + physicalLineOffset + physicalCrossPosition, width: item.main, height: item.cross)
                        : CGRect(x: contentPadding.left + physicalLineOffset + physicalCrossPosition, y: contentPadding.top + mainPosition, width: item.cross, height: item.main)
                    frames.append((item.view, frame))
                    if !useSharedPositions { mainOffset += item.mainMargins + item.main + mainGap + between }
                }
                if sharedCrossOffsets == nil { crossOffset += lineCross + crossBetween }
            }
        }
        return horizontal ? CGSize(width: contentMain, height: contentCross) : CGSize(width: contentCross, height: contentMain)
    }

    private func layoutGrid(
        _ children: [UIView],
        innerWidth: CGFloat?,
        roomWidth: CGFloat,
        innerHeight: CGFloat?,
        place: Bool,
        frames: inout [(UIView, CGRect)]
    ) -> CGSize {
        let contentPadding = effectivePadding
        let columns = max(1, gridColumns)
        let horizontalGap = columnGap ?? gap
        let verticalGap = rowGap ?? gap
        let gaps = CGFloat(columns - 1) * horizontalGap
        var cellWidth: CGFloat
        if let innerWidth {
            cellWidth = max(0, (innerWidth - gaps) / CGFloat(columns))
        } else {
            // Sized by content: the widest cell, as long as the row fits.
            let widest = children.map { child -> CGFloat in
                let style = child.craftLayoutStyle
                return CraftNativeFlexLayout.measure(child, width: style.width?.resolve(nil), height: nil, maxWidth: roomWidth, maxHeight: CraftNativeFlexLayout.unbounded).width
                    + style.marginLeft + style.marginRight
            }.max() ?? 0
            cellWidth = min(widest, max(0, (roomWidth - gaps) / CGFloat(columns)))
        }
        var rowHeights: [CGFloat] = []
        var sizes: [CGSize] = []
        for (index, child) in children.enumerated() {
            let style = child.craftLayoutStyle
            let available = max(0, cellWidth - style.marginLeft - style.marginRight)
            let align = style.alignSelf ?? alignItems
            var fixedWidth = style.width?.resolve(cellWidth)
            var fixedHeight = style.height?.resolve(innerHeight)
            // A cell's item is as wide as its column unless it sets a width
            // (or an aspect ratio derives one from its height), whatever its
            // height: a fixed-height swatch with no content was drawn 0 wide.
            if fixedWidth == nil && align == "stretch" && (fixedHeight == nil || style.aspectRatio == nil) { fixedWidth = available }
            (fixedWidth, fixedHeight) = aspectDimensions(style, width: fixedWidth, height: fixedHeight)
            let size = CraftNativeFlexLayout.measure(
                child,
                width: fixedWidth.map { min($0, available) },
                height: fixedHeight,
                maxWidth: available,
                maxHeight: CraftNativeFlexLayout.unbounded
            )
            sizes.append(size)
            let row = index / columns
            while rowHeights.count <= row { rowHeights.append(gridAutoRows?.resolve(innerHeight) ?? 0) }
            rowHeights[row] = max(rowHeights[row], size.height + style.marginTop + style.marginBottom)
        }
        let width = innerWidth ?? (CGFloat(columns) * cellWidth + gaps)
        let height = rowHeights.reduce(0, +) + CGFloat(max(0, rowHeights.count - 1)) * verticalGap
        // Older runtimes return nil for the optional symbol; the local layout
        // below remains the compatibility path in that case.
        let sharedFrames = CraftNativeGridBridge.frames(
            availableWidth: innerWidth ?? width,
            availableHeight: innerHeight ?? height,
            columns: columns,
            columnGap: horizontalGap,
            rowGap: verticalGap,
            items: children.enumerated().map { index, child in
                let style = child.craftLayoutStyle
                let align = style.alignSelf ?? alignItems
                let size = sizes[index]
                let alignment: UInt32 = align == "center" ? 1 : align == "flex-end" ? 2 : 0
                var explicitWidth = style.width?.resolve(cellWidth)
                var explicitHeight = style.height?.resolve(innerHeight)
                if explicitWidth == nil && align == "stretch" && (explicitHeight == nil || style.aspectRatio == nil) {
                    explicitWidth = max(0, cellWidth - style.marginLeft - style.marginRight)
                }
                (explicitWidth, explicitHeight) = aspectDimensions(style, width: explicitWidth, height: explicitHeight)
                return (
                    size.width, size.height,
                    explicitWidth, explicitHeight,
                    style.minWidth?.resolve(cellWidth), style.maxWidth?.resolve(cellWidth),
                    style.minHeight?.resolve(innerHeight), style.maxHeight?.resolve(innerHeight),
                    style.marginLeft, style.marginRight, style.marginTop, style.marginBottom,
                    align == "stretch", alignment
                )
            },
            autoRowHeight: gridAutoRows.map { $0.resolve(innerHeight) ?? 0 },
            alignContent: craftNativeAlignContentCode(alignContent)
        )
        if place {
            if let sharedFrames {
                for (index, child) in children.enumerated() {
                    let frame = sharedFrames[index]
                    frames.append((child, CGRect(x: contentPadding.left + frame.x, y: contentPadding.top + frame.y, width: frame.width, height: frame.height)))
                }
                return CGSize(width: width, height: innerHeight ?? height)
            }
            let gridHeight = innerHeight ?? height
            let gridGaps = CGFloat(max(0, rowHeights.count - 1)) * verticalGap
            let gridFree = max(0, gridHeight - rowHeights.reduce(0, +) - gridGaps)
            var rowLeading: CGFloat = 0
            var rowBetween = verticalGap
            var rowExtra: CGFloat = 0
            switch alignContent {
            case "center": rowLeading = gridFree / 2
            case "flex-end": rowLeading = gridFree
            case "space-between":
                if rowHeights.count > 1 { rowBetween += gridFree / CGFloat(rowHeights.count - 1) }
            case "space-around":
                rowLeading = gridFree / CGFloat(rowHeights.count * 2)
                rowBetween += gridFree / CGFloat(rowHeights.count)
            case "space-evenly":
                rowLeading = gridFree / CGFloat(rowHeights.count + 1)
                rowBetween += gridFree / CGFloat(rowHeights.count + 1)
            case "stretch": rowExtra = gridFree / CGFloat(max(1, rowHeights.count))
            default: break
            }
            var rowTop = contentPadding.top + rowLeading
            for (index, child) in children.enumerated() {
                let style = child.craftLayoutStyle
                let row = index / columns
                let column = index % columns
                let rowHeight = rowHeights[row] + rowExtra
                let size = sizes[index]
                let align = style.alignSelf ?? alignItems
                let availableWidth = max(0, cellWidth - style.marginLeft - style.marginRight)
                let availableHeight = max(0, rowHeight - style.marginTop - style.marginBottom)
                let childWidth = min(availableWidth, size.width)
                let childHeight = align == "stretch" && style.height == nil && style.aspectRatio == nil ? availableHeight : min(availableHeight, size.height)
                let x = contentPadding.left + CGFloat(column) * (cellWidth + horizontalGap) + style.marginLeft
                    + (align == "center" ? (availableWidth - childWidth) / 2 : align == "flex-end" ? availableWidth - childWidth : 0)
                let y = rowTop + style.marginTop
                    + (align == "center" ? (availableHeight - childHeight) / 2 : align == "flex-end" ? availableHeight - childHeight : 0)
                frames.append((child, CGRect(x: x, y: y, width: childWidth, height: childHeight)))
                if column == columns - 1 || index == children.count - 1 { rowTop += rowHeight + rowBetween }
            }
        }
        return CGSize(width: width, height: innerHeight ?? height)
    }
}

/// A container that applies only the requested system safe-area edges. The
/// host keeps the root edge-to-edge when this node is the screen root so the
/// node, rather than the controller's outer stack, owns the insets.
private final class CraftNativeSafeAreaView: CraftNativeFlowView {
    private var edges: Set<String> = ["top", "right", "bottom", "left"]

    func setSafeAreaEdges(_ raw: Any?) {
        guard let values = raw as? [Any] else {
            edges = ["top", "right", "bottom", "left"]
            updateSafeAreaPadding()
            return
        }
        edges = Set(values.compactMap { value in
            guard let edge = value as? String, ["top", "right", "bottom", "left"].contains(edge) else { return nil }
            return edge
        })
        updateSafeAreaPadding()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateSafeAreaPadding()
    }

    private func updateSafeAreaPadding() {
        let insets = safeAreaInsets
        safeAreaPadding = UIEdgeInsets(
            top: edges.contains("top") ? insets.top : 0,
            left: edges.contains("left") ? insets.left : 0,
            bottom: edges.contains("bottom") ? insets.bottom : 0,
            right: edges.contains("right") ? insets.right : 0
        )
    }
}

/// A flex container that responds to the controller's keyboard overlap.
/// `padding` keeps the content visible without moving the field; `position`
/// lifts the whole container; `height` reduces its viewport.
private final class CraftNativeKeyboardAvoidingView: CraftNativeFlowView {
    private var authoredPadding = UIEdgeInsets.zero
    private var keyboardInset: CGFloat = 0
    private var keyboardVerticalOffset: CGFloat = 0
    private var keyboardBehavior = "padding"
    private var appliedHeightInset: CGFloat = 0
    private var adjustingHeight = false

    func configureKeyboard(props: [String: Any]) {
        let requestedBehavior = (props["behavior"] as? String) ?? "padding"
        keyboardBehavior = ["height", "position", "padding"].contains(requestedBehavior) ? requestedBehavior : "padding"
        keyboardVerticalOffset = number(props["keyboardVerticalOffset"]) ?? 0
        if keyboardBehavior != "height" { appliedHeightInset = 0 }
        authoredPadding = padding
        applyKeyboardAvoidance()
    }

    func setKeyboardInset(_ inset: CGFloat) {
        guard abs(keyboardInset - inset) > 0.5 else { return }
        keyboardInset = max(0, inset)
        applyKeyboardAvoidance()
    }

    private var effectiveInset: CGFloat { max(0, keyboardInset - keyboardVerticalOffset) }

    private func applyKeyboardAvoidance() {
        let inset = effectiveInset
        switch keyboardBehavior {
        case "position":
            transform = CGAffineTransform(translationX: 0, y: -inset)
            padding = authoredPadding
        case "height":
            transform = .identity
            padding = authoredPadding
        default:
            transform = .identity
            padding = UIEdgeInsets(
                top: authoredPadding.top,
                left: authoredPadding.left,
                bottom: authoredPadding.bottom + inset,
                right: authoredPadding.right
            )
        }
        invalidateMeasurements()
    }

    override func layoutSubviews() {
        if keyboardBehavior == "height", !adjustingHeight {
            let inset = effectiveInset
            let target = max(0, bounds.height + appliedHeightInset - inset)
            if abs(target - bounds.height) > 0.5 {
                adjustingHeight = true
                appliedHeightInset = inset
                bounds.size.height = target
                super.layoutSubviews()
                adjustingHeight = false
                return
            }
        }
        super.layoutSubviews()
    }
}

/// An image-backed flex container. The image stays behind ordinary native
/// children so `ImageBackground` keeps the same layout and interaction
/// semantics as a `View` while using the shared image loader.
private final class CraftNativeImageBackgroundView: UIImageView {
    let contentStack = CraftNativeFlowView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        contentMode = .scaleAspectFill
        clipsToBounds = true
        contentStack.backgroundColor = .clear
        addSubview(contentStack)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentStack.frame = bounds
    }
}

private final class CraftNativeModalView: UIView {
    let contentStack = CraftNativeFlowView()
    private let blocker = UIView()
    private var renderedVisible = false
    private var dismissSuppressedByRequest = false
    private var animationGeneration = 0
    var onRequestClose: (() -> Void)?

    var transparent = false {
        didSet { blocker.backgroundColor = transparent ? .clear : UIColor.black.withAlphaComponent(0.32) }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        blocker.isUserInteractionEnabled = true
        blocker.backgroundColor = UIColor.black.withAlphaComponent(0.32)
        blocker.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(blockerTapped)))
        addSubview(blocker)
        contentStack.backgroundColor = .clear
        addSubview(contentStack)
    }

    required init?(coder: NSCoder) { nil }

    /// Whether the modal takes touches is its own to say: shown, it takes
    /// every one (the scrim and its controls); the screen's press and long
    /// press bookkeeping once turned that off for a view with no handler of
    /// its own, and a shown modal let every tap through to the screen behind.
    func setVisible(_ visible: Bool, opacity: CGFloat, animationType: String?) {
        if visible { isUserInteractionEnabled = true }
        if renderedVisible == visible && isHidden == !visible {
            if visible, alpha != opacity { alpha = opacity }
            return
        }
        let wasVisible = renderedVisible && !isHidden
        renderedVisible = visible
        animationGeneration += 1
        let generation = animationGeneration
        layer.removeAllAnimations()
        guard visible else {
            if animationType == "slide" && wasVisible {
                let distance = max(bounds.height, superview?.bounds.height ?? UIScreen.main.bounds.height)
                UIView.animate(withDuration: 0.24, animations: {
                    self.transform = CGAffineTransform(translationX: 0, y: distance)
                    self.alpha = 0
                }, completion: { _ in
                    guard self.animationGeneration == generation else { return }
                    self.isHidden = true
                    self.transform = .identity
                })
            } else {
                isHidden = true
                transform = .identity
                alpha = 0
            }
            return
        }
        isHidden = false
        if animationType == "none" {
            transform = .identity
            alpha = opacity
        } else if animationType == "slide" {
            let distance = max(bounds.height, superview?.bounds.height ?? UIScreen.main.bounds.height)
            transform = CGAffineTransform(translationX: 0, y: distance)
            alpha = opacity
            DispatchQueue.main.async {
                guard self.animationGeneration == generation, !self.isHidden else { return }
                let distance = max(self.bounds.height, self.superview?.bounds.height ?? UIScreen.main.bounds.height)
                self.transform = CGAffineTransform(translationX: 0, y: distance)
                UIView.animate(withDuration: 0.24) { self.transform = .identity }
            }
        } else {
            transform = .identity
            alpha = 0
            UIView.animate(withDuration: 0.18) { self.alpha = opacity }
        }
    }

    func resetForTeardown() {
        animationGeneration += 1
        layer.removeAllAnimations()
        isHidden = true
        transform = .identity
        alpha = 0
        isUserInteractionEnabled = true
        dismissSuppressedByRequest = false
        onRequestClose = nil
    }

    func requestClose() {
        guard let onRequestClose else { return }
        dismissSuppressedByRequest = true
        isUserInteractionEnabled = false
        onRequestClose()
    }

    func consumeDismissSuppression() -> Bool {
        let suppressed = dismissSuppressedByRequest
        dismissSuppressedByRequest = false
        return suppressed
    }

    func clearDismissSuppression() { dismissSuppressedByRequest = false }

    @objc private func blockerTapped() { requestClose() }

    override func layoutSubviews() {
        super.layoutSubviews()
        blocker.frame = bounds
        // The scrim covers the whole screen; what the modal holds stays
        // clear of the bars and the home indicator it is drawn over.
        contentStack.frame = bounds.inset(by: UIEdgeInsets(top: contentInsets.top, left: 0, bottom: contentInsets.bottom, right: 0))
    }

    /// Where the screen's own content starts and ends: the scrim covers the
    /// whole screen, what the modal holds stays clear of the bars.
    var contentInsets: UIEdgeInsets = .zero {
        didSet { if contentInsets != oldValue { setNeedsLayout() } }
    }
}

/// The delegate of a Pressable's press-in/out feedback. That recognizer is
/// a long press of no duration, so it begins the moment a finger lands; on its
/// own it would claim the touch, and the tap that is the Pressable's onPress
/// failed whenever onPressIn or onPressOut were set too. It only watches.
final class CraftPressFeedbackDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = CraftPressFeedbackDelegate()

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

/// Whether a scrolling view's gesture runs together with `other`. A scroll
/// view is the delegate of its own pan as well as of its keyboard tap, so this
/// answers for both. Everything runs together (the keyboard tap watches
/// alongside a control's own gestures; the back-swipe and the tab swipe decide
/// for themselves) except two scroll views' pans: run together, a drag on a
/// nested scroll view scrolled its parent at the same time.
func craftScrollGesture(_ gesture: UIGestureRecognizer, runsWith other: UIGestureRecognizer) -> Bool {
    guard let scroll = gesture.view as? UIScrollView, gesture === scroll.panGestureRecognizer,
          let otherScroll = other.view as? UIScrollView, other === otherScroll.panGestureRecognizer else { return true }
    return false
}

private final class CraftNativeScrollView: UIScrollView, UIGestureRecognizerDelegate {
    let contentStack = CraftNativeFlowView()
    private let keyboardTapGesture = UITapGestureRecognizer()
    private var keyboardShouldPersistTaps = "never"
    private var contentNeedsLayout = true
    private var laidOutSize: CGSize = .zero
    private let pullToRefresh = UIRefreshControl()
    private var refreshHandler: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        keyboardTapGesture.cancelsTouchesInView = false
        keyboardTapGesture.delegate = self
        keyboardTapGesture.addTarget(self, action: #selector(keyboardTap))
        addGestureRecognizer(keyboardTapGesture)
        pullToRefresh.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        addSubview(contentStack)
        setAxis(.vertical)
    }

    required init?(coder: NSCoder) { nil }

    var isVertical: Bool { contentStack.axis == .vertical }

    /// Lays the content out again on the next pass. Scrolling alone does not:
    /// a scroll view lays out on every frame of a scroll.
    func setContentNeedsLayout() {
        contentNeedsLayout = true
        setNeedsLayout()
    }

    /// The size of the content laid out across the visible width (or, sideways,
    /// height), which is also the scroll view's own size when nothing fixes it.
    func contentFitting(width: CGFloat?, height: CGFloat?) -> CGSize {
        if isVertical {
            let contentWidth = max(0, (width ?? bounds.width) - adjustedContentInset.left - adjustedContentInset.right)
            return contentStack.measure(width: contentWidth, height: nil, maxWidth: contentWidth, maxHeight: CraftNativeFlexLayout.unbounded)
        }
        let contentHeight = height.map { max(0, $0 - adjustedContentInset.top - adjustedContentInset.bottom) }
        return contentStack.measure(width: nil, height: contentHeight, maxWidth: CraftNativeFlexLayout.unbounded, maxHeight: contentHeight ?? CraftNativeFlexLayout.unbounded)
    }

    func measure(width: CGFloat?, height: CGFloat?, maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        if isVertical {
            let resolvedWidth = width ?? maxWidth
            return CGSize(width: resolvedWidth, height: height ?? contentFitting(width: resolvedWidth, height: nil).height)
        }
        let content = contentFitting(width: nil, height: height)
        return CGSize(width: width ?? min(content.width, maxWidth), height: height ?? content.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        craftApplyCornerRadius()
        if contentNeedsLayout || laidOutSize != bounds.size {
            contentNeedsLayout = false
            laidOutSize = bounds.size
            var size = contentFitting(width: bounds.width, height: bounds.height)
            if isVertical {
                size.width = max(0, bounds.width - adjustedContentInset.left - adjustedContentInset.right)
            } else {
                size.height = max(0, bounds.height - adjustedContentInset.top - adjustedContentInset.bottom)
            }
            let frame = CGRect(origin: .zero, size: size)
            if contentStack.frame != frame { contentStack.frame = frame }
            if contentSize != size { contentSize = size }
        }
        // A scroll view lays out on every frame of a scroll: the sticky
        // headers follow it here, over content placed by this same pass.
        if !stickyIndices.isEmpty || pendingScrollTarget != nil { contentStack.layoutIfNeeded() }
        updateStickyHeaders()
        scrollToPendingTarget()
    }

    // MARK: Sticky headers

    private var stickyIndices: [Int] = []
    private var stickyViews: [UIView] = []

    /// `stickyHeaderIndices`, as in React Native: the content's children at
    /// these indices stay at the top of the visible area once scrolled to,
    /// each pushed up by the next. Vertical scroll views only.
    func setStickyHeaderIndices(_ value: Any?) {
        let next = Array(Set(((value as? [Any]) ?? []).compactMap { ($0 as? NSNumber)?.intValue }.filter { $0 >= 0 })).sorted()
        guard next != stickyIndices else { return }
        stickyIndices = next
        setNeedsLayout()
    }

    /// Where a header sits in the content when it is not stuck.
    private func naturalTop(_ view: UIView) -> CGFloat {
        view.center.y - view.bounds.height / 2
    }

    private func updateStickyHeaders() {
        let children = contentStack.arrangedSubviews
        let headers = isVertical ? stickyIndices.compactMap { $0 < children.count ? children[$0] : nil }.filter { !$0.isHidden } : []
        for view in stickyViews where !headers.contains(where: { $0 === view }) {
            view.transform = .identity
            view.layer.zPosition = 0
        }
        stickyViews = headers
        guard !headers.isEmpty else { return }
        let visibleTop = contentOffset.y + adjustedContentInset.top
        for (index, header) in headers.enumerated() {
            let natural = naturalTop(header)
            var top = max(natural, visibleTop)
            if index + 1 < headers.count {
                top = max(natural, min(top, naturalTop(headers[index + 1]) - header.bounds.height))
            }
            let shift = CGAffineTransform(translationX: 0, y: top - natural)
            if header.transform != shift { header.transform = shift }
            // Above the content it covers, for drawing and for touches.
            header.layer.zPosition = 1
            if contentStack.subviews.last !== header { contentStack.bringSubviewToFront(header) }
        }
    }

    /// The height a stuck header covers above a point of the content.
    private func stickyHeight(above y: CGFloat) -> CGFloat {
        stickyViews.last(where: { naturalTop($0) <= y })?.bounds.height ?? 0
    }

    // MARK: Scroll targets

    private var scrollTargetKey: String?
    private var pendingScrollTarget: (id: String, animated: Bool, attempts: Int)?

    /// `scrollTarget`: `"<testID>"` or `{ id, animated?, key? }`. When it
    /// changes, the content scrolls so the view with that `testID` sits at
    /// the top of the visible area, below any sticky header. A new `key`
    /// scrolls to the same view again; `null` forgets the last target.
    func setScrollTarget(_ value: Any?) {
        var id: String?
        var animated = true
        if let text = value as? String {
            id = text
        } else if let target = value as? [String: Any] {
            id = target["id"] as? String
            animated = target["animated"] as? Bool ?? true
        }
        guard let id, !id.isEmpty else {
            scrollTargetKey = nil
            pendingScrollTarget = nil
            return
        }
        let key: String
        if let object = value as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) {
            key = String(decoding: data, as: UTF8.self)
        } else {
            key = id
        }
        guard key != scrollTargetKey else { return }
        scrollTargetKey = key
        pendingScrollTarget = (id, animated, 0)
        setNeedsLayout()
    }

    private func descendant(withIdentifier id: String, in view: UIView) -> UIView? {
        for child in view.subviews {
            if child.accessibilityIdentifier == id { return child }
            if let match = descendant(withIdentifier: id, in: child) { return match }
        }
        return nil
    }

    private func scrollToPendingTarget() {
        guard let target = pendingScrollTarget, bounds.height > 0 else { return }
        pendingScrollTarget = nil
        let view = descendant(withIdentifier: target.id, in: contentStack)
        // A target the same render created may not be in place yet (this pass
        // can run while the render is applied): try again on the next passes.
        guard let view, view.bounds.size != .zero else {
            if target.attempts < 3 {
                pendingScrollTarget = (target.id, target.animated, target.attempts + 1)
                DispatchQueue.main.async { [weak self] in self?.setNeedsLayout() }
            }
            return
        }
        let rect = view.convert(view.bounds, to: contentStack)
        if isVertical {
            let lowest = -adjustedContentInset.top
            let highest = max(lowest, contentSize.height + adjustedContentInset.bottom - bounds.height)
            let y = min(highest, max(lowest, rect.minY - adjustedContentInset.top - stickyHeight(above: rect.minY)))
            setContentOffset(CGPoint(x: contentOffset.x, y: y), animated: target.animated)
        } else {
            let lowest = -adjustedContentInset.left
            let highest = max(lowest, contentSize.width + adjustedContentInset.right - bounds.width)
            let x = min(highest, max(lowest, rect.minX - adjustedContentInset.left))
            setContentOffset(CGPoint(x: x, y: contentOffset.y), animated: target.animated)
        }
    }

    override func adjustedContentInsetDidChange() {
        super.adjustedContentInsetDidChange()
        setContentNeedsLayout()
    }

    private var refreshingProp = false

    /// `onRefresh` and `refreshing`: the system's pull to refresh, controlled
    /// as in React Native. The spinner shows while `refreshing` is true; a
    /// pull that the screen does not answer with `refreshing` true ends at
    /// once instead of spinning forever.
    func setRefreshHandler(_ handler: (() -> Void)?, refreshing: Bool) {
        refreshHandler = handler
        refreshingProp = refreshing
        if handler == nil {
            if pullToRefresh.isRefreshing { pullToRefresh.endRefreshing() }
            if refreshControl === pullToRefresh { refreshControl = nil }
            return
        }
        if refreshControl !== pullToRefresh { refreshControl = pullToRefresh }
        if refreshing, !pullToRefresh.isRefreshing {
            pullToRefresh.beginRefreshing()
        } else if !refreshing, pullToRefresh.isRefreshing {
            pullToRefresh.endRefreshing()
        }
    }

    /// Applies the shared RefreshControl appearance props. UIKit's refresh
    /// control owns the spinner and optional title; keep the authored values
    /// on the control so a later reconciliation can clear them as well.
    func setRefreshAppearance(_ props: [String: Any]) {
        pullToRefresh.tintColor = (props["tintColor"] as? String).flatMap { UIColor(hex: $0) }
        guard let title = props["title"] as? String, !title.isEmpty else {
            pullToRefresh.attributedTitle = nil
            return
        }
        var attributes: [NSAttributedString.Key: Any] = [:]
        if let titleColor = (props["titleColor"] as? String).flatMap({ UIColor(hex: $0) }) {
            attributes[.foregroundColor] = titleColor
        }
        pullToRefresh.attributedTitle = NSAttributedString(string: title, attributes: attributes)
    }

    var isRefreshingNow: Bool { pullToRefresh.isRefreshing }

    @objc private func refreshPulled() {
        refreshHandler?()
        // The handler's synchronous render has landed by now.
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.refreshingProp, self.pullToRefresh.isRefreshing else { return }
            self.pullToRefresh.endRefreshing()
        }
    }

    func setKeyboardShouldPersistTaps(_ value: Any?) {
        let requested = value as? String
        keyboardShouldPersistTaps = ["always", "handled", "never"].contains(requested) ? requested! : "never"
        keyboardTapGesture.isEnabled = keyboardShouldPersistTaps != "always"
    }

    @objc private func keyboardTap() {
        guard keyboardShouldPersistTaps != "always" else { return }
        let point = keyboardTapGesture.location(in: self)
        var hit = hitTest(point, with: nil)
        var onControl = false
        var onButton = false
        while let view = hit, view !== self {
            if view is UIButton { onButton = true }
            if view is UIControl || !(view.gestureRecognizers ?? []).isEmpty { onControl = true; break }
            hit = view.superview
        }
        if keyboardShouldPersistTaps == "handled", onControl { return }
        // A button keeps the keyboard: its press gives the focus straight
        // back. Ending editing first only let the keyboard's inset go while
        // the finger was down, the button moved out from under it, and the
        // press was lost.
        if onButton { return }
        // Otherwise the keyboard goes; after a tap on nothing, for good (the
        // next render must not bring the last input back).
        if !onControl { craftScreenController?.forgetFocusedInput() }
        window?.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        craftScrollGesture(gestureRecognizer, runsWith: otherGestureRecognizer)
    }

    func setAxis(_ axis: NSLayoutConstraint.Axis) {
        if contentStack.axis != axis { setContentNeedsLayout() }
        contentStack.axis = axis
        alwaysBounceVertical = axis == .vertical
        alwaysBounceHorizontal = axis == .horizontal
    }
}

/// Text with padding of its own: the padding is inside the label, around
/// the text, and counts in its measured size.
/// A vector drawing (stx `svg.ts`): an `Svg` node and the shapes below it,
/// replayed from each shape's `geometry` commands - 0 move, 1 line, 2 cubic,
/// 3 quadratic, 4 close, in viewBox units - and scaled to the view. Paint is
/// inherited down the tree as SVG does; `dark:` classes arrive already
/// resolved for the appearance, so a redraw is all a theme change needs.
private final class CraftNativeSvgView: UIView {
    var drawing: [String: Any] = [:] {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var viewBox: CGRect? {
        let props = drawing["props"] as? [String: Any] ?? [:]
        guard let box = props["viewBox"] as? [Any], box.count == 4 else { return nil }
        let n = box.compactMap { ($0 as? NSNumber).map { CGFloat(truncating: $0) } }
        guard n.count == 4, n.allSatisfy(\.isFinite), n[2] > 0, n[3] > 0 else { return nil }
        return CGRect(x: n[0], y: n[1], width: n[2], height: n[3])
    }

    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric) }

    /// Height from the viewBox's proportions, when no style gave one.
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard let box = viewBox, size.width > 0, size.width < CraftNativeFlexLayout.unbounded else { return CGSize(width: 0, height: 0) }
        return CGSize(width: size.width, height: size.width * box.height / box.width)
    }

    private struct Paint {
        var fill: String? = "#000000"
        var stroke: String?
        var strokeWidth: CGFloat = 1
        var color: String? = "#000000"
        var opacity: CGFloat = 1
        var linecap: String?
        var linejoin: String?
        var dashes: [CGFloat]?
        var vectorEffect: String?

        func merged(_ node: [String: Any]) -> Paint {
            var next = self
            let props = node["props"] as? [String: Any] ?? [:]
            let style = node["style"] as? [String: Any] ?? [:]
            func value(_ key: String) -> Any? { style[key] ?? props[key] }
            func finite(_ raw: Any?) -> CGFloat? {
                guard let number = raw as? NSNumber else { return nil }
                let value = CGFloat(truncating: number)
                return value.isFinite ? value : nil
            }
            if let color = style["color"] as? String { next.color = color }
            if let fill = style["fill"] as? String ?? props["fill"] as? String { next.fill = fill }
            if let stroke = style["stroke"] as? String ?? props["stroke"] as? String { next.stroke = stroke }
            if let width = finite(style["strokeWidth"] ?? props["strokeWidth"]) { next.strokeWidth = width }
            // Computed style wins over the component prop, matching Android
            // and the browser's cascade when both provide opacity.
            if let opacity = finite(style["opacity"] ?? props["opacity"]) { next.opacity *= opacity }
            if let cap = value("strokeLinecap") as? String { next.linecap = cap }
            if let join = value("strokeLinejoin") as? String { next.linejoin = join }
            if let dashes = value("strokeDasharray") as? [Any] { next.dashes = dashes.compactMap(finite).filter { $0 >= 0 } }
            if let vectorEffect = value("vectorEffect") as? String { next.vectorEffect = vectorEffect }
            return next
        }

        func resolve(_ value: String?) -> UIColor? {
            guard let value, value != "none", value != "transparent" else { return nil }
            let text = value == "currentColor" ? (color ?? "#000000") : value
            return UIColor(css: text) ?? UIColor(hex: text)
        }
    }

    /// viewBox units to the view's points, set by each draw.
    private var viewTransform = CGAffineTransform.identity

    /// viewBox to view: centred at one scale (SVG's default, `xMidYMid meet`),
    /// or each axis stretched to fill (`preserveAspectRatio="none"`), as a
    /// chart a page sizes to its width and a fixed height asks for.
    static func transform(box: CGRect, bounds: CGSize, preserveAspectRatio: String?) -> CGAffineTransform? {
        var sx = bounds.width / box.width
        var sy = bounds.height / box.height
        var dx: CGFloat = 0
        var dy: CGFloat = 0
        if preserveAspectRatio?.trimmingCharacters(in: .whitespaces) != "none" {
            let scale = min(sx, sy)
            sx = scale
            sy = scale
            dx = (bounds.width - box.width * scale) / 2
            dy = (bounds.height - box.height * scale) / 2
        }
        guard sx.isFinite, sy.isFinite, sx > 0, sy > 0 else { return nil }
        return CGAffineTransform(translationX: dx, y: dy).scaledBy(x: sx, y: sy).translatedBy(x: -box.minX, y: -box.minY)
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        viewTransform = .identity
        if let box = viewBox {
            let props = drawing["props"] as? [String: Any] ?? [:]
            guard let transform = CraftNativeSvgView.transform(box: box, bounds: bounds.size, preserveAspectRatio: props["preserveAspectRatio"] as? String) else { return }
            viewTransform = transform
            context.concatenate(transform)
        }
        draw(children: drawing["children"] as? [Any] ?? [], paint: Paint().merged(drawing), in: context)
    }

    private func draw(children: [Any], paint: Paint, in context: CGContext) {
        for case let shape as [String: Any] in children {
            let style = shape["style"] as? [String: Any] ?? [:]
            if style["display"] as? String == "none" { continue }
            let own = paint.merged(shape)
            switch shape["type"] as? String {
            case "G":
                draw(children: shape["children"] as? [Any] ?? [], paint: own, in: context)
            case "SvgText":
                drawText(shape, paint: own)
            default:
                guard let path = CraftNativeSvgView.path((shape["props"] as? [String: Any])?["geometry"]) else { continue }
                context.saveGState()
                context.setAlpha(own.opacity)
                if let fill = own.resolve(own.fill) {
                    fill.setFill()
                    path.fill()
                }
                if let stroke = own.resolve(own.stroke), own.strokeWidth > 0 {
                    // `vector-effect="non-scaling-stroke"`: the stroke is in the
                    // view's points, so a stretched chart's line keeps its width
                    // and a round cap stays a round dot.
                    let nonScaling = own.vectorEffect == "non-scaling-stroke"
                    let line: UIBezierPath
                    if nonScaling, let copy = path.copy() as? UIBezierPath {
                        copy.apply(viewTransform)
                        context.concatenate(viewTransform.inverted())
                        line = copy
                    }
                    else {
                        line = path
                    }
                    stroke.setStroke()
                    line.lineWidth = own.strokeWidth
                    line.lineCapStyle = own.linecap == "round" ? .round : own.linecap == "square" ? .square : .butt
                    line.lineJoinStyle = own.linejoin == "round" ? .round : own.linejoin == "bevel" ? .bevel : .miter
                    if let dashes = own.dashes, !dashes.isEmpty { line.setLineDash(dashes, count: dashes.count, phase: 0) }
                    line.stroke()
                }
                context.restoreGState()
            }
        }
    }

    private func drawText(_ node: [String: Any], paint: Paint) {
        let text = (node["children"] as? [Any] ?? []).compactMap { $0 as? String }.joined()
        guard !text.isEmpty else { return }
        let props = node["props"] as? [String: Any] ?? [:]
        let style = node["style"] as? [String: Any] ?? [:]
        let size = number(props["fontSize"]) ?? number(style["fontSize"]) ?? 12
        let weight: UIFont.Weight = (props["fontWeight"] as? String ?? style["fontWeight"] as? String).map { ["500": .medium, "600": .semibold, "700": .bold, "bold": .bold][$0] ?? .regular } ?? .regular
        let string = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: paint.resolve(paint.fill) ?? UIColor.label,
        ])
        var x = number(props["x"]) ?? 0
        let y = number(props["y"]) ?? 0
        switch props["textAnchor"] as? String {
        case "middle": x -= string.size().width / 2
        case "end": x -= string.size().width
        default: break
        }
        // y is the baseline, as in SVG.
        string.draw(at: CGPoint(x: x, y: y - UIFont.systemFont(ofSize: size).ascender))
    }

    static func path(_ value: Any?) -> UIBezierPath? {
        guard let list = value as? [Any] else { return nil }
        let n = list.compactMap { ($0 as? NSNumber).map { CGFloat(truncating: $0) } }
        guard !n.isEmpty, n.count == list.count, n.allSatisfy(\.isFinite) else { return nil }
        let path = UIBezierPath()
        var i = 0
        func point(_ at: Int) -> CGPoint { CGPoint(x: n[at], y: n[at + 1]) }
        while i < n.count {
            switch Int(n[i]) {
            case 0 where i + 2 < n.count: path.move(to: point(i + 1)); i += 3
            case 1 where i + 2 < n.count: path.addLine(to: point(i + 1)); i += 3
            case 2 where i + 6 < n.count: path.addCurve(to: point(i + 5), controlPoint1: point(i + 1), controlPoint2: point(i + 3)); i += 7
            case 3 where i + 4 < n.count: path.addQuadCurve(to: point(i + 3), controlPoint: point(i + 1)); i += 5
            case 4: path.close(); i += 1
            default: return path
            }
        }
        return path
    }
}

/// A view's linear gradient (stx `bg-gradient-to-br from-* via-* to-*`), kept
/// as its first sublayer - under its subviews - and following its bounds and
/// corners as they change.
private final class CraftNativeGradientLayer: CAGradientLayer {
    private var observations: [NSKeyValueObservation] = []

    static func apply(to view: UIView, direction: String?, colors: [UIColor?]) {
        let existing = view.layer.sublayers?.first as? CraftNativeGradientLayer
        guard let direction, let from = colors[0], let to = colors[2] else {
            existing?.removeFromSuperlayer()
            return
        }
        let layer = existing ?? CraftNativeGradientLayer()
        layer.colors = [from, colors[1], to].compactMap { $0?.cgColor }
        let points: (CGPoint, CGPoint)
        switch direction {
        case "to-t": points = (CGPoint(x: 0.5, y: 1), CGPoint(x: 0.5, y: 0))
        case "to-tr": points = (CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 0))
        case "to-r": points = (CGPoint(x: 0, y: 0.5), CGPoint(x: 1, y: 0.5))
        case "to-br": points = (CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1))
        case "to-bl": points = (CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1))
        case "to-l": points = (CGPoint(x: 1, y: 0.5), CGPoint(x: 0, y: 0.5))
        case "to-tl": points = (CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 0))
        default: points = (CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 1))
        }
        layer.startPoint = points.0
        layer.endPoint = points.1
        layer.follow(view)
        guard existing == nil else { return }
        view.layer.insertSublayer(layer, at: 0)
        // The layer's bounds, not the view's: UIKit does not promise KVO for
        // UIView.bounds, and a screen laid out by frame never reported it, so
        // every gradient stayed zero-sized. CALayer's own bounds always do.
        layer.observations = [
            view.layer.observe(\.bounds) { [weak layer, weak view] _, _ in if let view { layer?.follow(view) } },
            view.layer.observe(\.cornerRadius) { [weak layer, weak view] _, _ in if let view { layer?.follow(view) } },
        ]
    }

    private func follow(_ view: UIView) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        frame = view.bounds
        cornerRadius = view.layer.cornerRadius
        maskedCorners = view.layer.maskedCorners
        masksToBounds = cornerRadius > 0
        CATransaction.commit()
    }
}

/// A button that keeps the padding its style asks for (`px-4 py-2`). A bare
/// UIButton sizes to its title and ignores it, so a styled button drew as a
/// pill with its label touching the edges. The padding is added to its size
/// and the label laid out inside it, at the alignment the style asked for.
private final class CraftNativeButton: UIButton {
    var padding: UIEdgeInsets = .zero {
        didSet {
            guard padding != oldValue else { return }
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + padding.left + padding.right, height: size.height + padding.top + padding.bottom)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let inner = super.sizeThatFits(CGSize(
            width: max(0, size.width - padding.left - padding.right),
            height: max(0, size.height - padding.top - padding.bottom)
        ))
        return CGSize(width: inner.width + padding.left + padding.right, height: inner.height + padding.top + padding.bottom)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard padding != .zero, let label = titleLabel else { return }
        let area = bounds.inset(by: padding)
        let fitted = label.sizeThatFits(area.size)
        let width = min(ceil(fitted.width), area.width)
        let height = min(ceil(fitted.height), area.height)
        let x: CGFloat
        switch contentHorizontalAlignment {
        case .left, .leading: x = area.minX
        case .right, .trailing: x = area.maxX - width
        default: x = area.midX - width / 2
        }
        label.frame = CGRect(x: x, y: area.midY - height / 2, width: width, height: height)
    }
}

/// A native checkbox button. UIKit has no checkbox control, so use the system
/// square/checkmark symbols while keeping the control's title and accessibility
/// state native and keyboard/touch reachable.
private final class CraftNativeCheckboxButton: UIButton {
    var indeterminate = false
}

private final class CraftNativeLabel: UILabel {
    var insets = UIEdgeInsets.zero {
        didSet {
            guard insets != oldValue else { return }
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
        }
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        guard insets != .zero else { return super.textRect(forBounds: bounds, limitedToNumberOfLines: numberOfLines) }
        let inner = super.textRect(forBounds: bounds.inset(by: insets), limitedToNumberOfLines: numberOfLines)
        return CGRect(
            x: inner.minX - insets.left,
            y: inner.minY - insets.top,
            width: inner.width + insets.left + insets.right,
            height: inner.height + insets.top + insets.bottom
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        craftApplyCornerRadius()
    }
}

/// A one-line TextInput. Its style's padding is where the text and the
/// placeholder start, as in a web input; UITextField has no padding of its own.
final class CraftNativeTextField: UITextField {
    var padding = UIEdgeInsets.zero {
        didSet {
            guard padding != oldValue else { return }
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        super.textRect(forBounds: bounds.inset(by: padding))
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        super.editingRect(forBounds: bounds.inset(by: padding))
    }

    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        super.placeholderRect(forBounds: bounds.inset(by: padding))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + padding.left + padding.right, height: size.height + padding.top + padding.bottom)
    }
}

private final class CraftNativeFlexSpacer: UIView {}

/// An SF Symbol leaf. Its natural size is the symbol's, or a 20 pt square
/// when the style gives it no size at all.
private final class CraftNativeIconView: UIImageView {
    var defaultBox: CGFloat? { didSet { if defaultBox != oldValue { invalidateIntrinsicContentSize() } } }

    override var intrinsicContentSize: CGSize {
        if let defaultBox { return CGSize(width: defaultBox, height: defaultBox) }
        return super.intrinsicContentSize
    }
}

private final class CraftNativeTextView: UITextView {
    private let placeholderLabel = UILabel()
    var placeholder: String? {
        didSet { refreshPlaceholder() }
    }
    var placeholderColor: UIColor? {
        didSet { placeholderLabel.textColor = placeholderColor ?? .placeholderText }
    }
    var placeholderFont: UIFont? {
        didSet { placeholderLabel.font = placeholderFont ?? .systemFont(ofSize: 16) }
    }

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        configurePlaceholder()
    }

    convenience init() {
        self.init(frame: .zero, textContainer: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configurePlaceholder()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = textContainerInset
        let padding = textContainer.lineFragmentPadding
        placeholderLabel.frame = CGRect(
            x: inset.left + padding,
            y: inset.top,
            width: max(0, bounds.width - inset.left - inset.right - padding * 2),
            height: max(0, bounds.height - inset.top - inset.bottom)
        )
    }

    func refreshPlaceholder() {
        placeholderLabel.text = placeholder
        placeholderLabel.isHidden = !(text?.isEmpty ?? true) || placeholder?.isEmpty != false
    }

    private func configurePlaceholder() {
        placeholderLabel.numberOfLines = 0
        placeholderLabel.font = font
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.isUserInteractionEnabled = false
        addSubview(placeholderLabel)
        refreshPlaceholder()
    }
}

final class CraftNativeScreenController: UIViewController, UIScrollViewDelegate, UITextFieldDelegate, UITextViewDelegate, UIPickerViewDataSource, UIPickerViewDelegate {
    private final class RenderedNode {
        let identity: String
        let type: String
        let view: UIView
        var protocolId: String?
        var style: [String: Any] = [:]
        var children: [RenderedNode] = []
        var widthConstraint: NSLayoutConstraint?
        var heightConstraint: NSLayoutConstraint?

        init(identity: String, type: String, view: UIView) {
            self.identity = identity
            self.type = type
            self.view = view
        }
    }

    private let config: CraftConfig
    private let routeName: String?
    private(set) var routeParams: [String: Any]
    private let jsContext = JSContext()!
    private let rootStack = CraftNativeFlowView()
    private var handlers: [ObjectIdentifier: String] = [:]
    private var pressInHandlers: [ObjectIdentifier: String] = [:]
    private var pressOutHandlers: [ObjectIdentifier: String] = [:]
    private var focusHandlers: [ObjectIdentifier: String] = [:]
    private var blurHandlers: [ObjectIdentifier: String] = [:]
    private var endEditingHandlers: [ObjectIdentifier: String] = [:]
    private var submitHandlers: [ObjectIdentifier: String] = [:]
    private var inputIdentities: [ObjectIdentifier: String] = [:]
    private var inputDrafts: [String: String] = [:]
    private var longPressHandlers: [ObjectIdentifier: String] = [:]
    private var textMaxLengths: [ObjectIdentifier: Int] = [:]
    private var scrollHandlers: [ObjectIdentifier: String] = [:]
    private var scrollBeginHandlers: [ObjectIdentifier: String] = [:]
    private var scrollEndHandlers: [ObjectIdentifier: String] = [:]
    private var scrollMomentumBeginHandlers: [ObjectIdentifier: String] = [:]
    private var scrollMomentumEndHandlers: [ObjectIdentifier: String] = [:]
    private var sliderCompleteHandlers: [ObjectIdentifier: String] = [:]
    private var sliderSteps: [ObjectIdentifier: Float] = [:]
    private var pickerOptions: [ObjectIdentifier: [(value: String, label: String)]] = [:]
    private var modalVisibility: [ObjectIdentifier: Bool] = [:]
    private var layoutHandlers: [ObjectIdentifier: String] = [:]
    private var lastLayoutFrames: [ObjectIdentifier: CGRect] = [:]
    private var tapRecognizers: [ObjectIdentifier: UITapGestureRecognizer] = [:]
    private var longPressRecognizers: [ObjectIdentifier: UILongPressGestureRecognizer] = [:]
    private var pressFeedbackRecognizers: [ObjectIdentifier: UILongPressGestureRecognizer] = [:]
    private var imageSources: [ObjectIdentifier: String] = [:]
    private var imageTasks: [ObjectIdentifier: URLSessionDataTask] = [:]
    private var imageErrors: [ObjectIdentifier: String] = [:]
    private var checkboxIndeterminate: [ObjectIdentifier: Bool] = [:]
    private var tintedImages = Set<ObjectIdentifier>()
    private var imageLoadStartHandlers: [ObjectIdentifier: String] = [:]
    private var imageLoadHandlers: [ObjectIdentifier: String] = [:]
    private var imageLoadEndHandlers: [ObjectIdentifier: String] = [:]
    private var imageErrorHandlers: [ObjectIdentifier: String] = [:]
    /// Native links keep their target separate from optional press handlers.
    /// The compiler can emit an anchor as `TouchableOpacity`, so this map is
    /// intentionally shared by Link and the generic pressable path.
    private var linkTargets: [ObjectIdentifier: String] = [:]
    private var renderedRoot: RenderedNode?
    private weak var lastFocusedInput: UIView?

    /// The person put the keyboard away (Return, or a tap on nothing in a
    /// scroll view): the last input is let go. Kept, the next render or
    /// button press focused it again and the keyboard came straight back.
    func forgetFocusedInput(_ input: UIView? = nil) {
        if input == nil || lastFocusedInput === input { lastFocusedInput = nil }
    }
    private var flatListRows: [ObjectIdentifier: [String: RenderedNode]] = [:]
    private var flatListOwners: [String: String] = [:]
    /// A drawing's shapes are not views: a change to one redraws its `Svg`.
    private var svgOwners: [String: String] = [:]
    private let mutationDocument = CraftNativeMutationDocument()
    /// The screen's Web Audio (CraftWebAudio.swift): its `AudioContext`s.
    private let audio = CraftWebAudio()
    /// `craft.audio`'s sounds and the streaming responses this screen reads.
    private let sounds = CraftNativeSounds()
    private let streams = CraftNativeEventStreams()
    /// A request a screen-owned module answers, by request token, and how to
    /// call it off when it times out or is cancelled.
    private var screenRequestCancellers: [String: () -> Void] = [:]
    /// Shown at least once: a later appearance is the screen coming back.
    private var hasAppeared = false
    /// Whether the script was last told the screen is on screen.
    private var reportedVisible = false
    private let capabilityScope = UUID().uuidString
    private var pendingCapabilityRequests = Set<String>()
    private var pendingCapabilityDeadlines: [String: DispatchWorkItem] = [:]
    private var pendingTimers: [Int: DispatchWorkItem] = [:]
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var deepLinkListener: UUID?
    private var keyboardSafeAreaInset: CGFloat = 0
    /// Where the keyboard is on the screen while it is up, in screen coordinates.
    private var keyboardScreenFrame: CGRect?
    /// The hybrid shell (CraftHybrid.swift), when this screen is one of a web
    /// app's native screens: told of the first frame, of a first frame that
    /// could not be drawn, and of `craft.navigation.open(path)`.
    weak var hybridEvents: CraftHybridScreenEvents?
    private var hybridRendered = false
    private var runtimeDisposed = false
    /// The app script (`nativeApp`, CraftHybrid.swift): a bundle route with
    /// no screen, loaded once and never shown, that runs for the app's life.
    /// It hears every `APP_STATE` and the app's events (`CRAFT_EVENT`), no
    /// `DEEP_LINK`; it can open paths but not push, pop or style a bar.
    let isAppScript: Bool

    init(config: CraftConfig, routeName: String? = nil, routeParams: [String: Any] = [:], isAppScript: Bool = false) {
        self.config = config
        self.routeName = routeName
        self.routeParams = routeParams
        self.isAppScript = isAppScript
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        disposeRuntime()
        imageTasks.values.forEach { $0.cancel() }
        pendingCapabilityDeadlines.values.forEach { $0.cancel() }
        pendingTimers.values.forEach { $0.cancel() }
        pendingCapabilityRequests.forEach { CraftNativeActions.cancel(requestToken: $0) }
        lifecycleObservers.forEach(NotificationCenter.default.removeObserver)
        if let deepLinkListener = deepLinkListener { DeepLinkManager.shared.removeNativeListener(deepLinkListener) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = routeName ?? config.appName
        view.backgroundColor = config.resolvedBackgroundColor
        rootStack.axis = .vertical
        rootStack.alignItems = "stretch"
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootStack)
        rootTopToSafeArea = rootStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        rootTopToView = rootStack.topAnchor.constraint(equalTo: view.topAnchor)
        rootBottomToSafeArea = rootStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        rootBottomToView = rootStack.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        rootLeadingToSafeArea = rootStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor)
        rootLeadingToView = rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        rootTrailingToSafeArea = rootStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        rootTrailingToView = rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        NSLayoutConstraint.activate([
            rootTopToSafeArea!,
            rootBottomToSafeArea!,
            rootLeadingToSafeArea!,
            rootTrailingToSafeArea!
        ])
        setupJavaScript()
        loadBundle()
        observeNativeEvents()
        if isAppScript {
            // Its bundle has run, so its listeners are in place: the app's
            // events that waited for it arrive now, in order.
            CraftEventManager.shared.appScriptReady { [weak self] event, detail in
                self?.send(type: "CRAFT_EVENT", payload: ["event": event, "detail": detail])
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        let colorChanged = previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle
        let textSizeChanged = previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory
        guard colorChanged || textSizeChanged else { return }
        refreshTraitDefaults()
        sendAppearance()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let navigationBarHidden, navigationController?.isNavigationBarHidden != navigationBarHidden {
            navigationController?.setNavigationBarHidden(navigationBarHidden, animated: animated)
        } else if navigationBarHidden == nil, navigationController?.isNavigationBarHidden == true,
                  navigationController?.viewControllers.first !== self || wantsNavigationBar {
            // A screen that did not ask for a hidden bar shows one, even after
            // a screen that hid its own.
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
        // Each screen says whether it wants the tab bar, so one that hid it
        // never leaves it hidden for the next.
        CraftChrome.shared.setHiddenByScreen(tabBarHidden)
        refreshTraitDefaults()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Popped (or its stack dismissed) while the bar was away: it comes
        // back for whatever shows next, a web page included.
        if tabBarHidden, isMovingFromParent || isBeingDismissed || navigationController?.isBeingDismissed == true {
            CraftChrome.shared.setHiddenByScreen(false)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        screenVisibilityChanged(true)
        // A navigation breadcrumb for the crash reporter: the trail a crash
        // report carries is the screens that led to it.
        if !isAppScript, let routeName, !routeName.isEmpty {
            CraftCrashReporter.shared.screenAppeared(routeName)
        }
        // onLayout reports views that are on screen: a pushed screen lays
        // out before it has a window, and nothing moved again once it had
        // one, so its rows never reported.
        emitLayoutEvents()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Gone for good only when its stack no longer holds it. UIKit's
        // `isMovingFromParent` is no witness: a tab's first screen covered
        // by a push while its own first appearance was still settling (an
        // app script opening the sign-in screen at launch) reports it true
        // while still the root of its stack, and the screen's script was
        // torn down under it, frozen on whatever it showed then.
        let inStack = navigationController?.viewControllers.contains(where: { $0 === self }) ?? false
        if !inStack {
            disposeRuntime()
        } else {
            screenVisibilityChanged(false)
        }
    }

    /// The screen came on screen or went off it: a screen pushed over it was
    /// popped, or the hybrid shell switched to or away from its tab (which
    /// hides a stack rather than moving it, so UIKit says nothing). The first
    /// appearance is the screen's mount, not news; every later one is
    /// `SCREEN_FOCUS { focused: true }`, and going away is `focused: false`.
    func screenVisibilityChanged(_ visible: Bool) {
        guard !runtimeDisposed, visible != reportedVisible else { return }
        reportedVisible = visible
        if visible, !hasAppeared {
            hasAppeared = true
            return
        }
        send(type: "SCREEN_FOCUS", payload: ["focused": visible])
    }

    /// New params for the screen already showing a path: opened again with
    /// another query (`/m/messages?person=8`), or a tab's root opened with
    /// one (`/m/store?coach=5`). The script's `craft.route.params` changes
    /// and it hears `ROUTE_PARAMS`; before the script has run, it simply
    /// starts with them.
    func receiveRouteParams(_ params: [String: Any]) {
        routeParams = params
        guard isViewLoaded, !runtimeDisposed else { return }
        jsContext.setObject(params as NSDictionary, forKeyedSubscript: "__stxNativeParams" as NSString)
        send(type: "ROUTE_PARAMS", payload: ["params": params])
    }

    private func disposeRuntime() {
        guard !runtimeDisposed else { return }
        runtimeDisposed = true
        jsContext.objectForKeyedSubscript("__stxNativeUnmount")?.call(withArguments: [])
        audio.close()
        sounds.close()
        streams.close()
        screenRequestCancellers.values.forEach { $0() }
        screenRequestCancellers.removeAll()
    }

    private func refreshTraitDefaults() {
        view.backgroundColor = screenBackgroundColor ?? config.resolvedBackgroundColor
        if let document = mutationDocument.node("root") {
            renderCommitted(document)
        } else {
            rootStack.setNeedsLayout()
        }
        refreshTraitDefaults(in: renderedRoot)
    }

    private func refreshTraitDefaults(in node: RenderedNode?) {
        guard let node else { return }
        (node.view as? CraftNativeFlatList)?.refreshThemeDefaults()
        node.children.forEach { refreshTraitDefaults(in: $0) }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        positionModals()
        emitLayoutEvents()
    }

    /// Modals cover the screen; their content starts below its bars (the
    /// status bar is all the safe area counts on a native screen, and a
    /// modal's first control sat under the navigation bar).
    private func positionModals() {
        let modals = view.subviews.compactMap { $0 as? CraftNativeModalView }
        guard !modals.isEmpty else { return }
        var insets = view.safeAreaInsets
        // The navigation bar floats over the screen without counting in its
        // safe area, and it is drawn above anything the screen adds.
        if let nav = navigationController, !nav.isNavigationBarHidden, nav.navigationBar.window != nil {
            let bar = nav.navigationBar.convert(nav.navigationBar.bounds, to: view)
            if bar.intersects(view.bounds) { insets.top = max(insets.top, bar.maxY) }
        }
        for modal in modals {
            if modal.frame != view.bounds { modal.frame = view.bounds }
            modal.contentInsets = insets
        }
    }

    private static func safeJavaScriptString(_ value: JSValue?) -> String? {
        guard let value, !value.isUndefined, !value.isNull, value.isString else { return nil }
        return value.toString()
    }

    private func setupJavaScript() {
        if let routeName = routeName {
            jsContext.setObject(routeName, forKeyedSubscript: "__stxNativeRoute" as NSString)
        }
        jsContext.setObject(routeParams as NSDictionary, forKeyedSubscript: "__stxNativeParams" as NSString)
        jsContext.exceptionHandler = { [weak self] context, exception in
            // Never stringify an arbitrary JS object here. JavaScriptCore can
            // re-enter this handler while coercing an exception whose
            // `toString` is broken, turning a page error into a native crash.
            let message = Self.safeJavaScriptString(exception?.objectForKeyedSubscript("message"))
                ?? Self.safeJavaScriptString(exception)
                ?? "unknown"
            let stack = Self.safeJavaScriptString(exception?.objectForKeyedSubscript("stack")) ?? ""
            let screen = self?.screenName(in: context) ?? "screen"
            CraftNativeConsole.write("error", category: screen, message: stack.isEmpty || stack == "undefined" ? "Uncaught \(message)" : "Uncaught \(message)\n\(stack)")
            // To the app's crash reporter too (bughq, when configured): an
            // uncaught error in a shipped screen is otherwise only in a log
            // nobody reads on someone else's phone.
            CraftCrashReporter.shared.captureJavaScript(
                name: Self.safeJavaScriptString(exception?.objectForKeyedSubscript("name")),
                message: message,
                stack: stack,
                route: screen,
                isAppScript: self?.isAppScript ?? false
            )
            self?.hybridFailed(message)
        }
        let postMessage: @convention(block) (String) -> Void = { [weak self] json in
            self?.receive(json)
        }
        jsContext.setObject(postMessage, forKeyedSubscript: "craftNativePostMessage" as NSString)
        // JavaScriptCore has no timers of its own. The callbacks stay in
        // JavaScript; native only owns the main-queue deadline, so route
        // teardown cancels every pending timer with the controller.
        let scheduleTimer: @convention(block) (Int, Double) -> Void = { [weak self] id, delay in
            guard let self = self else { return }
            let work = DispatchWorkItem { [weak self] in
                guard let self = self, self.pendingTimers.removeValue(forKey: id) != nil else { return }
                self.jsContext.objectForKeyedSubscript("__craftNativeFireTimer")?.call(withArguments: [id])
            }
            self.pendingTimers[id] = work
            let milliseconds = delay.isFinite ? Int(min(max(delay, 0), 2_147_483_647)) : 0
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(milliseconds), execute: work)
        }
        let cancelTimer: @convention(block) (Int) -> Void = { [weak self] id in
            self?.pendingTimers.removeValue(forKey: id)?.cancel()
        }
        jsContext.setObject(scheduleTimer, forKeyedSubscript: "craftNativeScheduleTimer" as NSString)
        jsContext.setObject(cancelTimer, forKeyedSubscript: "craftNativeCancelTimer" as NSString)
        let capabilities = CraftNativeActions.capabilities(config: config)
        let capabilityData = try? JSONSerialization.data(withJSONObject: capabilities)
        let capabilityJSON = capabilityData.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        // The app's site and build, as JSON strings: the site an all-native
        // app's paths and links belong to (`devServerURL`), and the version a
        // request or a crash report names.
        let info = Bundle.main.infoDictionary
        let appURL = Self.jsonString(config.devServerURL ?? "")
        let appVersion = Self.jsonString(info?["CFBundleShortVersionString"] as? String ?? "")
        let appBuild = Self.jsonString(info?["CFBundleVersion"] as? String ?? "")
        jsContext.evaluateScript("""
            globalThis.__stxNativeCallback = null;
            globalThis.__stxNativeBridge = {
                platform: "ios",
                mutationProtocolVersion: 1,
                capabilityProtocolVersion: \(craftNativeCapabilityProtocolVersion),
                capabilityTimeoutMs: \(craftNativeCapabilityTimeoutMilliseconds),
                capabilities: \(capabilityJSON),
                initialAppState: "\(CraftNativeActions.currentAppState())",
                colorScheme: "\(colorScheme)",
                appearance: \(appearanceJSON()),
                appURL: \(appURL),
                appVersion: \(appVersion),
                appBuild: \(appBuild),
                postMessage: function(message) { craftNativePostMessage(message); },
                onMessage: function(callback) { globalThis.__stxNativeCallback = callback; }
            };
        """)
        installHostAPIs()
        jsContext.evaluateScript("""
            if (typeof globalThis.setTimeout !== 'function') {
                (function() {
                    var timers = new Map();
                    var nextTimer = 0;
                    globalThis.setTimeout = function(callback, delay) {
                        var args = Array.prototype.slice.call(arguments, 2);
                        var id = ++nextTimer;
                        timers.set(id, function() {
                            if (typeof callback === 'function') callback.apply(undefined, args);
                        });
                        craftNativeScheduleTimer(id, Number(delay) || 0);
                        return id;
                    };
                    globalThis.clearTimeout = function(id) {
                        if (timers.delete(id)) craftNativeCancelTimer(id);
                    };
                    globalThis.__craftNativeFireTimer = function(id) {
                        var callback = timers.get(id);
                        if (!callback) return;
                        timers.delete(id);
                        callback();
                    };
                })();
            }
            // Repeating timers, on the one-shot ones: each tick schedules the
            // next before running, so a callback that throws or clears itself
            // still behaves, and a screen that closes cancels them with the rest.
            if (typeof globalThis.setInterval !== 'function') {
                (function() {
                    var intervals = new Map();
                    var nextInterval = 0;
                    globalThis.setInterval = function(callback, delay) {
                        var args = Array.prototype.slice.call(arguments, 2);
                        var id = ++nextInterval;
                        var ms = Math.max(Number(delay) || 0, 1);
                        var tick = function() {
                            if (!intervals.has(id)) return;
                            intervals.set(id, globalThis.setTimeout(tick, ms));
                            if (typeof callback === 'function') callback.apply(undefined, args);
                        };
                        intervals.set(id, globalThis.setTimeout(tick, ms));
                        return id;
                    };
                    globalThis.clearInterval = function(id) {
                        var timer = intervals.get(id);
                        if (timer === undefined) return;
                        intervals.delete(id);
                        globalThis.clearTimeout(timer);
                    };
                })();
            }
        """)
    }

    /// `value` as a JavaScript string literal (JSON), quotes and all.
    static func jsonString(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let array = String(data: data, encoding: .utf8), array.count >= 2 else { return "\"\"" }
        return String(array.dropFirst().dropLast())
    }

    /// `"dark"` or `"light"` for the bundle's `dark:` classes (contract A4):
    /// the window's appearance once there is one, else the app's setting.
    private var colorScheme: String {
        let traits = [view.window?.traitCollection, CraftPresenter.keyWindow()?.traitCollection, traitCollection]
        if let style = traits.compactMap({ $0 }).first(where: { $0.userInterfaceStyle != .unspecified })?.userInterfaceStyle {
            return style == .dark ? "dark" : "light"
        }
        return config.appearance == "dark" ? "dark" : "light"
    }

    private func sendAppearance() {
        let style: UIUserInterfaceStyle = colorScheme == "dark" ? .dark : .light
        send(type: "APPEARANCE", payload: CraftPageAppearance.snapshot(style: style))
    }

    private func appearanceJSON() -> String {
        let style: UIUserInterfaceStyle = colorScheme == "dark" ? .dark : .light
        guard let data = try? JSONSerialization.data(withJSONObject: CraftPageAppearance.snapshot(style: style)),
              let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
    }

    /// The screen's name as its script knows it: the route the host opened,
    /// else the one a route bundle selected for itself.
    private func screenName(in context: JSContext? = nil) -> String {
        if let routeName, !routeName.isEmpty { return routeName }
        if let selected = (context ?? jsContext).objectForKeyedSubscript("__stxNativeRoute"), selected.isString {
            return selected.toString()
        }
        return "screen"
    }

    /// Host functions every screen script can call synchronously, installed
    /// before the script runs (contract sections 3, 4 and 5):
    ///
    /// - `console.*` writes to the unified log, subsystem `craft.native`,
    ///   category the screen's name.
    /// - `craft.storage.getSync(key)` / `setSync(key, value)`: the store the
    ///   asynchronous `craft.storage` uses. `getSync` answers what `get` would.
    /// - `craft.snapshots.get(name)` (sync) and `set(name, value)` (a
    ///   promise): `Application Support/craft-snapshots/<name>.json`.
    ///   `clear(keep?)` (a promise) deletes every snapshot but the names in
    ///   `keep`, as a sign-out does; each removal is a `SNAPSHOT_CHANGED`
    ///   for every screen.
    /// - `craft.secureStorage.getSync(key)`: the Keychain item the web page's
    ///   `craft.secureStorage.set` wrote.
    /// - `craft.navigation.setOptions({ title, largeTitle, hidden, backTitle,
    ///   tabBarHidden, swipeBack, contentSwipeBack, tabSwipeEnabled, backgroundColor, rightButtons })`;
    ///   a right button's tap is the event `navButton`.
    ///
    /// A runtime that assigns `craft.storage` (or the others) afterwards keeps
    /// these: each namespace is a property whose setter adds them back to the
    /// object it is given.
    private func installHostAPIs() {
        let log: @convention(block) (String, String, String) -> Void = { level, category, message in
            CraftNativeConsole.write(level, category: category, message: message)
        }
        let storageGet: @convention(block) (String) -> String? = { key in
            CraftNativeActions.storageJSON(forKey: key)
        }
        let storageSet: @convention(block) (String, JSValue) -> Bool = { key, value in
            CraftNativeActions.setStorageJSON(value.isNull || value.isUndefined ? nil : value.toString(), forKey: key)
        }
        let snapshotGet: @convention(block) (String) -> String? = { name in
            CraftSnapshots.read(name)
        }
        let snapshotSet: @convention(block) (String, JSValue, JSValue) -> Void = { name, value, done in
            CraftSnapshots.write(name, json: value.isNull || value.isUndefined ? nil : value.toString()) { ok in
                done.call(withArguments: [ok])
            }
        }
        let snapshotClear: @convention(block) (JSValue, JSValue) -> Void = { keep, done in
            let names = (keep.isUndefined || keep.isNull ? [] : (keep.toArray() ?? [])).compactMap { $0 as? String }
            CraftSnapshots.clear(keeping: Set(names)) { ok in
                done.call(withArguments: [ok])
            }
        }
        let config = self.config
        let secureGet: @convention(block) (String) -> String? = { key in
            config.enableSecureStorage ? CraftNativeActions.webSecureValue(forKey: key) : nil
        }
        let setOptions: @convention(block) (String) -> Void = { [weak self] json in
            guard let data = json.data(using: .utf8),
                  let options = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            self?.applyNavigationOptions(options)
        }
        jsContext.setObject(log, forKeyedSubscript: "craftNativeLog" as NSString)
        jsContext.setObject(storageGet, forKeyedSubscript: "craftNativeStorageGet" as NSString)
        jsContext.setObject(storageSet, forKeyedSubscript: "craftNativeStorageSet" as NSString)
        jsContext.setObject(snapshotGet, forKeyedSubscript: "craftNativeSnapshotGet" as NSString)
        jsContext.setObject(snapshotSet, forKeyedSubscript: "craftNativeSnapshotSet" as NSString)
        jsContext.setObject(snapshotClear, forKeyedSubscript: "craftNativeSnapshotClear" as NSString)
        jsContext.setObject(secureGet, forKeyedSubscript: "craftNativeSecureGet" as NSString)
        jsContext.setObject(setOptions, forKeyedSubscript: "craftNativeSetOptions" as NSString)
        // `AudioContext` and the rest of Web Audio, rendered natively.
        audio.install(in: jsContext)
        // `crypto` for code shared with the page (a sign-in's nonce and its
        // SHA-256): JavaScriptCore has none. Random bytes from the system's
        // generator, digests from CryptoKit, both as hex.
        let randomBytes: @convention(block) (Int) -> String? = { count in
            guard count >= 0, count <= 65_536 else { return nil }
            var bytes = [UInt8](repeating: 0, count: count)
            guard count == 0 || SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else { return nil }
            return bytes.map { String(format: "%02x", $0) }.joined()
        }
        let digest: @convention(block) (String, String) -> String? = { algorithm, hex in
            var data = Data(capacity: hex.count / 2)
            var index = hex.startIndex
            while index < hex.endIndex {
                let next = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
                guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
                data.append(byte)
                index = next
            }
            let bytes: [UInt8]
            switch algorithm.uppercased() {
            case "SHA-1": bytes = Array(Insecure.SHA1.hash(data: data))
            case "SHA-256": bytes = Array(SHA256.hash(data: data))
            case "SHA-384": bytes = Array(SHA384.hash(data: data))
            case "SHA-512": bytes = Array(SHA512.hash(data: data))
            default: return nil
            }
            return bytes.map { String(format: "%02x", $0) }.joined()
        }
        jsContext.setObject(randomBytes, forKeyedSubscript: "craftNativeRandomBytes" as NSString)
        jsContext.setObject(digest, forKeyedSubscript: "craftNativeDigest" as NSString)
        jsContext.evaluateScript("""
            (function() {
                var cryptoObject = globalThis.crypto || {};
                function hexToBytes(hex) {
                    var bytes = new Uint8Array(hex.length / 2);
                    for (var i = 0; i < bytes.length; i++) bytes[i] = parseInt(hex.substr(i * 2, 2), 16);
                    return bytes;
                }
                function toHex(bytes) {
                    var out = '';
                    for (var i = 0; i < bytes.length; i++) out += (bytes[i] < 16 ? '0' : '') + bytes[i].toString(16);
                    return out;
                }
                function viewOf(data) {
                    if (data instanceof ArrayBuffer) return new Uint8Array(data);
                    if (ArrayBuffer.isView(data)) return new Uint8Array(data.buffer, data.byteOffset, data.byteLength);
                    throw new TypeError('crypto.subtle.digest needs an ArrayBuffer or a typed array');
                }
                if (typeof cryptoObject.getRandomValues !== 'function') {
                    cryptoObject.getRandomValues = function(array) {
                        if (!ArrayBuffer.isView(array)) throw new TypeError('crypto.getRandomValues needs a typed array');
                        var hex = craftNativeRandomBytes(array.byteLength);
                        if (hex == null) throw new Error('No random bytes from the system');
                        new Uint8Array(array.buffer, array.byteOffset, array.byteLength).set(hexToBytes(hex));
                        return array;
                    };
                }
                if (typeof cryptoObject.randomUUID !== 'function') {
                    cryptoObject.randomUUID = function() {
                        var b = cryptoObject.getRandomValues(new Uint8Array(16));
                        b[6] = (b[6] & 0x0f) | 0x40;
                        b[8] = (b[8] & 0x3f) | 0x80;
                        var h = toHex(b);
                        return h.slice(0, 8) + '-' + h.slice(8, 12) + '-' + h.slice(12, 16) + '-' + h.slice(16, 20) + '-' + h.slice(20);
                    };
                }
                if (!cryptoObject.subtle || typeof cryptoObject.subtle.digest !== 'function') {
                    cryptoObject.subtle = Object.assign(cryptoObject.subtle || {}, {
                        digest: function(algorithm, data) {
                            try {
                                var name = typeof algorithm === 'string' ? algorithm : algorithm && algorithm.name;
                                var out = craftNativeDigest(String(name || ''), toHex(viewOf(data)));
                                if (out == null) return Promise.reject(new Error('Unsupported digest: ' + name));
                                return Promise.resolve(hexToBytes(out).buffer);
                            } catch (error) {
                                return Promise.reject(error);
                            }
                        }
                    });
                }
                globalThis.crypto = cryptoObject;
            })();
        """)
        jsContext.evaluateScript("""
            (function() {
                function text(value) {
                    if (typeof value === 'string') return value;
                    if (value === undefined) return 'undefined';
                    if (value instanceof Error) return value.stack ? value.message + '\\n' + value.stack : String(value);
                    try { var json = JSON.stringify(value); return json === undefined ? String(value) : json; }
                    catch (error) { return String(value); }
                }
                function screen() {
                    var route = globalThis.__stxNativeRoute;
                    return typeof route === 'string' && route ? route : 'screen';
                }
                function writer(level) {
                    return function() {
                        craftNativeLog(level, screen(), Array.prototype.map.call(arguments, text).join(' '));
                    };
                }
                globalThis.console = {
                    log: writer('log'), info: writer('info'), debug: writer('debug'), trace: writer('debug'),
                    warn: writer('warn'), error: writer('error')
                };

                function parsed(json) {
                    if (json === null || json === undefined) return null;
                    try { return JSON.parse(json); } catch (error) { return null; }
                }
                function encoded(value) {
                    return value === null || value === undefined ? null : JSON.stringify(value);
                }
                var craft = globalThis.craft = globalThis.craft || {};
                function keep(name, extras) {
                    var current = {};
                    function adopt(next) {
                        current = next && typeof next === 'object' ? next : {};
                        Object.keys(extras).forEach(function(key) {
                            if (!(key in current)) current[key] = extras[key];
                        });
                    }
                    adopt(craft[name]);
                    Object.defineProperty(craft, name, {
                        configurable: true,
                        enumerable: true,
                        get: function() { return current; },
                        set: adopt
                    });
                }
                keep('storage', {
                    getSync: function(key) { return parsed(craftNativeStorageGet(String(key))); },
                    setSync: function(key, value) {
                        if (!craftNativeStorageSet(String(key), encoded(value))) throw new Error('craft.storage.setSync could not store ' + key);
                    }
                });
                keep('snapshots', {
                    get: function(name) { return parsed(craftNativeSnapshotGet(String(name))); },
                    set: function(name, value) {
                        return new Promise(function(resolve, reject) {
                            craftNativeSnapshotSet(String(name), encoded(value), function(ok) {
                                if (ok) resolve();
                                else reject(new Error('craft.snapshots.set could not write ' + name));
                            });
                        });
                    },
                    // Every snapshot but the names in `keep` (a sign-out).
                    clear: function(keep) {
                        var names = Array.isArray(keep) ? keep.map(String) : [];
                        return new Promise(function(resolve, reject) {
                            craftNativeSnapshotClear(names, function(ok) {
                                if (ok) resolve();
                                else reject(new Error('craft.snapshots.clear could not remove every snapshot'));
                            });
                        });
                    }
                });
                keep('secureStorage', {
                    getSync: function(key) {
                        var value = craftNativeSecureGet(String(key));
                        return value === undefined ? null : value;
                    }
                });
                keep('navigation', {
                    setOptions: function(options) { craftNativeSetOptions(JSON.stringify(options || {})); }
                });
            })();
        """)
    }

    private func loadBundle() {
        guard let url = Bundle.main.url(forResource: "native-screen", withExtension: "js", subdirectory: "dist")
            ?? Bundle.main.url(forResource: "native-screen", withExtension: "js"),
            let script = try? String(contentsOf: url, encoding: .utf8) else {
            showError("Missing dist/native-screen.js. Compile a .stx screen with `stx native compile` first.")
            return
        }
        jsContext.evaluateScript(script)
        // A bundle that names no route leaves `__stxNativeRoute` undefined;
        // its title is the app's, not the word "undefined". A title the
        // script set with `navigation.setOptions` wins over both.
        if routeName == nil, !titleFromOptions,
           let selected = jsContext.objectForKeyedSubscript("__stxNativeRoute"), selected.isString,
           let name = selected.toString(), !name.isEmpty {
            navigationItem.title = name
        }
    }

    // MARK: Navigation bar options

    private var titleFromOptions = false
    private var rootTopToSafeArea: NSLayoutConstraint?
    private var rootTopToView: NSLayoutConstraint?
    private var rootBottomToSafeArea: NSLayoutConstraint?
    private var rootBottomToView: NSLayoutConstraint?
    private var rootLeadingToSafeArea: NSLayoutConstraint?
    private var rootLeadingToView: NSLayoutConstraint?
    private var rootTrailingToSafeArea: NSLayoutConstraint?
    private var rootTrailingToView: NSLayoutConstraint?
    private var rootIsSafeAreaView = false
    private var navigationBarHidden: Bool?
    /// A native `<StatusBar>` node overrides the app default for this screen.
    private var statusBarStyleOverride: UIStatusBarStyle?
    private var statusBarHiddenOverride: Bool?
    /// The app's tab bar away while this screen shows (`tabBarHidden`).
    private var tabBarHidden = false
    /// Whether a back-swipe may leave this screen at all, the edge's
    /// included (`swipeBack: false`): a screen that steps through its own
    /// pages with a Back of its own (a first-run tour's questions) would
    /// otherwise lose its place to a stray swipe.
    private(set) var swipeBack = true
    /// Whether iOS 26's content-wide back-swipe may begin on this screen.
    /// Setting `contentSwipeBack: false` leaves the 32-point edge gesture.
    private(set) var contentSwipeBack = true
    /// Whether the shell's horizontal tab switch gesture may begin here.
    /// This is separate so a screen can keep navigation back while owning its
    /// own horizontal pager or chart gesture.
    private(set) var tabSwipeEnabled = true
    private var prefersLargeTitle: Bool?
    /// The screen's own colour (`backgroundColor`), under the status bar and
    /// the home indicator too, where its content never reaches: a black
    /// full-screen timer is black edge to edge. nil is the app's.
    private var screenBackgroundColor: UIColor?

    override var preferredStatusBarStyle: UIStatusBarStyle {
        statusBarStyleOverride ?? .default
    }

    override var prefersStatusBarHidden: Bool {
        statusBarHiddenOverride ?? false
    }

    /// Whether this screen asked for a bar of its own through `setOptions`: a
    /// title, a large title or buttons, and not `hidden`. A tab's root screen
    /// in a hybrid app is shown bare unless it did.
    var wantsNavigationBar: Bool {
        if let navigationBarHidden { return !navigationBarHidden }
        return titleFromOptions || prefersLargeTitle == true || !(navigationItem.rightBarButtonItems ?? []).isEmpty
    }
    private weak var trackedScrollView: UIScrollView?

    /// `craft.navigation.setOptions`: this screen's bar. Every key is
    /// optional and only the keys given change.
    private func applyNavigationOptions(_ options: [String: Any]) {
        // The app script has no screen, so no bar and no tab bar to change.
        guard !isAppScript else { return }
        if options.keys.contains("title") {
            navigationItem.title = options["title"] as? String
            titleFromOptions = true
        }
        if options.keys.contains("backTitle") {
            navigationItem.backButtonTitle = options["backTitle"] as? String
        }
        if let largeTitle = options["largeTitle"] as? Bool {
            prefersLargeTitle = largeTitle
            navigationItem.largeTitleDisplayMode = largeTitle ? .always : .never
            if largeTitle { navigationController?.navigationBar.prefersLargeTitles = true }
            trackContentScrollView()
        }
        if let hidden = options["tabBarHidden"] as? Bool {
            tabBarHidden = hidden
            if navigationController?.topViewController === self, view.window != nil {
                CraftChrome.shared.setHiddenByScreen(hidden)
            }
        }
        if let swipeBack = options["swipeBack"] as? Bool {
            self.swipeBack = swipeBack
        }
        if let contentSwipeBack = options["contentSwipeBack"] as? Bool {
            self.contentSwipeBack = contentSwipeBack
        }
        if let tabSwipeEnabled = options["tabSwipeEnabled"] as? Bool {
            self.tabSwipeEnabled = tabSwipeEnabled
        }
        if options.keys.contains("backgroundColor") {
            screenBackgroundColor = color(options["backgroundColor"])
            view.backgroundColor = screenBackgroundColor ?? config.resolvedBackgroundColor
        }
        if let hidden = options["hidden"] as? Bool {
            navigationBarHidden = hidden
            if navigationController?.topViewController === self {
                navigationController?.setNavigationBarHidden(hidden, animated: view.window != nil)
            }
        }
        if options.keys.contains("rightButtons") {
            let buttons = (options["rightButtons"] as? [[String: Any]]) ?? []
            navigationItem.rightBarButtonItems = buttons.compactMap(navigationButton).reversed()
        }
        // Asked for after the bar was hidden for a bare root screen.
        if navigationBarHidden == nil, wantsNavigationBar, navigationController?.topViewController === self,
           navigationController?.isNavigationBarHidden == true {
            navigationController?.setNavigationBarHidden(false, animated: view.window != nil)
        }
    }

    private func applyStatusBar(_ props: [String: Any]) {
        let style: UIStatusBarStyle?
        switch (props["barStyle"] as? String)?.lowercased() {
        case "light-content", "light": style = .lightContent
        case "dark-content", "dark": style = .darkContent
        case "default": style = .default
        default: style = nil
        }
        let hidden = props["hidden"] as? Bool
        if statusBarStyleOverride != style || statusBarHiddenOverride != hidden {
            statusBarStyleOverride = style
            statusBarHiddenOverride = hidden
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    /// A bar button from `{ id, symbol | title }`. Its tap is the event
    /// `navButton` with `{ id }`.
    private func navigationButton(_ spec: [String: Any]) -> UIBarButtonItem? {
        guard let id = spec["id"] as? String, !id.isEmpty else { return nil }
        let action = UIAction { [weak self] _ in
            self?.send(type: "EVENT", payload: ["handlerName": "navButton", "nativeEvent": ["id": id]])
        }
        if spec["variant"] as? String == "accent" || spec["variant"] as? String == "account" {
            return accountNavigationButton(spec, action: action)
        }
        let item: UIBarButtonItem
        if let symbol = spec["symbol"] as? String, let image = UIImage(systemName: symbol) {
            item = UIBarButtonItem(image: image, primaryAction: action)
        } else if let title = spec["title"] as? String {
            item = UIBarButtonItem(title: title, primaryAction: action)
        } else {
            return nil
        }
        item.accessibilityIdentifier = "nav-\(id)"
        if let label = (spec["accessibilityLabel"] as? String) ?? (spec["title"] as? String) {
            item.accessibilityLabel = label
        } else {
            item.accessibilityLabel = id
        }
        if let tint = (spec["color"] as? String).flatMap({ UIColor(hex: $0) }) { item.tintColor = tint }
        // `image`: a picture (an https URL, the account's own photo), drawn
        // round as iOS draws an account button. The symbol or title shows
        // until it has loaded, and stays if it cannot be.
        if let source = spec["image"] as? String, let url = URL(string: source), url.scheme == "https" {
            loadBarImage(url) { [weak item] image in
                guard let item, let image else { return }
                let size = CGSize(width: 32, height: 32)
                let round = UIGraphicsImageRenderer(size: size).image { _ in
                    UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).addClip()
                    let scale = max(size.width / image.size.width, size.height / image.size.height)
                    let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    image.draw(in: CGRect(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2, width: drawn.width, height: drawn.height))
                }
                item.title = nil
                item.image = round.withRenderingMode(.alwaysOriginal)
            }
        }
        return item
    }

    /// Shared account/chat controls: the same 44-point target, independent
    /// circular surface and unread indicator on every native screen.
    private func accountNavigationButton(_ spec: [String: Any], action: UIAction) -> UIBarButtonItem {
        let button = UIButton(type: .custom)
        button.addAction(action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([button.widthAnchor.constraint(equalToConstant: 44), button.heightAnchor.constraint(equalToConstant: 44)])
        // Floating, as the tab bar floats: a round piece of glass on iOS 26
        // (the bar's own material), the thin material with the tab bar's
        // hairline and shadow before it. The content scrolls on under it, and
        // it follows light, dark and Increase Contrast by itself.
        let surface = Self.floatingSurface(diameter: 44)
        button.addSubview(surface)
        // Pinned to the button rather than resized with it: the button starts
        // at zero size, so a 44-point surface that grew with its superview
        // came out 88 points, a rounded card twice the button's size that
        // spilled off the bar's edge and covered its neighbour.
        NSLayoutConstraint.activate([
            surface.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            surface.topAnchor.constraint(equalTo: button.topAnchor),
            surface.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])
        // Glass lifts itself off the content; the material needs the tab
        // bar's shadow to.
        if surface.effect is UIBlurEffect {
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOpacity = 0.12
            button.layer.shadowRadius = 8
            button.layer.shadowOffset = CGSize(width: 0, height: 3)
            button.layer.shadowPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 44, height: 44)).cgPath
        }
        button.tintColor = .systemBlue
        button.setTitleColor(button.tintColor, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        if let title = spec["title"] as? String, !title.isEmpty { button.setTitle(title, for: .normal) }
        else if let symbol = spec["symbol"] as? String { button.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)), for: .normal) }
        button.accessibilityIdentifier = spec["id"] as? String
        button.accessibilityLabel = spec["accessibilityLabel"] as? String
        if let value = spec["badge"] as? NSNumber, value.intValue > 0 {
            let dot = spec["badgeStyle"] as? String == "dot"
            let size: CGFloat = dot ? 9 : 18
            // The fill is a tinted symbol, not a background colour: on iOS 26
            // a bar item's custom view keeps its tint but drew a plain
            // backgroundColor white, so the red unread dot came out white
            // (invisible in light mode) and the count lost its blue.
            let fill = UIImageView(image: UIImage(systemName: "circle.fill"))
            fill.tintColor = dot ? .systemRed : .systemBlue
            fill.contentMode = .scaleToFill
            fill.frame = CGRect(x: 44 - size, y: 0, width: size, height: size)
            fill.isAccessibilityElement = false
            button.addSubview(fill)
            if !dot {
                let count = UILabel(frame: fill.frame)
                count.text = value.intValue > 99 ? "99+" : String(value.intValue)
                count.font = .systemFont(ofSize: 10, weight: .bold)
                count.textColor = .white
                count.textAlignment = .center
                count.adjustsFontSizeToFitWidth = true
                count.isAccessibilityElement = false
                button.addSubview(count)
            }
            button.accessibilityValue = "\(value.intValue) unread"
        }
        if let source = spec["image"] as? String, let url = URL(string: source), url.scheme == "https" {
            loadBarImage(url) { [weak button] image in
                guard let button, let image else { return }
                let size = CGSize(width: 36, height: 36)
                let round = UIGraphicsImageRenderer(size: size).image { _ in
                    UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).addClip()
                    let scale = max(size.width / image.size.width, size.height / image.size.height)
                    let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    image.draw(in: CGRect(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2, width: drawn.width, height: drawn.height))
                }
                button.setTitle(nil, for: .normal)
                button.setImage(round.withRenderingMode(.alwaysOriginal), for: .normal)
                if let surface = button.subviews.first(where: { $0 is UIVisualEffectView }) { button.sendSubviewToBack(surface) }
            }
        }
        // Under the symbol, the initials, the picture and the badge.
        if let surface = button.subviews.first(where: { $0 is UIVisualEffectView }) { button.sendSubviewToBack(surface) }
        let item = UIBarButtonItem(customView: button)
        // iOS 26 groups adjacent bar items on one glass platter and tints
        // their custom views with it: the two 44-point circles came out as
        // solid accent ovals inside a capsule, unlike the web screens' bar.
        // The button draws its own surface, so it opts out of the platter.
        // Guarded by compiler too, for the older SDKs in the release matrix.
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) { item.hidesSharedBackground = true; item.sharesBackground = false }
        #endif
        return item
    }

    /// The round surface under a bar button: glass on iOS 26, the tab bar's
    /// thin material and hairline before it. It takes no touches.
    private static func floatingSurface(diameter: CGFloat) -> UIVisualEffectView {
        let effect: UIVisualEffect
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) { effect = UIGlassEffect() } else { effect = UIBlurEffect(style: .systemUltraThinMaterial) }
        #else
        effect = UIBlurEffect(style: .systemUltraThinMaterial)
        #endif
        let surface = UIVisualEffectView(effect: effect)
        // The caller pins it to its button; it is exactly `diameter` across.
        surface.translatesAutoresizingMaskIntoConstraints = false
        surface.isUserInteractionEnabled = false
        surface.layer.cornerRadius = diameter / 2
        surface.layer.cornerCurve = .circular
        surface.clipsToBounds = true
        if effect is UIBlurEffect {
            surface.layer.borderWidth = 0.5
            surface.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        }
        return surface
    }

    /// A bar picture, kept for the app's life so each screen does not fetch it again.
    private static let barImages = NSCache<NSURL, UIImage>()

    private func loadBarImage(_ url: URL, _ done: @escaping (UIImage?) -> Void) {
        if let cached = Self.barImages.object(forKey: url as NSURL) { done(cached); return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            let image = data.flatMap(UIImage.init(data:))
            if let image { Self.barImages.setObject(image, forKey: url as NSURL) }
            DispatchQueue.main.async { done(image) }
        }.resume()
    }

    /// The first vertical scroll view of the screen drives the bar: a large
    /// title collapses as it scrolls, and the bar's background follows it.
    private func trackContentScrollView() {
        guard let renderedRoot else { return }
        func find(_ node: RenderedNode) -> UIScrollView? {
            if let scroll = node.view as? CraftNativeScrollView, scroll.isVertical, scroll.isScrollEnabled { return scroll }
            if let list = node.view as? CraftNativeFlatList, list.isScrollEnabled,
               (list.collectionViewLayout as? UICollectionViewFlowLayout)?.scrollDirection != .horizontal { return list }
            for child in node.children {
                if let match = find(child) { return match }
            }
            return nil
        }
        /// The scroll view the screen starts with, when nothing sits above it:
        /// the root's first child, its first, and so on, none padded on top.
        func leading(_ node: RenderedNode) -> UIScrollView? {
            if let scroll = node.view as? CraftNativeScrollView { return scroll.isVertical && scroll.isScrollEnabled ? scroll : nil }
            if let list = node.view as? CraftNativeFlatList {
                return list.isScrollEnabled && (list.collectionViewLayout as? UICollectionViewFlowLayout)?.scrollDirection != .horizontal ? list : nil
            }
            guard paddingInsets(node.style).top == 0,
                  let first = node.children.first(where: { $0.type != "Modal" && !$0.view.isHidden }) else { return nil }
            return leading(first)
        }
        let scroll = find(renderedRoot)
        // Under a large title the screen runs edge to edge, as UIKit's own
        // screens do: the scroll view starts under the bar and insets its
        // content by it, so the title collapses and pull to refresh draws
        // in the bar's space. So does a screen that starts with its scroll
        // view: its content scrolls up under the bar behind iOS's scroll edge
        // effect, rather than over the bar's back button. Other screens stay
        // inside the safe area.
        let edgeToEdge = scroll != nil && (prefersLargeTitle == true || scroll === leading(renderedRoot))
        let fullEdgeToEdge = rootIsSafeAreaView
        let topEdgeToEdge = fullEdgeToEdge || edgeToEdge
        rootTopToSafeArea?.isActive = !topEdgeToEdge
        rootTopToView?.isActive = topEdgeToEdge
        rootBottomToSafeArea?.isActive = !fullEdgeToEdge
        rootBottomToView?.isActive = fullEdgeToEdge
        rootLeadingToSafeArea?.isActive = !fullEdgeToEdge
        rootLeadingToView?.isActive = fullEdgeToEdge
        rootTrailingToSafeArea?.isActive = !fullEdgeToEdge
        rootTrailingToView?.isActive = fullEdgeToEdge
        scroll?.contentInsetAdjustmentBehavior = edgeToEdge ? .automatic : .never
        guard scroll !== trackedScrollView else { return }
        trackedScrollView = scroll
        setContentScrollView(scroll, for: .top)
    }

    private func observeNativeEvents() {
        func observe(_ name: Notification.Name, state: String) {
            lifecycleObservers.append(NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in self?.sendAppState(state) })
        }
        observe(UIApplication.didBecomeActiveNotification, state: "active")
        observe(UIApplication.willResignActiveNotification, state: "inactive")
        observe(UIApplication.didEnterBackgroundNotification, state: "background")
        for name in [UIContentSizeCategory.didChangeNotification, UIAccessibility.reduceMotionStatusDidChangeNotification, UIAccessibility.reduceTransparencyStatusDidChangeNotification, .craftColorSchemeChanged] {
            lifecycleObservers.append(NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshTraitDefaults()
                self?.sendAppearance()
            })
        }
        // The app script has no screen for the keyboard to cover.
        if !isAppScript {
            lifecycleObservers.append(NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.applyKeyboardSafeArea(notification)
            })
            lifecycleObservers.append(NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.applyKeyboardSafeArea(notification, hidden: true)
            })
        }
        lifecycleObservers.append(NotificationCenter.default.addObserver(
            forName: CraftSnapshots.changed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let name = notification.userInfo?["name"] as? String else { return }
            self?.send(type: "SNAPSHOT_CHANGED", payload: ["name": name])
        })
        if config.enablePushNotifications {
            // A new device token (iOS hands one out after a reinstall or a
            // restore): every screen's `craft.push.onToken` hears it.
            lifecycleObservers.append(NotificationCenter.default.addObserver(
                forName: .craftPushToken,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let token = notification.object as? String else { return }
                self?.send(type: "PUSH_TOKEN", payload: ["token": token])
            })
        }
        // The coordinator's location events (a watch, a recording's fixes):
        // to this screen's script as the page's own CustomEvents.
        lifecycleObservers.append(NotificationCenter.default.addObserver(
            forName: CraftWebServices.event,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let name = notification.userInfo?["event"] as? String else { return }
            self?.send(type: "CRAFT_EVENT", payload: ["event": name, "detail": notification.userInfo?["detail"] ?? [:]])
        })
        sounds.emit = { [weak self] payload in self?.send(type: "SOUND_EVENT", payload: payload) }
        streams.emit = { [weak self] payload in self?.send(type: "NETWORK_STREAM", payload: payload) }
        sendAppState(CraftNativeActions.currentAppState())
        // Links are the screens' to show; the app script hears none.
        guard !isAppScript else { return }
        deepLinkListener = DeepLinkManager.shared.addNativeListener { [weak self] url, initial in
            guard let self = self, self.navigationController?.topViewController === self else { return }
            var payload = CraftNativeActions.deepLinkData(url)
            payload["initial"] = initial
            self.send(type: "DEEP_LINK", payload: payload)
        }
    }

    private func applyKeyboardSafeArea(_ notification: Notification, hidden: Bool = false) {
        let inset: CGFloat
        let keyboardFrame: CGRect?
        if hidden {
            inset = 0
            keyboardFrame = nil
        } else if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            keyboardFrame = frame.cgRectValue
            let local = view.convert(frame.cgRectValue, from: nil)
            // The safe area without the keyboard's own share, which an earlier
            // change of the keyboard's height added to it.
            inset = max(0, view.bounds.intersection(local).height - (view.safeAreaInsets.bottom - additionalSafeAreaInsets.bottom))
        } else {
            return
        }
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
        let curve = (notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? 7
        let globalInset = containsKeyboardAvoidingView() ? 0 : inset
        let safeAreaChanged = abs(additionalSafeAreaInsets.bottom - globalInset) > 0.5
        keyboardSafeAreaInset = inset
        keyboardScreenFrame = keyboardFrame
        updateKeyboardAvoidingViews()
        UIView.animate(withDuration: duration, delay: 0, options: UIView.AnimationOptions(rawValue: UInt(curve << 16))) {
            if safeAreaChanged {
                self.additionalSafeAreaInsets.bottom = globalInset
                self.view.layoutIfNeeded()
            }
            self.insetScrollViewsForKeyboard()
            self.scrollFocusedInputIntoView(animated: false)
        }
    }

    private func updateKeyboardAvoidingViews() {
        func visit(_ node: RenderedNode?) {
            guard let node else { return }
            if let keyboard = node.view as? CraftNativeKeyboardAvoidingView {
                keyboard.setKeyboardInset(keyboardSafeAreaInset)
            }
            node.children.forEach(visit)
        }
        visit(renderedRoot)
    }

    private func containsKeyboardAvoidingView() -> Bool {
        func visit(_ node: RenderedNode?) -> Bool {
            guard let node else { return false }
            if node.view is CraftNativeKeyboardAvoidingView { return true }
            return node.children.contains(where: visit)
        }
        return visit(renderedRoot)
    }

    private func syncGlobalKeyboardSafeArea() {
        let globalInset = containsKeyboardAvoidingView() ? 0 : keyboardSafeAreaInset
        guard abs(additionalSafeAreaInsets.bottom - globalInset) > 0.5 else { return }
        additionalSafeAreaInsets.bottom = globalInset
        view.setNeedsLayout()
    }

    /// A scroll view the keyboard still covers part of (one that does not end
    /// at the screen's bottom edge, or a keyboard taller than the safe area
    /// took account of) insets its content by that much, so everything in it
    /// can be scrolled above the keyboard. Internal for XCTest.
    func insetScrollViewsForKeyboard() {
        var scrolls: [UIScrollView] = []
        func collect(_ node: RenderedNode?) {
            guard let node else { return }
            if let scroll = node.view as? CraftNativeScrollView, scroll.isVertical { scrolls.append(scroll) }
            node.children.forEach(collect)
        }
        collect(renderedRoot)
        for scroll in scrolls {
            var overlap: CGFloat = 0
            if let keyboard = keyboardScreenFrame, let window = scroll.window {
                let frame = scroll.convert(scroll.bounds, to: window)
                overlap = max(0, frame.maxY - window.convert(keyboard, from: nil).minY)
            }
            if abs(scroll.contentInset.bottom - overlap) > 0.5 { scroll.contentInset.bottom = overlap }
            if abs(scroll.verticalScrollIndicatorInsets.bottom - overlap) > 0.5 { scroll.verticalScrollIndicatorInsets.bottom = overlap }
        }
    }

    /// The focused field, scrolled into the part of its scroll view the
    /// keyboard leaves, with a little room around it.
    func scrollFocusedInputIntoView(animated: Bool) {
        guard let input = firstResponder(in: rootStack) else { return }
        scrollIntoView(input, animated: animated)
    }

    /// `input`, scrolled into the visible part of the scroll view it is in.
    /// Internal for XCTest.
    func scrollIntoView(_ input: UIView, animated: Bool) {
        var ancestor = input.superview
        while let current = ancestor, !(current is CraftNativeScrollView) { ancestor = current.superview }
        guard let scroll = ancestor as? CraftNativeScrollView, scroll.isVertical else { return }
        let rect = input.convert(input.bounds, to: scroll).insetBy(dx: 0, dy: -16)
        scroll.scrollRectToVisible(rect, animated: animated)
    }

    private func sendAppState(_ state: String) {
        // A screen hears it while it is on top of its stack; the app script,
        // which is on no stack, always.
        guard isAppScript || navigationController?.topViewController === self else { return }
        send(type: "APP_STATE", payload: ["state": state])
    }

    private func showError(_ message: String) {
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = .systemRed
        label.textAlignment = .center
        label.text = message
        rootStack.addArrangedSubview(label)
        rootStack.setLayoutStyle(["alignSelf": "stretch"], for: label)
        NSLog("[craft native] %@", message)
        hybridFailed(message)
    }

    /// Only before the first frame: later exceptions belong to a screen that
    /// is up, and are logged.
    private func hybridFailed(_ message: String) {
        guard !hybridRendered else { return }
        // The app script draws nothing for anything to stand in for: logged
        // (by the caller) and left to run on.
        guard !isAppScript else { return }
        hybridEvents?.nativeScreen(self, didFail: message)
    }

    private func receive(_ raw: String) {
        guard let data = raw.data(using: .utf8),
              let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = message["type"] as? String else { return }
        let payload = message["payload"] as? [String: Any] ?? [:]

        switch type {
        case "RENDER":
            guard let document = payload["document"] as? [String: Any] else { return }
            render(document)
        case "MUTATE":
            do {
                let result = try applyMutation(payload)
                send(type: "MUTATION_ACK", payload: [
                    "batchId": result.batchId,
                    "revision": result.revision,
                    "version": craftNativeMutationProtocolVersion,
                ])
            } catch let failure as CraftNativeMutationFailure {
                var error: [String: Any] = [
                    "batchId": payload["batchId"] as? String ?? "",
                    "code": failure.code,
                    "message": failure.message,
                    "version": craftNativeMutationProtocolVersion,
                ]
                if let operationIndex = failure.operationIndex { error["operationIndex"] = operationIndex }
                // In the log as well: the screen redraws itself on this, so
                // nothing on screen says a batch was refused.
                CraftNativeConsole.write("error", category: screenName(), message: "mutation \(error["batchId"] ?? "") refused: \(failure.code) \(failure.message)")
                send(type: "MUTATION_ERROR", payload: error)
            } catch {
                send(type: "MUTATION_ERROR", payload: [
                    "batchId": payload["batchId"] as? String ?? "",
                    "code": "INVALID_BATCH",
                    "message": "mutation batch could not be applied",
                    "version": craftNativeMutationProtocolVersion,
                ])
            }
        case "NAVIGATE", "NAVIGATE_REPLACE":
            // A screen's own stack; the app script has none (it opens paths).
            guard !isAppScript, navigationController?.topViewController === self,
                  let screen = payload["screen"] as? String, !screen.isEmpty,
                  let navigation = navigationController else { return }
            let params = payload["params"] as? [String: Any] ?? [:]
            let next = CraftNativeScreenController(config: config, routeName: screen, routeParams: params)
            next.hybridEvents = hybridEvents
            if type == "NAVIGATE" {
                navigation.pushViewController(next, animated: true)
            } else {
                disposeRuntime()
                navigation.setViewControllers(Array(navigation.viewControllers.dropLast()) + [next], animated: true)
            }
        case "NAVIGATION_SET_OPTIONS":
            applyNavigationOptions(payload)
        case "NAVIGATE_OPEN":
            // A path rather than a screen: the hybrid shell opens it, natively
            // or in the web view.
            guard let path = payload["path"] as? String, !path.isEmpty else { return }
            hybridEvents?.nativeScreen(self, open: path)
        case "NAVIGATE_BACK":
            if !isAppScript, navigationController?.topViewController === self {
                navigationController?.popViewController(animated: true)
            }
        case "NAVIGATE_POP_TO_ROOT":
            // Back to the first screen of this screen's stack in one move: a
            // finished task (a saved workout) closes the way it was reached.
            if !isAppScript, navigationController?.topViewController === self {
                navigationController?.popToRootViewController(animated: true)
            }
        case "API_REQUEST":
            guard let id = message["id"] as? String else { return }
            let args = payload["args"] as? [Any] ?? []
            let requestToken = "\(capabilityScope)/\(id)"
            pendingCapabilityRequests.insert(requestToken)
            let deadline = DispatchWorkItem { [weak self] in
                guard let self = self, self.pendingCapabilityRequests.remove(requestToken) != nil else { return }
                self.pendingCapabilityDeadlines.removeValue(forKey: requestToken)
                self.screenRequestCancellers.removeValue(forKey: requestToken)?()
                CraftNativeActions.cancel(requestToken: requestToken)
                self.send(type: "API_ERROR", payload: [
                    "version": craftNativeCapabilityProtocolVersion,
                    "requestId": id,
                    "code": "TIMEOUT",
                    "message": "Native API request timed out",
                ], correlationId: id)
            }
            // A request a person answers (a share sheet, a dialog, the photo
            // picker, Face ID) says so (`untimed`, stx's callPersonFacingAPI)
            // and waits for them: a deadline would answer TIMEOUT while the
            // sheet is still up and they are still choosing.
            if payload["untimed"] as? Bool != true {
                pendingCapabilityDeadlines[requestToken] = deadline
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + .milliseconds(craftNativeCapabilityTimeoutMilliseconds),
                    execute: deadline
                )
            }
            let module = payload["module"] as? String ?? ""
            let method = payload["method"] as? String ?? ""
            let reply: (Result<Any, CraftNativeActionError>) -> Void = { [weak self] answer in
                guard let self = self, self.pendingCapabilityRequests.remove(requestToken) != nil else { return }
                self.pendingCapabilityDeadlines.removeValue(forKey: requestToken)?.cancel()
                self.screenRequestCancellers.removeValue(forKey: requestToken)
                switch answer {
                case .success(let data):
                    self.send(type: "API_RESPONSE", payload: [
                        "version": craftNativeCapabilityProtocolVersion,
                        "requestId": id,
                        "data": data,
                    ], correlationId: id)
                case .failure(let error):
                    self.send(type: "API_ERROR", payload: [
                        "version": craftNativeCapabilityProtocolVersion,
                        "requestId": id,
                        "code": error.code,
                        "message": error.message,
                    ], correlationId: id)
                }
            }
            if performOnScreen(module: module, method: method, args: args, requestToken: requestToken, reply: reply) { return }
            CraftNativeActions.perform(
                requestToken: requestToken,
                version: payload["version"] as? Int ?? craftNativeCapabilityProtocolVersion,
                module: module,
                method: method,
                args: args,
                config: config,
                completion: reply
            )
        case "API_CANCEL":
            guard let id = payload["requestId"] as? String else { return }
            let requestToken = "\(capabilityScope)/\(id)"
            pendingCapabilityRequests.remove(requestToken)
            pendingCapabilityDeadlines.removeValue(forKey: requestToken)?.cancel()
            screenRequestCancellers.removeValue(forKey: requestToken)?()
            CraftNativeActions.cancel(requestToken: requestToken)
        default:
            break
        }
    }

    /// The modules whose work belongs to this screen and ends with it:
    /// `craft.audio`'s sounds and streaming `fetch`. False for any other
    /// module, which CraftNativeActions serves.
    private func performOnScreen(
        module: String,
        method: String,
        args: [Any],
        requestToken: String,
        reply: @escaping (Result<Any, CraftNativeActionError>) -> Void
    ) -> Bool {
        func number(_ index: Int, _ key: String? = nil) -> Double {
            guard args.count > index else { return 0 }
            if let key { return ((args[index] as? [String: Any])?[key] as? NSNumber)?.doubleValue ?? 0 }
            return (args[index] as? NSNumber)?.doubleValue ?? 0
        }
        let id = args.first as? String ?? ""
        switch (module, method) {
        case ("Network", "stream"):
            let options = args.first as? [String: Any] ?? [:]
            let streamId = options["id"] as? String ?? ""
            screenRequestCancellers[requestToken] = { [weak self] in self?.streams.cancel(id: streamId) }
            streams.open(id: streamId, options: options, answer: reply)
        case ("Network", "cancelStream"):
            streams.cancel(id: id)
            reply(.success(true))
        case ("Audio", "play"):
            guard args.count > 1, let address = args[1] as? String, let url = URL(string: address), url.scheme != nil, !id.isEmpty else {
                reply(.failure(CraftNativeActionError(code: "INVALID_ARGUMENT", message: "audio.play needs a URL")))
                return true
            }
            screenRequestCancellers[requestToken] = { [weak self] in self?.sounds.stop(id: id, fadeOut: 0) }
            sounds.play(id: id, url: url, options: args.count > 2 ? args[2] as? [String: Any] ?? [:] : [:], answer: reply)
        case ("Audio", "pause"):
            sounds.pause(id: id)
            reply(.success(true))
        case ("Audio", "resume"):
            sounds.resume(id: id)
            reply(.success(true))
        case ("Audio", "setVolume"):
            sounds.setVolume(id: id, volume: number(1), fade: number(2, "fade") / 1000)
            reply(.success(true))
        case ("Audio", "stop"):
            sounds.stop(id: id, fadeOut: number(1, "fadeOut") / 1000)
            reply(.success(true))
        case ("Audio", "stopAll"):
            sounds.stopAll(fadeOut: number(0, "fadeOut") / 1000)
            reply(.success(true))
        default:
            return false
        }
        return true
    }

    /// Runs script in the screen's JavaScript context. Internal for
    /// simulator-hosted XCTest of the host APIs.
    @discardableResult
    func evaluateScript(_ script: String) -> JSValue? {
        jsContext.evaluateScript(script)
    }

    // Internal so simulator-hosted XCTest can assert actual UIView identity.
    func render(_ document: [String: Any]) {
        mutationDocument.replace(with: document)
        renderCommitted(document)
        if !hybridRendered {
            hybridRendered = true
            // The app script's drawing is never on screen: not a first frame.
            if !isAppScript { hybridEvents?.nativeScreenDidRender(self) }
        }
    }

    @discardableResult
    func applyMutation(_ payload: [String: Any]) throws -> CraftNativeMutationResult {
        let result = try mutationDocument.apply(payload)
        if !result.requiresFullRender, applyTargetedUpdates(result.affectedNodeIds) { return result }
        if let document = result.document { renderCommitted(document) } else { clearRenderedTree() }
        return result
    }

    private func applyTargetedUpdates(_ ids: [String]) -> Bool {
        let focused = firstResponder(in: rootStack) ?? lastFocusedInput
        var applied = Set<String>()
        for id in ids {
            guard let target = drawnTarget(id) else { return false }
            guard applied.insert(target).inserted else { continue }
            guard let document = mutationDocument.node(target), let previous = renderedNode(target) else { return false }
            // A node that needs a new view (a TextInput turned multiline) is
            // its parent's to swap in: a targeted update only redraws in
            // place, and the new view was made and never attached.
            guard canReuseView(document, previous: previous) else { return false }
            let next = reconcile(document, identity: previous.identity, path: target, previous: previous)
            // A style patch is applied in place, layout included: the parent
            // reads the node's new layout style on its next pass.
            CraftNativeFlexLayout.invalidateAncestors(of: next.view)
        }
        restoreFocus(focused)
        return true
    }

    /// The drawn node a change to `id` redraws: the list or drawing a row or
    /// shape belongs to, else the node itself. A node this batch created is
    /// not drawn yet (a drawing an `:if` just revealed, its shapes inserted
    /// into it), so its nearest drawn ancestor draws it, rather than the whole
    /// screen being reconciled again for want of it.
    private func drawnTarget(_ id: String) -> String? {
        var current: String? = id
        while let candidate = current {
            let target = flatListOwners[candidate] ?? svgOwners[candidate] ?? candidate
            if renderedNode(target) != nil { return target }
            current = mutationDocument.parentId(of: candidate)
        }
        return nil
    }

    private func renderedNode(_ id: String, below node: RenderedNode? = nil) -> RenderedNode? {
        guard let node = node ?? renderedRoot else { return nil }
        if node.protocolId == id { return node }
        for child in node.children {
            if let match = renderedNode(id, below: child) { return match }
        }
        return nil
    }

    private func renderCommitted(_ document: [String: Any]) {
        let focused = firstResponder(in: rootStack) ?? lastFocusedInput
        statusBarStyleOverride = nil
        statusBarHiddenOverride = nil
        let previous = renderedRoot
        let next = reconcile(document, identity: "root", path: "root", previous: previous)
        if previous?.view !== next.view {
            if let old = previous { detach(old, from: rootStack) }
        }
        // A failed or interrupted reconciliation can leave an older root
        // attached even though `renderedRoot` points at the latest tree. Keep
        // the host single-rooted so accessibility queries and event routing
        // never see stale copies of the native screen.
        for child in rootStack.arrangedSubviews where child !== next.view {
            rootStack.removeArrangedSubview(child)
            child.removeFromSuperview()
        }
        if next.view.superview !== rootStack { rootStack.addArrangedSubview(next.view) }
        // A native screen root fills the safe-area viewport unless the bundle
        // explicitly sizes it. Without this default, an unstyled SafeAreaView
        // measures to its scroll content and leaves no viewport to scroll.
        var rootStyle = next.style
        if rootStyle["flex"] == nil, rootStyle["height"] == nil { rootStyle["flex"] = 1 }
        rootStack.setLayoutStyle(rootStyle, for: next.view)
        rootStack.setViewportChild(next.view, fillsHeight: rootStyle["height"] == nil)
        rootStack.invalidateMeasurements()
        renderedRoot = next
        rootIsSafeAreaView = next.type == "SafeAreaView"
        updateKeyboardAvoidingViews()
        syncGlobalKeyboardSafeArea()
        trackContentScrollView()
        setNeedsStatusBarAppearanceUpdate()
        restoreFocus(focused)
    }

    private func clearRenderedTree() {
        if let root = renderedRoot { detach(root, from: rootStack) }
        renderedRoot = nil
        rootIsSafeAreaView = false
        rootStack.setViewportChild(nil, fillsHeight: false)
        rootTopToSafeArea?.isActive = true
        rootTopToView?.isActive = false
        rootBottomToSafeArea?.isActive = true
        rootBottomToView?.isActive = false
        rootLeadingToSafeArea?.isActive = true
        rootLeadingToView?.isActive = false
        rootTrailingToSafeArea?.isActive = true
        rootTrailingToView?.isActive = false
        statusBarStyleOverride = nil
        statusBarHiddenOverride = nil
        setNeedsStatusBarAppearanceUpdate()
        syncGlobalKeyboardSafeArea()
    }

    private func firstResponder(in view: UIView) -> UIView? {
        if view.isFirstResponder { return view }
        for child in view.subviews {
            if let responder = firstResponder(in: child) { return responder }
        }
        return nil
    }

    /// Whether `previous`'s view can draw `node`: the same type, and for a
    /// TextInput the same kind of field (multiline is a UITextView).
    private func canReuseView(_ node: [String: Any], previous: RenderedNode) -> Bool {
        let type = canonicalType(node["type"] as? String ?? "View")
        guard previous.type == type else { return false }
        guard type == "TextInput" else { return true }
        let props = node["props"] as? [String: Any] ?? [:]
        return (previous.view is UITextView) == (props["multiline"] as? Bool == true)
    }

    private func restoreFocus(_ focused: UIView?) {
        guard let focused, focused.window != nil, !focused.isFirstResponder else { return }
        _ = focused.becomeFirstResponder()
    }

    private func reconcile(_ node: [String: Any], identity: String, path: String, previous: RenderedNode?) -> RenderedNode {
        let type = canonicalType(node["type"] as? String ?? "View")
        let props = node["props"] as? [String: Any] ?? [:]
        let style = node["style"] as? [String: Any] ?? [:]
        let events = node["events"] as? [String: String] ?? [:]
        let children = node["children"] as? [Any] ?? []
        let current: RenderedNode
        if let previous = previous, previous.identity == identity, canReuseView(node, previous: previous) {
            current = previous
        } else {
            current = RenderedNode(identity: identity, type: type, view: makeView(type, props: props))
        }

        let result = current.view
        current.protocolId = node["id"] as? String
        current.style = style
        let linkTarget = ["href", "to"].lazy.compactMap { props[$0] as? String }
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if ["Link", "TouchableOpacity", "TouchableHighlight", "Pressable"].contains(type),
           props["disabled"] as? Bool != true, let linkTarget {
            linkTargets[ObjectIdentifier(result)] = linkTarget
        } else {
            linkTargets.removeValue(forKey: ObjectIdentifier(result))
        }
        result.accessibilityIdentifier = accessibilityIdentifier(node, props: props) ?? path
        if type != "View" && type != "SafeAreaView" && type != "KeyboardAvoidingView" && type != "ScrollView" && type != "SectionList" && type != "FlatList" && type != "Modal" {
            result.setContentHuggingPriority(.required, for: .vertical)
        }
        applyViewStyle(style, to: result, node: current)
        if type == "SafeAreaView", let safeArea = result as? CraftNativeSafeAreaView {
            safeArea.setSafeAreaEdges(props["edges"])
        }
        updateLayoutHandler(events["onLayout"], for: result)
        if type == "StatusBar" { applyStatusBar(props) }

        switch type {
        case "StatusBar", "RefreshControl":
            // StatusBar is a screen trait, and RefreshControl is consumed by
            // its nearest ScrollView. Neither contributes a visible child.
            result.isHidden = true
            result.isUserInteractionEnabled = false
        case "Text":
            let label = result as! UILabel
            label.numberOfLines = max(0, (props["numberOfLines"] as? NSNumber)?.intValue ?? 0)
            label.lineBreakMode = textLineBreakMode(props["ellipsizeMode"])
            (label as? CraftNativeLabel)?.insets = paddingInsets(style)
            configureText(label, text: children.compactMap { $0 as? String }.joined(), style: style)
        case "Button", "Link":
            let button = result as! UIButton
            let title = props["title"] as? String ?? children.compactMap { $0 as? String }.joined()
            let transformedTitle = transformedText(title, style: style)
            let titleColor = color(props["color"]) ?? color(style["color"]) ?? .systemBlue
            let font = textFont(
                style,
                default: .systemFont(ofSize: 16)
            )
            // The plain title too, so `title(for:)` and accessibility read it.
            if button.title(for: .normal) != transformedTitle { button.setTitle(transformedTitle, for: .normal) }
            button.setAttributedTitle(NSAttributedString(
                string: transformedTitle,
                attributes: buttonTitleAttributes(style, color: titleColor, font: font, forceUnderline: type == "Link")
            ), for: .normal)
            button.contentHorizontalAlignment = buttonAlignment(style["textAlign"])
            (button as? CraftNativeButton)?.padding = paddingInsets(style)
            button.isEnabled = props["disabled"] as? Bool != true
            updateHandler(nonEmptyHandler(events["onPress"]) ?? nonEmptyHandler(events["onClick"]), for: button)
        case "Checkbox":
            let checkbox = result as! CraftNativeCheckboxButton
            let label = props["label"] as? String ?? children.compactMap { $0 as? String }.joined()
            let transformedLabel = transformedText(label, style: style)
            let checked = (props["checked"] as? Bool) ?? (props["value"] as? Bool) ?? false
            let indeterminate = props["indeterminate"] as? Bool == true
            checkbox.isSelected = checked
            checkbox.indeterminate = indeterminate
            checkboxIndeterminate[ObjectIdentifier(checkbox)] = indeterminate
            checkbox.setTitle(transformedLabel, for: .normal)
            checkbox.setAttributedTitle(NSAttributedString(
                string: transformedLabel,
                attributes: buttonTitleAttributes(style, color: color(props["color"]) ?? color(style["color"]) ?? .label, font: textFont(style, default: .systemFont(ofSize: 16)), forceUnderline: false)
            ), for: .normal)
            let uncheckedImage = UIImage(systemName: indeterminate ? "minus.square" : "square")
            checkbox.setImage(uncheckedImage, for: .normal)
            checkbox.setImage(
                UIImage(systemName: indeterminate ? "minus.square" : "checkmark.square.fill"),
                for: .selected
            )
            checkbox.tintColor = color(props["color"]) ?? color(style["color"]) ?? .systemBlue
            checkbox.isEnabled = props["disabled"] as? Bool != true
            updateHandler(nonEmptyHandler(events["onValueChange"]) ?? nonEmptyHandler(events["onChange"]), for: checkbox)
        case "TextInput":
            if let textView = result as? UITextView {
                inputIdentities[ObjectIdentifier(textView)] = current.identity
                configureTextView(
                    textView,
                    props: props,
                    style: style,
                    events: events,
                    defaultValue: previous?.view === textView
                        ? nil
                        : inputDrafts[current.identity] ?? props["defaultValue"] as? String
                )
                break
            }
            let field = result as! UITextField
            field.placeholder = props["placeholder"] as? String
            if let placeholder = field.placeholder,
               let placeholderColor = color(props["placeholderTextColor"]) {
                field.attributedPlaceholder = NSAttributedString(
                    string: placeholder,
                    attributes: [.foregroundColor: placeholderColor]
                )
            } else {
                field.attributedPlaceholder = nil
            }
            field.tintColor = color(props["selectionColor"])
            let fieldId = ObjectIdentifier(field)
            inputIdentities[fieldId] = current.identity
            if let maxLength = (props["maxLength"] as? NSNumber)?.intValue, maxLength > 0 {
                textMaxLengths[fieldId] = maxLength
            } else {
                textMaxLengths.removeValue(forKey: fieldId)
            }
            field.delegate = self
            (field as? CraftNativeTextField)?.padding = paddingInsets(style)
            field.textColor = color(style["color"]) ?? .label
            field.font = textFont(style, default: .systemFont(ofSize: 16))
            field.textAlignment = textAlignment(style["textAlign"])
            field.defaultTextAttributes = inputTextAttributes(style, font: field.font ?? .systemFont(ofSize: 16), alignment: field.textAlignment)
            let desiredKeyboardType = keyboardType(props["keyboardType"])
            if field.keyboardType != desiredKeyboardType { field.keyboardType = desiredKeyboardType }
            let desiredReturnKeyType = returnKeyType(props["returnKeyType"])
            if field.returnKeyType != desiredReturnKeyType { field.returnKeyType = desiredReturnKeyType }
            let desiredAutocorrection: UITextAutocorrectionType = props["autoCorrect"] as? Bool == false ? .no : .default
            if field.autocorrectionType != desiredAutocorrection { field.autocorrectionType = desiredAutocorrection }
            // Secure entry first: turning it on resets the capitalization.
            let desiredSecureEntry = props["secureTextEntry"] as? Bool == true
            if field.isSecureTextEntry != desiredSecureEntry { field.isSecureTextEntry = desiredSecureEntry }
            let desiredCapitalization = capitalizationType(props["autoCapitalize"])
            if field.autocapitalizationType != desiredCapitalization { field.autocapitalizationType = desiredCapitalization }
            let desiredEnabled = props["editable"] as? Bool != false
            if field.isEnabled != desiredEnabled { field.isEnabled = desiredEnabled }
            applyAutofill(to: field, props: props)
            if let value = props["value"] as? String {
                updateField(field, value: value)
            } else if previous?.view !== field {
                updateField(field, value: inputDrafts[current.identity] ?? props["defaultValue"] as? String)
            }
            updateHandler(nonEmptyHandler(events["onChange"]) ?? nonEmptyHandler(events["onChangeText"]), for: field)
            updateAuxiliaryHandler(events["onFocus"], in: &focusHandlers, for: field)
            updateAuxiliaryHandler(events["onBlur"], in: &blurHandlers, for: field)
            updateAuxiliaryHandler(events["onEndEditing"], in: &endEditingHandlers, for: field)
            updateAuxiliaryHandler(events["onSubmitEditing"], in: &submitHandlers, for: field)
            if props["autoFocus"] as? Bool == true, !field.isFirstResponder {
                DispatchQueue.main.async { _ = field.becomeFirstResponder() }
            }
        case "Picker":
            let picker = result as! UIPickerView
            let options = children.compactMap { child -> (value: String, label: String)? in
                guard let node = child as? [String: Any], node["type"] as? String == "Text" else { return nil }
                let optionProps = node["props"] as? [String: Any] ?? [:]
                let label = (node["children"] as? [Any] ?? []).compactMap { $0 as? String }.joined()
                guard !label.isEmpty else { return nil }
                return (value: optionProps["value"] as? String ?? label, label: label)
            }
            let pickerID = ObjectIdentifier(picker)
            pickerOptions[pickerID] = options
            picker.reloadAllComponents()
            if let selected = (props["selectedValue"] as? String) ?? (props["value"] as? String),
               let row = options.firstIndex(where: { $0.value == selected }) {
                picker.selectRow(row, inComponent: 0, animated: false)
            } else if !options.isEmpty {
                picker.selectRow(0, inComponent: 0, animated: false)
            }
            picker.isUserInteractionEnabled = props["disabled"] as? Bool != true
            updateHandler(nonEmptyHandler(events["onValueChange"]) ?? nonEmptyHandler(events["onChange"]), for: picker)
        case "DatePicker":
            let picker = result as! UIDatePicker
            let mode = Self.datePickerMode(props["mode"])
            // A countdown is wheels only: UIKit asserts (and the app aborts)
            // on a countdown in the compact or inline style, so the style is
            // settled before the mode becomes a countdown, and after it
            // stops being one.
            let display: UIDatePickerStyle = mode == .countDownTimer ? .wheels
                : props["display"] as? String == "inline" ? .inline
                : props["display"] as? String == "wheels" || props["display"] as? String == "spinner" ? .wheels
                : .compact
            if mode == .countDownTimer {
                if picker.preferredDatePickerStyle != display { picker.preferredDatePickerStyle = display }
                if picker.datePickerMode != mode { picker.datePickerMode = mode }
            } else {
                if picker.datePickerMode != mode { picker.datePickerMode = mode }
                if picker.preferredDatePickerStyle != display { picker.preferredDatePickerStyle = display }
            }
            // UIKit takes an interval that divides an hour, and ignores others.
            let interval = (props["minuteInterval"] as? NSNumber)?.intValue ?? 1
            picker.minuteInterval = (1...30).contains(interval) && 60 % interval == 0 ? interval : 1
            picker.minimumDate = Self.pickerDate(props["minimumDate"])
            picker.maximumDate = Self.pickerDate(props["maximumDate"])
            if mode == .countDownTimer {
                if let duration = Self.countdownDuration(props["value"]), abs(picker.countDownDuration - duration) >= 1 {
                    picker.countDownDuration = duration
                }
            } else if let date = Self.pickerDate(props["value"]), abs(picker.date.timeIntervalSince(date)) >= 1 {
                picker.setDate(date, animated: false)
            }
            picker.tintColor = color(props["color"]) ?? color(style["color"])
            picker.isEnabled = props["disabled"] as? Bool != true
            updateHandler(nonEmptyHandler(events["onValueChange"]) ?? nonEmptyHandler(events["onChange"]), for: picker)
        case "Modal":
            let modal = result as! CraftNativeModalView
            modal.transparent = props["transparent"] as? Bool == true
            let visible: Bool
            if let propVisible = props["visible"] as? Bool {
                // An explicit visible prop owns modal visibility. The
                // binding runtime may leave a stale display:none style
                // from the previous hidden state when it patches props.
                visible = propVisible
            } else {
                let display = style["display"] as? String
                visible = display != nil && display != "none"
            }
            let modalID = ObjectIdentifier(modal)
            let wasVisible = modalVisibility[modalID]
            modalVisibility[modalID] = visible
            if visible, wasVisible != true { positionModals() }
            modal.setVisible(visible, opacity: number(style["opacity"]) ?? 1, animationType: props["animationType"] as? String)
            modal.onRequestClose = nonEmptyHandler(events["onRequestClose"]).map { handler in
                { [weak self] in self?.send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": [:]]) }
            }
            if visible { modal.clearDismissSuppression() }
            let suppressDismiss = !visible && modal.consumeDismissSuppression()
            if wasVisible != visible, visible || wasVisible == true {
                let lifecycleHandler = visible ? events["onShow"] : events["onDismiss"]
                if let lifecycleHandler = nonEmptyHandler(lifecycleHandler), !suppressDismiss {
                    send(type: "EVENT", payload: ["handlerName": lifecycleHandler, "nativeEvent": [:]])
                }
            }
            configureStack(modal.contentStack, style: style)
            reconcileChildren(children, in: modal.contentStack, parent: current, path: path, style: style)
        case "TouchableOpacity", "TouchableHighlight", "Pressable":
            let pressable = result as! CraftNativeFlowView
            configureStack(pressable, style: style)
            reconcileChildren(children, in: pressable, parent: current, path: path, style: style)
            pressable.pressActiveOpacity = props["disabled"] as? Bool == true
                ? nil : number(props["activeOpacity"]) ?? 0.5
            pressable.pressBaseOpacity = number(style["opacity"]) ?? 1
        case "Switch":
            let toggle = result as! UISwitch
            toggle.isOn = props["value"] as? Bool ?? props["checked"] as? Bool ?? false
            toggle.isEnabled = props["disabled"] as? Bool != true
            if let track = props["trackColor"] as? [String: Any] {
                toggle.onTintColor = color(track["true"])
                toggle.tintColor = color(track["false"])
            } else {
                toggle.onTintColor = nil
                toggle.tintColor = nil
            }
            toggle.thumbTintColor = color(props["thumbColor"])
            if let background = color(props["ios_backgroundColor"]) { toggle.tintColor = background }
            updateHandler(nonEmptyHandler(events["onValueChange"]) ?? nonEmptyHandler(events["onChange"]), for: toggle)
        case "Slider":
            let slider = result as! UISlider
            let minimum = (props["minimumValue"] as? NSNumber)?.floatValue ?? 0
            slider.minimumValue = minimum.isFinite ? minimum : 0
            let maximum = (props["maximumValue"] as? NSNumber)?.floatValue ?? 1
            slider.maximumValue = max(slider.minimumValue + .leastNonzeroMagnitude, maximum.isFinite ? maximum : 1)
            let authoredValue = (props["value"] as? NSNumber)?.floatValue ?? slider.minimumValue
            let value = authoredValue.isFinite ? authoredValue : slider.minimumValue
            if let step = (props["step"] as? NSNumber)?.floatValue, step.isFinite, step > 0 { sliderSteps[ObjectIdentifier(slider)] = step }
            else { sliderSteps.removeValue(forKey: ObjectIdentifier(slider)) }
            slider.value = snappedSliderValue(value, for: slider)
            slider.minimumTrackTintColor = color(props["minimumTrackTintColor"])
            slider.maximumTrackTintColor = color(props["maximumTrackTintColor"])
            slider.thumbTintColor = color(props["thumbTintColor"])
            slider.isEnabled = props["disabled"] as? Bool != true
            updateHandler(nonEmptyHandler(events["onValueChange"]) ?? nonEmptyHandler(events["onChange"]), for: slider)
            updateAuxiliaryHandler(events["onSlidingComplete"], in: &sliderCompleteHandlers, for: slider)
        case "ActivityIndicator":
            let indicator = result as! UIActivityIndicatorView
            let requestedSize = props["size"]
            indicator.style = (requestedSize as? String) == "large" ? .large : .medium
            let scale: CGFloat
            if let numericSize = requestedSize as? NSNumber {
                let value = CGFloat(numericSize.doubleValue / 20.0)
                scale = value.isFinite ? max(0.5, value) : 1
            } else if (requestedSize as? String) == "small" {
                scale = 0.75
            } else {
                scale = 1
            }
            indicator.transform = CGAffineTransform(scaleX: scale, y: scale)
            indicator.color = color(props["color"]) ?? .tintColor
            indicator.hidesWhenStopped = props["hidesWhenStopped"] as? Bool ?? true
            if props["animating"] as? Bool == false {
                indicator.stopAnimating()
            } else {
                indicator.startAnimating()
            }
        case "Svg":
            let drawing = result as! CraftNativeSvgView
            let owner = current.protocolId ?? path
            svgOwners = svgOwners.filter { $0.value != owner }
            for child in children { registerSvgOwnership(child, owner: owner) }
            let previousBox = drawing.viewBox
            drawing.drawing = node
            if drawing.viewBox != previousBox { CraftNativeFlexLayout.invalidateAncestors(of: drawing) }
            current.children = []
        case "Icon":
            configureIcon(result as! UIImageView, props: props, style: style)
        case "Image":
            let image = result as! UIImageView
            let imageID = ObjectIdentifier(image)
            if let tint = color(style["tintColor"]) {
                tintedImages.insert(imageID)
                image.tintColor = tint
            } else {
                tintedImages.remove(imageID)
                image.tintColor = nil
            }
            if let current = image.image { image.image = imageForDisplay(current, view: image) }
            let requestedResizeMode = style["resizeMode"] as? String ?? props["resizeMode"] as? String
            image.contentMode = imageContentMode(requestedResizeMode)
            image.clipsToBounds = image.contentMode == .scaleAspectFill
            updateAuxiliaryHandler(events["onLoadStart"], in: &imageLoadStartHandlers, for: image)
            updateAuxiliaryHandler(events["onLoad"], in: &imageLoadHandlers, for: image)
            updateAuxiliaryHandler(events["onLoadEnd"], in: &imageLoadEndHandlers, for: image)
            updateAuxiliaryHandler(events["onError"], in: &imageErrorHandlers, for: image)
            updateImage(image, source: props["source"], defaultSource: props["defaultSource"])
        case "ImageBackground":
            let background = result as! CraftNativeImageBackgroundView
            let requestedResizeMode = style["resizeMode"] as? String ?? props["resizeMode"] as? String
            background.contentMode = imageContentMode(requestedResizeMode)
            background.clipsToBounds = background.contentMode == .scaleAspectFill
            updateAuxiliaryHandler(events["onLoadStart"], in: &imageLoadStartHandlers, for: background)
            updateAuxiliaryHandler(events["onLoad"], in: &imageLoadHandlers, for: background)
            updateAuxiliaryHandler(events["onLoadEnd"], in: &imageLoadEndHandlers, for: background)
            updateAuxiliaryHandler(events["onError"], in: &imageErrorHandlers, for: background)
            updateImage(background, source: props["source"], defaultSource: props["defaultSource"])
            configureStack(background.contentStack, style: style)
            reconcileChildren(children, in: background.contentStack, parent: current, path: path, style: style)
        case "KeyboardAvoidingView":
            let keyboard = result as! CraftNativeKeyboardAvoidingView
            configureStack(keyboard, style: style)
            keyboard.configureKeyboard(props: props)
            reconcileChildren(children, in: keyboard, parent: current, path: path, style: style)
        case "Video":
            let video = result as! CraftNativeVideoView
            let autoplay = (props["autoplay"] as? Bool) == true || (props["autoPlay"] as? Bool) == true
            video.handlers = events
            video.emit = { [weak self] handler, nativeEvent in
                self?.send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": nativeEvent])
            }
            video.configure(
                source: props["source"] ?? props["src"],
                autoplay: autoplay,
                paused: (props["paused"] as? Bool) == true,
                loop: (props["loop"] as? Bool) == true,
                muted: (props["muted"] as? Bool) == true,
                controls: (props["controls"] as? Bool) == true,
                resizeMode: style["resizeMode"] as? String ?? props["resizeMode"] as? String
            )
        case "Map":
            let map = result as! CraftNativeMapView
            map.configure(props: props, children: children) { [weak self, weak map] markerID in
                guard let self, let map, let handler = map.markerHandlers[markerID], !handler.isEmpty else { return }
                self.send(type: "EVENT", payload: [
                    "handlerName": handler,
                    "nativeEvent": ["id": markerID],
                ])
            }
        case "ScrollView", "SectionList":
            let scroll = result as! CraftNativeScrollView
            let flexDirection = style["flexDirection"] as? String
            let direction = (props["horizontal"] as? Bool) == true
                || flexDirection == "row"
                || flexDirection == "row-reverse"
                ? NSLayoutConstraint.Axis.horizontal : .vertical
            scroll.setAxis(direction)
            scroll.delegate = self
            scroll.isScrollEnabled = props["scrollEnabled"] as? Bool != false
            scroll.bounces = props["bounces"] as? Bool ?? true
            scroll.isPagingEnabled = props["pagingEnabled"] as? Bool ?? false
            scroll.keyboardDismissMode = keyboardDismissMode(props["keyboardDismissMode"])
            scroll.setKeyboardShouldPersistTaps(props["keyboardShouldPersistTaps"])
            scroll.showsVerticalScrollIndicator = props["showsVerticalScrollIndicator"] as? Bool != false
            scroll.showsHorizontalScrollIndicator = props["showsHorizontalScrollIndicator"] as? Bool != false
            scroll.alwaysBounceVertical = props["alwaysBounceVertical"] as? Bool ?? (direction == .vertical)
            scroll.alwaysBounceHorizontal = props["alwaysBounceHorizontal"] as? Bool ?? (direction == .horizontal)
            scroll.setStickyHeaderIndices(props["stickyHeaderIndices"])
            scroll.setScrollTarget(props["scrollTarget"])
            updateAuxiliaryHandler(events["onScroll"], in: &scrollHandlers, for: scroll)
            updateAuxiliaryHandler(events["onScrollBeginDrag"], in: &scrollBeginHandlers, for: scroll)
            updateAuxiliaryHandler(events["onScrollEndDrag"], in: &scrollEndHandlers, for: scroll)
            updateAuxiliaryHandler(events["onMomentumScrollBegin"], in: &scrollMomentumBeginHandlers, for: scroll)
            updateAuxiliaryHandler(events["onMomentumScrollEnd"], in: &scrollMomentumEndHandlers, for: scroll)
            let refreshNode = children.compactMap { $0 as? [String: Any] }.first {
                canonicalType($0["type"] as? String ?? "") == "RefreshControl"
            }
            let refreshProps = refreshNode?["props"] as? [String: Any] ?? [:]
            let refreshEvents = refreshNode?["events"] as? [String: String] ?? [:]
            let refreshHandlerName = nonEmptyHandler(refreshEvents["onRefresh"])
                ?? nonEmptyHandler(events["onRefresh"])
            scroll.setRefreshHandler(refreshHandlerName.map { [weak self] handler in
                { self?.send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": [:]]) }
            }, refreshing: (refreshNode == nil ? props["refreshing"] : refreshProps["refreshing"]) as? Bool == true)
            scroll.setRefreshAppearance(refreshProps)
            var contentStyle = style
            if let override = props["contentContainerStyle"] as? [String: Any] {
                contentStyle.merge(override) { _, next in next }
            }
            configureStack(scroll.contentStack, style: contentStyle)
            reconcileChildren(children.filter {
                guard let child = $0 as? [String: Any] else { return true }
                return canonicalType(child["type"] as? String ?? "") != "RefreshControl"
            }, in: scroll.contentStack, parent: current, path: path, style: contentStyle)
        case "FlatList":
            let list = result as! CraftNativeFlatList
            reconcileFlatList(
                children.compactMap { $0 as? [String: Any] },
                in: list,
                parent: current,
                path: path,
                props: props,
                events: events
            )
        default:
            let stack = result as! CraftNativeFlowView
            configureStack(stack, style: style)
            reconcileChildren(children, in: stack, parent: current, path: path, style: style)
        }
        updateLongPressHandler(props["disabled"] as? Bool == true ? nil : events["onLongPress"], for: result)
        if type != "Button" && type != "Link" && type != "Checkbox" && type != "TextInput" && type != "Picker" && type != "DatePicker" && type != "Modal" && type != "Switch" && type != "Slider" && type != "ActivityIndicator" && type != "StatusBar" && type != "RefreshControl" && type != "Map" {
            let disabled = props["disabled"] as? Bool == true
            updatePressHandler(disabled ? nil : nonEmptyHandler(events["onPress"]) ?? nonEmptyHandler(events["onClick"]), for: result)
            updatePressFeedback(
                disabled ? nil : nonEmptyHandler(events["onPressIn"]),
                disabled ? nil : nonEmptyHandler(events["onPressOut"]),
                for: result
            )
            if disabled { result.isUserInteractionEnabled = false }
        }
        applyAccessibility(props, type: type, to: result)
        return current
    }

    private func makeView(_ type: String, props: [String: Any]) -> UIView {
        switch type {
        case "Text":
            let label = CraftNativeLabel()
            label.numberOfLines = 0
            return label
        case "Button", "Link":
            let button = CraftNativeButton(type: .system)
            button.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchUpInside)
            return button
        case "Checkbox":
            let checkbox = CraftNativeCheckboxButton(type: .system)
            checkbox.semanticContentAttribute = .forceLeftToRight
            checkbox.contentHorizontalAlignment = .leading
            checkbox.addTarget(self, action: #selector(checkboxPressed(_:)), for: .touchUpInside)
            return checkbox
        case "TextInput":
            if props["multiline"] as? Bool == true {
                let textView = CraftNativeTextView()
                textView.delegate = self
                return textView
            }
            let field = CraftNativeTextField()
            field.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)
            field.addTarget(self, action: #selector(textFocused(_:)), for: .editingDidBegin)
            field.addTarget(self, action: #selector(textBlurred(_:)), for: .editingDidEnd)
            field.addTarget(self, action: #selector(textSubmitted(_:)), for: .editingDidEndOnExit)
            return field
        case "Picker":
            let picker = UIPickerView()
            picker.dataSource = self
            picker.delegate = self
            return picker
        case "DatePicker":
            let picker = UIDatePicker()
            picker.preferredDatePickerStyle = .compact
            picker.addTarget(self, action: #selector(datePicked(_:)), for: .valueChanged)
            return picker
        case "Modal":
            return CraftNativeModalView()
        case "Switch":
            let toggle = UISwitch()
            toggle.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
            return toggle
        case "Slider":
            let slider = UISlider()
            slider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)
            slider.addTarget(self, action: #selector(sliderFinished(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
            return slider
        case "ActivityIndicator":
            return UIActivityIndicatorView(style: .medium)
        case "StatusBar", "RefreshControl":
            return CraftNativeFlowView()
        case "Image":
            return UIImageView()
        case "ImageBackground":
            return CraftNativeImageBackgroundView(frame: .zero)
        case "KeyboardAvoidingView":
            return CraftNativeKeyboardAvoidingView()
        case "Video":
            return CraftNativeVideoView(host: self)
        case "Map":
            return CraftNativeMapView()
        case "Icon":
            let icon = CraftNativeIconView()
            icon.contentMode = .scaleAspectFit
            return icon
        case "ScrollView", "SectionList":
            return CraftNativeScrollView()
        case "FlatList":
            return CraftNativeFlatList()
        case "Svg":
            return CraftNativeSvgView()
        case "View":
            return CraftNativeFlowView()
        case "SafeAreaView":
            return CraftNativeSafeAreaView()
        case "TouchableOpacity", "TouchableHighlight", "Pressable":
            return CraftNativeFlowView()
        default:
            return CraftNativeFlowView()
        }
    }

    private func canonicalType(_ raw: String) -> String {
        switch raw.lowercased() {
        case "view": return "View"
        case "safeareaview": return "SafeAreaView"
        case "keyboardavoidingview": return "KeyboardAvoidingView"
        case "text": return "Text"
        case "button": return "Button"
        case "link": return "Link"
        case "checkbox": return "Checkbox"
        case "textinput", "input": return "TextInput"
        case "picker", "select": return "Picker"
        case "datepicker", "date-picker", "date": return "DatePicker"
        case "modal": return "Modal"
        case "switch": return "Switch"
        case "slider": return "Slider"
        case "activityindicator": return "ActivityIndicator"
        case "statusbar": return "StatusBar"
        case "refreshcontrol": return "RefreshControl"
        case "image": return "Image"
        case "imagebackground": return "ImageBackground"
        case "video": return "Video"
        case "map": return "Map"
        case "icon": return "Icon"
        case "scrollview": return "ScrollView"
        case "sectionlist": return "SectionList"
        case "flatlist": return "FlatList"
        case "svg": return "Svg"
        case "touchableopacity": return "TouchableOpacity"
        case "touchablehighlight": return "TouchableHighlight"
        case "pressable": return "Pressable"
        default: return raw
        }
    }

    private func explicitKey(_ node: [String: Any], props: [String: Any]) -> String? {
        // The current @stacksjs/stx native compiler emits key in props; accept the IR
        // field too so keyed children keep working when the compiler adopts it.
        let direct = [node["key"], props["key"], props["testID"]]
            .compactMap { $0 as? String }
            .first { !$0.isEmpty }
        if let direct { return direct }
        for child in node["children"] as? [[String: Any]] ?? [] {
            let childProps = child["props"] as? [String: Any] ?? [:]
            if let nested = explicitKey(child, props: childProps) { return nested }
        }
        return (node["id"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    private func accessibilityIdentifier(_ node: [String: Any], props: [String: Any]) -> String? {
        [props["testID"], props["key"], node["key"], node["id"]]
            .compactMap { $0 as? String }
            .first { !$0.isEmpty }
    }

    private func reconcileChildren(
        _ children: [Any],
        in stack: CraftNativeFlowView,
        parent: RenderedNode,
        path: String,
        style: [String: Any]
    ) {
        for spacer in stack.arrangedSubviews.compactMap({ $0 as? CraftNativeFlexSpacer }) {
            stack.removeArrangedSubview(spacer)
            spacer.removeFromSuperview()
        }
        let nodes = children.compactMap { $0 as? [String: Any] }
        let keys = nodes.compactMap { explicitKey($0, props: $0["props"] as? [String: Any] ?? [:]) }
        let counts = Dictionary(keys.map { ($0, 1) }, uniquingKeysWith: +)
        let old = Dictionary(uniqueKeysWithValues: parent.children.map { ($0.identity, $0) })
        var next: [RenderedNode] = []

        for (index, node) in nodes.enumerated() {
            let key = explicitKey(node, props: node["props"] as? [String: Any] ?? [:])
            // Keys are local to a parent. Ambiguous sibling keys fall back to
            // position so a move never attaches the wrong live control.
            let identity = key.flatMap { counts[$0] == 1 ? "key:\($0)" : nil } ?? "index:\(index)"
            let child = reconcile(node, identity: identity, path: "\(path).\(index)", previous: old[identity])
            next.append(child)
        }
        if (style["flexDirection"] as? String)?.hasSuffix("-reverse") == true { next.reverse() }

        for child in parent.children where !next.contains(where: { $0 === child }) {
            detach(child, from: stack)
        }
        for modal in stack.arrangedSubviews where modal is CraftNativeModalView {
            stack.removeArrangedSubview(modal)
        }
        let flowChildren = next.filter { $0.type != "Modal" }
        for (index, child) in flowChildren.enumerated() {
            if index < stack.arrangedSubviews.count, stack.arrangedSubviews[index] === child.view {
                stack.setLayoutStyle(child.style, for: child.view)
                continue
            }
            if child.view.superview === stack { stack.removeArrangedSubview(child.view) }
            stack.insertArrangedSubview(child.view, at: min(index, stack.arrangedSubviews.count))
            stack.setLayoutStyle(child.style, for: child.view)
        }
        for child in next where child.type == "Modal" {
            guard let modal = child.view as? CraftNativeModalView else { continue }
            // A modal covers the screen, wherever it is declared. Laid over
            // its parent instead, one declared in a scroll view covered the
            // whole content: its controls sat wherever the content had
            // scrolled to, under the bar or off screen, out of reach.
            if modal.superview !== view {
                modal.removeFromSuperview()
                view.addSubview(modal)
            }
            modal.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.bringSubviewToFront(modal)
        }
        positionModals()
        parent.children = next
        addJustificationSpacers(to: stack, value: style["justifyContent"] as? String)
    }

    private func reconcileFlatList(
        _ children: [[String: Any]],
        in list: CraftNativeFlatList,
        parent: RenderedNode,
        path: String,
        props: [String: Any],
        events: [String: String]
    ) {
        let listKey = ObjectIdentifier(list)
        let owner = parent.protocolId ?? path
        flatListOwners = flatListOwners.filter { $0.value != owner }
        for child in children { registerFlatListOwnership(child, owner: owner) }
        list.bounces = props["bounces"] as? Bool ?? true
        list.isScrollEnabled = props["scrollEnabled"] as? Bool != false
        list.onFittingHeightChanged = { [weak list] in
            guard let list else { return }
            CraftNativeFlexLayout.invalidateAncestors(of: list)
        }
        list.setKeyboardShouldPersistTaps(props["keyboardShouldPersistTaps"])
        list.setContentContainerStyle(props["contentContainerStyle"] as? [String: Any])
        list.setRefreshHandler(nonEmptyHandler(events["onRefresh"]).map { [weak self] handler in
            { self?.send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": [:]]) }
        }, refreshing: props["refreshing"] as? Bool == true)
        list.keyboardDismissMode = keyboardDismissMode(props["keyboardDismissMode"])
        list.onScrollEvent = nonEmptyHandler(events["onScroll"]).map { handler in
            { [weak self] scrollView in self?.send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": self?.scrollEvent(scrollView) ?? [:]]) }
        }
        list.onScrollBeginDrag = nonEmptyHandler(events["onScrollBeginDrag"]).map { handler in
            { [weak self] scrollView in self?.send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": self?.scrollEvent(scrollView) ?? [:]]) }
        }
        list.onScrollEndDrag = nonEmptyHandler(events["onScrollEndDrag"]).map { handler in
            { [weak self] scrollView in self?.send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": self?.scrollEvent(scrollView) ?? [:]]) }
        }
        list.onMomentumScrollBegin = nonEmptyHandler(events["onMomentumScrollBegin"]).map { handler in
            { [weak self] scrollView in self?.send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": self?.scrollEvent(scrollView) ?? [:]]) }
        }
        list.onMomentumScrollEnd = nonEmptyHandler(events["onMomentumScrollEnd"]).map { handler in
            { [weak self] scrollView in self?.send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": self?.scrollEvent(scrollView) ?? [:]]) }
        }

        let threshold = max(
            0,
            Double(number(props["onEndReachedThreshold"]) ?? number(props["threshold"]) ?? 0.1)
        )
        list.apply(
            nodes: children,
            horizontal: props["horizontal"] as? Bool == true,
            columns: (props["numColumns"] as? NSNumber)?.intValue ?? 1,
            inverted: props["inverted"] as? Bool == true,
            endReachedThreshold: threshold,
            renderItem: { [weak self] node, identity, _ in
                guard let self = self else { return UIView() }
                let previous = self.flatListRows[listKey]?[identity]
                let next = self.reconcile(
                    node,
                    identity: "list:\(identity)",
                    path: "\(path).\(identity)",
                    previous: previous
                )
                if let previous, previous.view !== next.view {
                    self.forgetHandlers(previous)
                }
                self.flatListRows[listKey, default: [:]][identity] = next
                return next.view
            },
            recycleItem: { [weak self] identity in
                guard let self = self,
                      let row = self.flatListRows[listKey]?.removeValue(forKey: identity) else { return }
                self.forgetHandlers(row, preservingInputDrafts: true)
            },
            endReached: nonEmptyHandler(events["onEndReached"]).map { [weak self] handler in
                { self?.send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": [:]]) }
            }
        )
        parent.children = []
    }

    private func registerFlatListOwnership(_ node: [String: Any], owner: String) {
        let props = node["props"] as? [String: Any] ?? [:]
        for identity in [node["id"], node["key"], props["key"], props["testID"]].compactMap({ $0 as? String }) {
            if !identity.isEmpty { flatListOwners[identity] = owner }
        }
        for child in (node["children"] as? [Any] ?? []).compactMap({ $0 as? [String: Any] }) {
            registerFlatListOwnership(child, owner: owner)
        }
    }

    private func registerSvgOwnership(_ node: Any, owner: String) {
        guard let node = node as? [String: Any] else { return }
        if let id = node["id"] as? String, !id.isEmpty { svgOwners[id] = owner }
        for child in node["children"] as? [Any] ?? [] { registerSvgOwnership(child, owner: owner) }
    }

    private func detach(_ node: RenderedNode, from stack: CraftNativeFlowView) {
        forgetHandlers(node)
        if node.type == "Modal" {
            node.view.removeFromSuperview()
            return
        }
        stack.removeLayoutStyle(for: node.view)
        stack.removeArrangedSubview(node.view)
        node.view.removeFromSuperview()
    }

    private func forgetHandlers(_ node: RenderedNode, preservingInputDrafts: Bool = false) {
        (node.view as? CraftNativeScrollView)?.setRefreshHandler(nil, refreshing: false)
        if let list = node.view as? CraftNativeFlatList {
            let listKey = ObjectIdentifier(list)
            list.setRefreshHandler(nil, refreshing: false)
            list.discardAll()
            flatListRows.removeValue(forKey: listKey)
            if let owner = node.protocolId { flatListOwners = flatListOwners.filter { $0.value != owner } }
        }
        if node.view is CraftNativeSvgView, let owner = node.protocolId { svgOwners = svgOwners.filter { $0.value != owner } }
        let id = ObjectIdentifier(node.view)
        if let modal = node.view as? CraftNativeModalView {
            modal.resetForTeardown()
            // It sits on the screen, not in its parent: leaving with the
            // parent's subtree does not take it away.
            modal.removeFromSuperview()
        }
        handlers.removeValue(forKey: id)
        linkTargets.removeValue(forKey: id)
        pressInHandlers.removeValue(forKey: id)
        pressOutHandlers.removeValue(forKey: id)
        layoutHandlers.removeValue(forKey: id)
        lastLayoutFrames.removeValue(forKey: id)
        focusHandlers.removeValue(forKey: id)
        blurHandlers.removeValue(forKey: id)
        endEditingHandlers.removeValue(forKey: id)
        submitHandlers.removeValue(forKey: id)
        inputIdentities.removeValue(forKey: id)
        if node.type == "TextInput" && !preservingInputDrafts { inputDrafts.removeValue(forKey: node.identity) }
        longPressHandlers.removeValue(forKey: id)
        textMaxLengths.removeValue(forKey: id)
        scrollHandlers.removeValue(forKey: id)
        scrollBeginHandlers.removeValue(forKey: id)
        scrollEndHandlers.removeValue(forKey: id)
        scrollMomentumBeginHandlers.removeValue(forKey: id)
        scrollMomentumEndHandlers.removeValue(forKey: id)
        sliderCompleteHandlers.removeValue(forKey: id)
        sliderSteps.removeValue(forKey: id)
        pickerOptions.removeValue(forKey: id)
        modalVisibility.removeValue(forKey: id)
        if let recognizer = tapRecognizers.removeValue(forKey: id) {
            node.view.removeGestureRecognizer(recognizer)
        }
        if let recognizer = longPressRecognizers.removeValue(forKey: id) {
            node.view.removeGestureRecognizer(recognizer)
        }
        if let recognizer = pressFeedbackRecognizers.removeValue(forKey: id) {
            node.view.removeGestureRecognizer(recognizer)
        }
        imageSources.removeValue(forKey: id)
        imageTasks.removeValue(forKey: id)?.cancel()
        imageErrors.removeValue(forKey: id)
        tintedImages.remove(id)
        imageLoadStartHandlers.removeValue(forKey: id)
        imageLoadHandlers.removeValue(forKey: id)
        imageLoadEndHandlers.removeValue(forKey: id)
        imageErrorHandlers.removeValue(forKey: id)
        checkboxIndeterminate.removeValue(forKey: id)
        if let video = node.view as? CraftNativeVideoView { video.stop() }
        for child in node.children { forgetHandlers(child, preservingInputDrafts: preservingInputDrafts) }
    }

    private func updateHandler(_ handler: String?, for view: UIView) {
        let id = ObjectIdentifier(view)
        if let handler, !handler.isEmpty { handlers[id] = handler }
        else { handlers.removeValue(forKey: id) }
    }

    private func snappedSliderValue(_ value: Float, for slider: UISlider) -> Float {
        let bounded = min(slider.maximumValue, max(slider.minimumValue, value))
        guard let step = sliderSteps[ObjectIdentifier(slider)], step > 0 else { return bounded }
        let steps = ((bounded - slider.minimumValue) / step).rounded()
        return min(slider.maximumValue, max(slider.minimumValue, slider.minimumValue + steps * step))
    }

    private func updateLayoutHandler(_ handler: String?, for view: UIView) {
        let id = ObjectIdentifier(view)
        guard let handler, !handler.isEmpty else {
            layoutHandlers.removeValue(forKey: id)
            lastLayoutFrames.removeValue(forKey: id)
            return
        }
        if layoutHandlers[id] != handler { lastLayoutFrames.removeValue(forKey: id) }
        layoutHandlers[id] = handler
    }

    private func emitLayoutEvents() {
        guard let renderedRoot else { return }
        emitLayoutEvents(for: renderedRoot)
    }

    private var layoutEventsScheduled = false

    /// A view inside the screen moved: report onLayout once the pass that
    /// moved it is over, however deep it was.
    fileprivate func scheduleLayoutEvents() {
        guard !layoutEventsScheduled, !layoutHandlers.isEmpty else { return }
        layoutEventsScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.layoutEventsScheduled = false
            self.emitLayoutEvents()
        }
    }

    private func emitLayoutEvents(for node: RenderedNode) {
        let id = ObjectIdentifier(node.view)
        if let handler = layoutHandlers[id], isEffectivelyVisible(node.view) {
            let frame = node.view.frame
            if lastLayoutFrames[id] != frame {
                lastLayoutFrames[id] = frame
                send(type: "EVENT", payload: [
                    "handlerName": handler,
                    "nativeEvent": ["layout": [
                        "x": frame.minX,
                        "y": frame.minY,
                        "width": frame.width,
                        "height": frame.height,
                    ]],
                ])
            }
        }
        for child in node.children { emitLayoutEvents(for: child) }
        if let list = node.view as? CraftNativeFlatList {
            flatListRows[ObjectIdentifier(list)]?.values.forEach { emitLayoutEvents(for: $0) }
        }
    }

    private func isEffectivelyVisible(_ view: UIView) -> Bool {
        guard view.window != nil, !view.isHidden else { return false }
        var ancestor = view.superview
        while let current = ancestor {
            if current.isHidden { return false }
            ancestor = current.superview
        }
        return true
    }

    private func updateAuxiliaryHandler(
        _ handler: String?,
        in handlers: inout [ObjectIdentifier: String],
        for view: UIView
    ) {
        let id = ObjectIdentifier(view)
        if let handler, !handler.isEmpty { handlers[id] = handler }
        else { handlers.removeValue(forKey: id) }
    }

    private func nonEmptyHandler(_ handler: String?) -> String? {
        guard let handler, !handler.isEmpty else { return nil }
        return handler
    }

    private func updatePressHandler(_ handler: String?, for view: UIView) {
        let id = ObjectIdentifier(view)
        let handler = handler?.isEmpty == false ? handler : nil
        updateHandler(handler, for: view)
        let actionable = handler != nil || linkTargets[id] != nil
        if actionable, tapRecognizers[id] == nil {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(viewPressed(_:)))
            tapRecognizers[id] = recognizer
            view.addGestureRecognizer(recognizer)
        } else if handler == nil, let recognizer = tapRecognizers.removeValue(forKey: id) {
            view.removeGestureRecognizer(recognizer)
        }
        // A container keeps receiving touches without a handler of its own,
        // or every control inside it (and the screen root) would be dead.
        if !(view is UIScrollView || view is CraftNativeModalView) { view.isUserInteractionEnabled = actionable || longPressHandlers[id] != nil || view is CraftNativeFlowView }
    }

    private func updatePressFeedback(_ pressIn: String?, _ pressOut: String?, for view: UIView) {
        let id = ObjectIdentifier(view)
        if let pressIn, !pressIn.isEmpty { pressInHandlers[id] = pressIn } else { pressInHandlers.removeValue(forKey: id) }
        if let pressOut, !pressOut.isEmpty { pressOutHandlers[id] = pressOut } else { pressOutHandlers.removeValue(forKey: id) }
        guard pressInHandlers[id] != nil || pressOutHandlers[id] != nil else {
            if let recognizer = pressFeedbackRecognizers.removeValue(forKey: id) { view.removeGestureRecognizer(recognizer) }
            if !(view is UIScrollView || view is CraftNativeModalView) { view.isUserInteractionEnabled = handlers[id] != nil || linkTargets[id] != nil || longPressHandlers[id] != nil || view is CraftNativeFlowView }
            return
        }
        if pressFeedbackRecognizers[id] == nil {
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(viewPressFeedback(_:)))
            recognizer.minimumPressDuration = 0
            recognizer.allowableMovement = 10
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = CraftPressFeedbackDelegate.shared
            pressFeedbackRecognizers[id] = recognizer
            view.addGestureRecognizer(recognizer)
        }
        if !(view is UIScrollView || view is CraftNativeModalView) { view.isUserInteractionEnabled = true }
    }

    private func updateLongPressHandler(_ handler: String?, for view: UIView) {
        let id = ObjectIdentifier(view)
        if let handler, !handler.isEmpty {
            longPressHandlers[id] = handler
            if !(view is UIScrollView || view is CraftNativeModalView) { view.isUserInteractionEnabled = true }
            if longPressRecognizers[id] == nil {
                let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(viewLongPressed(_:)))
                longPressRecognizers[id] = recognizer
                view.addGestureRecognizer(recognizer)
            }
        } else {
            longPressHandlers.removeValue(forKey: id)
            if let recognizer = longPressRecognizers.removeValue(forKey: id) {
                view.removeGestureRecognizer(recognizer)
            }
            if !(view is UIScrollView || view is CraftNativeModalView) { view.isUserInteractionEnabled = handlers[id] != nil || linkTargets[id] != nil || view is CraftNativeFlowView }
        }
    }

    private func updateField(_ field: UITextField, value: String?) {
        guard let value = value, field.text != value, field.markedTextRange == nil else { return }
        let selection = field.selectedTextRange
        let start = selection.map { field.offset(from: field.beginningOfDocument, to: $0.start) }
        let end = selection.map { field.offset(from: field.beginningOfDocument, to: $0.end) }
        field.text = value
        if let start = start, let end = end,
           let from = field.position(from: field.beginningOfDocument, offset: min(start, value.utf16.count)),
           let to = field.position(from: field.beginningOfDocument, offset: min(end, value.utf16.count)) {
            field.selectedTextRange = field.textRange(from: from, to: to)
        }
    }

    private func updateTextView(_ textView: UITextView, value: String?) {
        guard let value = value, textView.text != value, textView.markedTextRange == nil else { return }
        let selection = textView.selectedTextRange
        let start = selection.map { textView.offset(from: textView.beginningOfDocument, to: $0.start) }
        let end = selection.map { textView.offset(from: textView.beginningOfDocument, to: $0.end) }
        textView.text = value
        if let start = start, let end = end,
           let from = textView.position(from: textView.beginningOfDocument, offset: min(start, value.utf16.count)),
           let to = textView.position(from: textView.beginningOfDocument, offset: min(end, value.utf16.count)) {
            textView.selectedTextRange = textView.textRange(from: from, to: to)
        }
    }

    private func configureTextView(
        _ textView: UITextView,
        props: [String: Any],
        style: [String: Any],
        events: [String: String],
        defaultValue: String?
    ) {
        let id = ObjectIdentifier(textView)
        textView.delegate = self
        textView.textColor = color(style["color"]) ?? .label
        textView.font = textFont(style, default: .systemFont(ofSize: 16))
        textView.textAlignment = textAlignment(style["textAlign"])
        textView.tintColor = color(props["selectionColor"])
        textView.keyboardType = keyboardType(props["keyboardType"])
        textView.returnKeyType = returnKeyType(props["returnKeyType"])
        textView.autocorrectionType = props["autoCorrect"] as? Bool == false ? .no : .default
        textView.autocapitalizationType = capitalizationType(props["autoCapitalize"])
        textView.isSecureTextEntry = props["secureTextEntry"] as? Bool == true
        textView.isEditable = props["editable"] as? Bool != false
        applyAutofill(to: textView, props: props)
        // The style's padding is where the text starts, as in a web textarea.
        let padding = paddingInsets(style)
        if padding != .zero {
            if textView.textContainerInset != padding { textView.textContainerInset = padding }
            textView.textContainer.lineFragmentPadding = 0
        }
        textView.isScrollEnabled = false
        if let numberOfLines = (props["numberOfLines"] as? NSNumber)?.intValue, numberOfLines > 0 {
            textView.textContainer.maximumNumberOfLines = numberOfLines
        } else {
            textView.textContainer.maximumNumberOfLines = 0
        }
        if let maxLength = (props["maxLength"] as? NSNumber)?.intValue, maxLength > 0 {
            textMaxLengths[id] = maxLength
        } else {
            textMaxLengths.removeValue(forKey: id)
        }
        if let craftTextView = textView as? CraftNativeTextView {
            craftTextView.placeholder = props["placeholder"] as? String
            craftTextView.placeholderColor = color(props["placeholderTextColor"])
            craftTextView.placeholderFont = textView.font
        }
        updateTextView(textView, value: (props["value"] as? String) ?? defaultValue)
        let selectedRange = textView.selectedRange
        let attributes = inputTextAttributes(style, font: textView.font ?? .systemFont(ofSize: 16), alignment: textView.textAlignment)
        textView.typingAttributes = attributes
        if !textView.text.isEmpty {
            textView.attributedText = NSAttributedString(string: textView.text, attributes: attributes)
            textView.selectedRange = selectedRange
        }
        (textView as? CraftNativeTextView)?.refreshPlaceholder()
        updateHandler(nonEmptyHandler(events["onChange"]) ?? nonEmptyHandler(events["onChangeText"]), for: textView)
        updateAuxiliaryHandler(events["onFocus"], in: &focusHandlers, for: textView)
        updateAuxiliaryHandler(events["onBlur"], in: &blurHandlers, for: textView)
        updateAuxiliaryHandler(events["onEndEditing"], in: &endEditingHandlers, for: textView)
        updateAuxiliaryHandler(events["onSubmitEditing"], in: &submitHandlers, for: textView)
        if props["autoFocus"] as? Bool == true, !textView.isFirstResponder {
            DispatchQueue.main.async { _ = textView.becomeFirstResponder() }
        }
    }

    /// `<Icon symbol="sun.max">`: an SF Symbol, tinted by `color`, sized by
    /// `fontSize` or else the icon's box, weighted by `fontWeight`. A name
    /// the system does not have draws `circle`, so a typo shows rather than
    /// leaving a hole.
    private func configureIcon(_ icon: UIImageView, props: [String: Any], style: [String: Any]) {
        let name = (props["symbol"] as? String) ?? (props["name"] as? String) ?? ""
        let box = [number(style["width"]), number(style["height"])].compactMap { $0 }.min()
        let fontSize = number(style["fontSize"])
        // Without a size of its own an icon is a 20 pt square (contract A2).
        (icon as? CraftNativeIconView)?.defaultBox = box == nil && fontSize == nil ? 20 : nil
        let pointSize = fontSize ?? (box ?? 20) * 0.84
        let weight: UIImage.SymbolWeight
        switch style["fontWeight"] as? String {
        case "100": weight = .ultraLight
        case "200": weight = .thin
        case "300": weight = .light
        case "500": weight = .medium
        case "600": weight = .semibold
        case "bold", "700": weight = .bold
        case "800": weight = .heavy
        case "900": weight = .black
        default: weight = .regular
        }
        let scale: UIImage.SymbolScale
        switch props["scale"] as? String {
        case "small": scale = .small
        case "large": scale = .large
        default: scale = .medium
        }
        let configuration = UIImage.SymbolConfiguration(pointSize: max(1, pointSize), weight: weight, scale: scale)
        let image = UIImage(systemName: name, withConfiguration: configuration)
            ?? UIImage(systemName: "circle", withConfiguration: configuration)
        if icon.image != image { icon.image = image }
        icon.preferredSymbolConfiguration = configuration
        icon.tintColor = color(style["color"]) ?? color(props["color"]) ?? .label
        icon.contentMode = .scaleAspectFit
    }

    private func configureStack(_ stack: CraftNativeFlowView, style: [String: Any]) {
        let direction = style["flexDirection"] as? String
        stack.axis = direction == "row" || direction == "row-reverse" ? .horizontal : .vertical
        stack.reverse = direction?.hasSuffix("-reverse") == true
        let flexWrap = style["flexWrap"] as? String
        stack.wrap = flexWrap == "wrap" || flexWrap == "wrap-reverse" || style["flexWrap"] as? Bool == true
        stack.wrapReverse = flexWrap == "wrap-reverse"
        stack.alignItems = style["alignItems"] as? String ?? "stretch"
        stack.alignContent = style["alignContent"] as? String ?? "flex-start"
        stack.justifyContent = style["justifyContent"] as? String ?? "flex-start"
        let gap = max(0, number(style["gap"]) ?? 0)
        stack.gap = gap
        stack.rowGap = max(0, number(style["rowGap"]) ?? gap)
        stack.columnGap = max(0, number(style["columnGap"]) ?? gap)
        stack.grid = style["display"] as? String == "grid"
        stack.gridColumns = craftNativeGridColumnCount(style["gridTemplateColumns"] ?? style["gridColumns"])
        stack.gridAutoRows = CraftNativeLength(style["gridAutoRows"])
        stack.padding = paddingInsets(style)
        stack.invalidateMeasurements()
    }

    private func addJustificationSpacers(to stack: CraftNativeFlowView, value: String?) { }

    private func applyViewStyle(_ style: [String: Any], to view: UIView, node: RenderedNode) {
        let width = style["minWidth"] == nil && style["maxWidth"] == nil ? number(style["width"]) : nil
        let height = style["minHeight"] == nil && style["maxHeight"] == nil ? number(style["height"]) : nil
        updateDimension(width, constraint: &node.widthConstraint, anchor: view.widthAnchor)
        updateDimension(height, constraint: &node.heightConstraint, anchor: view.heightAnchor)
        view.backgroundColor = color(style["backgroundColor"]) ?? .clear
        // A field the style dresses itself (`border-0`, a border or a
        // background, as a search field inside its own pill is) draws no
        // system box of its own; a bare one keeps the rounded rectangle.
        if let field = view as? UITextField {
            field.borderStyle = style["borderWidth"] != nil || style["backgroundColor"] != nil ? .none : .roundedRect
        }
        CraftNativeGradientLayer.apply(
            to: view,
            direction: style["gradientDirection"] as? String,
            colors: [color(style["gradientFrom"]), color(style["gradientVia"]), color(style["gradientTo"])]
        )
        view.alpha = number(style["opacity"]) ?? 1
        view.isHidden = style["display"] as? String == "none"
        let borderRadius = number(style["borderRadius"]) ?? 0
        let cornerRadiusKeys = ["borderTopLeftRadius", "borderTopRightRadius", "borderBottomRightRadius", "borderBottomLeftRadius"]
        let hasCornerRadii = cornerRadiusKeys.contains { style[$0] != nil }
        view.craftRequestedCornerRadius = borderRadius
        view.craftRequestedCornerRadii = hasCornerRadii
            ? cornerRadiusKeys.map { number(style[$0]) ?? borderRadius }
            : nil
        let borderWidth = number(style["borderWidth"]) ?? 0
        let borderColor = color(style["borderColor"]) ?? .clear
        let sideWidthKeys = ["borderTopWidth", "borderRightWidth", "borderBottomWidth", "borderLeftWidth"]
        let sideColorKeys = ["borderTopColor", "borderRightColor", "borderBottomColor", "borderLeftColor"]
        view.craftApplySideBorders(
            (sideWidthKeys + sideColorKeys).contains { style[$0] != nil },
            style: style["borderStyle"] as? String,
            widths: sideWidthKeys.map { number(style[$0]) ?? borderWidth },
            colors: sideColorKeys.map { color(style[$0]) ?? borderColor }
        )
        view.layer.zPosition = number(style["zIndex"]) ?? 0
        applyTransform(style["transform"], to: view)
        let elevation = max(0, number(style["elevation"]) ?? 0)
        let shadowColor = color(style["shadowColor"]) ?? .black
        let shadowOpacity = min(1, max(0, number(style["shadowOpacity"]) ?? (elevation > 0 ? min(0.28, 0.12 + elevation * 0.02) : 0)))
        let shadowRadius = max(0, number(style["shadowRadius"]) ?? elevation * 0.5)
        let shadowOffset = style["shadowOffset"] as? [String: Any]
        view.layer.shadowColor = shadowColor.cgColor
        view.layer.shadowOpacity = Float(shadowOpacity)
        view.layer.shadowRadius = shadowRadius
        view.layer.shadowOffset = CGSize(
            width: number(shadowOffset?["width"]) ?? 0,
            height: number(shadowOffset?["height"]) ?? (elevation * 0.25)
        )
        // A label paints its background inside its own bounds, so a rounded
        // chip of text clips to its corners.
        // A scroll view does not clip either: its content runs on under the
        // floating tab bar and the home indicator, as iOS 26's own screens'
        // does. At the top, a screen that starts with one runs edge to edge
        // (trackContentScrollView), so nothing scrolls over the bar.
        view.clipsToBounds = style["overflow"] as? String == "hidden"
            || (view is UILabel && (view.craftRequestedCornerRadius ?? 0) > 0)
        view.layer.masksToBounds = view.clipsToBounds
        view.craftLayoutStyle = CraftNativeLayoutStyle(style)
        (view as? CraftNativeFlowView)?.invalidateMeasurements()
        (view as? CraftNativeScrollView)?.setContentNeedsLayout()
    }

    private func paddingInsets(_ style: [String: Any]) -> UIEdgeInsets {
        func nonNegative(_ value: Any?) -> CGFloat? {
            guard let value = number(value), value >= 0 else { return nil }
            return value
        }
        let padding = nonNegative(style["padding"]) ?? 0
        let horizontal = nonNegative(style["paddingHorizontal"]) ?? padding
        let vertical = nonNegative(style["paddingVertical"]) ?? padding
        return UIEdgeInsets(
            top: nonNegative(style["paddingTop"]) ?? vertical,
            left: nonNegative(style["paddingLeft"]) ?? horizontal,
            bottom: nonNegative(style["paddingBottom"]) ?? vertical,
            right: nonNegative(style["paddingRight"]) ?? horizontal
        )
    }

    private func applyTransform(_ raw: Any?, to view: UIView) {
        view.transform = .identity
        view.layer.transform = CATransform3DIdentity
        guard let transforms = raw as? [[String: Any]] else { return }
        var affine = CGAffineTransform.identity
        var threeDimensional = CATransform3DIdentity
        var hasThreeDimensionalRotation = false
        for transform in transforms {
            if let value = number(transform["translateX"]) { affine = affine.translatedBy(x: value, y: 0) }
            if let value = number(transform["translateY"]) { affine = affine.translatedBy(x: 0, y: value) }
            if let value = number(transform["scale"]) { affine = affine.scaledBy(x: value, y: value) }
            if let value = number(transform["scaleX"]) { affine = affine.scaledBy(x: value, y: 1) }
            if let value = number(transform["scaleY"]) { affine = affine.scaledBy(x: 1, y: value) }
            if let value = transformAngle(transform["rotate"] ?? transform["rotateZ"]) { affine = affine.rotated(by: value) }
            if let value = transformAngle(transform["skewX"]) { affine = affine.concatenating(CGAffineTransform(a: 1, b: 0, c: tan(value), d: 1, tx: 0, ty: 0)) }
            if let value = transformAngle(transform["skewY"]) { affine = affine.concatenating(CGAffineTransform(a: 1, b: tan(value), c: 0, d: 1, tx: 0, ty: 0)) }
            if let value = transformAngle(transform["rotateX"]) {
                threeDimensional = CATransform3DRotate(threeDimensional, value, 1, 0, 0)
                hasThreeDimensionalRotation = true
            }
            if let value = transformAngle(transform["rotateY"]) {
                threeDimensional = CATransform3DRotate(threeDimensional, value, 0, 1, 0)
                hasThreeDimensionalRotation = true
            }
        }
        if hasThreeDimensionalRotation {
            view.layer.transform = CATransform3DConcat(CATransform3DMakeAffineTransform(affine), threeDimensional)
        } else {
            view.transform = affine
        }
    }

    private func transformAngle(_ raw: Any?) -> CGFloat? {
        if let value = number(raw) { return value }
        guard let text = raw as? String else { return nil }
        if text.hasSuffix("rad") { return CGFloat(Double(text.dropLast(3)) ?? 0) }
        if text.hasSuffix("deg") { return CGFloat((Double(text.dropLast(3)) ?? 0) * .pi / 180) }
        // Keep the conversion explicit: newer Swift toolchains see both the
        // CGFloat(Double) and CGFloat(Float) initializers through map and
        // reject the overloaded constructor reference.
        return Double(text).map { CGFloat($0) }
    }

    private func configureText(_ label: UILabel, text: String, style: [String: Any]) {
        let transformed = transformedText(text, style: style)
        label.textColor = color(style["color"]) ?? .label
        label.font = textFont(style, default: .systemFont(ofSize: 16))
        label.textAlignment = textAlignment(style["textAlign"])
        var attributes: [NSAttributedString.Key: Any] = [:]
        if let spacing = number(style["letterSpacing"]) { attributes[.kern] = spacing }
        addTextDecorationAttributes(style, to: &attributes)
        if let shadow = textShadow(style) { attributes[.shadow] = shadow }
        if let lineHeight = number(style["lineHeight"]) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.minimumLineHeight = lineHeight
            paragraph.maximumLineHeight = lineHeight
            paragraph.alignment = label.textAlignment
            attributes[.paragraphStyle] = paragraph
        }
        let alignment = label.textAlignment
        let lineBreakMode = label.lineBreakMode
        label.attributedText = attributes.isEmpty ? nil : NSAttributedString(string: transformed, attributes: attributes)
        if attributes.isEmpty { label.text = transformed }
        // Attributed text brings its own paragraph style, which resets the
        // label's alignment and truncation; set them again over the whole text.
        label.textAlignment = alignment
        label.lineBreakMode = lineBreakMode
    }

    private func textLineBreakMode(_ value: Any?) -> NSLineBreakMode {
        switch value as? String {
        case "head": return .byTruncatingHead
        case "middle": return .byTruncatingMiddle
        case "tail": return .byTruncatingTail
        case "clip": return .byClipping
        default: return .byTruncatingTail
        }
    }

    private func buttonTitleAttributes(
        _ style: [String: Any],
        color: UIColor,
        font: UIFont,
        forceUnderline: Bool
    ) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .font: font,
        ]
        if let spacing = number(style["letterSpacing"]) { attributes[.kern] = spacing }
        if let lineHeight = number(style["lineHeight"]) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.minimumLineHeight = lineHeight
            paragraph.maximumLineHeight = lineHeight
            attributes[.paragraphStyle] = paragraph
        }
        addTextDecorationAttributes(style, to: &attributes)
        if let shadow = textShadow(style) { attributes[.shadow] = shadow }
        if forceUnderline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        return attributes
    }

    private func inputTextAttributes(
        _ style: [String: Any],
        font: UIFont,
        alignment: NSTextAlignment
    ) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: color(style["color"]) ?? .label,
            .font: font,
        ]
        if let spacing = number(style["letterSpacing"]) { attributes[.kern] = spacing }
        if let lineHeight = number(style["lineHeight"]) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.minimumLineHeight = lineHeight
            paragraph.maximumLineHeight = lineHeight
            paragraph.alignment = alignment
            attributes[.paragraphStyle] = paragraph
        }
        addTextDecorationAttributes(style, to: &attributes)
        if let shadow = textShadow(style) { attributes[.shadow] = shadow }
        return attributes
    }

    private func textShadow(_ style: [String: Any]) -> NSShadow? {
        guard let shadowColor = color(style["textShadowColor"]) else { return nil }
        let offset = style["textShadowOffset"] as? [String: Any]
        let shadow = NSShadow()
        shadow.shadowColor = shadowColor
        shadow.shadowOffset = CGSize(
            width: number(offset?["width"]) ?? 0,
            height: number(offset?["height"]) ?? 0
        )
        shadow.shadowBlurRadius = max(0, number(style["textShadowRadius"]) ?? 0)
        return shadow
    }

    private func addTextDecorationAttributes(_ style: [String: Any], to attributes: inout [NSAttributedString.Key: Any]) {
        let line = style["textDecorationLine"] as? String
        let decorationStyle: NSUnderlineStyle = {
            switch style["textDecorationStyle"] as? String {
            case "double": return .double
            case "dotted": return [.single, .patternDot]
            case "dashed": return [.single, .patternDash]
            default: return .single
            }
        }()
        let rawStyle = decorationStyle.rawValue
        let decorationColor = color(style["textDecorationColor"])
        if line == "underline" || line == "underline line-through" {
            attributes[.underlineStyle] = rawStyle
            if let decorationColor { attributes[.underlineColor] = decorationColor }
        }
        if line == "line-through" || line == "underline line-through" {
            attributes[.strikethroughStyle] = rawStyle
            if let decorationColor { attributes[.strikethroughColor] = decorationColor }
        }
    }

    private func transformedText(_ text: String, style: [String: Any]) -> String {
        switch style["textTransform"] as? String {
        case "uppercase": return text.uppercased()
        case "lowercase": return text.lowercased()
        case "capitalize": return text.split(separator: " ", omittingEmptySubsequences: false).map { word in
            guard let first = word.first else { return String(word) }
            return String(first).uppercased() + String(word.dropFirst())
        }.joined(separator: " ")
        default: return text
        }
    }

    private func textFont(_ style: [String: Any], default fallback: UIFont) -> UIFont {
        let size = number(style["fontSize"]) ?? fallback.pointSize
        let weight: UIFont.Weight
        switch style["fontWeight"] as? String {
        case "100": weight = .ultraLight
        case "200": weight = .thin
        case "300": weight = .light
        case "500": weight = .medium
        case "600": weight = .semibold
        case "bold", "700": weight = .bold
        case "800": weight = .heavy
        case "900": weight = .black
        default: weight = .regular
        }
        var font = (style["fontFamily"] as? String).flatMap { UIFont(name: $0, size: size) }
            ?? .systemFont(ofSize: size, weight: weight)
        if style["fontStyle"] as? String == "italic",
           let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) {
            font = UIFont(descriptor: descriptor, size: size)
        }
        return font
    }

    private func textAlignment(_ value: Any?) -> NSTextAlignment {
        switch value as? String {
        case "left": return .left
        case "right": return .right
        case "center": return .center
        case "justify": return .justified
        default: return .natural
        }
    }

    private func buttonAlignment(_ value: Any?) -> UIControl.ContentHorizontalAlignment {
        switch value as? String {
        case "left": return .left
        case "right": return .right
        case "center": return .center
        default: return .center
        }
    }

    private func imageContentMode(_ value: Any?) -> UIView.ContentMode {
        switch value as? String {
        case "cover": return .scaleAspectFill
        case "stretch": return .scaleToFill
        case "center": return .center
        default: return .scaleAspectFit
        }
    }

    private func keyboardDismissMode(_ value: Any?) -> UIScrollView.KeyboardDismissMode {
        switch value as? String {
        case "on-drag": return .onDrag
        case "interactive": return .interactive
        default: return .none
        }
    }

    /// An image the screen downloads: https anywhere, and http only from this
    /// machine (localhost, 127.0.0.1, ::1, *.localhost), the development
    /// server the app's ATS exception already allows. Internal for XCTest.
    static func loadsImage(from url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        if scheme == "https" { return true }
        guard scheme == "http", let host = url.host?.lowercased() else { return false }
        let bare = host.hasPrefix("[") && host.hasSuffix("]") ? String(host.dropFirst().dropLast()) : host
        return ["localhost", "127.0.0.1", "::1"].contains(bare) || bare.hasSuffix(".localhost")
    }

    private func updateImage(_ view: UIImageView, source: Any?, defaultSource: Any? = nil) {
        let uri = (source as? String) ?? (source as? [String: Any])?["uri"] as? String
        let id = ObjectIdentifier(view)
        guard let uri, !uri.isEmpty else {
            if imageSources[id] == "" { return }
            imageTasks.removeValue(forKey: id)?.cancel()
            imageSources[id] = ""
            imageFailure(view, uri: nil, message: "Image source is missing")
            return
        }
        guard imageSources[id] != uri else { return }
        imageTasks.removeValue(forKey: id)?.cancel()
        imageSources[id] = uri
        imageErrors.removeValue(forKey: id)
        view.image = immediateImage(defaultSource).map { imageForDisplay($0, view: view) }
        imageDidChange(view)
        view.accessibilityValue = nil
        emitImageEvent(view, handler: imageLoadStartHandlers[id])

        if uri.hasPrefix("data:image/") {
            guard let comma = uri.firstIndex(of: ","),
                  let data = Data(base64Encoded: String(uri[uri.index(after: comma)...])),
                  let image = UIImage(data: data) else {
                imageFailure(view, uri: uri, message: "Image data is invalid")
                return
            }
            view.image = imageForDisplay(image, view: view)
            imageDidChange(view)
            emitImageEvent(view, handler: imageLoadHandlers[id])
            emitImageEvent(view, handler: imageLoadEndHandlers[id])
            return
        }
        if let url = URL(string: uri), Self.loadsImage(from: url) {
            let task = URLSession.shared.dataTask(with: url) { [weak self, weak view] data, _, _ in
                guard let self, let view else { return }
                DispatchQueue.main.async {
                    guard self.imageSources[ObjectIdentifier(view)] == uri else { return }
                    self.imageTasks.removeValue(forKey: ObjectIdentifier(view))
                    guard let data, let image = UIImage(data: data) else {
                        self.imageFailure(view, uri: uri, message: "Image download failed")
                        return
                    }
                    view.image = self.imageForDisplay(image, view: view)
                    self.imageDidChange(view)
                    self.emitImageEvent(view, handler: self.imageLoadHandlers[ObjectIdentifier(view)])
                    self.emitImageEvent(view, handler: self.imageLoadEndHandlers[ObjectIdentifier(view)])
                }
            }
            imageTasks[id] = task
            task.resume()
            return
        }
        if !uri.contains(":") {
            guard let image = UIImage(named: uri) else {
                imageFailure(view, uri: uri, message: "Bundled image was not found")
                return
            }
            view.image = imageForDisplay(image, view: view)
            imageDidChange(view)
            emitImageEvent(view, handler: imageLoadHandlers[id])
            emitImageEvent(view, handler: imageLoadEndHandlers[id])
            return
        }
        imageFailure(view, uri: uri, message: "Unsupported image source")
    }

    /// `defaultSource` is intentionally local-only: data and bundled assets
    /// can be shown before a network image arrives without starting another
    /// request or bypassing the source's URL policy.
    private func immediateImage(_ source: Any?) -> UIImage? {
        let uri = (source as? String) ?? (source as? [String: Any])?["uri"] as? String
        guard let uri, !uri.isEmpty else { return nil }
        if uri.hasPrefix("data:image/"),
           let comma = uri.firstIndex(of: ","),
           let data = Data(base64Encoded: String(uri[uri.index(after: comma)...])) {
            return UIImage(data: data)
        }
        return !uri.contains(":") ? UIImage(named: uri) : nil
    }

    private func imageFailure(_ view: UIImageView, uri: String?, message: String) {
        imageErrors[ObjectIdentifier(view)] = message
        view.image = nil
        imageDidChange(view)
        view.accessibilityValue = message
        let id = ObjectIdentifier(view)
        emitImageEvent(view, handler: imageErrorHandlers[id], nativeEvent: ["error": ["message": message]])
        emitImageEvent(view, handler: imageLoadEndHandlers[id])
        NSLog("[craft native] %@: %@", message, uri ?? "<missing>")
    }

    private func imageDidChange(_ view: UIImageView) {
        view.invalidateIntrinsicContentSize()
        CraftNativeFlexLayout.invalidateAncestors(of: view)
    }

    private func imageForDisplay(_ image: UIImage, view: UIImageView) -> UIImage {
        image.withRenderingMode(tintedImages.contains(ObjectIdentifier(view)) ? .alwaysTemplate : .alwaysOriginal)
    }

    private func emitImageEvent(
        _ view: UIImageView,
        handler: String?,
        nativeEvent: [String: Any] = [:]
    ) {
        guard let handler, !handler.isEmpty else { return }
        send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": nativeEvent])
    }

    private func applyAccessibility(_ props: [String: Any], type: String, to view: UIView) {
        view.accessibilityLabel = (props["accessibilityLabel"] as? String)
            ?? ((type == "Image" || type == "ImageBackground") ? props["alt"] as? String : nil)
        view.accessibilityHint = props["accessibilityHint"] as? String
        if let value = props["accessibilityValue"] {
            view.accessibilityValue = (value as? String) ?? (value as? NSNumber)?.stringValue
        } else if type != "TextInput" {
            view.accessibilityValue = nil
        }
        let role = props["accessibilityRole"] as? String
        view.isAccessibilityElement = role != "none" && (view.accessibilityLabel != nil || role != nil || ["Text", "Button", "Link", "Checkbox", "Image", "ImageBackground", "Video", "TextInput", "Picker", "DatePicker", "Switch", "Slider"].contains(type))
        var traits: UIAccessibilityTraits = []
        switch role ?? type.lowercased() {
        case "button", "checkbox": traits.insert(.button)
        case "image": traits.insert(.image)
        case "header": traits.insert(.header)
        case "link": traits.insert(.link)
        case "search": traits.insert(.searchField)
        default: break
        }
        if let state = props["accessibilityState"] as? [String: Any] {
            if state["disabled"] as? Bool == true {
                traits.insert(.notEnabled)
                if let control = view as? UIControl {
                    control.isEnabled = false
                } else if handlers[ObjectIdentifier(view)] != nil || longPressHandlers[ObjectIdentifier(view)] != nil {
                    view.isUserInteractionEnabled = false
                }
            }
            if state["selected"] as? Bool == true { traits.insert(.selected) }
            if state["checked"] as? Bool == true { traits.insert(.selected) }
        }
        if let control = view as? UIControl, !control.isEnabled { traits.insert(.notEnabled) }
        // A disabled Pressable or touchable takes no touches; it says so too.
        if props["disabled"] as? Bool == true { traits.insert(.notEnabled) }
        if type == "Checkbox", let checkbox = view as? CraftNativeCheckboxButton {
            if checkbox.isSelected { traits.insert(.selected) }
            view.accessibilityValue = checkbox.indeterminate ? "mixed" : checkbox.isSelected ? "checked" : "unchecked"
        }
        if (type == "Image" || type == "ImageBackground"), let message = imageErrors[ObjectIdentifier(view)] {
            let current = view.accessibilityValue
            if current?.contains(message) != true {
                view.accessibilityValue = [current, message].compactMap { $0 }.joined(separator: ", ")
            }
        }
        // A multiline TextInput is a UITextView, which works out its traits
        // as it goes: while it has the keyboard they say it is editing, and
        // that is what UI tests and VoiceOver read focus from. Setting them
        // froze them, so it read as static text that never had focus ("neither
        // element nor any descendant has keyboard focus"); it keeps its own.
        if view is UITextView { return }
        view.accessibilityTraits = traits
    }

    private func updateDimension(_ value: CGFloat?, constraint: inout NSLayoutConstraint?, anchor: NSLayoutDimension) {
        if let value = value {
            if let constraint = constraint { constraint.constant = value }
            else {
                // Below required: the flex layout owns frames, and a width
                // the layout stretches or shrinks must not log a conflict.
                constraint = anchor.constraint(equalToConstant: value)
                constraint?.priority = UILayoutPriority(999)
                constraint?.isActive = true
            }
        } else {
            constraint?.isActive = false
            constraint = nil
        }
    }

    @objc private func buttonPressed(_ sender: UIButton) {
        let focused = firstResponder(in: rootStack) ?? lastFocusedInput
        if let target = linkTargets[ObjectIdentifier(sender)] {
            hybridEvents?.nativeScreen(self, open: target)
            return
        }
        guard let handler = handlers[ObjectIdentifier(sender)] else { return }
        send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": [:]])
        restoreFocus(focused)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak focused] in
            self?.restoreFocus(focused)
        }
    }

    @objc private func checkboxPressed(_ sender: CraftNativeCheckboxButton) {
        sender.indeterminate = false
        checkboxIndeterminate[ObjectIdentifier(sender)] = false
        sender.isSelected.toggle()
        if let handler = handlers[ObjectIdentifier(sender)] {
            send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": ["value": sender.isSelected]])
        }
        applyAccessibility([:], type: "Checkbox", to: sender)
    }

    /// Return on a `returnKeyType="next"` field the screen does not handle
    /// itself (no `@submit`) goes to the next field down the screen, keeping
    /// the keyboard up. Every other Return ends editing and fires `@submit`.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard textField.returnKeyType == .next, submitHandlers[ObjectIdentifier(textField)] == nil,
              let next = inputAfter(textField) else { return true }
        next.becomeFirstResponder()
        return false
    }

    /// The editable field after `input` in the screen's document order.
    /// Internal for XCTest.
    func inputAfter(_ input: UIView) -> UIView? {
        var inputs: [UIView] = []
        func collect(_ node: RenderedNode?) {
            guard let node else { return }
            if let field = node.view as? UITextField, field.isEnabled, !field.isHidden { inputs.append(field) }
            if let textView = node.view as? UITextView, textView.isEditable, !textView.isHidden { inputs.append(textView) }
            node.children.forEach(collect)
        }
        collect(renderedRoot)
        guard let index = inputs.firstIndex(where: { $0 === input }), index + 1 < inputs.count else { return nil }
        return inputs[index + 1]
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let maxLength = textMaxLengths[ObjectIdentifier(textField)],
              let current = textField.text,
              let stringRange = Range(range, in: current) else { return true }
        return current.replacingCharacters(in: stringRange, with: string).utf16.count <= maxLength
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n", let handler = submitHandlers[ObjectIdentifier(textView)] {
            send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": ["text": textView.text ?? ""]])
        }
        guard let maxLength = textMaxLengths[ObjectIdentifier(textView)],
              let current = textView.text,
              let stringRange = Range(range, in: current) else { return true }
        return current.replacingCharacters(in: stringRange, with: text).utf16.count <= maxLength
    }

    func textViewDidChange(_ textView: UITextView) {
        lastFocusedInput = textView
        let id = ObjectIdentifier(textView)
        inputIdentities[id].map { inputDrafts[$0] = textView.text ?? "" }
        (textView as? CraftNativeTextView)?.refreshPlaceholder()
        guard let handler = handlers[id] else { return }
        send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": ["text": textView.text ?? ""]])
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        lastFocusedInput = textView
        if keyboardScreenFrame != nil { DispatchQueue.main.async { self.scrollFocusedInputIntoView(animated: true) } }
        guard let handler = focusHandlers[ObjectIdentifier(textView)] else { return }
        send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": ["text": textView.text ?? ""]])
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        let id = ObjectIdentifier(textView)
        let nativeEvent: [String: Any] = ["text": textView.text ?? ""]
        if let handler = blurHandlers[id] {
            send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": nativeEvent])
        }
        if let handler = endEditingHandlers[id] {
            send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": nativeEvent])
        }
    }

    @objc private func textChanged(_ sender: UITextField) {
        lastFocusedInput = sender
        let id = ObjectIdentifier(sender)
        inputIdentities[id].map { inputDrafts[$0] = sender.text ?? "" }
        let focused = sender.isFirstResponder ? sender : firstResponder(in: rootStack)
        guard let handler = handlers[id] else { return }
        send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": ["text": sender.text ?? ""]])
        restoreFocus(focused)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak focused] in
            self?.restoreFocus(focused)
        }
    }

    @objc private func switchChanged(_ sender: UISwitch) {
        guard let handler = handlers[ObjectIdentifier(sender)] else { return }
        send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": ["value": sender.isOn]])
    }

    @objc private func sliderChanged(_ sender: UISlider) {
        let value = snappedSliderValue(sender.value, for: sender)
        if sender.value != value { sender.value = value }
        guard let handler = handlers[ObjectIdentifier(sender)] else { return }
        send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": ["value": Self.sliderEventValue(value, step: sliderSteps[ObjectIdentifier(sender)])]])
    }

    /// A slider's value as the script reads it. UISlider keeps a Float, and a
    /// step of 0.1 counted up in Floats lands beside the decimal (0.8 read as
    /// 0.800000011920929, nine steps as 0.90000004), so the value is the
    /// shortest decimal for that Float, rounded to as many places as the step
    /// has.
    static func sliderEventValue(_ value: Float, step: Float? = nil) -> Double {
        let decimal = Double(value.description) ?? Double(value)
        guard let step, step > 0, step.isFinite else { return decimal }
        // "0.1" is one place, "0.25" two, "1.0" none; a step as small as
        // "1e-07" is held to six.
        let fraction = step.description.split(separator: ".").dropFirst().first
        let places = step.description.contains("e") ? 6 : min(6, fraction.map { $0 == "0" ? 0 : $0.count } ?? 0)
        let scale = pow(10, Double(places))
        return (decimal * scale).rounded() / scale
    }

    /// `@change` on a DatePicker: the value as `<input type="date|time|
    /// datetime-local">` writes it, in local time, with the moment as ISO and
    /// milliseconds for code that wants those.
    @objc private func datePicked(_ sender: UIDatePicker) {
        guard let handler = handlers[ObjectIdentifier(sender)] else { return }
        send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": Self.datePickerEvent(sender)])
    }

    static func datePickerEvent(_ picker: UIDatePicker) -> [String: Any] {
        if picker.datePickerMode == .countDownTimer { return countdownEvent(picker.countDownDuration) }
        return datePickerEvent(picker.date, mode: picker.datePickerMode)
    }

    static func countdownEvent(_ duration: TimeInterval) -> [String: Any] {
        let totalSeconds = max(0, Int(duration.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return [
            "value": String(format: "%02d:%02d:%02d", hours, minutes, seconds),
            "iso": "PT\(totalSeconds)S",
            "timestamp": Double(totalSeconds * 1000),
        ]
    }

    static func datePickerEvent(_ date: Date, mode: UIDatePicker.Mode) -> [String: Any] {
        let local = DateFormatter()
        local.locale = Locale(identifier: "en_US_POSIX")
        local.calendar = Calendar(identifier: .gregorian)
        local.timeZone = .current
        local.dateFormat = mode == .date ? "yyyy-MM-dd" : mode == .time ? "HH:mm" : "yyyy-MM-dd'T'HH:mm"
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return [
            "value": local.string(from: date),
            "iso": iso.string(from: date),
            "timestamp": (date.timeIntervalSince1970 * 1000).rounded(),
        ]
    }

    static func datePickerMode(_ value: Any?) -> UIDatePicker.Mode {
        switch value as? String {
        case "time": return .time
        case "datetime", "dateAndTime", "datetime-local": return .dateAndTime
        case "countdown": return .countDownTimer
        default: return .date
        }
    }

    /// Countdown values use seconds when numeric, or `HH:mm[:ss]` text.
    static func countdownDuration(_ value: Any?) -> TimeInterval? {
        let maximum: TimeInterval = 23 * 3600 + 59 * 60 + 59
        if let number = value as? NSNumber, !(value is Bool) {
            let seconds = number.doubleValue
            guard seconds.isFinite else { return nil }
            return min(maximum, max(0, seconds))
        }
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        if let seconds = Double(text), seconds.isFinite { return min(maximum, max(0, seconds)) }
        let parts = text.split(separator: ":")
        guard parts.count == 2 || parts.count == 3,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]) else { return nil }
        let seconds = parts.count == 3 ? (Double(parts[2]) ?? -1) : 0
        guard hours.isFinite, minutes.isFinite, seconds.isFinite,
              hours >= 0, minutes >= 0, minutes < 60, seconds >= 0, seconds < 60 else { return nil }
        return min(maximum, hours * 3600 + minutes * 60 + seconds)
    }

    /// A DatePicker's value: `2026-10-12` (that day), `07:30` (today at that
    /// time), `2026-10-12T07:30` (local), a full ISO 8601 string, or
    /// milliseconds since 1970. Nil for anything else.
    static func pickerDate(_ value: Any?) -> Date? {
        if let number = value as? NSNumber, !(value is Bool) {
            let milliseconds = number.doubleValue
            guard milliseconds.isFinite else { return nil }
            return Date(timeIntervalSince1970: milliseconds / 1000)
        }
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        let local = DateFormatter()
        local.locale = Locale(identifier: "en_US_POSIX")
        local.calendar = Calendar(identifier: .gregorian)
        local.timeZone = .current
        for format in ["HH:mm", "HH:mm:ss"] {
            local.dateFormat = format
            if let time = local.date(from: text) {
                let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: time)
                return Calendar.current.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: parts.second ?? 0, of: Date())
            }
        }
        for format in ["yyyy-MM-dd", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss.SSS"] {
            local.dateFormat = format
            if let date = local.date(from: text) { return date }
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: text) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: text)
    }

    @objc private func sliderFinished(_ sender: UISlider) {
        guard let handler = sliderCompleteHandlers[ObjectIdentifier(sender)] else { return }
        send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": ["value": Self.sliderEventValue(snappedSliderValue(sender.value, for: sender), step: sliderSteps[ObjectIdentifier(sender)])]])
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        pickerOptions[ObjectIdentifier(pickerView)]?.count ?? 0
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        guard let options = pickerOptions[ObjectIdentifier(pickerView)], options.indices.contains(row) else { return nil }
        return options[row].label
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        guard let options = pickerOptions[ObjectIdentifier(pickerView)], options.indices.contains(row),
              let handler = handlers[ObjectIdentifier(pickerView)] else { return }
        let option = options[row]
        send(type: "EVENT", payload: [
            "handlerName": handler,
            "nativeEvent": ["value": option.value, "index": row],
        ])
    }

    @objc private func textFocused(_ sender: UITextField) {
        lastFocusedInput = sender
        // Moving between fields does not move the keyboard, so nothing else
        // brings the next one up from under it.
        if keyboardScreenFrame != nil { DispatchQueue.main.async { self.scrollFocusedInputIntoView(animated: true) } }
        guard let handler = focusHandlers[ObjectIdentifier(sender)] else { return }
        send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": ["text": sender.text ?? ""]])
    }

    @objc private func textBlurred(_ sender: UITextField) {
        let id = ObjectIdentifier(sender)
        let nativeEvent: [String: Any] = ["text": sender.text ?? ""]
        if let handler = blurHandlers[id] {
            send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": nativeEvent])
        }
        if let handler = endEditingHandlers[id] {
            send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": nativeEvent])
        }
    }

    @objc private func textSubmitted(_ sender: UITextField) {
        // Return put the keyboard away.
        forgetFocusedInput(sender)
        guard let handler = submitHandlers[ObjectIdentifier(sender)] else { return }
        send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": ["text": sender.text ?? ""]])
    }

    @objc private func viewPressed(_ sender: UITapGestureRecognizer) {
        guard let view = sender.view else { return }
        let id = ObjectIdentifier(view)
        if let target = linkTargets[id] {
            hybridEvents?.nativeScreen(self, open: target)
            return
        }
        guard let handler = handlers[id] else { return }
        if pressInHandlers[id] == nil, pressOutHandlers[id] == nil,
           let pressable = view as? CraftNativeFlowView, let activeOpacity = pressable.pressActiveOpacity {
            UIView.animate(withDuration: 0.1, animations: { pressable.alpha = pressable.pressBaseOpacity * activeOpacity }) { _ in
                UIView.animate(withDuration: 0.1) { pressable.alpha = pressable.pressBaseOpacity }
            }
        }
        send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": [:]])
    }

    @objc private func viewPressFeedback(_ sender: UILongPressGestureRecognizer) {
        guard let view = sender.view else { return }
        let id = ObjectIdentifier(view)
        switch sender.state {
        case .began:
            if let pressable = view as? CraftNativeFlowView, let activeOpacity = pressable.pressActiveOpacity {
                UIView.animate(withDuration: 0.1) { pressable.alpha = pressable.pressBaseOpacity * activeOpacity }
            }
            if let handler = pressInHandlers[id] { send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": [:]]) }
        case .ended, .cancelled, .failed:
            if let pressable = view as? CraftNativeFlowView { UIView.animate(withDuration: 0.1) { pressable.alpha = pressable.pressBaseOpacity } }
            if let handler = pressOutHandlers[id] { send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": [:]]) }
        default:
            break
        }
    }

    @objc private func viewLongPressed(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began,
              let view = sender.view,
              let handler = longPressHandlers[ObjectIdentifier(view)] else { return }
        send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": [:]])
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let handler = scrollHandlers[ObjectIdentifier(scrollView)] else { return }
        send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": scrollEvent(scrollView)])
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard let handler = scrollBeginHandlers[ObjectIdentifier(scrollView)] else { return }
        send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": scrollEvent(scrollView)])
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard let handler = scrollEndHandlers[ObjectIdentifier(scrollView)] else { return }
        send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": scrollEvent(scrollView)])
    }

    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        guard let handler = scrollMomentumBeginHandlers[ObjectIdentifier(scrollView)] else { return }
        send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": scrollEvent(scrollView)])
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard let handler = scrollMomentumEndHandlers[ObjectIdentifier(scrollView)] else { return }
        send(type: "EVENT", payload: ["handlerName": handler, "nativeEvent": scrollEvent(scrollView)])
    }

    private func scrollEvent(_ scrollView: UIScrollView) -> [String: Any] {
        [
            "contentOffset": ["x": scrollView.contentOffset.x, "y": scrollView.contentOffset.y],
            "contentSize": ["width": scrollView.contentSize.width, "height": scrollView.contentSize.height],
            "layoutMeasurement": ["width": scrollView.bounds.width, "height": scrollView.bounds.height],
        ]
    }

    private func send(type: String, payload: [String: Any], correlationId: String? = nil) {
        var message: [String: Any] = ["type": type, "payload": payload]
        if let correlationId = correlationId { message["correlationId"] = correlationId }
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let json = String(data: data, encoding: .utf8) else { return }
        jsContext.objectForKeyedSubscript("__stxNativeCallback")?.call(withArguments: [json])
    }

    private func number(_ value: Any?) -> CGFloat? {
        guard let number = value as? NSNumber else { return nil }
        let value = CGFloat(truncating: number)
        return value.isFinite ? value : nil
    }

    private func keyboardType(_ value: Any?) -> UIKeyboardType {
        switch value as? String {
        case "email-address": return .emailAddress
        case "numeric", "number-pad": return .numberPad
        case "phone-pad": return .phonePad
        case "decimal-pad": return .decimalPad
        case "url": return .URL
        case "web-search": return .webSearch
        case "visible-password": return .asciiCapable
        case "ascii-capable": return .asciiCapable
        case "numbers-and-punctuation": return .numbersAndPunctuation
        case "name-phone-pad": return .namePhonePad
        case "twitter": return .twitter
        default: return .default
        }
    }

    /// What the field holds, for the system's autofill: `textContentType` in
    /// UITextContentType's names (`username`, `password`, `newPassword`,
    /// `oneTimeCode`...), or `autoComplete` in HTML's (`current-password`,
    /// `one-time-code`, `email`). A password field without it gets no
    /// Passwords suggestion above the keyboard.
    static func textContentType(_ props: [String: Any]) -> UITextContentType? {
        let raw = (props["textContentType"] as? String) ?? (props["autoComplete"] as? String) ?? (props["autocomplete"] as? String)
        guard let raw, !raw.isEmpty else { return nil }
        let key = raw.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "_", with: "").lowercased()
        switch key {
        case "username": return .username
        case "nickname": return .nickname
        case "password", "currentpassword": return .password
        case "newpassword": return .newPassword
        case "onetimecode": return .oneTimeCode
        case "emailaddress", "email": return .emailAddress
        case "telephonenumber", "tel", "phone": return .telephoneNumber
        case "name": return .name
        case "givenname", "firstname": return .givenName
        case "middlename", "additionalname": return .middleName
        case "familyname", "lastname": return .familyName
        case "nameprefix", "honorificprefix": return .namePrefix
        case "namesuffix", "honorificsuffix": return .nameSuffix
        case "organizationname", "organization": return .organizationName
        case "jobtitle", "organizationtitle": return .jobTitle
        case "url": return .URL
        case "fullstreetaddress", "streetaddress": return .fullStreetAddress
        case "streetaddressline1", "addressline1": return .streetAddressLine1
        case "streetaddressline2", "addressline2": return .streetAddressLine2
        case "addresscity", "addresslevel2": return .addressCity
        case "addressstate", "addresslevel1": return .addressState
        case "addresscityandstate": return .addressCityAndState
        case "postalcode": return .postalCode
        case "countryname", "country": return .countryName
        case "location": return .location
        case "creditcardnumber", "ccnumber": return .creditCardNumber
        default: return nil
        }
    }

    private func applyAutofill(to input: UITextInputTraits & UIView, props: [String: Any]) {
        let type = Self.textContentType(props)
        let rules = (props["passwordRules"] as? String).flatMap { $0.isEmpty ? nil : UITextInputPasswordRules(descriptor: $0) }
        if let field = input as? UITextField {
            if field.textContentType != type { field.textContentType = type }
            if field.passwordRules?.passwordRulesDescriptor != rules?.passwordRulesDescriptor { field.passwordRules = rules }
        } else if let textView = input as? UITextView {
            if textView.textContentType != type { textView.textContentType = type }
            if textView.passwordRules?.passwordRulesDescriptor != rules?.passwordRulesDescriptor { textView.passwordRules = rules }
        }
    }

    private func returnKeyType(_ value: Any?) -> UIReturnKeyType {
        switch value as? String {
        case "done": return .done
        case "go": return .go
        case "next": return .next
        case "search": return .search
        case "send": return .send
        case "join": return .join
        case "route": return .route
        case "continue": return .continue
        case "emergency-call": return .emergencyCall
        default: return .default
        }
    }

    private func capitalizationType(_ value: Any?) -> UITextAutocapitalizationType {
        switch value as? String {
        case "none": return .none
        case "words": return .words
        case "characters": return .allCharacters
        default: return .sentences
        }
    }

    /// A style colour: CSS hex with or without alpha (`#10b9811a` is
    /// emerald at 10%), `rgb()`/`rgba()` and the few names; `UIColor(hex:)`
    /// for anything else it has always read.
    private func color(_ value: Any?) -> UIColor? {
        guard let text = value as? String else { return nil }
        return UIColor(css: text) ?? UIColor(hex: text)
    }
}

/// `console` for native screens: the unified log, subsystem `craft.native`,
/// category the screen's name. Read it with
/// `log stream --predicate 'subsystem == "craft.native"'`.
enum CraftNativeConsole {
    private static var loggers: [String: Logger] = [:]
    private static let lock = NSLock()

    static func write(_ level: String, category: String, message: String) {
        lock.lock()
        let logger = loggers[category] ?? Logger(subsystem: "craft.native", category: category)
        loggers[category] = logger
        lock.unlock()
        switch level {
        case "debug": logger.debug("\(message, privacy: .public)")
        case "info": logger.info("\(message, privacy: .public)")
        case "warn": logger.warning("\(message, privacy: .public)")
        case "error": logger.error("\(message, privacy: .public)")
        default: logger.notice("\(message, privacy: .public)")
        }
    }
}
