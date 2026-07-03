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

#pragma mark - Appearance guard (SkyLight)

// macOS couples the "Auto" appearance setting to the Night Shift engine:
// toggling Night Shift can flip the system Light/Dark theme as a side
// effect. Night Shift tinting and the theme are independent settings from
// the user's point of view, so we snapshot the theme before our own
// setEnabled: calls and restore it if it changes in the seconds after.
// Scoped to OUR toggles only — theme changes made by the user or by the
// schedule outside our calls are left alone.

typedef BOOL (*SLSGetAppearanceThemeLegacyFunc)(void);
typedef void (*SLSSetAppearanceThemeLegacyFunc)(BOOL);

static SLSGetAppearanceThemeLegacyFunc slsGetTheme = NULL;
static SLSSetAppearanceThemeLegacyFunc slsSetTheme = NULL;
static NSUInteger themeGuardGeneration = 0;

static void loadSkyLightIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen(
            "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
            RTLD_LAZY
        );
        if (!handle) {
            NSLog(@"[ShiftChange] Failed to load SkyLight — appearance guard disabled");
            return;
        }
        slsGetTheme = (SLSGetAppearanceThemeLegacyFunc)dlsym(handle, "SLSGetAppearanceThemeLegacy");
        slsSetTheme = (SLSSetAppearanceThemeLegacyFunc)dlsym(handle, "SLSSetAppearanceThemeLegacy");
        if (!slsGetTheme || !slsSetTheme) {
            NSLog(@"[ShiftChange] SkyLight appearance symbols not found — appearance guard disabled");
            slsGetTheme = NULL;
            slsSetTheme = NULL;
        }
    });
}

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

    // Snapshot the theme so the appearance guard can undo any Light/Dark
    // flip this toggle causes (see the guard comment above).
    loadSkyLightIfNeeded();
    BOOL guardActive = (slsGetTheme != NULL && slsSetTheme != NULL);
    BOOL themeBefore = guardActive ? slsGetTheme() : NO;
    NSUInteger generation = ++themeGuardGeneration;

    void (*setEnabledFn)(id, SEL, BOOL) =
        (void (*)(id, SEL, BOOL))objc_msgSend;
    setEnabledFn(client, sel, enabled);

    if (!guardActive) return;

    // The appearance engine reacts asynchronously, so check a few times.
    // A newer toggle supersedes this guard via the generation counter.
    void (^restoreTheme)(void) = ^{
        if (generation != themeGuardGeneration) return;
        if (slsGetTheme() != themeBefore) {
            NSLog(@"[ShiftChange] Night Shift toggle flipped the system appearance — restoring");
            slsSetTheme(themeBefore);
        }
    };
    for (NSNumber *delay in @[@0.3, @1.2, @3.0]) {
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
            dispatch_get_main_queue(),
            restoreTheme
        );
    }
}

+ (BOOL)isNightShiftScheduled {
    BlueLightStatus status = {0};
    if (![self fetchStatus:&status]) return NO;

    // mode != 0 means a schedule is configured
    return status.mode != 0;
}

static void (^statusChangeHandler)(void) = nil;

+ (void)setStatusChangeHandler:(void (^ _Nullable)(void))handler {
    statusChangeHandler = [handler copy];

    id client = [self sharedClient];
    if (!client) return;

    SEL sel = NSSelectorFromString(@"setStatusNotificationBlock:");
    if (![client respondsToSelector:sel]) {
        NSLog(@"[ShiftChange] setStatusNotificationBlock: selector not found");
        return;
    }

    // The block deliberately takes no parameters even though the framework
    // passes a status pointer — ignoring trailing arguments is safe under
    // the C calling convention, and re-querying via fetchStatus: avoids
    // depending on the struct layout here. May be invoked on any thread.
    dispatch_block_t block = nil;
    if (handler) {
        block = ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                void (^h)(void) = statusChangeHandler;
                if (h) h();
            });
        };
    }

    void (*setBlock)(id, SEL, id) = (void (*)(id, SEL, id))objc_msgSend;
    setBlock(client, sel, block);
}

@end
