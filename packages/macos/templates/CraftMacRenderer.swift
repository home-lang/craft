import AppKit
import AVKit
import Darwin

enum CraftMacColor {
    static var isDark: Bool { NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
    static func parse(_ value: Any?, fallback: NSColor = .labelColor) -> NSColor {
        guard let text = value as? String else { return fallback }
        if text == "transparent" { return .clear }
        let named: [String: NSColor] = ["label": .labelColor, "secondaryLabel": .secondaryLabelColor, "separator": .separatorColor,
            "controlBackground": .controlBackgroundColor, "windowBackground": .windowBackgroundColor, "textBackground": .textBackgroundColor,
            "accent": .controlAccentColor, "white": .white, "black": .black]
        if let color = named[text] { return color }
        let hex = text.replacingOccurrences(of: "#", with: "")
        if let n = UInt64(hex, radix: 16), hex.count == 6 || hex.count == 8 {
            let rgb = hex.count == 8 ? n >> 8 : n
            return NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255, blue: CGFloat(rgb & 255) / 255,
                           alpha: hex.count == 8 ? CGFloat(n & 255) / 255 : 1)
        }
        return fallback
    }
}

/// The same C ABI used by Craft's mobile hosts. AppKit supplies text metrics;
/// Zig supplies flex sizing and justification, without a second layout rule.
enum CraftMacFlex {
    struct Item { var basis: Float; var grow: Float; var shrink: Float; var min: Float; var max: Float; var start: Float; var end: Float }
    typealias Function = @convention(c) (Float, Float, UInt32, UnsafeRawPointer, Int, UnsafeMutableRawPointer, UnsafeMutableRawPointer) -> Int32
    static let function: Function = {
        guard let address = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "craft_native_flex_row_justified") else { fatalError("Craft's shared native layout library is missing") }
        return unsafeBitCast(address, to: Function.self)
    }()
    static func layout(_ items: [Item], available: CGFloat, gap: CGFloat, justify: String) -> [(CGFloat, CGFloat)] {
        guard !items.isEmpty else { return [] }
        let code: UInt32 = ["flex-start": 0, "center": 1, "flex-end": 2, "space-between": 3, "space-around": 4, "space-evenly": 5][justify] ?? 0
        var widths = [Float](repeating: 0, count: items.count), positions = widths
        let status = items.withUnsafeBufferPointer { input in widths.withUnsafeMutableBufferPointer { output in positions.withUnsafeMutableBufferPointer { offsets in
            function(Float(available), Float(gap), code, UnsafeRawPointer(input.baseAddress!), items.count, UnsafeMutableRawPointer(output.baseAddress!), UnsafeMutableRawPointer(offsets.baseAddress!))
        } } }
        precondition(status == 0, "Shared native layout rejected finite dimensions")
        return zip(widths, positions).map { (CGFloat($0), CGFloat($1)) }
    }
}

