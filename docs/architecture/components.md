# Component Architecture

This document describes Craft's native UI component system architecture.

## Overview

Craft provides 35+ native UI components that render using platform-native widgets rather than web-based rendering, ensuring native look, feel, and performance.

## Component Hierarchy

```mermaid
graph TB
    subgraph "Component Base"
        BC[BaseComponent]
        LC[LayoutComponent]
        IC[InteractiveComponent]
    end

    subgraph "Input Components"
        BTN[Button]
        TXT[TextInput]
        CHK[Checkbox]
        RAD[RadioButton]
        SLD[Slider]
        TOG[Toggle]
        CLR[ColorPicker]
        DTE[DatePicker]
        TME[TimePicker]
        AUT[Autocomplete]
    end

    subgraph "Display Components"
        LBL[Label]
        IMG[ImageView]
        PRG[ProgressBar]
        SPN[Spinner]
        AVT[Avatar]
        BDG[Badge]
        CHP[Chip]
        CRD[Card]
        TIP[Tooltip]
        TST[Toast]
    end

    subgraph "Layout Components"
        SCR[ScrollView]
        SPL[SplitView]
        STK[Stack]
        ACC[Accordion]
        STP[Stepper]
        MOD[Modal]
        TAB[Tabs]
        DRP[Dropdown]
    end

    subgraph "Data Components"
        LST[ListView]
        TBL[Table]
        TRE[TreeView]
        DGR[DataGrid]
        CHT[Chart]
    end

    subgraph "Advanced Components"
        RAT[Rating]
        CDE[CodeEditor]
        MDP[MediaPlayer]
    end

    BC --> IC
    BC --> LC

    IC --> BTN
    IC --> TXT
    IC --> CHK
    IC --> RAD
    IC --> SLD
    IC --> TOG
    IC --> CLR
    IC --> DTE
    IC --> TME
    IC --> AUT

    BC --> LBL
    BC --> IMG
    BC --> PRG
    BC --> SPN
    BC --> AVT
    BC --> BDG
    BC --> CHP
    BC --> CRD
    IC --> TIP
    BC --> TST

    LC --> SCR
    LC --> SPL
    LC --> STK
    LC --> ACC
    IC --> STP
    LC --> MOD
    IC --> TAB
    IC --> DRP

    LC --> LST
    LC --> TBL
    LC --> TRE
    LC --> DGR
    LC --> CHT

    IC --> RAT
    IC --> CDE
    IC --> MDP
```

## Component Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Created: create()
    Created --> Initialized: init()
    Initialized --> Mounted: mount()
    Mounted --> Updated: update()
    Updated --> Mounted: render()
    Mounted --> Unmounted: unmount()
    Unmounted --> [*]: destroy()

    note right of Created: Memory allocated
    note right of Initialized: Properties set
    note right of Mounted: Visible in UI
    note right of Updated: Props changed
    note right of Unmounted: Removed from UI
```

## Platform Widget Mapping

### Button Component

```mermaid
graph LR
    subgraph "Button API"
        BTN[Button]
    end

    subgraph "macOS"
        NS[NSButton]
    end

    subgraph "Linux"
        GTK[GtkButton]
    end

    subgraph "Windows"
        WIN[HWND Button]
    end

    BTN --> NS
    BTN --> GTK
    BTN --> WIN
```

### Text Input Component

```mermaid
graph LR
    subgraph "TextInput API"
        TXT[TextInput]
    end

    subgraph "macOS"
        NST[NSTextField]
        NSTV[NSTextView]
    end

    subgraph "Linux"
        GE[GtkEntry]
        GTV[GtkTextView]
    end

    subgraph "Windows"
        WE[HWND Edit]
        WRE[RichEdit]
    end

    TXT --> NST
    TXT --> NSTV
    TXT --> GE
    TXT --> GTV
    TXT --> WE
    TXT --> WRE
