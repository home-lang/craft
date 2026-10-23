// Native visibility contract researched in Hidden Bar (MIT), Copyright (c) 2019
// Dwarves Foundation. See third-party/hidden-bar-LICENSE. Native code belongs in
// Craft so consumers need no platform sources or private-framework knowledge.
#import "menubar_visibility.h"
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <dlfcn.h>

@protocol CraftVisibilityConfiguration
- (id)initWithAllowedSystemItems:(NSArray *)systemItems allowedBundleIdentifiers:(NSArray *)bundles;
@end
@protocol CraftVisibilityAssertion
- (void)activateWithConfiguration:(id)configuration completionHandler:(void (^)(NSError *))completion;
- (void)invalidate;
@end

static NSStatusItem *marker;
static void (*changed)(void);
static id<CraftVisibilityAssertion> assertion;
static id<CraftVisibilityAssertion> pendingAssertion;
static NSUInteger generation;
static BOOL busy;
static BOOL requestedPermission;
static NSString *failure;
static NSUInteger hiddenAppCount;
static Class configurationClass;
static Class assertionClass;

static BOOL available(void) {
    // Sandboxed/App Store consumers must never activate this private backend.
    if (getenv("APP_SANDBOX_CONTAINER_ID")) return NO;
    if (![NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){27, 0, 0}]) return NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (dlopen("/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore", RTLD_NOW | RTLD_LOCAL)) {
            configurationClass = NSClassFromString(@"MBAssessmentModeConfiguration");
            assertionClass = NSClassFromString(@"MBAssessmentModeAssertion");
        }
    });
    return [configurationClass instancesRespondToSelector:@selector(initWithAllowedSystemItems:allowedBundleIdentifiers:)]
        && [assertionClass instancesRespondToSelector:@selector(activateWithConfiguration:completionHandler:)]
        && [assertionClass instancesRespondToSelector:@selector(invalidate)];
}

static void invalidate(id<CraftVisibilityAssertion> value) {
    @try { [value invalidate]; }
    @catch (NSException *exception) { NSLog(@"Craft menu bar: invalidate failed: %@", exception); }
}

static void notify(void) {
    if (changed) changed();
}

static void fail(NSString *reason) {
    generation++;
    invalidate(pendingAssertion);
    pendingAssertion = nil;
    invalidate(assertion);
    assertion = nil;
    busy = NO;
    hiddenAppCount = 0;
    failure = reason;
    notify();
}

bool craft_menubar_visibility_available(void) { return available(); }

void craft_menubar_visibility_init(void *item, void (*callback)(void)) {
    marker = (__bridge NSStatusItem *)item;
    changed = callback;
    failure = available() ? nil : @"unavailable";
}

void craft_menubar_visibility_request_permission(void) {
    if (!available() || AXIsProcessTrusted()) return;
    if (!requestedPermission) {
        requestedPermission = YES;
        AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES});
    }
    // A denied request may no longer show a prompt. An explicit user action
    // always opens the OS permission pane; it never grants access itself.
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
    notify();
}

// Keep incomplete geometry visible. A bundle with icons on both sides belongs
// to the visible group, because macOS hides by owning application.
static void recordItem(NSMutableDictionary *sections, NSString *bundle, CGRect frame, double boundary, BOOL rtl) {
    BOOL valid = !CGRectIsNull(frame) && frame.size.width > 0 && frame.size.height > 0
        && isfinite(frame.origin.x) && isfinite(frame.size.width);
    BOOL visible = !valid || (rtl ? CGRectGetMidX(frame) < boundary : CGRectGetMidX(frame) > boundary);
    sections[bundle] = @([sections[bundle] boolValue] || visible);
}

static NSArray *allowedBundles(NSArray<NSString *> *bundles, NSDictionary *sections, NSArray<NSString *> *ownBundles, NSUInteger *hiddenCount) {
    NSSet *system = [NSSet setWithArray:@[@"com.apple.MenuBarAgent", @"com.apple.controlcenter", @"com.apple.systemuiserver"]];
    NSSet *protected = [NSSet setWithArray:ownBundles];
    NSMutableSet *allowed = [protected mutableCopy];
    NSMutableSet *hidden = [NSMutableSet set];
    for (NSString *bundle in bundles) {
        if (sections[bundle] && ![sections[bundle] boolValue] && ![protected containsObject:bundle] && ![system containsObject:bundle])
            [hidden addObject:bundle];
        else [allowed addObject:bundle];
    }
    *hiddenCount = hidden.count;
    return allowed.allObjects;
}

