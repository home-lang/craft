#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN
/// Test-runner-only native events. Never linked into a shipped application.
@interface CraftTimedInput : NSObject
+ (BOOL)synthesizePaths:(NSArray<NSArray<NSDictionary<NSString *, NSNumber *> *> *> *)paths
                 frame:(CGRect)frame
                 error:(NSError * _Nullable * _Nullable)error NS_SWIFT_NAME(synthesize(paths:frame:));
@end
NS_ASSUME_NONNULL_END
