#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface ClockView : NSView

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, assign, getter=isInFullScreen) BOOL inFullScreen;

- (void)loadClock;
- (void)startClock;
- (void)stopClock;
- (void)animateBackgroundToFullScreen:(BOOL)fullScreen;
- (BOOL)isPointInInteractiveArea:(NSPoint)viewPoint;
- (BOOL)isUserInteracting;

@end
