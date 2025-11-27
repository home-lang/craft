# Components API

The Components API provides React Native-style component abstractions for building cross-platform UIs.

## Import

```typescript
import {
  Platform,
  StyleSheet,
  Animated,
  type ViewStyle,
  type TextStyle,
  type ImageStyle
} from 'ts-craft'
```

## Platform

Utilities for platform-specific code.

### Platform.OS

Get the current platform.

```typescript
console.log(Platform.OS)
// Returns: 'ios' | 'android' | 'macos' | 'windows' | 'linux' | 'web'
```

### Platform.Version

Get the OS version.

```typescript
console.log(Platform.Version)
// iOS: "17.0"
// Android: 34
// macOS: "14.0"
```

### Platform.select(options)

Select a value based on the current platform.

```typescript
const containerStyle = Platform.select({
  ios: { paddingTop: 44 },
  android: { paddingTop: 24 },
  default: { paddingTop: 0 }
})

const fontFamily = Platform.select({
  ios: 'SF Pro',
  android: 'Roboto',
  macos: 'SF Pro',
  windows: 'Segoe UI',
  default: 'system-ui'
})
```

### Platform.isPad / Platform.isTV

Check device type on iOS/tvOS.

```typescript
if (Platform.isPad) {
  // iPad-specific layout
}

if (Platform.isTV) {
  // tvOS-specific layout
}
```

## StyleSheet

Create and manage styles efficiently.

### StyleSheet.create(styles)

Create a stylesheet with type checking.

```typescript
const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#ffffff',
    padding: 16
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#000000'
  },
  image: {
    width: 100,
    height: 100,
    borderRadius: 50
  }
})

// Usage
element.style = styles.container
```

### StyleSheet.flatten(styles)

Flatten an array of styles into a single object.

```typescript
const combined = StyleSheet.flatten([
  styles.container,
  styles.customPadding,
  { marginTop: 10 }
])
```

### StyleSheet.absoluteFill

A preset style for absolute fill positioning.

```typescript
const overlayStyle = {
  ...StyleSheet.absoluteFill,
  backgroundColor: 'rgba(0, 0, 0, 0.5)'
}
// Equivalent to: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 }
```

### StyleSheet.hairlineWidth

The thinnest line the platform can render.

```typescript
const borderStyle = {
  borderBottomWidth: StyleSheet.hairlineWidth,
  borderBottomColor: '#cccccc'
}
```

## Animated

Create fluid, powerful animations.

### Animated.Value

A standard value for animations.

```typescript
const fadeAnim = new Animated.Value(0)

// Use in style
const style = {
  opacity: fadeAnim
}
```

### Animated.timing(value, config)

Animate a value over time using easing.

```typescript
const fadeAnim = new Animated.Value(0)

// Fade in
Animated.timing(fadeAnim, {
  toValue: 1,
  duration: 300,
  easing: Easing.ease,
  useNativeDriver: true
}).start()

// With callback
Animated.timing(fadeAnim, {
  toValue: 0,
  duration: 200
}).start(() => {
  console.log('Animation complete')
})
```

### Animated.spring(value, config)

Animate using spring physics.

```typescript
const scaleAnim = new Animated.Value(0.5)

Animated.spring(scaleAnim, {
  toValue: 1,
  friction: 3,
  tension: 40,
  useNativeDriver: true
}).start()
```

### Animated.parallel(animations)

Run animations in parallel.

```typescript
const fadeAnim = new Animated.Value(0)
const slideAnim = new Animated.Value(100)

Animated.parallel([
  Animated.timing(fadeAnim, { toValue: 1, duration: 300 }),
  Animated.timing(slideAnim, { toValue: 0, duration: 300 })
]).start()
```

### Animated.sequence(animations)

Run animations in sequence.

```typescript
Animated.sequence([
  Animated.timing(fadeAnim, { toValue: 1, duration: 200 }),
  Animated.delay(100),
  Animated.timing(slideAnim, { toValue: 0, duration: 200 })
]).start()
```

### Animated.stagger(delay, animations)

Run animations with a staggered start.

```typescript
const items = [anim1, anim2, anim3, anim4]

Animated.stagger(100, items.map(anim =>
  Animated.timing(anim, { toValue: 1, duration: 300 })
)).start()
```

### Animated.loop(animation, config?)

Loop an animation.

```typescript
const rotateAnim = new Animated.Value(0)

Animated.loop(
  Animated.timing(rotateAnim, {
    toValue: 1,
    duration: 1000,
    easing: Easing.linear
  }),
  { iterations: -1 } // Infinite
).start()
```

## Style Types

