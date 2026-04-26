#import "AppDelegate.h"
#import "ClockWindow.h"
#import "ClockView.h"

static const CGFloat kDefaultSize = 200.0;
static const CGFloat kMinSize     = 80.0;

@interface AppDelegate ()

@property (nonatomic, strong) ClockWindow *window;
@property (nonatomic, strong) ClockView   *clockView;
@property (nonatomic, strong) NSMenuItem  *alwaysOnTopItem;
@property (nonatomic, strong) NSTimer     *mouseTimer;

@end

@implementation AppDelegate

#pragma mark - Application lifecycle

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self setupMenu];
    [self setupWindow];

    /* Restore "always on top" preference */
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"alwaysOnTop"]) {
        self.window.level = NSFloatingWindowLevel;
        self.alwaysOnTopItem.state = NSOnState;
    }

    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [self.clockView loadClock];

    [self startMouseTimer];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self stopMouseTimer];
    [self saveWindowState];
}

#pragma mark - Window setup

- (void)setupWindow {
    NSRect frame = [self restoredFrame];

    NSUInteger style = NSTitledWindowMask
                     | NSClosableWindowMask
                     | NSMiniaturizableWindowMask
                     | NSResizableWindowMask
                     | NSFullSizeContentViewWindowMask;

    self.window = [[ClockWindow alloc] initWithContentRect:frame
                                                 styleMask:style
                                                   backing:NSBackingStoreBuffered
                                                     defer:NO];

    self.window.title = @"Uhr";
    self.window.titlebarAppearsTransparent = YES;
    self.window.titleVisibility = NSWindowTitleHidden;
    self.window.opaque = NO;
    self.window.backgroundColor  = [NSColor clearColor];
    self.window.hasShadow = NO;
    self.window.movableByWindowBackground = NO;
    self.window.minSize = NSMakeSize(kMinSize, kMinSize);
    [self.window setContentAspectRatio:NSMakeSize(1, 1)];
    self.window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
    self.window.delegate = self;

    /* Hide traffic-light buttons */
    [[self.window standardWindowButton:NSWindowCloseButton] setHidden:YES];
    [[self.window standardWindowButton:NSWindowMiniaturizeButton] setHidden:YES];
    [[self.window standardWindowButton:NSWindowZoomButton] setHidden:YES];

    /* Content view */
    self.clockView = [[ClockView alloc] initWithFrame:
        [[self.window contentView] bounds]];
    self.clockView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.window setContentView:self.clockView];
}

- (NSRect)restoredFrame {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    CGFloat w = [defaults doubleForKey:@"windowWidth"];
    if (w < kMinSize) w = kDefaultSize;
    CGFloat h = w; /* always square */

    CGFloat x = [defaults doubleForKey:@"windowX"];
    CGFloat y = [defaults doubleForKey:@"windowY"];

    NSRect frame = NSMakeRect(x, y, w, h);

    /* Make sure the center is on a visible screen */
    NSPoint center = NSMakePoint(NSMidX(frame), NSMidY(frame));
    BOOL visible = NO;
    for (NSScreen *screen in [NSScreen screens]) {
        if (NSPointInRect(center, screen.visibleFrame)) {
            visible = YES;
            break;
        }
    }
    if (!visible) {
        NSRect sf = [[NSScreen mainScreen] visibleFrame];
        frame.origin.x = NSMidX(sf) - w / 2.0;
        frame.origin.y = NSMidY(sf) - h / 2.0;
    }
    return frame;
}

- (void)saveWindowState {
    if (self.clockView.isInFullScreen) return; /* don't save fullscreen geometry */
    NSRect frame = self.window.frame;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setDouble:frame.origin.x    forKey:@"windowX"];
    [defaults setDouble:frame.origin.y    forKey:@"windowY"];
    [defaults setDouble:frame.size.width  forKey:@"windowWidth"];
    [defaults setDouble:frame.size.height forKey:@"windowHeight"];
    [defaults synchronize];
}

#pragma mark - Menu

- (void)setupMenu {
    NSMenu *menuBar = [[NSMenu alloc] init];

    /* ---- App menu ---- */
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Uhr"];

    [appMenu addItemWithTitle:@"About Uhr"
                       action:@selector(orderFrontStandardAboutPanel:)
                keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];

    [appMenu addItemWithTitle:@"Hide Uhr"
                       action:@selector(hide:)
                keyEquivalent:@"h"];

    NSMenuItem *hideOthers =
        [appMenu addItemWithTitle:@"Hide Others"
                           action:@selector(hideOtherApplications:)
                    keyEquivalent:@"h"];
    [hideOthers setKeyEquivalentModifierMask:
        NSCommandKeyMask | NSAlternateKeyMask];

    [appMenu addItemWithTitle:@"Show All"
                       action:@selector(unhideAllApplications:)
                keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];

    [appMenu addItemWithTitle:@"Quit Uhr"
                       action:@selector(terminate:)
                keyEquivalent:@"q"];

    appMenuItem.submenu = appMenu;
    [menuBar addItem:appMenuItem];

    /* ---- View menu ---- */
    NSMenuItem *viewMenuItem = [[NSMenuItem alloc] init];
    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];

    self.alwaysOnTopItem =
        [[NSMenuItem alloc] initWithTitle:@"Always on Top"
                                   action:@selector(toggleAlwaysOnTop:)
                            keyEquivalent:@""];
    self.alwaysOnTopItem.target = self;
    [viewMenu addItem:self.alwaysOnTopItem];
    [viewMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *fsItem =
        [viewMenu addItemWithTitle:@"Toggle Fullscreen"
                            action:@selector(toggleFullScreen:)
                     keyEquivalent:@"f"];
    [fsItem setKeyEquivalentModifierMask:
        NSCommandKeyMask | NSControlKeyMask];

    viewMenuItem.submenu = viewMenu;
    [menuBar addItem:viewMenuItem];

    /* ---- Window menu ---- */
    NSMenuItem *windowMenuItem = [[NSMenuItem alloc] init];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];

    [windowMenu addItemWithTitle:@"Minimize"
                          action:@selector(performMiniaturize:)
                   keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"Zoom"
                          action:@selector(performZoom:)
                   keyEquivalent:@""];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [windowMenu addItemWithTitle:@"Bring All to Front"
                          action:@selector(arrangeInFront:)
                   keyEquivalent:@""];

    windowMenuItem.submenu = windowMenu;
    [menuBar addItem:windowMenuItem];
    [NSApp setWindowsMenu:windowMenu];

    [NSApp setMainMenu:menuBar];
}