final class CraftMacFlow: NSView {
    var boxes: [CraftMacBox] = []
    var style: [String: Any] = [:]
    override var isFlipped: Bool { true }
    override func layout() {
        super.layout()
        layoutBoxes(in: bounds.size)
    }
    func layoutBoxes(in size: CGSize) {
        let horizontal = style["flexDirection"] as? String == "row"
        let padding = dimension(style["padding"], base: size.width) ?? 0
        let left = dimension(style["paddingLeft"], base: size.width) ?? dimension(style["paddingHorizontal"], base: size.width) ?? padding
        let right = dimension(style["paddingRight"], base: size.width) ?? dimension(style["paddingHorizontal"], base: size.width) ?? padding
        let top = dimension(style["paddingTop"], base: size.height) ?? dimension(style["paddingVertical"], base: size.height) ?? padding
        let bottom = dimension(style["paddingBottom"], base: size.height) ?? dimension(style["paddingVertical"], base: size.height) ?? padding
        let inner = CGSize(width: max(0, size.width - left - right), height: max(0, size.height - top - bottom))
        let visible = boxes.filter { !$0.isHidden && $0.kind != "Modal" }
        let gap = dimension(style["gap"], base: inner.width) ?? 0
        let sizes = visible.map { $0.measure(width: inner.width) }
        let items = visible.enumerated().map { index, box -> CraftMacFlex.Item in
            let main = horizontal ? sizes[index].width : sizes[index].height
            let basis = dimension(box.style["flexBasis"], base: horizontal ? inner.width : inner.height) ?? main
            let grow = number(box.style["flexGrow"]) ?? number(box.style["flex"]) ?? 0
            let shrink = number(box.style["flexShrink"]) ?? (grow > 0 ? 1 : 0)
            let minimum = dimension(box.style[horizontal ? "minWidth" : "minHeight"], base: horizontal ? inner.width : inner.height)
            let maximum = dimension(box.style[horizontal ? "maxWidth" : "maxHeight"], base: horizontal ? inner.width : inner.height)
            return .init(basis: Float(basis), grow: Float(grow), shrink: Float(shrink), min: minimum.map(Float.init) ?? .nan, max: maximum.map(Float.init) ?? .nan, start: 0, end: 0)
        }
        let frames = CraftMacFlex.layout(items, available: horizontal ? inner.width : inner.height, gap: gap, justify: style["justifyContent"] as? String ?? "flex-start")
        for (index, box) in visible.enumerated() {
            let crossAvailable = horizontal ? inner.height : inner.width
            let crossExplicit = dimension(box.style[horizontal ? "height" : "width"], base: crossAvailable)
            let alignment = box.style["alignSelf"] as? String ?? style["alignItems"] as? String ?? "stretch"
            let cross = min(crossAvailable, crossExplicit ?? (alignment == "stretch" ? crossAvailable : (horizontal ? sizes[index].height : sizes[index].width)))
            let offset = alignment == "center" ? (crossAvailable - cross) / 2 : alignment == "flex-end" ? crossAvailable - cross : 0
            box.frame = horizontal ? CGRect(x: left + frames[index].1, y: top + offset, width: frames[index].0, height: cross)
                : CGRect(x: left + offset, y: top + frames[index].1, width: cross, height: frames[index].0)
            box.layoutSubtreeIfNeeded()
        }
    }
    func fitting(width: CGFloat) -> CGSize {
        let padding = number(style["padding"]) ?? 0
        let horizontalPadding = (number(style["paddingLeft"]) ?? number(style["paddingHorizontal"]) ?? padding) + (number(style["paddingRight"]) ?? number(style["paddingHorizontal"]) ?? padding)
        let verticalPadding = (number(style["paddingTop"]) ?? number(style["paddingVertical"]) ?? padding) + (number(style["paddingBottom"]) ?? number(style["paddingVertical"]) ?? padding)
        let visible = boxes.filter { !$0.isHidden && $0.kind != "Modal" }
        let sizes = visible.map { $0.measure(width: max(0, width - horizontalPadding)) }
        let gaps = CGFloat(max(0, sizes.count - 1)) * (number(style["gap"]) ?? 0)
        if style["flexDirection"] as? String == "row" {
            return CGSize(width: sizes.reduce(0) { $0 + $1.width } + horizontalPadding + gaps, height: (sizes.map(\.height).max() ?? 0) + verticalPadding)
        }
        return CGSize(width: (sizes.map(\.width).max() ?? 0) + horizontalPadding, height: sizes.reduce(0) { $0 + $1.height } + verticalPadding + gaps)
    }
}

