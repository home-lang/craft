// Exercises the production native lifecycle with controlled asynchronous replies.
// No Accessibility grant or live menu-bar restriction is used by this fixture.
#import <ApplicationServices/ApplicationServices.h>
static Boolean trusted = true;
static Boolean testTrusted(void) { return trusted; }
#define AXIsProcessTrusted testTrusted
#import "../src/menubar_visibility.m"
#include <assert.h>
#include <spawn.h>
#include <sys/wait.h>

@interface TestConfiguration : NSObject <CraftVisibilityConfiguration>
@end
@implementation TestConfiguration
- (id)initWithAllowedSystemItems:(NSArray *)systemItems allowedBundleIdentifiers:(NSArray *)bundles {
    assert([systemItems isKindOfClass:NSArray.class]);
    assert([bundles isKindOfClass:NSArray.class]);
    return [super init];
}
@end

static BOOL throwOnActivation;
static NSMutableArray *created;
static NSDictionary *snapshot = nil;
static NSDictionary *testSnapshot(pid_t agent, double boundary, BOOL rtl, BOOL protectedOnly) {
    (void)agent; (void)boundary; (void)rtl; (void)protectedOnly;
    return snapshot;
}
@interface TestAssertion : NSObject <CraftVisibilityAssertion>
@property (copy) void (^completion)(NSError *);
@property BOOL invalidated;
@end
@implementation TestAssertion
- (void)activateWithConfiguration:(id)configuration completionHandler:(void (^)(NSError *))completion {
    (void)configuration;
    [created addObject:self];
    self.completion = completion;
    if (throwOnActivation) [NSException raise:@"TestException" format:@"Activation failed"];
}
- (void)invalidate { self.invalidated = YES; }
@end

