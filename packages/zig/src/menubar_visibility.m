// Native visibility contract researched in Hidden Bar (MIT), Copyright (c) 2019
// Dwarves Foundation. See third-party/hidden-bar-LICENSE. Native code belongs in
// Craft so consumers need no platform sources or private-framework knowledge.
#import "menubar_visibility.h"
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Security/Security.h>
#import <dlfcn.h>
#include <unistd.h>

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

static NSString *identifierForCode(SecCodeRef code) {
    CFDictionaryRef information = NULL;
    NSString *identifier = nil;
    if (SecCodeCopySigningInformation(code, kSecCSDefaultFlags, &information) == errSecSuccess) {
        id value = (__bridge id)CFDictionaryGetValue(information, kSecCodeInfoIdentifier);
        if ([value isKindOfClass:NSString.class]) identifier = [value copy];
        CFRelease(information);
    }
    return identifier;
}

static NSString *signingIdentifier(void) {
    SecCodeRef code = NULL;
    NSString *identifier = nil;
    if (SecCodeCopySelf(kSecCSDefaultFlags, &code) == errSecSuccess) {
        identifier = identifierForCode(code);
        CFRelease(code);
    }
    return identifier;
}

static NSString *processSigningIdentifier(pid_t pid) {
    SecCodeRef code = NULL;
    NSString *identifier = nil;
    NSDictionary *attributes = @{(__bridge NSString *)kSecGuestAttributePid: @(pid)};
    if (SecCodeCopyGuestWithAttributes(NULL, (__bridge CFDictionaryRef)attributes, kSecCSDefaultFlags, &code) == errSecSuccess) {
        identifier = identifierForCode(code);
        CFRelease(code);
    }
    return identifier;
}

static NSDictionary *applicationIdentities(NSArray<NSRunningApplication *> *apps) {
    NSMutableDictionary *identities = [NSMutableDictionary dictionary];
    for (NSRunningApplication *app in apps) {
        NSString *bundle = app.bundleIdentifier;
        NSString *signedIdentity = processSigningIdentifier(app.processIdentifier);
        if (!bundle.length && !signedIdentity.length) continue;
        // An unbundled GUI process still has a native signing identity. Its
        // unknown position stays visible; this process key is inventory-only.
        NSString *key = bundle.length ? bundle : [NSString stringWithFormat:@"process:%d", app.processIdentifier];
        NSMutableSet *aliases = identities[key];
        if (!aliases) identities[key] = aliases = [NSMutableSet set];
        if (bundle.length) [aliases addObject:bundle];
        if (signedIdentity.length) [aliases addObject:signedIdentity];
    }
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSString *bundle in identities) result[bundle] = [identities[bundle] allObjects];
    return result;
}

static NSArray<NSString *> *ownIdentifiers(void) {
    NSMutableOrderedSet *identifiers = [NSMutableOrderedSet orderedSet];
    NSString *bundle = NSBundle.mainBundle.bundleIdentifier;
    NSString *registered = NSRunningApplication.currentApplication.bundleIdentifier;
    NSString *signedIdentity = signingIdentifier();
    if (bundle.length) [identifiers addObject:bundle];
    if (registered.length) [identifiers addObject:registered];
    // MenuBarAgent identifies a separately signed native helper by its sealed
    // signing identifier, even when LaunchServices reports its enclosing app ID.
    if (signedIdentity.length) [identifiers addObject:signedIdentity];
    return identifiers.array;
}

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

