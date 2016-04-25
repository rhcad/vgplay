//! \file GiPlayingHelper.h
//! \brief 实现矢量图形播放类 GiPlayingHelper
// Copyright (c) 2014-2016 Zhang Yungui, https://github.com/rhcad/vgplay (GPL v3 licensed)

#import <UIKit/UIKit.h>

@class GiPaintView;
@class CALayer;
@protocol GiPlayProvider;

typedef struct GiFrame GiFrame;
typedef int (^GiFrameBlock)(GiFrame frame);
typedef void (^GiFrameEnded)(GiFrame frame);

extern const int GI_FRAMEFLAGS_DYN;

//! 图形播放辅助类
/*! 每个绘图视图对象(GiPaintView)可有最多一个 GiPlayingHelper 对象。
    \ingroup GROUP_IOS
 */
@interface GiPlayingHelper : NSObject

//! 指定视图的构造函数，每个绘图视图对象可有最多一个 GiPlayingHelper 对象
- (id)initWithView:(GiPaintView *)view;
+ (NSString *)getVersion;                   //!< 得到本库的版本号
- (void)stop;                               //!< 停止所有播放项，包含 startPlay/startSyncPlay/addPlayProvider 对应项

- (BOOL)startPlay:(NSString *)path;         //!< 开始播放指定的目录下录制的图形，在主线程用
- (void)stopPlay;                           //!< 停止播放，在主线程用
- (BOOL)isPaused;                           //!< 是否已暂停
- (BOOL)playPause;                          //!< 暂停播放
- (BOOL)playResume;                         //!< 继续播放
- (long)getPlayTicks;                       //!< 得到已播放的毫秒数

- (BOOL)startSyncPlay:(int)cid path:(NSString *)path;   //!< 开始同步播放，待播放的图形将缓存在指定的目录
- (void)applySyncPlayFrame:(int)cid index:(int)index;   //!< 同步播放一帧，此帧(*.vgr)已缓存到指定的目录
- (void)stopSyncPlay:(int)cid;              //!< 停止同步播放
- (void)stopSyncPlayings;                   //!< 停止所有同步播放

- (BOOL)addPlayProvider:(id<GiPlayProvider>)p tag:(int)tag;  //!< 添加一个播放源
- (int)playProviderCount;                   //!< 返回播放源的个数
- (void)stopPlayProviders;                  //!< 标记所有播放源需要停止
- (int)stopPlayProvider:(int)tag;           //!< 标记指定标识的播放源需要停止
- (BOOL)addPlayProvider:(GiFrameBlock)b ended:(GiFrameEnded)e tag:(int)tag; //!< 添加一个播放源

- (int)insertSpirit:(NSString *)format count:(int)count
              delay:(int)ms repeatCount:(int)rcount
                tag:(int)tag center:(CGPoint)pt;            //!< 插入帧动画精灵，并指定其中心位置
- (int)insertSpirit:(NSString *)format count:(int)count
              delay:(int)ms repeatCount:(int)rcount tag:(int)tag;   //!< 在默认位置插入帧动画精灵

//! 将静态图形转换到三级层，第二级为每个图形的层，其下有CAShapeLayer，返回顶级层
+ (CALayer *)exportLayerTree:(GiPaintView *)view hidden:(BOOL)hidden;

//! 将静态图形转换为二级层，第二级为多个CAShapeLayer，不按图形归类
+ (CALayer *)exportLayers:(GiPaintView *)view;

@end