static TestAssertion *begin(void) {
    busy = YES;
    activate(@[@0, @1], @[@"own.app"], 2, ++generation, 1, 100, NO, @{@"right": @1});
    return created.lastObject;
}
static void drain(void) {
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.35, false);
}
static NSDictionary *state(void) {
    const char *json = craft_menubar_visibility_state();
    return [NSJSONSerialization JSONObjectWithData:[[NSString stringWithUTF8String:json] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}
int main(int argc, char *argv[]) {
    if (argc == 2 && strcmp(argv[1], "--identity-fixture") == 0) {
        pause();
        return 0;
    }
    @autoreleasepool {
        (void)available(); // Resolve once before substituting the test classes.
        configurationClass = TestConfiguration.class;
        assertionClass = TestAssertion.class;
        created = [NSMutableArray array];
        snapshot = @{@"right": @1, @"system": @1};
        readBarSnapshot = testSnapshot;
        assert(preservesItems(@{@"right": @1}, snapshot));
        assert(!preservesItems(@{@"right": @2}, snapshot));
        assert(!preservesItems(@{@"missing": @1}, snapshot));
        assert(!preservesItems(nil, snapshot));
        // Unlabeled items are matched by retained AX identity, not by a shared
        // empty string or a position that changes when the bar reflows.
        AXUIElementRef anonymous = AXUIElementCreateApplication(getpid());
        AXUIElementRef same = AXUIElementCreateApplication(getpid());
        AXUIElementRef other = AXUIElementCreateApplication(getpid() + 1);
        NSDictionary *expectedAnonymous = @{@"anonymous": @[(__bridge id)anonymous]};
        assert(preservesItems(expectedAnonymous, @{@"anonymous": @[(__bridge id)same]}));
        assert(!preservesItems(expectedAnonymous, @{@"anonymous": @[(__bridge id)other]}));
        assert(!preservesItems(expectedAnonymous, snapshot));
        assert(!preservesItems(@{@"anonymous": @[(__bridge id)anonymous, (__bridge id)anonymous]}, expectedAnonymous));
        CFRelease(anonymous); CFRelease(same); CFRelease(other);
        // A helper's sealed identifier differs from its app/LaunchServices ID.
        // It must stay allowed even when its icon sits in the hidden section.
        NSString *signedIdentity = @"dev.craft.visibility.fixture.runtime";
        assert([signingIdentifier() isEqual:signedIdentity]);
        assert([processSigningIdentifier(getpid()) isEqual:signedIdentity]);
        assert(processSigningIdentifier(-1) == nil);
        // Reading another live process must work without task-port access or
        // a matching LaunchServices app bundle. Reap only this owned fixture.
        pid_t guest;
        char *guestArgs[] = {argv[0], "--identity-fixture", NULL};
        extern char **environ;
        assert(posix_spawn(&guest, argv[0], NULL, NULL, guestArgs, environ) == 0);
        NSString *guestIdentity = processSigningIdentifier(guest);
        assert(kill(guest, SIGTERM) == 0);
        assert(waitpid(guest, NULL, 0) == guest);
        assert([guestIdentity isEqual:signedIdentity]);
        NSArray *protectedIdentifiers = ownIdentifiers();
        assert([protectedIdentifiers containsObject:signedIdentity]);
        NSUInteger selfHidden = 0;
        NSArray *selfAllowed = allowedBundles(@[signedIdentity, @"other.app"],
            @{signedIdentity: @NO, @"other.app": @NO}, @{}, protectedIdentifiers, &selfHidden);
        assert(selfHidden == 1 && [selfAllowed containsObject:signedIdentity]);
        assert(![selfAllowed containsObject:@"other.app"]);
        NSMutableDictionary *sections = [NSMutableDictionary dictionary];
        CGRect left = CGRectMake(20, 0, 20, 24), right = CGRectMake(200, 0, 20, 24);
        recordItem(sections, @"left", left, 100, NO);
        recordItem(sections, @"right", right, 100, NO);
        recordItem(sections, @"both", left, 100, NO);
        recordItem(sections, @"both", right, 100, NO);
        recordItem(sections, @"both", left, 100, NO);
        recordItem(sections, @"unknown", left, 100, NO);
        recordItem(sections, @"unknown", CGRectNull, 100, NO);
        recordItem(sections, @"rtl-left", left, 100, YES);
        recordItem(sections, @"rtl-right", right, 100, YES);
        assert(![sections[@"left"] boolValue] && [sections[@"right"] boolValue]);
        assert([sections[@"both"] boolValue] && [sections[@"unknown"] boolValue]);
        assert([sections[@"rtl-left"] boolValue] && ![sections[@"rtl-right"] boolValue]);
        sections[@"own.app"] = @NO;
        sections[@"native.helper"] = @NO;
        sections[@"com.apple.controlcenter"] = @NO;
        NSUInteger hidden = 0;
        NSArray *allowed = allowedBundles(@[@"left", @"left", @"right", @"both", @"new", @"unknown", @"own.app", @"native.helper", @"com.apple.controlcenter"], sections, @{}, @[@"own.app", @"native.helper"], &hidden);
        assert(hidden == 1 && ![allowed containsObject:@"left"]);
        for (NSString *bundle in @[@"right", @"both", @"new", @"unknown", @"own.app", @"native.helper", @"com.apple.controlcenter"]) assert([allowed containsObject:bundle]);

        // Allow a right-side native helper by its actual signing identity.
        // An independent left-side app keeps both of its identities excluded.
        NSDictionary *identities = @{
            @"left": @[@"left", @"left.runtime"],
            @"right": @[@"right", @"right.runtime"],
            @"new": @[@"new", @"new.runtime"],
        };
        NSArray *nativeAllowed = allowedBundles(@[@"left", @"right", @"new"], sections, identities, @[], &hidden);
        assert(hidden == 1 && ![nativeAllowed containsObject:@"left"] && ![nativeAllowed containsObject:@"left.runtime"]);
        for (NSString *identifier in @[@"right", @"right.runtime", @"new", @"new.runtime"]) assert([nativeAllowed containsObject:identifier]);

        // Two apps sharing a signed runtime cannot be hidden independently.
        // The visible member protects all aliases, including chained groups.
        NSDictionary *shared = @{
            @"left": @[@"left", @"shared.first"],
            @"also.left": @[@"also.left", @"shared.first", @"shared.second"],
            @"right": @[@"right", @"shared.second"],
            @"independent": @[@"independent", @"independent.runtime"],
        };
        NSArray *sharedAllowed = allowedBundles(@[@"left", @"also.left", @"right", @"independent"],
            @{@"left": @NO, @"also.left": @NO, @"right": @YES, @"independent": @NO}, shared, @[], &hidden);
        assert(hidden == 1 && ![sharedAllowed containsObject:@"independent"] && ![sharedAllowed containsObject:@"independent.runtime"]);
        for (NSString *identifier in @[@"left", @"also.left", @"right", @"shared.first", @"shared.second"]) assert([sharedAllowed containsObject:identifier]);
        NSArray *sharedHidden = allowedBundles(@[@"left", @"also.left"],
            @{@"left": @NO, @"also.left": @NO}, shared, @[], &hidden);
        assert(hidden == 2 && ![sharedHidden containsObject:@"shared.first"] && ![sharedHidden containsObject:@"shared.second"]);

        busy = YES;
        activate(@[@0, @1], ownIdentifiers(), 0, ++generation, 1, 100, NO, snapshot);
        assert(!busy && !assertion && created.count == 0 && [failure isEqual:@"emptyGroup"]);

        TestAssertion *first = begin();
        assert(busy && !assertion);
        first.completion(nil); drain();
        assert(assertion == first && !busy && hiddenAppCount == 2);
        assert(CFGetTypeID((__bridge CFTypeRef)state()[@"collapsed"]) == CFBooleanGetTypeID());
        craft_menubar_visibility_expand();
        assert(first.invalidated && !assertion && !busy && hiddenAppCount == 0);

        snapshot = @{@"unexpected": @1};
        TestAssertion *unsafe = begin();
        unsafe.completion(nil); drain();
        assert(unsafe.invalidated && !assertion && !busy && [failure isEqual:@"visibilityMismatch"]);
        snapshot = @{@"right": @1, @"system": @1};

        TestAssertion *checking = begin();
        checking.completion(nil);
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, false);
        craft_menubar_visibility_expand();
        drain();
        assert(checking.invalidated && !assertion && !busy);

        TestAssertion *stale = begin();
        craft_menubar_visibility_expand();
        TestAssertion *current = begin();
        stale.completion(nil); drain();
        assert(stale.invalidated && !assertion && busy);
        current.completion(nil); drain();
        assert(assertion == current && !current.invalidated);
        trusted = false;
        assert([state()[@"error"] isEqual:@"permissionRequired"]);
        assert(current.invalidated && !assertion && !busy);
        trusted = true;

        TestAssertion *failed = begin();
        failed.completion([NSError errorWithDomain:@"test" code:1 userInfo:nil]); drain();
        assert(failed.invalidated && !assertion && !busy && [failure isEqual:@"activationFailed"]);
        TestAssertion *timed = begin();
        activationDeadline(generation);
        assert(timed.invalidated && !busy && [failure isEqual:@"activationTimeout"]);
        timed.completion(nil); drain();
        assert(!assertion);

        throwOnActivation = YES;
        TestAssertion *exception = begin();
        assert(exception.invalidated && !assertion && !busy && [failure isEqual:@"activationFailed"]);
        throwOnActivation = NO;
        TestAssertion *quitting = begin();
        craft_menubar_visibility_cleanup();
        quitting.completion(nil); drain();
        assert(quitting.invalidated && !assertion && !pendingAssertion && !busy && !marker);
        puts("native visibility: grouping, protected owners, JSON booleans, cancellation, permission revocation, errors, timeout and quit passed");
    }
}
