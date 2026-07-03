#import "CBlueLightBridge.h"
#import <dlfcn.h>
#import <objc/runtime.h>
#import <objc/message.h>

// Status struct returned by CBBlueLightClient -getBlueLightStatus:
// Layout from reverse engineering; fields may vary across macOS versions.
typedef struct {
    BOOL active;
    BOOL enabled;
    BOOL sunSchedulePermitted;
    int mode;  // 0 = off, 1 = sunSchedule, 2 = customSchedule
    // Additional schedule fields follow but are not needed here.
    unsigned char _padding[508];
} BlueLightStatus;

@implementation CBlueLightBridge

+ (id _Nullable)sharedClient {
    static id client = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Dynamically load the CoreBrightness private framework
        void *handle = dlopen(
            "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness",
            RTLD_LAZY
        );
        if (!handle) {
            NSLog(@"[ShiftChange] Failed to load CoreBrightness framework");
            return;
        }

        Class CBBlueLightClient = NSClassFromString(@"CBBlueLightClient");
        if (!CBBlueLightClient) {
            NSLog(@"[ShiftChange] CBBlueLightClient class not found");
            return;
        }

        client = [[CBBlueLightClient alloc] init];
    });
    return client;
}

/// Fetches the current status into *status. Returns NO if the client is
/// unavailable or the call fails.
+ (BOOL)fetchStatus:(BlueLightStatus *)status {
    id client = [self sharedClient];
    if (!client) return NO;

    SEL sel = NSSelectorFromString(@"getBlueLightStatus:");
    if (![client respondsToSelector:sel]) {
        NSLog(@"[ShiftChange] getBlueLightStatus: selector not found");
        return NO;
    }

    // Use objc_msgSend to call the method with a struct pointer argument
    BOOL (*getStatus)(id, SEL, BlueLightStatus *) =
        (BOOL (*)(id, SEL, BlueLightStatus *))objc_msgSend;
    return getStatus(client, sel, status);
}

+ (BOOL)isNightShiftEnabled {
    BlueLightStatus status = {0};
    if (![self fetchStatus:&status]) return NO;
    return status.enabled;
}

+ (BOOL)isNightShiftActive {
    BlueLightStatus status = {0};
    if (![self fetchStatus:&status]) return NO;
    return status.active;
}

+ (void)setNightShiftEnabled:(BOOL)enabled {
    id client = [self sharedClient];
    if (!client) return;

    SEL sel = NSSelectorFromString(@"setEnabled:");
    if (![client respondsToSelector:sel]) {
        NSLog(@"[ShiftChange] setEnabled: selector not found");
        return;
    }

    void (*setEnabled)(id, SEL, BOOL) =
        (void (*)(id, SEL, BOOL))objc_msgSend;
    setEnabled(client, sel, enabled);
}

+ (BOOL)isNightShiftScheduled {
    BlueLightStatus status = {0};
    if (![self fetchStatus:&status]) return NO;

    // mode != 0 means a schedule is configured
    return status.mode != 0;
}

@end
