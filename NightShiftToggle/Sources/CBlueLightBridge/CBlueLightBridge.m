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
            NSLog(@"[NightShiftToggle] Failed to load CoreBrightness framework");
            return;
        }

        Class CBBlueLightClient = NSClassFromString(@"CBBlueLightClient");
        if (!CBBlueLightClient) {
            NSLog(@"[NightShiftToggle] CBBlueLightClient class not found");
            return;
        }

        client = [[CBBlueLightClient alloc] init];
    });
    return client;
}

+ (BOOL)isNightShiftEnabled {
    id client = [self sharedClient];
    if (!client) return NO;

    BlueLightStatus status = {0};
    // -getBlueLightStatus: takes a pointer to the status struct
    SEL sel = NSSelectorFromString(@"getBlueLightStatus:");
    if (![client respondsToSelector:sel]) {
        NSLog(@"[NightShiftToggle] getBlueLightStatus: selector not found");
        return NO;
    }

    // Use objc_msgSend to call the method with a struct pointer argument
    BOOL (*getStatus)(id, SEL, BlueLightStatus *) =
        (BOOL (*)(id, SEL, BlueLightStatus *))objc_msgSend;
    getStatus(client, sel, &status);

    return status.enabled;
}

+ (void)setNightShiftEnabled:(BOOL)enabled {
    id client = [self sharedClient];
    if (!client) return;

    SEL sel = NSSelectorFromString(@"setEnabled:");
    if (![client respondsToSelector:sel]) {
        NSLog(@"[NightShiftToggle] setEnabled: selector not found");
        return;
    }

    void (*setEnabled)(id, SEL, BOOL) =
        (void (*)(id, SEL, BOOL))objc_msgSend;
    setEnabled(client, sel, enabled);
}

+ (BOOL)isNightShiftScheduled {
    id client = [self sharedClient];
    if (!client) return NO;

    BlueLightStatus status = {0};
    SEL sel = NSSelectorFromString(@"getBlueLightStatus:");
    if (![client respondsToSelector:sel]) {
        return NO;
    }

    BOOL (*getStatus)(id, SEL, BlueLightStatus *) =
        (BOOL (*)(id, SEL, BlueLightStatus *))objc_msgSend;
    getStatus(client, sel, &status);

    // mode != 0 means a schedule is configured
    return status.mode != 0;
}

@end