#pragma mark - Actions

- (void)toggleAlwaysOnTop:(id)sender {
    BOOL isOnTop = (self.window.level == NSFloatingWindowLevel);
    if (isOnTop) {
        self.window.level = NSNormalWindowLevel;
        self.alwaysOnTopItem.state = NSOffState;
    } else {
        self.window.level = NSFloatingWindowLevel;
        self.alwaysOnTopItem.state = NSOnState;
    }
    [[NSUserDefaults standardUserDefaults] setBool:!isOnTop forKey:@"alwaysOnTop"];
}

#pragma mark - NSWindowDelegate – fullscreen

- (void)windowWillEnterFullScreen:(NSNotification *)notification {
    self.clockView.inFullScreen = YES;
    /* Remove aspect-ratio constraint so the window can fill the screen */
    [self.window setContentResizeIncrements:NSMakeSize(1, 1)];
    [self.clockView animateBackgroundToFullScreen:YES];
}

- (void)windowDidEnterFullScreen:(NSNotification *)notification {
    [self.window invalidateShadow];
}

- (void)windowWillExitFullScreen:(NSNotification *)notification {
    [self.clockView animateBackgroundToFullScreen:NO];
}

- (void)windowDidExitFullScreen:(NSNotification *)notification {
    self.clockView.inFullScreen = NO;
    /* Restore 1:1 aspect ratio */
    [self.window setContentAspectRatio:NSMakeSize(1, 1)];
    /* Ensure the window is square after exiting fullscreen */
    NSRect f = self.window.frame;
    CGFloat s = MIN(f.size.width, f.size.height);
    if (f.size.width != s || f.size.height != s) {
        f.origin.x += (f.size.width  - s) / 2.0;
        f.origin.y += (f.size.height - s) / 2.0;
        f.size = NSMakeSize(s, s);
        [self.window setFrame:f display:YES animate:YES];
    }
    [self.window invalidateShadow];
    self.clockView.needsLayout = YES;
}

#pragma mark - Mouse pass-through

- (void)startMouseTimer {
    if (self.mouseTimer) return;
    self.mouseTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 60.0
                                                      target:self
                                                    selector:@selector(updateMousePassthrough)
                                                    userInfo:nil
                                                     repeats:YES];
    /* Keep firing during live resize and modal panels */
    [[NSRunLoop currentRunLoop] addTimer:self.mouseTimer
                                 forMode:NSRunLoopCommonModes];
}

- (void)stopMouseTimer {
    [self.mouseTimer invalidate];
    self.mouseTimer = nil;
    /* Ensure window accepts events again when timer stops */
    if (self.window.ignoresMouseEvents)
        self.window.ignoresMouseEvents = NO;
}

- (void)updateMousePassthrough {
    /* Never ignore events in fullscreen or while user is resizing */
    if (self.clockView.isInFullScreen || [self.clockView isUserInteracting]) {
        if (self.window.ignoresMouseEvents)
            self.window.ignoresMouseEvents = NO;
        return;
    }
    if (self.window.isMiniaturized) return;

    NSPoint mouse = [NSEvent mouseLocation];
    NSRect  frame = self.window.frame;

    if (!NSPointInRect(mouse, frame)) {
        /* Mouse outside window – pass through so entry click isn't swallowed */
        if (!self.window.ignoresMouseEvents)
            self.window.ignoresMouseEvents = YES;
        return;
    }

    /* Convert screen → window → view coordinates */
    NSPoint windowPoint = NSMakePoint(mouse.x - frame.origin.x,
                                       mouse.y - frame.origin.y);
    NSPoint viewPoint = [self.clockView convertPoint:windowPoint fromView:nil];

    BOOL inClock     = [self.clockView isPointInInteractiveArea:viewPoint];
    BOOL shouldIgnore = !inClock;

    if (self.window.ignoresMouseEvents != shouldIgnore)
        self.window.ignoresMouseEvents = shouldIgnore;
}

#pragma mark - NSWindowDelegate – occlusion (energy saving)

- (void)windowDidChangeOcclusionState:(NSNotification *)notification {
    if (self.window.occlusionState & NSWindowOcclusionStateVisible) {
        [self.clockView startClock];
        [self startMouseTimer];
    } else {
        [self.clockView stopClock];
        [self stopMouseTimer];
    }
}

#pragma mark - NSWindowDelegate – close / resize

- (void)windowWillClose:(NSNotification *)notification {
    [self saveWindowState];
}

- (void)windowDidResize:(NSNotification *)notification {
    [self.window invalidateShadow];
}

@end