// AX is queried off the AppKit run loop. Each app has a bounded timeout. A
// missing/incomplete inventory entry is kept visible, never guessed as hidden.
static NSDictionary<NSString *, NSNumber *> *inventory(NSArray<NSRunningApplication *> *apps, double boundary, BOOL rtl) {
    NSMutableDictionary *sections = [NSMutableDictionary dictionary];
    NSSet *system = [NSSet setWithArray:@[@"com.apple.MenuBarAgent", @"com.apple.controlcenter", @"com.apple.systemuiserver"]];
    for (NSRunningApplication *app in apps) {
        NSString *bundle = app.bundleIdentifier;
        if (!bundle || [system containsObject:bundle]) continue;
        AXUIElementRef element = AXUIElementCreateApplication(app.processIdentifier);
        AXUIElementSetMessagingTimeout(element, 0.1);
        CFTypeRef bar = NULL;
        if (AXUIElementCopyAttributeValue(element, CFSTR("AXExtrasMenuBar"), &bar) == kAXErrorSuccess && bar) {
            if (CFGetTypeID(bar) != AXUIElementGetTypeID()) {
                CFRelease(bar);
                CFRelease(element);
                continue;
            }
            CFTypeRef children = NULL;
            AXUIElementSetMessagingTimeout((AXUIElementRef)bar, 0.1);
            if (AXUIElementCopyAttributeValue((AXUIElementRef)bar, kAXChildrenAttribute, &children) == kAXErrorSuccess && children) {
                if (CFGetTypeID(children) != CFArrayGetTypeID()) {
                    CFRelease(children);
                    CFRelease(bar);
                    CFRelease(element);
                    continue;
                }
                for (id child in (__bridge NSArray *)children) {
                    if (CFGetTypeID((__bridge CFTypeRef)child) != AXUIElementGetTypeID()) continue;
                    CFTypeRef position = NULL, size = NULL;
                    AXUIElementRef item = (__bridge AXUIElementRef)child;
                    AXUIElementSetMessagingTimeout(item, 0.1);
                    AXError p = AXUIElementCopyAttributeValue(item, kAXPositionAttribute, &position);
                    AXError s = AXUIElementCopyAttributeValue(item, kAXSizeAttribute, &size);
                    CGPoint point = CGPointZero;
                    CGSize dimensions = CGSizeZero;
                    if (p == kAXErrorSuccess && s == kAXErrorSuccess && position && size
                        && CFGetTypeID(position) == AXValueGetTypeID() && CFGetTypeID(size) == AXValueGetTypeID()
                        && AXValueGetValue(position, kAXValueCGPointType, &point)
                        && AXValueGetValue(size, kAXValueCGSizeType, &dimensions)
                        && dimensions.width > 0 && dimensions.height > 0 && isfinite(point.x)) {
                        recordItem(sections, bundle, (CGRect){point, dimensions}, boundary, rtl);
                    } else recordItem(sections, bundle, CGRectNull, boundary, rtl);
                    if (position) CFRelease(position);
                    if (size) CFRelease(size);
                }
                CFRelease(children);
            }
            CFRelease(bar);
        }
        CFRelease(element);
    }
    return sections;
}

static void activationDeadline(NSUInteger ticket) {
    if (ticket == generation && busy) fail(@"activationTimeout");
}

static void activate(NSArray *systemItems, NSArray *allowed, NSUInteger hidden, NSUInteger ticket) {
    @try {
        id configuration = [(id<CraftVisibilityConfiguration>)[configurationClass alloc]
            initWithAllowedSystemItems:[systemItems copy] allowedBundleIdentifiers:[allowed copy]];
        id<CraftVisibilityAssertion> pending = [[assertionClass alloc] init];
        if (!configuration || !pending) return fail(@"activationFailed");
        pendingAssertion = pending;
        [pending activateWithConfiguration:configuration completionHandler:^(NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (ticket != generation) { invalidate(pending); return; }
                if (error) {
                    invalidate(pending);
                    NSLog(@"Craft menu bar activation: %@", error);
                    return fail(@"activationFailed");
                }
                assertion = pending;
                pendingAssertion = nil;
                busy = NO;
                hiddenAppCount = hidden;
                notify();
            });
        }];
    } @catch (NSException *exception) {
        NSLog(@"Craft menu bar activation: %@", exception);
        fail(@"activationFailed");
    }
}

