#import "CraftTimedInput.h"
#import <UIKit/UIKit.h>
#import <math.h>

// XCTest's own touch-record API is private. Look up classes and check every
// selector at runtime; unsupported Xcode versions fail rather than skipping or
// falling back to serialized taps. These declarations create no class linkage.
@interface NSObject (CraftTestingTouchRecords)
- (id)initForTouchAtPoint:(CGPoint)point offset:(double)offset;
- (void)moveToPoint:(CGPoint)point atOffset:(double)offset;
- (void)liftUpAtOffset:(double)offset;
- (id)initWithName:(NSString *)name interfaceOrientation:(NSInteger)orientation;
- (void)addPointerEventPath:(id)path;
- (BOOL)synthesizeWithError:(NSError **)error;
@end

@implementation CraftTimedInput
+ (BOOL)fail:(NSString *)message error:(NSError **)error {
    if (error) *error = [NSError errorWithDomain:@"CraftTimedInput" code:1
                                      userInfo:@{NSLocalizedDescriptionKey: message}];
    return NO;
}

+ (BOOL)synthesizePaths:(NSArray *)paths frame:(CGRect)frame error:(NSError **)error {
    if (![paths isKindOfClass:NSArray.class] || paths.count == 0 || paths.count > 64
        || CGRectIsEmpty(frame) || !isfinite(frame.size.width) || !isfinite(frame.size.height))
        return [self fail:@"Expected 1–64 timed touch paths and a visible app frame" error:error];
    // Validate the entire record before any native event is submitted.
    for (id path in paths) {
        if (![path isKindOfClass:NSArray.class] || [path count] < 2 || [path count] > 64)
            return [self fail:@"Each touch needs 2–64 points" error:error];
        double previous = -1;
        for (id point in path) {
            if (![point isKindOfClass:NSDictionary.class]) return [self fail:@"Invalid touch point" error:error];
            for (NSString *key in @[@"x", @"y", @"at"]) {
                id value = point[key];
                if (![value isKindOfClass:NSNumber.class] || !isfinite([value doubleValue]))
                    return [self fail:@"Touch coordinates and times must be finite numbers" error:error];
            }
            double x = [point[@"x"] doubleValue], y = [point[@"y"] doubleValue], at = [point[@"at"] doubleValue];
            if (x < 0 || x > 1 || y < 0 || y > 1 || at < 0 || at > 12 || at <= previous)
                return [self fail:@"Touch coordinates must be normalized; times must increase within 12 seconds" error:error];
            previous = at;
        }
    }
    Class recordClass = NSClassFromString(@"XCSynthesizedEventRecord");
    Class pathClass = NSClassFromString(@"XCPointerEventPath");
    for (NSString *name in @[@"initWithName:interfaceOrientation:", @"addPointerEventPath:", @"synthesizeWithError:"])
        if (![recordClass instancesRespondToSelector:NSSelectorFromString(name)])
            return [self fail:@"XCTest does not support timed native event records" error:error];
    for (NSString *name in @[@"initForTouchAtPoint:offset:", @"moveToPoint:atOffset:", @"liftUpAtOffset:"])
        if (![pathClass instancesRespondToSelector:NSSelectorFromString(name)])
            return [self fail:@"XCTest does not support timed native touch paths" error:error];
    id record = [[recordClass alloc] initWithName:@"Craft timed native input" interfaceOrientation:UIInterfaceOrientationPortrait];
    if (!record) return [self fail:@"XCTest refused a native event record" error:error];
    for (NSArray *points in paths) {
        NSDictionary *first = points.firstObject;
        CGPoint start = CGPointMake(frame.origin.x + [first[@"x"] doubleValue] * frame.size.width,
                                    frame.origin.y + [first[@"y"] doubleValue] * frame.size.height);
        id path = [[pathClass alloc] initForTouchAtPoint:start offset:[first[@"at"] doubleValue]];
        if (!path) return [self fail:@"XCTest refused a native touch path" error:error];
        for (NSUInteger index = 1; index < points.count; index++) {
            NSDictionary *point = points[index];
            CGPoint location = CGPointMake(frame.origin.x + [point[@"x"] doubleValue] * frame.size.width,
                                           frame.origin.y + [point[@"y"] doubleValue] * frame.size.height);
            [path moveToPoint:location atOffset:[point[@"at"] doubleValue]];
        }
        [path liftUpAtOffset:[points.lastObject[@"at"] doubleValue]];
        [record addPointerEventPath:path];
    }
    // One dispatch retains the native offsets between different fingers/taps.
    // Individual XCUICoordinate.tap() calls would wait for app quiescence.
    return [record synthesizeWithError:error];
}
@end