```

## Component Properties

```mermaid
classDiagram
    class ComponentProps {
        +id: ?[]const u8
        +class: ?[]const u8
        +style: ?Style
        +visible: bool
        +enabled: bool
    }

    class ButtonProps {
        +label: []const u8
        +icon: ?Icon
        +variant: ButtonVariant
        +size: Size
        +onClick: ?Callback
    }

    class TextInputProps {
        +value: []const u8
        +placeholder: ?[]const u8
        +multiline: bool
        +password: bool
        +onChange: ?Callback
        +onSubmit: ?Callback
    }

    class SliderProps {
        +value: f64
        +min: f64
        +max: f64
        +step: f64
        +onChange: ?Callback
    }

    ComponentProps <|-- ButtonProps
    ComponentProps <|-- TextInputProps
    ComponentProps <|-- SliderProps
```

## Event System

```mermaid
sequenceDiagram
    participant User
    participant Native as Native Widget
    participant Comp as Component
    participant Bridge as Bridge
    participant JS as JavaScript

    User->>Native: Click/Input
    Native->>Comp: Platform Event
    Comp->>Comp: Process Event
    Comp->>Bridge: Emit Event
    Bridge->>JS: craftHandleEvent(...)
    JS->>JS: Call Handler
    JS-->>Bridge: Response (optional)
    Bridge-->>Comp: Update (optional)
    Comp-->>Native: Re-render
```

### Event Types

```mermaid
graph TB
    subgraph "Mouse Events"
        ME1[onClick]
        ME2[onDoubleClick]
        ME3[onMouseEnter]
        ME4[onMouseLeave]
        ME5[onMouseDown]
        ME6[onMouseUp]
    end

    subgraph "Keyboard Events"
        KE1[onKeyDown]
        KE2[onKeyUp]
        KE3[onKeyPress]
    end

    subgraph "Focus Events"
        FE1[onFocus]
        FE2[onBlur]
    end

    subgraph "Value Events"
        VE1[onChange]
        VE2[onInput]
        VE3[onSubmit]
    end

    subgraph "Drag Events"
        DE1[onDragStart]
        DE2[onDragOver]
        DE3[onDrop]
        DE4[onDragEnd]
    end
```

## Styling System

```mermaid
graph TB
    subgraph "Style Sources"
        TH[Theme]
        CL[Class Styles]
        IN[Inline Styles]
    end

    subgraph "Style Properties"
        LAY[Layout<br/>margin, padding, size]
        VIS[Visual<br/>color, background, border]
        TYP[Typography<br/>font, size, weight]
        EFF[Effects<br/>shadow, opacity, transform]
    end

    subgraph "Resolution"
        MRG[Merge Styles]
        APP[Apply to Widget]
    end

    TH --> MRG
    CL --> MRG
    IN --> MRG
    MRG --> LAY
    MRG --> VIS
    MRG --> TYP
    MRG --> EFF
    LAY --> APP
    VIS --> APP
    TYP --> APP
    EFF --> APP
```

## Layout System

```mermaid
graph TB
    subgraph "Layout Modes"
        FLX[Flexbox]
        GRD[Grid]
        ABS[Absolute]
        STK[Stack]
    end

    subgraph "Flexbox Properties"
        FD[flexDirection]
        JC[justifyContent]
        AI[alignItems]
        FW[flexWrap]
        FG[flexGrow]
        FS[flexShrink]
    end

    subgraph "Grid Properties"
        GTC[gridTemplateColumns]
        GTR[gridTemplateRows]
        GG[gridGap]
        GA[gridArea]
    end

    FLX --> FD
    FLX --> JC
    FLX --> AI
    FLX --> FW
    FLX --> FG
    FLX --> FS

    GRD --> GTC
    GRD --> GTR
    GRD --> GG
    GRD --> GA
```

## Accessibility

```mermaid
graph TB
    subgraph "Accessibility Features"
        ROLE[ARIA Roles]
        STAT[States]
        PROP[Properties]
        LIVE[Live Regions]
    end

    subgraph "Platform APIs"
        MAC[NSAccessibility]
        ATK[ATK/AT-SPI]
        UIA[UI Automation]
    end

    subgraph "Features"
        SR[Screen Reader]
        KB[Keyboard Navigation]
        FC[Focus Management]
        AN[Announcements]
    end

    ROLE --> MAC
    ROLE --> ATK
    ROLE --> UIA

    STAT --> MAC
    STAT --> ATK
    STAT --> UIA

    MAC --> SR
    ATK --> SR
    UIA --> SR

    MAC --> KB
    ATK --> KB
    UIA --> KB