void craft_menubar_visibility_collapse(void) {
    if (assertion || busy) return;
    if (!available()) return fail(@"unavailable");
    if (!AXIsProcessTrusted()) return fail(@"permissionRequired");
    NSString *ownBundle = NSBundle.mainBundle.bundleIdentifier;
    NSString *registeredBundle = NSRunningApplication.currentApplication.bundleIdentifier;
    NSMutableArray *ownBundles = [NSMutableArray array];
    if (ownBundle.length) [ownBundles addObject:ownBundle];
    // A composite app can register its native helper under a second identity.
    // Protect both identities regardless of where the user moves the cup.
    if (registeredBundle.length) [ownBundles addObject:registeredBundle];
    NSRect frame = marker.button.window.frame;
    if (!ownBundle.length || !marker.button.window || NSWidth(frame) <= 0) return fail(@"layoutUnavailable");
    busy = YES;
    failure = nil;
    const NSUInteger ticket = ++generation;
    const double boundary = NSMidX(frame);
    const BOOL rtl = NSApp.userInterfaceLayoutDirection == NSUserInterfaceLayoutDirectionRightToLeft;
    // Enumerate genuine app bundles, not every WebKit/XPC helper. Retaining the
    // running-app objects gives the worker a stable snapshot without AppKit IO.
    NSArray *apps = [NSWorkspace.sharedWorkspace.runningApplications filteredArrayUsingPredicate:
        [NSPredicate predicateWithBlock:^BOOL(NSRunningApplication *app, NSDictionary *bindings) {
            (void)bindings;
            return [app.bundleURL.pathExtension isEqualToString:@"app"];
        }]];
    notify();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        activationDeadline(ticket);
    });
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            NSDictionary *sections = inventory(apps, boundary, rtl);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (ticket != generation) return;
                if (!AXIsProcessTrusted()) return fail(@"permissionRequired");
                NSMutableArray *bundles = [NSMutableArray array];
                for (NSRunningApplication *app in apps)
                    if (app.bundleIdentifier) [bundles addObject:app.bundleIdentifier];
                NSUInteger hidden = 0;
                NSArray *allowed = allowedBundles(bundles, sections, ownBundles, &hidden);
                // Keep all system controls, including identifiers added by the
                // current OS. The framework ignores unrecognized identifiers.
                NSMutableArray *systemItems = [NSMutableArray array];
                for (NSUInteger i = 0; i < 64; i++) [systemItems addObject:@(i)];
                activate(systemItems, allowed, hidden, ticket);
            });
        }
    });
}

void craft_menubar_visibility_expand(void) {
    generation++;
    invalidate(pendingAssertion);
    pendingAssertion = nil;
    invalidate(assertion);
    assertion = nil;
    busy = NO;
    failure = nil;
    hiddenAppCount = 0;
    notify();
}

void craft_menubar_visibility_cleanup(void) {
    craft_menubar_visibility_expand();
    changed = NULL;
    marker = nil;
}

bool craft_menubar_visibility_collapsed(void) { return assertion != nil; }
bool craft_menubar_visibility_busy(void) { return busy; }

const char *craft_menubar_visibility_state(void) {
    if (assertion && !AXIsProcessTrusted()) fail(@"permissionRequired");
    NSDictionary *state = @{
        @"backend": @"nativeVisibility", @"initialized": @((bool)(marker != nil)),
        @"collapsed": @((bool)(assertion != nil)), @"separatorHidden": @NO,
        @"available": @(available()), @"authorized": @((bool)AXIsProcessTrusted()),
        @"busy": @(busy), @"hiddenAppCount": @(hiddenAppCount),
        @"markerWidth": @(marker.length), @"error": failure ?: (id)NSNull.null,
    };
    NSData *json = [NSJSONSerialization dataWithJSONObject:state options:0 error:nil];
    // A C caller must not observe an ARC temporary after its final release.
    static NSString *serialized;
    serialized = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    return serialized.UTF8String;
}
