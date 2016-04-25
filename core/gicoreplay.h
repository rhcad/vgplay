//! \file gicoreplay.h
//! \brief 定义矢量图形播放内核类 GiCorePlay
// Copyright (c) 2014-2016 Zhang Yungui, https://github.com/rhcad/vgplay (GPL v3 licensed)

#ifndef TOUCHVG_CORE_PLAY_H
#define TOUCHVG_CORE_PLAY_H

#include "mgvector.h"
#ifndef SWIG
#include "mgshapedoc.h"
#endif

struct MgCoreView;
class GiCoreViewData;
class GiPlaying;

//! 矢量图形播放内核类
class GiCorePlay
{
public:
    enum { DOC_CHANGED = 1, SHAPE_APPEND = 2, DYN_CHANGED = 4 };    // for load?Frame
    
    GiCorePlay(long coreView);
    ~GiCorePlay();
    static int getVersion();                                        //!< 得到内核版本号
    
    int loadFirstFrame();                       //!< 异步加载第0帧
    int loadFirstFrame(const char* file);       //!< 加载第0帧
    int loadNextFrame(int index);               //!< 异步加载下一帧
    int loadPrevFrame(int index, long curTick); //!< 异步加载上一帧
    void applyFrame(int flags);                 //!< 播放当前帧, 需要并发访问保护
    static void applyFrame(long coreView, long playing, int flags); //!< 播放当前帧
    
    static bool loadFrameIndex(const char* path, mgvector<int>& arr); //!< 加载帧索引{index,tick,flags}
    int loadNextFrame(const mgvector<int>& head, long curTick);     //!< 加载下一帧，跳过过时的帧
    int skipExpireFrame(const mgvector<int>& head, int index, long curTick);    //!< 跳过过时的帧
    bool frameNeedWait(long curTick);           //!< 当前帧是否等待显示
    
private:
    GiCoreViewData* getData();
    static GiCoreViewData* getData(long coreView);
    static void applyFrame(GiCoreViewData* data, GiPlaying* playing, int flags);
    MgShapeFactory* shapeFactory();
    
    MgCoreView* _v;
};

#endif // TOUCHVG_CORE_PLAY_H