func number(_ value: Any?) -> CGFloat? { (value as? NSNumber).map { CGFloat(truncating: $0) } }
func dimension(_ value: Any?, base: CGFloat) -> CGFloat? {
    if let number = number(value), number.isFinite { return max(0, number) }
    if let text = value as? String, text.hasSuffix("%"), let percent = Double(text.dropLast()), percent.isFinite { return max(0, base * CGFloat(percent) / 100) }
    return nil
}
func nativeText(_ node: [String: Any]) -> String {
    (node["children"] as? [Any] ?? []).map { child -> String in
        if let text = child as? String { return text }
        if let node = child as? [String: Any] { return nativeText(node) }
        return ""
    }.joined()
}

/// Each node owns an AppKit control. IDs survive STX mutations, so editing,
/// selection, and scroll position survive updates instead of being recreated.
final class CraftMacTextView: NSTextView {
    var placeholder = ""
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if string.isEmpty && !placeholder.isEmpty {
            (placeholder as NSString).draw(at: CGPoint(x: textContainerInset.width + (textContainer?.lineFragmentPadding ?? 5), y: textContainerInset.height),
                withAttributes: [.font: font ?? NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.placeholderTextColor])
        }
    }
}

final class CraftMacBox: NSView, NSTextFieldDelegate, NSTextViewDelegate {
    let id: String
    let kind: String
    weak var renderer: CraftMacRenderer?
    var props: [String: Any] = [:], style: [String: Any] = [:], events: [String: String] = [:]
    var flow: CraftMacFlow?
    var control: NSView?
    var imageTask: URLSessionDataTask?
    var imageSource = ""
    var scrollKey = ""
    var modal: NSPanel?
    override var isFlipped: Bool { true }

