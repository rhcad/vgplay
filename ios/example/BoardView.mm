//
//  BoardView.mm
//  SharedBoard
//
//  Created by Zhang Yungui on 14-4-27.
//

#import "BoardView.h"
#import "GiViewHelper.h"
#import "GiPaintView.h"
#import "GiPlayingHelper.h"
#include "gicoreview.h"
#include "ARCMacro.h"

@interface BoardView ()<GiPaintViewDelegate> {
    GiPaintView *_view;
    GiPlayingHelper *_play;
    UIButton    *_selectBtn;
    UIButton    *_splinesBtn;
    UIButton    *_ellipseBtn;
}
@end

@implementation BoardView

@synthesize cid, recordPath, receiver;

+ (void)createTwoViews:(UIView *)view {
    CGRect rect = view.bounds;
    rect.size.height /= 2;
    
    BoardView *view1 = [[BoardView alloc]initWithFrame:rect];
    view1.lineColor = [UIColor greenColor];
    view1.cid = 1;
    [view addSubview:view1];
    [view1 RELEASE];
    
    rect.origin.y += rect.size.height;
    BoardView *view2 = [[BoardView alloc]initWithFrame:rect];
    view2.lineColor = [UIColor redColor];
    view2.cid = 2;
    [view addSubview:view2];
    [view2 RELEASE];
    
    view1.receiver = view2;
    view2.receiver = view1;
}

- (void)dealloc {
    [_play RELEASE];
    [super DEALLOC];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizingMask = 0xFF;
        
        _view = [[GiViewHelper sharedInstance] createGraphView:self.bounds :self];
        _play = [[GiPlayingHelper alloc]initWithView:_view];
        [_view addDelegate:self];
        
        [self onSplines];
        [self createToolbar];
        [self layoutButtons];
    }
    return self;
}

- (NSString *)name {
    return [@(self.cid) stringValue];
}

- (NSString *)recordPath {
    return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                 NSUserDomainMask, YES)objectAtIndex:0]
            stringByAppendingPathComponent:self.name];
}

- (UIColor *)lineColor {
    return [GiViewHelper sharedInstance:_view].lineColor;
}

- (void)setLineColor:(UIColor *)value {
    self.layer.borderColor = value.CGColor;
    self.layer.borderWidth = 2;
    [GiViewHelper sharedInstance:_view].lineColor = value;
}

- (void)createToolbar {
    _selectBtn = [[UIButton alloc]initWithFrame:CGRectNull];
    _splinesBtn = [[UIButton alloc]initWithFrame:CGRectNull];
    _ellipseBtn = [[UIButton alloc]initWithFrame:CGRectNull];
    
    [self addButton:_selectBtn title:@"Select" action:@selector(onSelect)];
    [self addButton:_splinesBtn title:@"Splines" action:@selector(onSplines)];
    [self addButton:_ellipseBtn title:@"Ellipse" action:@selector(onEllipse)];
}

- (void)addButton:(UIButton *)btn title:(NSString *)title action:(SEL)action {
    btn.showsTouchWhenHighlighted = YES;
    [btn setTitle:title forState: UIControlStateNormal];
    btn.layer.borderWidth = 1;
    btn.layer.borderColor = [UIColor grayColor].CGColor;
    [btn setTitleColor:[UIColor blackColor] forState: UIControlStateNormal];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:btn];
    [btn RELEASE];
}

- (void)layoutSubviews {
    [self layoutButtons];
    [super layoutSubviews];
}

- (void)layoutButtons {
    NSArray *buttons = @[_selectBtn, _splinesBtn, _ellipseBtn];
    CGFloat w = 65, h = 32, n = (CGFloat)[buttons count];
    CGFloat space = (self.bounds.size.width - w * n) / (n + 1);
    CGFloat x = space, y = self.bounds.size.height - h - 2;
    
    for (UIButton *btn in buttons) {
        btn.frame = CGRectMake(x, y, w, h);
        x += w + space;
    }
}

- (void)onSelect {
    [GiViewHelper sharedInstance:_view].command = @"select";
}

- (void)onSplines {
    [GiViewHelper sharedInstance:_view].command = @"splines";
}

- (void)onEllipse {
    [GiViewHelper sharedInstance:_view].command = @"ellipse";
}

- (void)onFirstRegen:(id)view {
    [[GiViewHelper sharedInstance:_view] startRecord:self.recordPath];
    [_play startSyncPlay:self.cid path:self.receiver.recordPath];
}

- (void)onShapesRecorded:(NSDictionary *)info {
    int index = [info[@"index"] intValue];
    
    if (index > 1 && [_view coreView]->getGestureState() != kGiGestureMoved) {
        [self.receiver onSyncPlay:info];
    }
}

- (void)onSyncPlay:(NSDictionary *)info {
    int index = [info[@"index"] intValue] - 1;
    [_play applySyncPlayFrame:self.cid index:index];
}

@end
