#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Bridge to the private CoreBrightness framework's CBBlueLightClient.
/// All methods dynamically load the framework at runtime.
@interface CBlueLightBridge : NSObject

/// Returns YES if Night Shift is currently enabled.
+ (BOOL)isNightShiftEnabled;

/// Enable or disable Night Shift.
+ (void)setNightShiftEnabled:(BOOL)enabled;

/// Returns YES if Night Shift has a schedule configured (sun-based or custom).
+ (BOOL)isNightShiftScheduled;

@end

NS_ASSUME_NONNULL_END