    init(id: String, kind: String, renderer: CraftMacRenderer) {
        self.id = id; self.kind = kind; self.renderer = renderer
        super.init(frame: .zero)
        wantsLayer = true
        setAccessibilityElement(false)
        switch kind {
        case "Text":
            let text = NSTextField(wrappingLabelWithString: "")
            text.isSelectable = true; text.maximumNumberOfLines = 0
            control = text
        case "Button", "Link":
            let button = NSButton(title: "", target: self, action: #selector(pressed))
            button.bezelStyle = .rounded; control = button
        case "TextInput":
            let input = NSTextField(); input.delegate = self; control = input
        case "Picker":
            let picker = NSPopUpButton(frame: .zero, pullsDown: false)
            picker.target = self; picker.action = #selector(changed); control = picker
        case "Switch", "Checkbox":
            let button = NSButton(checkboxWithTitle: "", target: self, action: #selector(changed)); control = button
        case "Icon", "Image":
            let image = NSImageView(); image.imageScaling = .scaleProportionallyUpOrDown; control = image
        case "Video": control = AVPlayerView()
        case "ActivityIndicator": let indicator = NSProgressIndicator(); indicator.style = .spinning; indicator.startAnimation(nil); control = indicator
        case "ScrollView", "FlatList", "SectionList":
            let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.drawsBackground = false; scroll.borderType = .noBorder
            let content = CraftMacFlow(); content.style = ["flexDirection": "column"]
            scroll.documentView = content; flow = content; control = scroll
        case "Sidebar": control = CraftMacSidebar(box: self)
        case "View", "SafeAreaView", "Pressable", "TouchableOpacity", "TouchableHighlight", "KeyboardAvoidingView", "Modal", "SplitView":
            let container = CraftMacFlow(); flow = container; control = container
        default:
            let text = NSTextField(labelWithString: "Unsupported native control: \(kind)"); control = text
            renderer.runtime.errors.append("Unsupported native control: \(kind)")
        }
        if let control { addSubview(control) }
    }
    required init?(coder: NSCoder) { fatalError("Native controls are created from STX") }

    func configure(_ node: [String: Any]) {
        props = node["props"] as? [String: Any] ?? [:]
        style = node["style"] as? [String: Any] ?? [:]
        events = node["events"] as? [String: String] ?? [:]
        isHidden = style["display"] as? String == "none" || props["hidden"] as? Bool == true
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = CraftMacColor.parse(style["backgroundColor"], fallback: .clear).cgColor
            layer?.borderColor = CraftMacColor.parse(style["borderColor"], fallback: .separatorColor).cgColor
        }
        layer?.cornerRadius = number(style["borderRadius"]) ?? 0
        layer?.borderWidth = number(style["borderWidth"]) ?? 0
        alphaValue = number(style["opacity"]) ?? 1
        let identifier = props["testID"] as? String ?? props["testId"] as? String ?? props["accessibilityIdentifier"] as? String ?? id
        control?.setAccessibilityIdentifier(identifier)
        let label = props["accessibilityLabel"] as? String ?? props["aria-label"] as? String ?? props["title"] as? String
        if let label { control?.setAccessibilityLabel(label) }
        control?.toolTip = props["title"] as? String
        let fontSize = number(style["fontSize"]) ?? 13
        let weightValue = number(style["fontWeight"]) ?? CGFloat(Double(style["fontWeight"] as? String ?? "") ?? 0)
        let weight: NSFont.Weight = (style["fontWeight"] as? String == "bold" || weightValue >= 600) ? .semibold : .regular
        let font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        if let text = control as? NSTextField, kind == "Text" {
            text.stringValue = props["text"] as? String ?? nativeText(node)
            text.font = font; text.textColor = CraftMacColor.parse(style["color"])
            text.alignment = style["textAlign"] as? String == "center" ? .center : style["textAlign"] as? String == "right" ? .right : .left
            text.maximumNumberOfLines = (props["numberOfLines"] as? NSNumber)?.intValue ?? 0
            text.lineBreakMode = text.maximumNumberOfLines == 1 ? .byTruncatingTail : .byWordWrapping
        }
        if let button = control as? NSButton {
            button.title = props["title"] as? String ?? nativeText(node)
            button.font = font
            button.isEnabled = props["disabled"] as? Bool != true
            if kind == "Switch" || kind == "Checkbox" { button.state = (props["value"] as? Bool ?? props["checked"] as? Bool ?? false) ? .on : .off }
            button.bezelStyle = props["variant"] as? String == "toolbar" ? .texturedRounded : .rounded
            if let symbol = props["symbol"] as? String { button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: button.title); button.imagePosition = button.title.isEmpty ? .imageOnly : .imageLeading }
            if props["variant"] as? String == "primary" { button.bezelColor = .controlAccentColor }
            if props["variant"] as? String == "danger" { button.contentTintColor = .systemRed }
        }
        if kind == "TextInput" { configureInput(font: font) }
        if let picker = control as? NSPopUpButton {
            let rawOptions = props["options"] as? [[String: Any]] ?? (node["children"] as? [[String: Any]] ?? []).map { child in
                ["value": (child["props"] as? [String: Any])?["value"] ?? nativeText(child), "label": nativeText(child)]
            }
            let old = picker.itemArray.map { $0.representedObject as? String ?? "" }
            let new = rawOptions.map { String(describing: $0["value"] ?? "") }
            if old != new { picker.removeAllItems(); for option in rawOptions { picker.addItem(withTitle: option["label"] as? String ?? ""); picker.lastItem?.representedObject = String(describing: option["value"] ?? "") } }
            if let value = props["value"] ?? props["selectedValue"], let index = new.firstIndex(of: String(describing: value)) { picker.selectItem(at: index) }
            picker.isEnabled = props["disabled"] as? Bool != true
        }
        if let image = control as? NSImageView {
            if kind == "Icon" { image.image = NSImage(systemSymbolName: props["symbol"] as? String ?? props["name"] as? String ?? "questionmark", accessibilityDescription: label); image.contentTintColor = CraftMacColor.parse(style["color"]) }
            else { configureImage(image) }
        }
        if let video = control as? AVPlayerView, let source = (props["source"] as? String ?? props["src"] as? String), source != imageSource {
            imageSource = source
            if let url = renderer?.runtime.network.request(["url": source])?.url {
                video.player = AVPlayer(url: url); video.controlsStyle = .inline
                if props["autoplay"] as? Bool == true { video.player?.play() }
            }
        }
        if let sidebar = control as? CraftMacSidebar { sidebar.configure(props) }
        flow?.style = style
        needsLayout = true
    }

