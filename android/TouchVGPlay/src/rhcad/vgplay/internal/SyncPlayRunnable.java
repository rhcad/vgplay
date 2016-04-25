// Copyright (c) 2014-2016 Zhang Yungui, https://github.com/rhcad/vgplay (GPL v3 licensed)

package rhcad.vgplay.internal;

import rhcad.touchvg.core.GiCoreViewData;
import rhcad.touchvg.core.GiPlayShapes;
import rhcad.touchvg.core.GiPlaying;
import rhcad.touchvg.core.MgRecordShapes;
import rhcad.touchvg.view.internal.BaseViewAdapter;
import rhcad.touchvg.view.internal.LogHelper;
import rhcad.touchvg.view.internal.ShapeRunnable;
import rhcad.vgplay.core.GiCorePlay;

public class SyncPlayRunnable extends ShapeRunnable {
    public static final int TYPE = 4;
    private Playings mInternal;
    private GiPlayShapes mPlay = new GiPlayShapes();
    private GiPlaying mPlaying;
    private GiCoreViewData mCoreData;
    private int PLAY_LIMITMS = 120000;

    public SyncPlayRunnable(Playings internal, String path, int tag) {
        super(path, TYPE, internal.coreView());
        this.mInternal = internal;
        mPlay.setPlaying(GiPlaying.create(internal.coreView(), tag));
        mPlay.setPlayer(new MgRecordShapes(path, null, false, BaseViewAdapter.getTick()));
        mPlaying = mPlay.getPlaying();
        mCoreData = GiCoreViewData.fromHandle(internal.coreView().viewDataHandle());
    }

    public GiPlayShapes getPlayer() {
        return mPlay;
    }

    public int getTag() {
        return mPlaying.getTag();
    }

    @Override
    protected boolean beforeStopped() {
        final LogHelper log = new LogHelper("GiCoreView.class synchronized " + getTag());
        boolean ret = mInternal.onStopped(this);
        if (ret) {
            synchronized (mCoreView) {
                mPlay.getPlayer().delete();
                mPlay.setPlayer(null);
                mPlaying.release(mInternal.coreView());
                mPlay.setPlaying(null);
            }
        }
        log.r(ret);
        return ret;
    }

    @Override
    protected void afterStopped(boolean normal) {
        mInternal = null;
        mPlay = null;
        mPlaying = null;
        mCoreData = null;
    }

    @Override
    protected void process(int tick, int change, int doc, int shapes) {
        int index = tick;
        final int flags = mPlay.getPlayer().applyRedoFile(mCoreData.getShapeFactory(),
                mPlaying.getBackDoc(), mPlaying.getBackShapes(true), index);
        final int playticks = mPlay.getPlayer().getCurrentTick(BaseViewAdapter.getTick());

        mStopping = mStopping || playticks > PLAY_LIMITMS;
        if (flags != 0 && !mStopping) {
            synchronized (mCoreView) {
                GiCorePlay.applyFrame(mInternal.coreView().toHandle(), mPlaying.toHandle(), flags);
            }
        }
    }
}
