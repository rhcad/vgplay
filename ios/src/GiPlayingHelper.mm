//! \file GiPlayingHelper.mm
//! \brief 实现矢量图形播放类 GiPlayingHelper
// Copyright (c) 2014-2016 Zhang Yungui, https://github.com/rhcad/vgplay (GPL v3 licensed)

#import "GiPlayingHelper.h"
#import "GiPaintView.h"
#import "GiImageCache.h"
#import "GiPlayDelegate.h"
#import "GiSpiritProvider.h"
#include "GiShapeAdapter.h"
#include "gicoreplay.h"
#include "gicoreview.h"
#include <map>
#include <vector>
#include "gicoreviewdata.h"

const int IOSPLAY_RELEASE   = 3;    // TODO: 每次更新iOS代码后发布前加1
const int GI_FRAMEFLAGS_DYN = 8;

struct GiPlayingEx {
    GiPaintView* view;
    GiPlaying* playing;
    GiFrame frame;
    id<GiPlayProvider> p;
    
    GiPlayingEx(GiPaintView* view, id<GiPlayProvider> p, int tag) : view(view), p(p) {
        playing = GiPlaying::create([view coreView], tag);
        memset(&frame, 0, sizeof(frame));
        frame.view = view;
        frame.tag = tag;
        frame.shapes = playing->getBackShapesHandle(true);
        frame.backShapes = [view coreView]->backShapes();
    }
    
    ~GiPlayingEx() {
        NSLog(@"Play provider exit, tag=0x%x", frame.tag);
        playing->release([view coreView]);
        [frame.extra RELEASEOBJ];
    }
};

typedef std::map<int, GiPlayShapes> SYNCPLAYINGS;

@interface GiPlayingHelper()<GiPaintViewDelegate> {
    GiPaintView     *_view;
    GiCorePlay      *_coreplay;
    NSMutableArray  *_spirits;                      //!< GiSpiritProvider 数组
    SYNCPLAYINGS    _syncPlayings;                  //!< 同步播放数组
    
    mgvector<int>   _frameIndex;                    //!< 帧索引
    dispatch_queue_t _queue;                        //!< 播放任务队列
    __block std::vector<GiPlayingEx*> _providers;   //!< 播放源
    __block bool    _stopping;                      //!< 播放队列待停止
}

@end

@implementation GiPlayingHelper

+ (NSString *)getVersion {
    return [NSString stringWithFormat:@"%d.%d", IOSPLAY_RELEASE, GiCorePlay::getVersion()];
}

- (id)initWithView:(GiPaintView *)view {
    self = [super init];
    if (self) {
        _view = view;
        _queue = dispatch_queue_create("touchvg.play", NULL);
        [_view addDelegate:self];
    }
    return self;
}

- (void)stop {
    [_view removeDelegate:self];
    [self stopPlay];
    [self stopSyncPlayings];
}

- (void)dealloc {
#ifndef OS_OBJECT_USE_OBJC
    dispatch_release(_queue);
#endif
    [_spirits RELEASEOBJ];
    delete _coreplay;
    [super DEALLOC];
}

+ (CALayer *)exportLayerTree:(GiPaintView *)view hidden:(BOOL)hidden {
    CALayer *rootLayer = [CALayer layer];
    rootLayer.frame = view.bounds;
    
    GiShapeCallback shapeCallback(rootLayer, hidden);
    GiShapeAdapter adapter(&shapeCallback);
    GiCoreView *coreView = [view coreView];
    long doc, gs;
    
    @synchronized([view locker]) {
        doc = coreView->acquireFrontDoc();
        if (!doc) {
            coreView->submitBackDoc(NULL, false);
            doc = coreView->acquireFrontDoc();
        }
        gs = coreView->acquireGraphics([view viewAdapter]);
    }
    coreView->drawAll(doc, gs, &adapter);
    GiCoreView::releaseDoc(doc);
    coreView->releaseGraphics(gs);
    
    return rootLayer;
}