    private func configureInput(font: NSFont) {
        let multiline = props["multiline"] as? Bool == true
        if multiline, !(control is NSScrollView) {
            control?.removeFromSuperview()
            let scroll = NSScrollView(); scroll.drawsBackground = true; scroll.backgroundColor = .textBackgroundColor; scroll.hasVerticalScroller = true
            scroll.borderType = .bezelBorder
            let text = CraftMacTextView(); text.isRichText = false; text.delegate = self; text.font = font; text.isVerticallyResizable = true; text.isHorizontallyResizable = false
            text.textContainerInset = CGSize(width: 5, height: 6)
            text.autoresizingMask = [.width]; text.textContainer?.widthTracksTextView = true
            scroll.documentView = text; control = scroll; addSubview(scroll)
        } else if !multiline, let current = control as? NSTextField {
            let search = props["type"] as? String == "search"
            let secure = props["secureTextEntry"] as? Bool == true || props["type"] as? String == "password"
            if (search && !(current is NSSearchField)) || (secure && !(current is NSSecureTextField)) {
                current.removeFromSuperview()
                let field: NSTextField = search ? NSSearchField() : NSSecureTextField()
                field.delegate = self; control = field; addSubview(field)
            }
        }
        let value = props["value"] as? String ?? ""
        if let text = (control as? NSScrollView)?.documentView as? NSTextView {
            if text.string != value { text.string = value }
            text.isEditable = props["disabled"] as? Bool != true; text.font = font
            if let editor = text as? CraftMacTextView { editor.placeholder = props["placeholder"] as? String ?? ""; editor.needsDisplay = true }
            text.setAccessibilityIdentifier(props["testID"] as? String ?? props["testId"] as? String ?? id)
            text.setAccessibilityLabel(props["placeholder"] as? String ?? "Message")
        } else if let field = control as? NSTextField {
            if field.stringValue != value { field.stringValue = value }
            field.placeholderString = props["placeholder"] as? String
            field.font = font; field.isEnabled = props["disabled"] as? Bool != true
            field.setAccessibilityIdentifier(props["testID"] as? String ?? props["testId"] as? String ?? id)
        }
    }

    private func configureImage(_ image: NSImageView) {
        let source = props["source"] as? String ?? props["src"] as? String ?? (props["source"] as? [String: Any])?["uri"] as? String ?? ""
        guard source != imageSource else { return }
        imageSource = source; imageTask?.cancel(); image.image = nil
        if source.hasPrefix("data:"), let encoded = source.split(separator: ",", maxSplits: 1).last, let data = Data(base64Encoded: String(encoded)) { image.image = NSImage(data: data); return }
        guard !source.isEmpty, let request = renderer?.runtime.network.request(["url": source]), let session = renderer?.runtime.network.session else { return }
        imageTask = session.dataTask(with: request) { [weak self, weak image] data, _, _ in
            DispatchQueue.main.async {
                guard let self, self.imageSource == source else { return }
                image?.image = data.flatMap(NSImage.init(data:))
                self.fire(image?.image == nil ? "onError" : "onLoad")
            }
        }; imageTask?.resume()
    }

