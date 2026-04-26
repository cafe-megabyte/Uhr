#import "ClockView.h"
#import <QuartzCore/QuartzCore.h>

#define CLOCK_RADIUS_RATIO (52.5 / 56.0)
#define RESIZE_RING_WIDTH 10.0
#define MIN_CLOCK_SIZE 80.0

@interface ClockView ()

@property (nonatomic, strong) NSTrackingArea *trackingArea;
@property (nonatomic, assign) BOOL isResizing;
@property (nonatomic, assign) CGFloat resizeStartRadius;
@property (nonatomic, assign) NSRect resizeStartFrame;
@property (nonatomic, assign) NSPoint resizeCenter;
@property (nonatomic, assign) CGFloat resizeBaseSize;
@property (nonatomic, assign) BOOL isPinching;

@end

@implementation ClockView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.wantsLayer = YES;
        self.layer.backgroundColor = [[NSColor clearColor] CGColor];

        /* Soft drop-shadow behind the clock face */
        self.layer.shadowColor   = [[NSColor blackColor] CGColor];
        self.layer.shadowOffset  = CGSizeMake(0, -2);
        self.layer.shadowRadius  = 12.0;
        self.layer.shadowOpacity = 0.25;

        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];

        /* Inject CSS at document start: transparent background, scale SVG images */
        NSString *cssScript =
            @"var _s = document.createElement('style');"
             "_s.textContent = '"
             "html, body { background: transparent !important; margin: 0; overflow: hidden; } "
             "#sbb_uhr_wrapper img { width: 100%; height: 100%; display: block; }"
             "';"
             "document.documentElement.appendChild(_s);";

        WKUserScript *cssUserScript = [[WKUserScript alloc]
            initWithSource:cssScript
            injectionTime:WKUserScriptInjectionTimeAtDocumentStart
            forMainFrameOnly:YES];
        [config.userContentController addUserScript:cssUserScript];

        /* Inject JS at document end: resize the clock wrapper when the viewport changes */
        NSString *resizeScript =
            @"function _uckResize() {"
             "  var w = document.getElementById('sbb_uhr_wrapper');"
             "  if (!w) return;"
             "  var s = Math.min(window.innerWidth, window.innerHeight);"
             "  w.style.width  = s + 'px';"
             "  w.style.height = s + 'px';"
             "  w.style.left   = ((window.innerWidth  - s) / 2) + 'px';"
             "  w.style.top    = ((window.innerHeight - s) / 2) + 'px';"
             "}"
             "window.addEventListener('resize', _uckResize);"
             "_uckResize();";

        WKUserScript *resizeUserScript = [[WKUserScript alloc]
            initWithSource:resizeScript
            injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
            forMainFrameOnly:YES];
        [config.userContentController addUserScript:resizeUserScript];

        self.webView = [[WKWebView alloc] initWithFrame:self.bounds configuration:config];
        self.webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        @try {
            [self.webView setValue:@NO forKey:@"drawsBackground"];
        } @catch (NSException *e) { /* ignore */ }
        [self addSubview:self.webView];
    }
    return self;
}

#pragma mark - Clock control

- (void)loadClock {
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *htmlPath = [resourcePath stringByAppendingPathComponent:@"index.html"];
    NSURL *htmlURL  = [NSURL fileURLWithPath:htmlPath];
    NSURL *baseURL  = [NSURL fileURLWithPath:resourcePath];
    [self.webView loadFileURL:htmlURL allowingReadAccessToURL:baseURL];
}

- (void)startClock {
    [self.webView evaluateJavaScript:
        @"if(typeof myClock!=='undefined') myClock.start();"
        completionHandler:nil];
}

- (void)stopClock {
    [self.webView evaluateJavaScript:
        @"if(typeof myClock!=='undefined') myClock.stop();"
        completionHandler:nil];
}

#pragma mark - Layout (shadow path)

- (void)layout {
    [super layout];
    if (self.inFullScreen) {
        self.layer.shadowOpacity = 0.0;
        return;
    }
    self.layer.shadowOpacity = 0.25;
    NSPoint center = [self clockCenterInView];
    CGFloat radius = [self clockVisualRadius];
    CGRect rect = CGRectMake(center.x - radius, center.y - radius,
                              radius * 2, radius * 2);
    CGPathRef path = CGPathCreateWithEllipseInRect(rect, NULL);
    self.layer.shadowPath = path;
    CGPathRelease(path);

    /* Scale shadow with the clock: a fixed blur radius looks fine at default
       size but, when the clock shrinks, the halo stays the same in points
       and starts bleeding past the (square) window bounds, exposing its
       outline. Cap at the original values so large clocks don't gain a
       heavier shadow than designed. */
    CGFloat diameter = radius * 2.0;
    self.layer.shadowRadius = MIN(diameter * 0.03, 12.0);
    self.layer.shadowOffset = CGSizeMake(0, MAX(-diameter * 0.005, -2.0));
}

