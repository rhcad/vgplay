//
//  BoardView.h
//  SharedBoard
//
//  Created by Zhang Yungui on 14-4-27.
//

#import <UIKit/UIKit.h>

@interface BoardView : UIView

@property(nonatomic)        int         cid;
@property(nonatomic, copy) NSString     *recordPath;
@property (nonatomic, assign) UIColor   *lineColor;
@property (nonatomic, assign) BoardView *receiver;

+ (void)createTwoViews:(UIView *)view;

@end