    func measure(width: CGFloat) -> CGSize {
        if isHidden { return .zero }
        let specifiedWidth = dimension(style["width"], base: width)
        let limit = min(specifiedWidth ?? width, dimension(style["maxWidth"], base: width) ?? width)
        var size = CGSize(width: limit, height: 0)
        if let text = control as? NSTextField, kind == "Text" {
            let rect = (text.stringValue as NSString).boundingRect(with: CGSize(width: max(1, limit - 6), height: 1_000_000), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: text.font ?? NSFont.systemFont(ofSize: 13)])
            size = CGSize(width: min(limit, ceil(rect.width) + 6), height: max(18, ceil(rect.height) + 2))
            if text.maximumNumberOfLines == 1 { size.height = max(18, (text.font?.pointSize ?? 13) + 5) }
        } else if kind == "ScrollView" || kind == "FlatList" || kind == "Sidebar" { size = CGSize(width: limit, height: 100) }
        else if kind == "Icon" { size = CGSize(width: 18, height: 18) }
        else if kind == "Image" || kind == "Video" { size = CGSize(width: limit, height: 160) }
        else if kind == "TextInput" { size = CGSize(width: limit, height: props["multiline"] as? Bool == true ? 48 : 28) }
        else if let control = control as? NSControl { size = control.intrinsicContentSize; size.width = max(24, size.width); size.height = max(26, size.height) }
        else if let flow { size = flow.fitting(width: limit) }
        size.width = specifiedWidth ?? min(limit, size.width)
        if let maximum = dimension(style["maxWidth"], base: width) { size.width = min(size.width, maximum) }
        // A naturally sized column can be narrower than its measurement limit.
        // Measure its wrapped children again at the width it will actually get.
        if let flow, style["flexDirection"] as? String != "row" {
            size.height = flow.fitting(width: size.width).height
        }
        size.height = dimension(style["height"], base: 1000) ?? size.height
        size.width = max(size.width, dimension(style["minWidth"], base: width) ?? 0)
        size.height = max(size.height, dimension(style["minHeight"], base: 1000) ?? 0)
        if let maxHeight = dimension(style["maxHeight"], base: 1000) { size.height = min(size.height, maxHeight) }
        return size
    }
    override func layout() {
        super.layout()
        control?.frame = bounds
        if let scroll = control as? NSScrollView {
            if let flow {
                let width = scroll.contentSize.width
                flow.frame = CGRect(x: 0, y: 0, width: width, height: max(scroll.contentSize.height, flow.fitting(width: width).height))
                flow.layoutBoxes(in: flow.bounds.size)
            }
            if let text = scroll.documentView as? NSTextView { text.frame.size.width = scroll.contentSize.width; text.textContainer?.containerSize = CGSize(width: scroll.contentSize.width, height: .greatestFiniteMagnitude) }
        } else if let flow { flow.layoutBoxes(in: bounds.size) }
    }
    func fire(_ name: String, _ payload: [String: Any] = [:]) { renderer?.runtime.event(events[name], payload: payload) }
    @objc func pressed() { fire("onPress") }
    @objc func changed() {
        let value: Any = (control as? NSPopUpButton)?.selectedItem?.representedObject ?? ((control as? NSButton)?.state == .on)
        fire("onValueChange", ["value": value, "nativeEvent": ["value": value]])
    }
    func controlTextDidChange(_ notification: Notification) { if let field = notification.object as? NSTextField { input(field.stringValue) } }
    func textDidChange(_ notification: Notification) { if let text = notification.object as? NSTextView { input(text.string) } }
    func input(_ value: String) { fire("onChangeText", ["text": value, "value": value, "nativeEvent": ["text": value, "value": value]]) }
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)), !NSEvent.modifierFlags.contains(.shift), events["onSubmitEditing"] != nil { fire("onSubmitEditing", ["text": textView.string]); return true }
        return false
    }
    override func mouseDown(with event: NSEvent) { if events["onPress"] != nil { fire("onPress") } else { super.mouseDown(with: event) } }
    override func rightMouseDown(with event: NSEvent) { fire("onLongPress", ["x": event.locationInWindow.x, "y": event.locationInWindow.y]) }
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, bounds.contains(convert(point, from: superview)) else { return nil }
        // Rows handle the whole click. Transcript text keeps AppKit selection,
        // while a right click is routed to the STX conversation/message menu.
        if kind == "Pressable", events["onPress"] != nil || (events["onLongPress"] != nil && NSApp.currentEvent?.type == .rightMouseDown) { return self }
        return super.hitTest(point)
    }
}