#pragma mark - Background animation (fullscreen)

- (void)animateBackgroundToFullScreen:(BOOL)fullScreen {
    CGColorRef newColor = fullScreen
        ? [[NSColor blackColor] CGColor]
        : [[NSColor clearColor] CGColor];

    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"backgroundColor"];
    anim.fromValue  = (__bridge id)self.layer.backgroundColor;
    anim.toValue    = (__bridge id)newColor;
    anim.duration   = 0.25;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.layer addAnimation:anim forKey:@"backgroundColor"];
    self.layer.backgroundColor = newColor;
    self.layer.shadowOpacity = fullScreen ? 0.0 : 0.25;
}

#pragma mark - Geometry helpers

- (NSPoint)clockCenterInView {
    return NSMakePoint(NSMidX(self.bounds), NSMidY(self.bounds));
}

- (CGFloat)clockVisualRadius {
    CGFloat minDim = MIN(self.bounds.size.width, self.bounds.size.height);
    return minDim / 2.0 * CLOCK_RADIUS_RATIO;
}

- (CGFloat)distanceFromClockCenter:(NSPoint)point {
    NSPoint center = [self clockCenterInView];
    CGFloat dx = point.x - center.x;
    CGFloat dy = point.y - center.y;
    return sqrt(dx * dx + dy * dy);
}

- (BOOL)isPointInClockFace:(NSPoint)point {
    return [self distanceFromClockCenter:point] <= [self clockVisualRadius];
}

- (BOOL)isPointOnResizeRing:(NSPoint)point {
    if (self.inFullScreen) return NO;
    CGFloat dist   = [self distanceFromClockCenter:point];
    CGFloat radius = [self clockVisualRadius];
    return (dist > radius - RESIZE_RING_WIDTH / 2.0) &&
           (dist <= radius + RESIZE_RING_WIDTH / 2.0);
}

- (BOOL)isPointInInteractiveArea:(NSPoint)point {
    if (self.inFullScreen) return YES;
    CGFloat dist   = [self distanceFromClockCenter:point];
    CGFloat radius = [self clockVisualRadius];
    return dist <= radius + RESIZE_RING_WIDTH / 2.0;
}

#pragma mark - Hit testing (click-through for areas outside the clock)

- (NSView *)hitTest:(NSPoint)point {
    NSPoint local = [self convertPoint:point fromView:self.superview];
    if ([self isPointInInteractiveArea:local]) {
        return self;
    }
    return nil;
}

#pragma mark - Tracking areas & cursor

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (self.trackingArea) {
        [self removeTrackingArea:self.trackingArea];
    }
    NSTrackingAreaOptions opts = NSTrackingMouseMoved
        | NSTrackingMouseEnteredAndExited
        | NSTrackingActiveAlways
        | NSTrackingInVisibleRect
        | NSTrackingCursorUpdate;
    self.trackingArea = [[NSTrackingArea alloc]
        initWithRect:self.bounds
             options:opts
               owner:self
            userInfo:nil];
    [self addTrackingArea:self.trackingArea];
}

- (NSCursor *)resizeCursorForPoint:(NSPoint)point {
    NSPoint center = [self clockCenterInView];
    CGFloat dx = point.x - center.x;
    CGFloat dy = point.y - center.y;
    if (fabs(dx) > fabs(dy)) {
        return [NSCursor resizeLeftRightCursor];
    }
    return [NSCursor resizeUpDownCursor];
}

- (void)updateCursorAtPoint:(NSPoint)local {
    if (self.inFullScreen) {
        [[NSCursor arrowCursor] set];
        return;
    }
    if (self.isResizing) return;

    if ([self isPointOnResizeRing:local]) {
        [[self resizeCursorForPoint:local] set];
    } else if ([self isPointInClockFace:local]) {
        [[NSCursor openHandCursor] set];
    } else {
        [[NSCursor arrowCursor] set];
    }
}

- (void)mouseMoved:(NSEvent *)event {
    [self updateCursorAtPoint:[self convertPoint:event.locationInWindow fromView:nil]];
}

- (void)cursorUpdate:(NSEvent *)event {
    [self updateCursorAtPoint:[self convertPoint:event.locationInWindow fromView:nil]];
}

- (void)mouseEntered:(NSEvent *)event {
    [self updateCursorAtPoint:[self convertPoint:event.locationInWindow fromView:nil]];
}

- (void)mouseExited:(NSEvent *)event {
    [[NSCursor arrowCursor] set];
}

#pragma mark - Live resize (transform-based)