static NSArray *allowedBundles(NSArray<NSString *> *bundles, NSDictionary *sections, NSDictionary *identities,
    NSArray<NSString *> *ownBundles, NSUInteger *hiddenCount) {
    NSSet *system = [NSSet setWithArray:@[@"com.apple.MenuBarAgent", @"com.apple.controlcenter", @"com.apple.systemuiserver"]];
    NSSet *protected = [NSSet setWithArray:ownBundles];
    NSMutableSet *allowed = [protected mutableCopy];
    [allowed addObjectsFromArray:system.allObjects];
    NSMutableSet *hidden = [NSMutableSet set];
    for (NSString *bundle in bundles) {
        if (sections[bundle] && ![sections[bundle] boolValue] && ![protected containsObject:bundle] && ![system containsObject:bundle])
            [hidden addObject:bundle];
        else [allowed addObjectsFromArray:identities[bundle] ?: @[bundle]];
    }
    // Native helpers can share a signing identifier, including helpers from
    // different app bundles. If any member must remain visible, allow the
    // complete connected group. Hiding one side must never hide the other.
    BOOL updated;
    do {
        updated = NO;
        for (NSString *bundle in hidden.allObjects) {
            NSArray *aliases = identities[bundle] ?: @[bundle];
            if ([allowed intersectsSet:[NSSet setWithArray:aliases]]) {
                [allowed addObjectsFromArray:aliases];
                [hidden removeObject:bundle];
                updated = YES;
            }
        }
    } while (updated);
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
        // Helpers without an app bundle stay allowed without spending an AX
        // timeout on each one. Their identities still participate below.
        if (!bundle || ![app.bundleURL.pathExtension isEqualToString:@"app"] || [system containsObject:bundle]) continue;
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

static id attribute(AXUIElementRef element, CFStringRef name) {
    CFTypeRef value = NULL;
    if (AXUIElementCopyAttributeValue(element, name, &value) != kAXErrorSuccess) return nil;
    return CFBridgingRelease(value);
}

// Verify the displayed bar independently of the per-app grouping inventory.
// A private allow-list can silently omit an allowed app (notably a mismatched
// helper bundle), or suppress a system indicator. Such an activation is unsafe.
static BOOL snapshotItems(AXUIElementRef node, NSUInteger depth, double boundary, BOOL rtl,
    BOOL protectedOnly, NSMutableDictionary *items, NSUInteger *remaining) {
    if (!depth || !*remaining) return NO;
    (*remaining)--;
    AXUIElementSetMessagingTimeout(node, 0.1);
    NSString *role = attribute(node, kAXRoleAttribute);
    NSString *identifier = attribute(node, kAXIdentifierAttribute);
    BOOL system = [identifier isKindOfClass:NSString.class] && [identifier hasPrefix:@"com.apple.menuextra."];
    if (system || [role isEqual:(__bridge NSString *)kAXButtonRole]) {
        id position = attribute(node, kAXPositionAttribute), size = attribute(node, kAXSizeAttribute);
        CGPoint point = CGPointZero;
        CGSize dimensions = CGSizeZero;
        if (position && size && CFGetTypeID((__bridge CFTypeRef)position) == AXValueGetTypeID()
            && CFGetTypeID((__bridge CFTypeRef)size) == AXValueGetTypeID()
            && AXValueGetValue((__bridge AXValueRef)position, kAXValueCGPointType, &point)
            && AXValueGetValue((__bridge AXValueRef)size, kAXValueCGSizeType, &dimensions)
            && isfinite(point.x) && dimensions.width > 0 && dimensions.height > 0 && dimensions.height <= 64) {
            double middle = point.x + dimensions.width / 2;
            // The arrow changes its label after activation. Its own native
            // identity remains protected by the allow-list, not by text.
            BOOL arrow = fabs(middle - boundary) < 2;
            pid_t owner = 0;
            AXUIElementGetPid(node, &owner);
            BOOL visibleSide = rtl ? middle < boundary : middle > boundary;
            if (!arrow && (!protectedOnly || system || owner == getpid() || visibleSide)) {
                NSMutableArray *parts = [NSMutableArray arrayWithObject:role ?: @""];
                for (id name in @[(__bridge NSString *)kAXIdentifierAttribute, (__bridge NSString *)kAXTitleAttribute,
                    (__bridge NSString *)kAXDescriptionAttribute, (__bridge NSString *)kAXHelpAttribute]) {
                    id value = attribute(node, (__bridge CFStringRef)name);
                    [parts addObject:[value isKindOfClass:NSString.class] ? value : @""];
                }
                if (![[parts subarrayWithRange:NSMakeRange(1, 4)] componentsJoinedByString:@""].length) {
                    // An icon is allowed to omit every text attribute. Retain
                    // its native AX identity across the verification interval:
                    // labels and coordinates cannot identify this item safely.
                    NSMutableArray *anonymous = items[@"anonymous"];
                    if (!anonymous) items[@"anonymous"] = anonymous = [NSMutableArray array];
                    [anonymous addObject:(__bridge id)node];
                } else {
                    NSString *key = [parts componentsJoinedByString:@"\x1f"];
                    items[key] = @([items[key] unsignedIntegerValue] + 1);
                }
            }
        }
    }
    id children = attribute(node, kAXChildrenAttribute);
    if ([children isKindOfClass:NSArray.class]) {
        for (id child in children) {
            if (CFGetTypeID((__bridge CFTypeRef)child) == AXUIElementGetTypeID()
                && !snapshotItems((__bridge AXUIElementRef)child, depth - 1, boundary, rtl, protectedOnly, items, remaining)) return NO;
        }
    }
    return YES;
}

static NSDictionary *barSnapshot(pid_t agent, double boundary, BOOL rtl, BOOL protectedOnly) {
    if (!agent) return nil;
    AXUIElementRef element = AXUIElementCreateApplication(agent);
    NSMutableDictionary *items = [NSMutableDictionary dictionary];
    NSUInteger remaining = 256;
    BOOL complete = snapshotItems(element, 8, boundary, rtl, protectedOnly, items, &remaining);
    CFRelease(element);
    return complete && items.count ? [items copy] : nil;
}

static NSDictionary *(*readBarSnapshot)(pid_t, double, BOOL, BOOL) = barSnapshot;

static BOOL preservesItems(NSDictionary *expected, NSDictionary *actual) {
    if (!expected.count || !actual.count) return NO;
    for (NSString *key in expected) {
        if ([key isEqual:@"anonymous"]) {
            NSMutableArray *remaining = [actual[key] mutableCopy];
            for (id element in expected[key]) {
                NSUInteger match = [remaining indexOfObjectPassingTest:^BOOL(id candidate, NSUInteger index, BOOL *stop) {
                    (void)index; (void)stop;
                    return CFEqual((__bridge CFTypeRef)element, (__bridge CFTypeRef)candidate);
                }];
                if (!remaining || match == NSNotFound) return NO;
                [remaining removeObjectAtIndex:match];
            }
            continue;
        }
        if ([actual[key] unsignedIntegerValue] < [expected[key] unsignedIntegerValue]) return NO;
    }
    return YES;
}

static void activate(NSArray *systemItems, NSArray *allowed, NSUInteger hidden, NSUInteger ticket,
    pid_t agent, double boundary, BOOL rtl, NSDictionary *protectedItems) {
    // Assessment mode can suppress system indicators even with all apps allowed.
    // Never activate a global restriction when there is no selected app to hide.
    if (!hidden) return fail(@"emptyGroup");
    if (!protectedItems.count) return fail(@"layoutUnavailable");
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
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                    NSDictionary *actual = readBarSnapshot(agent, boundary, rtl, NO);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (ticket != generation) { invalidate(pending); return; }
                        if (!AXIsProcessTrusted()) return fail(@"permissionRequired");
                        if (!preservesItems(protectedItems, actual)) return fail(@"visibilityMismatch");
                        assertion = pending;
                        pendingAssertion = nil;
                        busy = NO;
                        hiddenAppCount = hidden;
                        notify();
                    });
                });
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
    NSArray *ownBundles = ownIdentifiers();
    NSRect frame = marker.button.window.frame;
    if (!ownBundle.length || !marker.button.window || NSWidth(frame) <= 0) return fail(@"layoutUnavailable");
    busy = YES;
    failure = nil;
    const NSUInteger ticket = ++generation;
    const double boundary = NSMidX(frame);
    const BOOL rtl = NSApp.userInterfaceLayoutDirection == NSUserInterfaceLayoutDirectionRightToLeft;
    // Unknown helpers stay allowed too. Omitting one from a native allow-list
    // can hide its item even when its owning application is on the right.
    NSArray *apps = [NSWorkspace.sharedWorkspace.runningApplications copy];
    pid_t agent = 0;
    for (NSRunningApplication *app in apps)
        if ([app.bundleIdentifier isEqual:@"com.apple.MenuBarAgent"]) agent = app.processIdentifier;
    notify();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        activationDeadline(ticket);
    });
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            NSDictionary *sections = inventory(apps, boundary, rtl);
            NSDictionary *identities = applicationIdentities(apps);
            NSDictionary *protectedItems = readBarSnapshot(agent, boundary, rtl, YES);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (ticket != generation) return;
                if (!AXIsProcessTrusted()) return fail(@"permissionRequired");
                NSArray *bundles = identities.allKeys;
                NSUInteger hidden = 0;
                NSArray *allowed = allowedBundles(bundles, sections, identities, ownBundles, &hidden);
                // Keep all system controls, including identifiers added by the
                // current OS. The framework ignores unrecognized identifiers.
                NSMutableArray *systemItems = [NSMutableArray array];
                for (NSUInteger i = 0; i < 64; i++) [systemItems addObject:@(i)];
                activate(systemItems, allowed, hidden, ticket, agent, boundary, rtl, protectedItems);
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