final class CraftMacSidebarRow: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        guard isSelected else { return }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            NSColor.unemphasizedSelectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 1), xRadius: 7, yRadius: 7).fill()
        }
    }
}

final class CraftMacSidebar: NSScrollView, NSOutlineViewDataSource, NSOutlineViewDelegate {
    final class Item { let id: String; let label: String; let icon: String; let badge: String; let children: [Item]
        init(_ raw: [String: Any]) { id = raw["id"] as? String ?? ""; label = raw["label"] as? String ?? raw["header"] as? String ?? ""; icon = raw["icon"] as? String ?? ""; badge = raw["badge"].map { $0 is NSNull ? "" : String(describing: $0) } ?? ""; children = (raw["items"] as? [[String: Any]] ?? []).map(Item.init) }
    }
    weak var box: CraftMacBox?
    let outline = NSOutlineView()
    var sections: [Item] = []
    var fingerprint = ""
    init(box: CraftMacBox) {
        self.box = box; super.init(frame: .zero)
        hasVerticalScroller = true; drawsBackground = false
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("label")); outline.addTableColumn(column); outline.outlineTableColumn = column
        outline.headerView = nil; outline.style = .plain; outline.backgroundColor = .windowBackgroundColor
        outline.rowSizeStyle = .default; outline.indentationPerLevel = 0
        outline.dataSource = self; outline.delegate = self; outline.autoresizesOutlineColumn = true; documentView = outline
    }
    required init?(coder: NSCoder) { fatalError("Native sidebar is created from STX") }
    func configure(_ props: [String: Any]) {
        let raw = props["sections"] as? [[String: Any]] ?? []
        let data = (try? JSONSerialization.data(withJSONObject: raw, options: .sortedKeys)) ?? Data()
        let next = String(decoding: data, as: UTF8.self)
        if next != fingerprint { fingerprint = next; sections = raw.map(Item.init); outline.reloadData(); outline.expandItem(nil, expandChildren: true) }
        if let selected = props["selected"] as? String { for index in 0..<outline.numberOfRows { if (outline.item(atRow: index) as? Item)?.id == selected { outline.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false); break } } }
    }
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int { (item as? Item)?.children.count ?? sections.count }
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any { (item as? Item)?.children[index] ?? sections[index] }
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool { !(item as! Item).children.isEmpty }
    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool { !(item as! Item).children.isEmpty }
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool { (item as! Item).children.isEmpty }
    func outlineView(_ outlineView: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool { false }
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        let item = item as! Item
        return item.children.isEmpty ? 32 : item.label.isEmpty ? 12 : 28
    }
    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        let row = CraftMacSidebarRow(); row.isEmphasized = false; return row
    }
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let item = item as! Item
        let cell = NSTableCellView(); let label = NSTextField(labelWithString: item.label + (item.badge.isEmpty ? "" : "  \(item.badge)"))
        label.font = NSFont.systemFont(ofSize: 13); label.lineBreakMode = .byTruncatingTail; cell.textField = label; cell.addSubview(label)
        if !item.children.isEmpty { label.font = NSFont.systemFont(ofSize: 11, weight: .semibold); label.textColor = .secondaryLabelColor }
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: item.icon.isEmpty ? 4 : 27), label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6), label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)])
        if !item.icon.isEmpty { let image = NSImageView(image: NSImage(systemSymbolName: item.icon, accessibilityDescription: nil) ?? NSImage()); image.frame = CGRect(x: 4, y: 7, width: 18, height: 18); cell.imageView = image; cell.addSubview(image) }
        cell.setAccessibilityIdentifier(item.id); cell.setAccessibilityLabel(item.label)
        return cell
    }
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let item = outline.item(atRow: outline.selectedRow) as? Item, item.children.isEmpty, item.id != box?.props["selected"] as? String else { return }
        box?.fire("onValueChange", ["value": item.id, "nativeEvent": ["value": item.id]])
    }
    override func layout() { super.layout(); outline.frame.size.width = contentSize.width }
}

