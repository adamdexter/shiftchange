#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Bridge to the private CoreBrightness framework's CBBlueLightClient.
/// All methods dynamically load the framework at runtime.
@interface CBlueLightBridge : NSObject

/// Returns YES if Night Shift is currently enabled (manual toggle or schedule-triggered).
+ (BOOL)isNightShiftEnabled;

/// Returns YES if the Night Shift feature is running/monitoring — true whenever
/// a schedule is configured, even outside warming hours. This does NOT mean the
/// display is currently warmed; use isNightShiftEnabled for that.
+ (BOOL)isNightShiftActive;

/// Enable or disable Night Shift.
+ (void)setNightShiftEnabled:(BOOL)enabled;

/// Returns YES if Night Shift has a schedule configured (sun-based or custom).
+ (BOOL)isNightShiftScheduled;

/// Registers a handler invoked on the main queue whenever Night Shift status
/// changes (schedule triggers, System Settings, Control Center, or our own
/// setNightShiftEnabled: calls). Pass nil to remove the handler.
+ (void)setStatusChangeHandler:(void (^ _Nullable)(void))handler;

@end

NS_ASSUME_NONNULL_END
