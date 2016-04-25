//! \file GiPlayProvider.h
//! \brief Define GiPlayProvider protocol
// Copyright (c) 2014-2016, https://github.com/rhcad/touchvg

#import <Foundation/Foundation.h>

#define SPIRIT_TAG  0x1000000

//! Animation frame info.
struct GiFrame {
    id      view;               //!< GiPaintView
    int     tag;                //!< ID setted by app
    long    shapes;             //!< MgShapes
    int     tick;               //!< played time in microsecond
    int     lastTick;           //!< last frame's played time in microsecond
    int     index;              //!< zero based frame index
    id      extra;              //!< App's customized object
    long    backShapes;         //!< MgCoreView::backShapes(), MgShapes
};
typedef struct GiFrame GiFrame;

//! Animation content provider protocol.
@protocol GiPlayProvider <NSObject>

- (BOOL)initProvider:(GiFrame *)frame;
- (int)provideFrame:(GiFrame)frame;
- (void)onProvideEnded:(GiFrame)frame;

@optional

- (void)beforeSubmitShapes:(GiFrame)frame;
- (void)onBackDocChanged:(GiFrame)frame;

@end