+ (CALayer *)exportLayers:(GiPaintView *)view {
    GiShapeCallback shapeCallback(nil, false);
    GiShapeAdapter adapter(&shapeCallback);
    GiCoreView *coreView = [view coreView];
    long doc, gs;
    
    @synchronized([view locker]) {
        doc = coreView->acquireFrontDoc();
        if (!doc) {
            coreView->submitBackDoc(NULL, false);
            doc = coreView->acquireFrontDoc();
        }
        gs = coreView->acquireGraphics([view viewAdapter]);
    }
    coreView->drawAll(doc, gs, &adapter);
    GiCoreView::releaseDoc(doc);
    coreView->releaseGraphics(gs);
    
    return shapeCallback.layer();
}

- (BOOL)startPlay:(NSString *)path {
    GiCoreView *coreView = [_view coreView];
    
    if (!coreView || coreView->isPlaying() || !path || _coreplay) {
        return NO;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSLog(@"No recorded files in %@", path);
        return NO;
    }
    if (!coreView->startRecord([path UTF8String], 0, false, getTickCount(), NULL)) {
        return NO;
    }
    
    _stopping = false;
    _coreplay = new GiCorePlay(coreView->toHandle());
    
    [_view viewAdapter]->hideContextActions();
    [_view.imageCache setPlayPath:path];
    
    coreView->addRef();
    dispatch_async(_queue, ^{
        while (![_view dynamicShapeView:YES] && !coreView->isStopping()) {
            [NSThread sleepForTimeInterval:0.1];
        }
        NSLog(@"Start playing...");
        
        int flags = _coreplay->loadFirstFrame();
        if (flags && GiCorePlay::loadFrameIndex([path UTF8String], _frameIndex)) {
            @synchronized([_view locker]) {
                _coreplay->applyFrame(flags);
                [self onPlayFrame_];
            }
            coreView->release();
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self stopPlay];
                coreView->release();
            });
        }
    });
    
    return YES;
}

- (void)stopPlay {
    GiCoreView *coreView = [_view coreView];
    
    if (coreView->isPlaying()) {
        _stopping = true;
        coreView->addRef();
        dispatch_async(_queue, ^{
            @synchronized([_view locker]) {
                coreView->stopRecord(false);
            }
            if (_view && _view.window) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(@"Playing ended");
                    [_view.imageCache setPlayPath:nil];
                    [self onPlayEnded_];
                    [_view viewAdapter]->regenAll(false);
                    delete _coreplay;
                    _coreplay = NULL;
                    coreView->release();
                });
            } else {
                delete _coreplay;
                _coreplay = NULL;
                coreView->release();
            }
        });
    }
}

- (BOOL)isPaused {
    return [_view coreView]->isPaused();
}

- (BOOL)playPause {
    return [_view coreView]->onPause(getTickCount());
}

- (BOOL)playResume {
    return [_view coreView]->onResume(getTickCount());
}

- (long)getPlayTicks {
    return [_view coreView]->getPlayingTick(getTickCount());
}

- (BOOL)startSyncPlay:(int)cid path:(NSString *)path {
    if (_syncPlayings.find(cid) != _syncPlayings.end()) {
        NSLog(@"Fail to call startSyncPlay, cid %d exist", cid);
        return NO;
    }
    
    GiCoreView *coreView = [_view coreView];
    GiPlayShapes play;
    
    play.player = new MgRecordShapes([path UTF8String], NULL, false, getTickCount());
    play.playing = GiPlaying::create(coreView, cid);
    
    _stopping = false;
    _syncPlayings[cid] = play;
    
    dispatch_async(_queue, ^{
        while (![_view dynamicShapeView:YES] && !coreView->isStopping()) {
            [NSThread sleepForTimeInterval:0.1];
        }
        NSLog(@"Start sync playing...");
    });
    
    return YES;
}