```

### ARIA Role Mapping

| Component | ARIA Role | macOS | GTK | Windows |
|-----------|-----------|-------|-----|---------|
| Button | button | AXButton | GTK_ROLE_BUTTON | UIA_ButtonControlTypeId |
| Checkbox | checkbox | AXCheckBox | GTK_ROLE_CHECK_BOX | UIA_CheckBoxControlTypeId |
| TextInput | textbox | AXTextField | GTK_ROLE_ENTRY | UIA_EditControlTypeId |
| Slider | slider | AXSlider | GTK_ROLE_SLIDER | UIA_SliderControlTypeId |
| Tabs | tablist | AXTabGroup | GTK_ROLE_TAB_GROUP | UIA_TabControlTypeId |
| Modal | dialog | AXSheet | GTK_ROLE_DIALOG | UIA_WindowControlTypeId |

## Component Implementation Pattern

```zig
pub const Button = struct {
    base: BaseComponent,
    props: ButtonProps,
    native_handle: ?*anyopaque,

    pub fn create(allocator: Allocator, props: ButtonProps) !*Button {
        const self = try allocator.create(Button);
        self.* = .{
            .base = BaseComponent.init(allocator),
            .props = props,
            .native_handle = null,
        };
        return self;
    }

    pub fn mount(self: *Button, parent: *anyopaque) !void {
        self.native_handle = switch (builtin.os.tag) {
            .macos => try self.createNSButton(parent),
            .linux => try self.createGtkButton(parent),
            .windows => try self.createWin32Button(parent),
            else => return error.UnsupportedPlatform,
        };
        self.base.state = .mounted;
    }

    pub fn update(self: *Button, new_props: ButtonProps) !void {
        if (!std.mem.eql(u8, self.props.label, new_props.label)) {
            try self.setLabel(new_props.label);
        }
        self.props = new_props;
    }

    pub fn unmount(self: *Button) void {
        if (self.native_handle) |handle| {
            self.destroyNativeWidget(handle);
            self.native_handle = null;
        }
        self.base.state = .unmounted;
    }

    pub fn destroy(self: *Button, allocator: Allocator) void {
        self.unmount();
        allocator.destroy(self);
    }
};
```

## Theme System

```mermaid
graph TB
    subgraph "Built-in Themes"
        SYS[System Default]
        NOR[Nord]
        DRA[Dracula]
        GRU[Gruvbox]
        SOL[Solarized]
        MON[Monokai]
    end

    subgraph "Theme Properties"
        COL[Colors]
        TYP[Typography]
        SPC[Spacing]
        RAD[Border Radius]
        SHD[Shadows]
    end

    subgraph "Application"
        GLB[Global Theme]
        CMP[Component Override]
        INL[Inline Style]
    end

    SYS --> COL
    NOR --> COL
    DRA --> COL

    COL --> GLB
    TYP --> GLB
    SPC --> GLB

    GLB --> CMP
    CMP --> INL
```

## Complex Component: DataGrid

```mermaid
graph TB
    subgraph "DataGrid"
        DG[DataGrid Component]
    end

    subgraph "Sub-components"
        HDR[Header Row]
        BDY[Body]
        ROW[Rows]
        CEL[Cells]
        SRT[Sort Controls]
        FLT[Filter Controls]
        PAG[Pagination]
        SEL[Selection]
    end

    subgraph "Features"
        VIR[Virtual Scrolling]
        RSZ[Column Resize]
        ROR[Row Reorder]
        EDT[Inline Edit]
        EXP[Export]
    end

    DG --> HDR
    DG --> BDY
    BDY --> ROW
    ROW --> CEL

    HDR --> SRT
    HDR --> FLT
    DG --> PAG
    DG --> SEL

    DG --> VIR
    HDR --> RSZ
    BDY --> ROR
    CEL --> EDT
    DG --> EXP
```

## Further Reading

- [components.zig](../../packages/zig/src/components.zig) - Component manager
- [components/](../../packages/zig/src/components/) - Individual components
- [accessibility.zig](../../packages/zig/src/accessibility.zig) - Accessibility system
- [theme.zig](../../packages/zig/src/theme.zig) - Theme system