- (CGFloat)clampedSize:(CGFloat)size {
    if (size < MIN_CLOCK_SIZE) size = MIN_CLOCK_SIZE;
    CGFloat maxDim = 0;
    for (NSScreen *s in [NSScreen screens]) {
        CGFloat m = MAX(s.frame.size.width, s.frame.size.height);
        if (m > maxDim) maxDim = m;
    }
    if (size > maxDim) size = maxDim;
    return size;
}

- (void)beginLiveResize {
    _resizeBaseSize = self.bounds.size.width;
}

- (void)liveResizeToSize:(CGFloat)newSize {
    newSize = [self clampedSize:newSize];

    /* Resize window so nothing gets clipped */
    NSRect frame = self.window.frame;
    NSPoint center = NSMakePoint(NSMidX(frame), NSMidY(frame));
    NSRect newFrame = NSMakeRect(center.x - newSize / 2.0, center.y - newSize / 2.0,
                                  newSize, newSize);
    [self.window setFrame:newFrame display:YES];

    /* Pin WebView to its original size — override any auto-resize that
       the window change may have triggered — then scale via GPU. */
    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    self.webView.layer.affineTransform = CGAffineTransformIdentity;
    self.webView.frame = NSMakeRect(0, 0, _resizeBaseSize, _resizeBaseSize);

    CGFloat scale  = newSize / _resizeBaseSize;
    CGPoint anchor = self.webView.layer.anchorPoint;
    CGFloat tx = anchor.x * _resizeBaseSize * (scale - 1.0);
    CGFloat ty = anchor.y * _resizeBaseSize * (scale - 1.0);
    CGAffineTransform t = CGAffineTransformMakeTranslation(tx, ty);
    t = CGAffineTransformScale(t, scale, scale);
    self.webView.layer.affineTransform = t;

    [CATransaction commit];
}

- (void)endLiveResize {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.webView.layer.affineTransform = CGAffineTransformIdentity;
    self.webView.frame = self.bounds;
    [CATransaction commit];
}

#pragma mark - Mouse events (drag & resize)

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    return YES;
}

- (void)mouseDown:(NSEvent *)event {
    if (self.inFullScreen) return;

    NSPoint local = [self convertPoint:event.locationInWindow fromView:nil];

    if ([self isPointOnResizeRing:local]) {
        /* Begin resize */
        self.isResizing = YES;
        self.resizeStartFrame = self.window.frame;
        self.resizeCenter = NSMakePoint(NSMidX(self.window.frame),
                                        NSMidY(self.window.frame));
        NSPoint mouse = [NSEvent mouseLocation];
        CGFloat dx = mouse.x - self.resizeCenter.x;
        CGFloat dy = mouse.y - self.resizeCenter.y;
        self.resizeStartRadius = sqrt(dx * dx + dy * dy);
        if (self.resizeStartRadius < 1.0) self.resizeStartRadius = 1.0;
        [self beginLiveResize];
    } else {
        /* Drag window */
        [[NSCursor closedHandCursor] set];
        [self.window performWindowDragWithEvent:event];
        /* performWindowDragWithEvent: returns when drag ends */
        NSPoint p = [self convertPoint:
            [self.window mouseLocationOutsideOfEventStream] fromView:nil];
        [self updateCursorAtPoint:p];
    }
}

- (void)mouseDragged:(NSEvent *)event {
    if (!self.isResizing) return;

    NSPoint mouse = [NSEvent mouseLocation];
    CGFloat dx = mouse.x - self.resizeCenter.x;
    CGFloat dy = mouse.y - self.resizeCenter.y;
    CGFloat currentRadius = sqrt(dx * dx + dy * dy);

    CGFloat scale   = currentRadius / self.resizeStartRadius;
    CGFloat newSize = round(self.resizeStartFrame.size.width * scale);
    [self liveResizeToSize:newSize];
}

- (void)mouseUp:(NSEvent *)event {
    if (self.isResizing) {
        self.isResizing = NO;
        [self endLiveResize];
        NSPoint local = [self convertPoint:event.locationInWindow fromView:nil];
        [self updateCursorAtPoint:local];
    }
}

- (BOOL)isUserInteracting {
    return self.isResizing || self.isPinching;
}

#pragma mark - Pinch-to-zoom

- (void)magnifyWithEvent:(NSEvent *)event {
    if (self.inFullScreen) return;

    if (event.phase == NSEventPhaseBegan) {
        self.isPinching = YES;
        [self beginLiveResize];
    }

    CGFloat newSize = round(self.window.frame.size.width * (1.0 + event.magnification));
    [self liveResizeToSize:newSize];

    if (event.phase == NSEventPhaseEnded || event.phase == NSEventPhaseCancelled) {
        self.isPinching = NO;
        [self endLiveResize];
    }
}

@end