- (void)applySyncPlayFrame:(int)cid index:(int)index {
    GiCoreView *coreView = [_view coreView];
    
    if (_queue && !_stopping && _syncPlayings.find(cid) != _syncPlayings.end()) {
        GiPlayShapes play = _syncPlayings[cid];
        GiCoreViewData* coreData = GiCoreViewData::fromHandle(coreView->viewDataHandle());
        
        dispatch_async(_queue, ^{
            GiPaintView *view = _view;
            int flags = play.player->applyRedoFile(coreData->getShapeFactory(),
                                                   play.playing->getBackDoc(),
                                                   play.playing->getBackShapes(true), index);
            _stopping = _stopping || play.player->getCurrentTick(getTickCount()) > 120000;
            if (!view.window || _stopping) {
            }
            else if (flags != 0) {
                @synchronized([_view locker]) {
                    if (view.window && !_stopping) {
                        GiCorePlay::applyFrame(coreView->toHandle(), play.playing->toHandle(), flags);
                        [self onPlayFrame_];
                    }
                }
            }
        });
    }
}

- (void)stopSyncPlay:(int)cid {
    if (_syncPlayings.find(cid) != _syncPlayings.end()) {
        GiPlayShapes play = _syncPlayings[cid];
        
        _syncPlayings.erase(cid);
        _stopping = true;
        dispatch_async(_queue, ^{
            @synchronized([_view locker]) {
                delete play.player;
                play.playing->release([_view coreView]);
            }
            if (_view && _view.window) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(@"Sync playing ended");
                    [_view viewAdapter]->regenAll(false);
                });
            }
        });
    }
}

- (void)stopSyncPlayings {
    if (!_syncPlayings.empty()) {
        _stopping = true;
        dispatch_async(_queue, ^{
            @synchronized([_view locker]) {
                SYNCPLAYINGS::iterator it = _syncPlayings.begin();
                for (; it != _syncPlayings.end(); ++it) {
                    delete it->second.player;
                    it->second.playing->release([_view coreView]);
                }
                _syncPlayings.clear();
            }
        });
        if (_view && _view.window) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"Sync playings ended");
                [_view viewAdapter]->regenAll(false);
            });
        }
    }
}

- (void)submitProviderShapes_:(GiPlayingEx *)playing {
    if ([playing->p respondsToSelector:@selector(beforeSubmitShapes:)]) {
        [playing->p beforeSubmitShapes:playing->frame];
    }
    playing->playing->submitBackShapes();
}

- (BOOL)addPlayProvider:(id<GiPlayProvider>)p tag:(int)tag {
    GiPlayingEx* playing = new GiPlayingEx(_view, p, tag);
    
    @synchronized([_view locker]) {
        if (![p initProvider:&playing->frame]) {
            delete playing;
            return false;
        }
        [self submitProviderShapes_:playing];
        _providers.push_back(playing);
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        while (![_view dynamicShapeView:YES] && !playing->playing->isStopping()) {
            [NSThread sleepForTimeInterval:0.1];
        }
        NSLog(@"Start play provider %d...", tag);
        
        int startTick = getTickCount();
        
        while (_view.window && !playing->playing->isStopping()) {
            int ret = 0;
            
            playing->frame.shapes = playing->playing->getBackShapesHandle(false);
            while (ret == 0 && _view.window && !playing->playing->isStopping()) {
                [NSThread sleepForTimeInterval:0.001];
                playing->frame.tick = getTickCount() - startTick;
                ret = [p provideFrame:playing->frame];
            }
            if (ret < 0 || !_view.window || playing->playing->isStopping()) {
                break;
            }
            playing->frame.lastTick = playing->frame.tick;
            playing->frame.index++;
            @synchronized([_view locker]) {
                [self submitProviderShapes_:playing];
            }
            [_view viewAdapter]->redraw(false);
        }
        @synchronized([_view locker]) {
            [p onProvideEnded:playing->frame];
            _providers.erase(std::find(_providers.begin(), _providers.end(), playing));
            delete playing;
            if (_view.window) {
                [_view viewAdapter]->redraw(false);
            }
        }
    });
    
    return true;
}

