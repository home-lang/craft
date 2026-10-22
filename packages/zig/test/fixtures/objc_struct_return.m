#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef struct { double x, y, z; } CraftVector3;
typedef struct { double values[9]; } CraftMatrix3;

@interface CraftStructReturnFixture : NSObject
- (CGPoint)smallPoint;
- (CGRect)largeRect;
- (CraftVector3)acceleration;
- (CraftMatrix3)largeMatrix;
@end

@implementation CraftStructReturnFixture
- (CGPoint)smallPoint { return CGPointMake(-17.5, 0.25); }
- (CGRect)largeRect { return CGRectMake(-17.5, 0.25, 200.0, 64.5); }
- (CraftVector3)acceleration { return (CraftVector3){ -17.5, 0.25, 64.5 }; }
- (CraftMatrix3)largeMatrix {
    return (CraftMatrix3){ { 1.25, -2.5, 3.75, 4.5, -5.25, 6.0, 7.5, -8.75, 9.25 } };
}
@end

void *craftStructReturnFixtureCreate(void) {
    return [[CraftStructReturnFixture alloc] init];
}
