//! \file GiPlayDelegate.h
//! \brief 定义图形播放通知协议 GiPlayDelegate
// Copyright (c) 2014-2016 Zhang Yungui, https://github.com/rhcad/vgplay (GPL v3 licensed)

#import "GiPaintViewDelegate.h"

//! 图形播放通知协议
/*! \ingroup GROUP_IOS
    \see GiPlayingHelper
 */
@protocol GiPlayDelegate <GiPaintViewDelegate>
@optional

- (void)onPlayFrame:(id)view;           //!< 播放一帧的通知
- (void)onPlayWillEnd:(id)view;         //!< 播放完成，待用户结束播放
- (void)onPlayEnded:(id)view;           //!< 播放结束的通知

@end