- (BOOL)addPlayProvider:(GiFrameBlock)block ended:(GiFrameEnded)ended tag:(int)tag {
    GiPlayingEx* playing = new GiPlayingEx(_view, nil, tag);
    
    @synchronized([_view locker]) {
        _providers.push_back(playing);
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        while (![_view dynamicShapeView:YES] && !playing->playing->isStopping()) {
            [NSThread sleepForTimeInterval:0.1];
        }
        NSLog(@"Start play provider %d...", tag);
        
        int startTick = getTickCount();
        
        while (_view.window && !playing->playing->isStopping()) {
            int ret = 0;
            
            playing->frame.shapes = playing->playing->getBackShapesHandle(false);
            while (ret == 0 && _view.window && !playing->playing->isStopping()) {
                [NSThread sleepForTimeInterval:0.001];
                playing->frame.tick = getTickCount() - startTick;
                ret = block(playing->frame);
            }
            if (ret < 0 || !_view.window || playing->playing->isStopping()) {
                break;
            }
            playing->frame.lastTick = playing->frame.tick;
            playing->frame.index++;
            @synchronized([_view locker]) {
                playing->playing->submitBackShapes();
            }
            [_view viewAdapter]->redraw(false);
        }
        @synchronized([_view locker]) {
            if (ended) {
                ended(playing->frame);
            }
            _providers.erase(std::find(_providers.begin(), _providers.end(), playing));
            delete playing;
            if (_view.window) {
                [_view viewAdapter]->redraw(false);
            }
        }
    });
    
    return true;
}

- (void)stopPlayProviders {
    @synchronized([_view locker]) {
        std::vector<GiPlayingEx*> playings(_providers);
        for (size_t i = 0; i < playings.size(); i++) {
            playings[i]->playing->stop();
        }
    }
}

- (int)stopPlayProvider:(int)tag {
    int n = 0;
    
    @synchronized([_view locker]) {
        std::vector<GiPlayingEx*> playings(_providers);
        for (size_t i = 0; i < playings.size(); i++) {
            if (playings[i]->frame.tag == tag) {
                playings[i]->playing->stop();
                n++;
            }
        }
    }
    
    return n;
}

- (int)playProviderCount {
    int n = 0;
    @synchronized([_view locker]) {
        n = (int)_providers.size();
    }
    return n;
}

- (CGSize)insertSpirit_:(GiSpiritProvider *)spirit :(NSString **)name
                       :(NSString *)format :(int)count
                       :(int)ms :(int)rcount :(int)tag {
    spirit.format = format;
    spirit.frameCount = count;
    spirit.delay = ms;
    spirit.repeatCount = rcount;
    spirit.tag = tag;
    spirit.imageCache = _view.imageCache;
    
    if (!_spirits) {
        _spirits = [[NSMutableArray alloc]init];
    }
    if (!spirit || [GiSpiritProvider findSpirit:spirit.format :spirit.tag :_spirits]) {
        return CGSizeZero;
    }
    
    CGSize size = [_view.imageCache addPNGFromResource:spirit.currentName :name];
    
    if (size.width > 0.1f) {
        [_spirits addObject:spirit];
        spirit.owner = _spirits;
        *name = spirit.name;
    }
    
    return size;
}

- (int)insertSpirit:(NSString *)format count:(int)count
              delay:(int)ms repeatCount:(int)rcount tag:(int)tag {
    GiSpiritProvider *spirit = [[GiSpiritProvider alloc]init];
    NSString *name = nil;
    CGSize size = [self insertSpirit_:spirit :&name :format :count :ms :rcount :tag];
    int sid = [_view coreView]->addImageShape([name UTF8String], size.width, size.height);
    
    if (!sid) {
        [spirit RELEASEOBJ];
    } else {
        [self addPlayProvider:spirit tag:sid|SPIRIT_TAG];
    }
    
    return sid;
}

/* 帧动画精灵(Spirit)是一种播放源(PlayProvider)，其播放源tag为图形ID与 SPIRIT_TAG 相与组成。
 \param format 资源中的图片序列文件名格式，后缀为 %d.png，例如可有资源 A0.png、A1.png...
 \param count 图片个数
 \param delay 每帧停留毫秒数
 \param repeatCount 重复次数，小于1时循环播放
 \param tag 精灵标识号，与其播放源tag不同
 \param center 精灵中心点的显示坐标，视图点单位
 \return 精灵图形的图形ID
 */
