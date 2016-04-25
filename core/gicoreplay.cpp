//! \file gicoreplay.cpp
//! \brief 实现矢量图形播放内核类 GiCorePlay
// Copyright (c) 2014-2016 Zhang Yungui, https://github.com/rhcad/vgplay (GPL v3 licensed)

#include "gicoreplay.h"
#include "gicoreview.h"
#include "gicoreviewdata.h"
#include "mglog.h"

#define COREPLAY_VERSION    3   // TODO: change it after any change

GiCorePlay::GiCorePlay(long coreView) : _v(MgCoreView::fromHandle(coreView))
{
    _v->addRef();
}

GiCorePlay::~GiCorePlay()
{
    _v->release();
}

int GiCorePlay::getVersion()
{
    return COREPLAY_VERSION;
}

GiCoreViewData* GiCorePlay::getData()
{
    return _v ? GiCoreViewData::fromHandle(_v->viewDataHandle()) : NULL;
}

GiCoreViewData* GiCorePlay::getData(long coreView)
{
    MgCoreView *v = MgCoreView::fromHandle(coreView);
    return v ? GiCoreViewData::fromHandle(v->viewDataHandle()) : NULL;
}

MgShapeFactory* GiCorePlay::shapeFactory()
{
    return getData()->getShapeFactory();
}

bool GiCorePlay::loadFrameIndex(const char* path, mgvector<int>& arr)
{
    std::vector<int> v;
    
    if (MgRecordShapes::loadFrameIndex(path, v)) {
        arr.setSize((int)v.size());
        for (int i = 0; i < arr.count(); i++) {
            arr.set(i, v[i]);
        }
    }
    return !v.empty() && arr.count() > 0;
}

int GiCorePlay::loadFirstFrame()
{
    GiCoreViewData* data = getData();
    if (!data || !_v->isPlaying()) {
        return 0;
    }
    
    MgShapeDoc* doc = data->play.playing->getBackDoc();
    if (!doc || !data->recorder(false)->applyFirstFile(shapeFactory(), doc)) {
        return 0;
    }
    
    doc->setReadOnly(true);
    return DOC_CHANGED;
}

int GiCorePlay::loadFirstFrame(const char* filename)
{
    GiCoreViewData* data = getData();
    if (!data || !_v->isPlaying()) {
        return 0;
    }
    
    MgShapeDoc* doc = data->play.playing->getBackDoc();
    if (!doc || !data->recorder(false)->applyFirstFile(shapeFactory(), doc, filename)) {
        return 0;
    }
    
    doc->setReadOnly(true);
    return DOC_CHANGED;
}

int GiCorePlay::skipExpireFrame(const mgvector<int>& head, int index, long curTick)
{
    int from = index;
    int tickNow = (int)_v->getPlayingTick(curTick);
    
    for ( ; index <= head.count() / 3; index++) {
        int tick = head.get(index * 3 - 2);
        int flags = head.get(index * 3 - 1);
        if (tickNow < 120000)   // for DEMO release
        if (flags != MgRecordShapes::DYN || tick + 200 > tickNow) {
            break;
        }
    }
    if (index > from) {
        LOGD("Skip %d frames from #%d, tick=%d, now=%d",
             index - from, from, head.get(from * 3 - 2), tickNow);
    }
    return index;
}

bool GiCorePlay::frameNeedWait(long curTick)
{
    GiCoreViewData* data = getData();
    if (!data) {
        return false;
    }
    return data->startPauseTick || _v->getFrameTick() - 100 > _v->getPlayingTick(curTick);
}

int GiCorePlay::loadNextFrame(const mgvector<int>& head, long curTick)
{
    return loadNextFrame(skipExpireFrame(head, _v->getFrameIndex(), curTick));
}

int GiCorePlay::loadNextFrame(int index)
{
    GiCoreViewData* data = getData();
    if (!data || !_v->isPlaying()) {
        return 0;
    }
    
    MgShapeDoc* doc = data->play.playing->getBackDoc();
    MgShapes* shapes = data->play.playing->getBackShapes(true);
    
    if (!doc || !shapes) {
        return 0;
    }
    
    return data->recorder(false)->applyRedoFile(shapeFactory(), doc, shapes, index);
}

int GiCorePlay::loadPrevFrame(int index, long curTick)
{
    GiCoreViewData* data = getData();
    if (!data || !_v->isPlaying()) {
        return 0;
    }
    
    MgShapeDoc* doc = data->play.playing->getBackDoc();
    MgShapes* shapes = data->play.playing->getBackShapes(true);
    
    if (!doc || !shapes) {
        return 0;
    }
    
    return data->recorder(false)->applyUndoFile(shapeFactory(), doc, shapes, index, curTick);
}

void GiCorePlay::applyFrame(long coreView, long playing, int flags)
{
    applyFrame(getData(coreView), GiPlaying::fromHandle(playing), flags);
}

void GiCorePlay::applyFrame(int flags)
{
    GiCoreViewData* data = getData();
    if (data) {
        applyFrame(data, data->play.playing, flags);
    }
}

void GiCorePlay::applyFrame(GiCoreViewData* data, GiPlaying* playing, int flags)
{
    if (!data || !playing) {
        return;
    }
    MgShapeDoc* doc = playing->getBackDoc();
    
    if (flags & (DOC_CHANGED | SHAPE_APPEND)) {
        playing->submitBackDoc();
        GiTransform* xf = data->xform();
        if (xf && playing == data->play.playing) {
            xf->setModelTransform(doc->modelTransform());
            xf->zoomTo(doc->getPageRectW());
            data->submitBackXform();
        }
    }
    if (flags & DYN_CHANGED) {
        playing->submitBackShapes();
    }
    
    if (flags & DOC_CHANGED) {
        data->regenAll(false);
    }
    else if (flags & SHAPE_APPEND) {
        data->regenAppend(doc->getLastShape()->getID(), playing->toHandle());
    }
    else if (flags & DYN_CHANGED) {
        data->redraw(false);
    }
}