final class CraftMacRenderer {
    let runtime: CraftMacRuntime
    let root = CraftMacFlow()
    var boxes: [String: CraftMacBox] = [:]
    weak var window: NSWindow?
    var sheets: [String: NSPanel] = [:]
    init(runtime: CraftMacRuntime) { self.runtime = runtime }
    func render(_ document: [String: Any]) {
        var retained = Set<String>()
        var scrolls: [(CraftMacBox, CGPoint, Bool)] = []
        for box in boxes.values { if let scroll = box.control as? NSScrollView, box.kind != "Sidebar" {
            let bounds = scroll.contentView.bounds
            let bottom = bounds.maxY >= (scroll.documentView?.bounds.height ?? 0) - 8
            scrolls.append((box, bounds.origin, bottom))
        } }
        func reconcile(_ node: [String: Any]) -> CraftMacBox {
            let id = node["id"] as? String ?? "root", kind = node["type"] as? String ?? "View"
            retained.insert(id)
            let box = boxes[id] ?? CraftMacBox(id: id, kind: kind, renderer: self)
            boxes[id] = box; box.configure(node)
            if let flow = box.flow, kind != "Button" {
                let children = (node["children"] as? [Any] ?? []).compactMap { $0 as? [String: Any] }.map(reconcile)
                for child in flow.boxes where !children.contains(where: { $0 === child }) { child.removeFromSuperview() }
                flow.boxes = children
                for child in children where child.superview !== flow && sheets[child.id] == nil { flow.addSubview(child) }
            }
            return box
        }
        let box = reconcile(document)
        for (id, box) in boxes where !retained.contains(id) {
            box.imageTask?.cancel(); box.removeFromSuperview(); boxes.removeValue(forKey: id)
            if let sheet = sheets.removeValue(forKey: id) { window?.endSheet(sheet); sheet.close() }
        }
        root.style = ["flexDirection": "column"]
        root.boxes = [box]; if box.superview !== root { root.addSubview(box) }
        box.frame = root.bounds; box.layoutSubtreeIfNeeded(); root.layoutBoxes(in: root.bounds.size)
        for modal in boxes.values where modal.kind == "Modal" {
            guard let window else { continue }
            if modal.props["visible"] as? Bool == false {
                if let sheet = sheets.removeValue(forKey: modal.id) { window.endSheet(sheet); sheet.close() }
                continue
            }
            if sheets[modal.id] == nil {
                let size = modal.measure(width: 480)
                let panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: 480, height: min(650, max(200, size.height))), styleMask: [.titled], backing: .buffered, defer: false)
                panel.title = modal.props["title"] as? String ?? ""; panel.isReleasedWhenClosed = false
                modal.removeFromSuperview(); panel.contentView = modal; sheets[modal.id] = panel
                window.beginSheet(panel)
            }
            modal.frame = sheets[modal.id]!.contentView!.bounds; modal.needsLayout = true; modal.layoutSubtreeIfNeeded()
        }
        for (box, origin, bottom) in scrolls {
            guard let scroll = box.control as? NSScrollView, box.kind != "TextInput" else { continue }
            let key = box.props["scrollKey"] as? String ?? ""
            let changed = key != box.scrollKey; box.scrollKey = key
            let y = (bottom || changed) && box.props["autoScrollBottom"] as? Bool == true ? max(0, (scroll.documentView?.frame.height ?? 0) - scroll.contentSize.height) : origin.y
            scroll.contentView.scroll(to: CGPoint(x: origin.x, y: y)); scroll.reflectScrolledClipView(scroll.contentView)
        }
        root.needsLayout = true
    }
}
