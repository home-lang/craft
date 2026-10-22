# Objective-C structure returns

Craft's Zig Apple bridges use `objc_runtime.zig` for typed Objective-C dispatch.
Use `objc.msgSendStret(T, object, selector)` for a zero-argument selector that
returns Cocoa geometry or a naturally aligned C aggregate. Declare its exact
foreign layout with `extern struct` and use the method's actual field types.

ARM64 uses `objc_msgSend` for every aggregate return. The typed C function
signature determines whether the result uses floating-point registers or an
indirect result address. x86_64 uses `objc_msgSend_stret` for aggregates larger
than 16 bytes. Selecting only by size references a symbol absent from ARM64
libobjc and prevents the application from linking.

The mobile screen and motion bridges share this helper. They do not each choose
their own structure-return entry point. Scalar properties still use their exact
scalar signatures; a `float` and a `double` are different contracts.

The maintained native check is:

```sh
bun scripts/zig.ts --core build test-objc-runtime
```

It calls independently compiled Objective-C methods through the public helper
and checks a point, rectangle, three-double aggregate and nine-element matrix.
The target also belongs to the normal Darwin native suite. Intel execution on
an Apple Silicon development host uses the installed Rosetta runtime and Zig's
`-frosetta` option; that evidence is identified as translated x86_64 execution.
These checks establish message ABI behavior, without claiming sensor readings,
native game presentation or original-game parity.

Apple's [runtime header](https://github.com/apple-oss-distributions/objc4/blob/main/runtime/message.h)
marks `objc_msgSend_stret` unavailable on ARM64.