- (int)insertSpirit:(NSString *)format count:(int)count
              delay:(int)ms repeatCount:(int)rcount
                tag:(int)tag center:(CGPoint)pt {
    GiSpiritProvider *spirit = [[GiSpiritProvider alloc]init];
    NSString *name = nil;
    CGSize size = [self insertSpirit_:spirit :&name :format :count :ms :rcount :tag];
    int sid = [_view coreView]->addImageShape([name UTF8String], pt.x, pt.y,
                                              size.width, size.height, 0);
    if (!sid) {
        [spirit RELEASEOBJ];
    } else {
        [self addPlayProvider:spirit tag:sid|SPIRIT_TAG];
    }
    
    return sid;
}

- (void)onShapeDeleted:(id)num {
    NSNumber * numobj = num;
    [self stopPlayProvider:SPIRIT_TAG | [numobj intValue]];
}

- (void)onContentChanged:(id)view {
    @synchronized([_view locker]) {
        for (size_t i = 0; i < _providers.size(); i++) {
            GiPlayingEx* playing = _providers[i];
            if ([playing->p respondsToSelector:@selector(onBackDocChanged:)]) {
                [playing->p onBackDocChanged:playing->frame];
            }
        }
    }
}

- (void)onDynDrawEnded:(id)view {
    [self playNextFrame_];
}

- (void)playNextFrame_ {
    GiCoreView *coreView = [_view coreView];
    
    if (_queue && coreView->isPlaying() && !coreView->isStopping()) {
        coreView->addRef();
        dispatch_async(_queue, ^{
            GiPaintView *view = _view;
            int flags = _coreplay->loadNextFrame(_frameIndex, getTickCount());
            
            if (!view.window || coreView->isStopping()) {
                coreView->release();
            }
            else if (flags == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([self onPlayWillEnd_]) {
                        coreView->onPause(getTickCount());
                    } else {
                        [self stopPlay];
                    }
                    coreView->release();
                });
            }
            else {
                while (view.window && !_stopping
                       && _coreplay->frameNeedWait(getTickCount())) {
                    [NSThread sleepForTimeInterval:0.1];
                }
                @synchronized([_view locker]) {
                    if (view.window && !_stopping) {
                        _coreplay->applyFrame(flags);
                        [self onPlayFrame_];
                    }
                }
                coreView->release();
            }
        });
    }
}

- (void)onPlayFrame_ {
    if ([NSThread isMainThread]) {
        [self onPlayFrameBlock_];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self onPlayFrameBlock_];
        });
    }
}

- (void)onPlayFrameBlock_ {
    for (id i in _view.delegates) {
        if ([i respondsToSelector:@selector(onPlayFrame:)]) {
            [i onPlayFrame:_view];
        }
    }
    if ([_view respondsToSelector:@selector(onPlayFrame:)]) {
        [_view performSelector:@selector(onPlayFrame:) withObject:_view];
    }
}

- (BOOL)onPlayWillEnd_ {
    int n = 0;
    for (id i in _view.delegates) {
        if ([i respondsToSelector:@selector(onPlayWillEnd:)]) {
            [i onPlayWillEnd:_view];
            n++;
        }
    }
    if ([_view respondsToSelector:@selector(onPlayWillEnd:)]) {
        [_view performSelector:@selector(onPlayWillEnd:) withObject:_view];
        n++;
    }
    return n > 0;
}

- (void)onPlayEnded_ {
    for (id i in _view.delegates) {
        if ([i respondsToSelector:@selector(onPlayEnded:)]) {
            [i onPlayEnded:_view];
        }
    }
    if ([_view respondsToSelector:@selector(onPlayEnded:)]) {
        [_view performSelector:@selector(onPlayEnded:) withObject:_view];
    }
}

@end