### ViewStyle

Style properties for container elements.

```typescript
const containerStyle: ViewStyle = {
  // Layout
  flex: 1,
  flexDirection: 'row',
  justifyContent: 'center',
  alignItems: 'center',

  // Spacing
  padding: 16,
  margin: 8,

  // Size
  width: 100,
  height: 100,
  minWidth: 50,
  maxWidth: 200,

  // Background
  backgroundColor: '#ffffff',

  // Border
  borderWidth: 1,
  borderColor: '#cccccc',
  borderRadius: 8,

  // Shadow (iOS)
  shadowColor: '#000000',
  shadowOffset: { width: 0, height: 2 },
  shadowOpacity: 0.25,
  shadowRadius: 4,

  // Elevation (Android)
  elevation: 4,

  // Position
  position: 'absolute',
  top: 0,
  left: 0,

  // Other
  opacity: 0.8,
  overflow: 'hidden',
  zIndex: 10
}
```

### TextStyle

Style properties for text elements.

```typescript
const textStyle: TextStyle = {
  // Font
  fontSize: 16,
  fontWeight: 'bold',
  fontFamily: 'System',
  fontStyle: 'italic',

  // Color
  color: '#333333',

  // Alignment
  textAlign: 'center',
  textAlignVertical: 'center',

  // Decoration
  textDecorationLine: 'underline',
  textDecorationColor: '#000000',
  textDecorationStyle: 'solid',

  // Transform
  textTransform: 'uppercase',

  // Spacing
  letterSpacing: 1,
  lineHeight: 24,

  // Shadow
  textShadowColor: '#000000',
  textShadowOffset: { width: 1, height: 1 },
  textShadowRadius: 2
}
```

### ImageStyle

Style properties for image elements.

```typescript
const imageStyle: ImageStyle = {
  // Size
  width: 100,
  height: 100,

  // Resize
  resizeMode: 'cover', // 'contain' | 'cover' | 'stretch' | 'center'

  // Border
  borderRadius: 50,
  borderWidth: 2,
  borderColor: '#ffffff',

  // Tint
  tintColor: '#007AFF',

  // Background
  backgroundColor: '#f0f0f0',

  // Opacity
  opacity: 1
}
```

## FlexStyle

Common flex layout properties.

```typescript
const flexStyle: FlexStyle = {
  // Flex container
  flexDirection: 'row',     // 'column' | 'row' | 'column-reverse' | 'row-reverse'
  flexWrap: 'wrap',         // 'nowrap' | 'wrap' | 'wrap-reverse'
  justifyContent: 'center', // 'flex-start' | 'flex-end' | 'center' | 'space-between' | 'space-around' | 'space-evenly'
  alignItems: 'center',     // 'flex-start' | 'flex-end' | 'center' | 'stretch' | 'baseline'
  alignContent: 'center',   // Same as alignItems

  // Flex item
  flex: 1,
  flexGrow: 1,
  flexShrink: 0,
  flexBasis: 'auto',
  alignSelf: 'center',      // Same as alignItems + 'auto'

  // Gap
  gap: 10,
  rowGap: 10,
  columnGap: 10
}
```

## Example Usage

```typescript
import { Platform, StyleSheet, Animated, Easing } from 'ts-craft'

// Create styles
const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Platform.select({
      ios: '#f8f8f8',
      android: '#ffffff',
      default: '#ffffff'
    })
  },
  card: {
    backgroundColor: '#ffffff',
    borderRadius: 12,
    padding: 16,
    margin: 8,
    ...Platform.select({
      ios: {
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.1,
        shadowRadius: 8
      },
      android: {
        elevation: 4
      },
      default: {
        boxShadow: '0 2px 8px rgba(0,0,0,0.1)'
      }
    })
  },
  title: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333333',
    marginBottom: 8
  }
})

// Animated component
class FadeInView {
  private fadeAnim = new Animated.Value(0)
  private slideAnim = new Animated.Value(20)

  show() {
    Animated.parallel([
      Animated.timing(this.fadeAnim, {
        toValue: 1,
        duration: 300,
        easing: Easing.out(Easing.ease)
      }),
      Animated.timing(this.slideAnim, {
        toValue: 0,
        duration: 300,
        easing: Easing.out(Easing.ease)
      })
    ]).start()
  }

  hide(callback?: () => void) {
    Animated.timing(this.fadeAnim, {
      toValue: 0,
      duration: 200
    }).start(callback)
  }

  getStyle() {
    return {
      opacity: this.fadeAnim,
      transform: [{ translateY: this.slideAnim }]
    }
  }
}
```
