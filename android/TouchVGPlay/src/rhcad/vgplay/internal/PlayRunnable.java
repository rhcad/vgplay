// Copyright (c) 2014-2016 Zhang Yungui, https://github.com/rhcad/vgplay (GPL v3 licensed)

package rhcad.vgplay.internal;

import rhcad.touchvg.view.internal.LogHelper;
import rhcad.touchvg.view.internal.ShapeRunnable;
import rhcad.vgplay.core.GiCorePlay;
import rhcad.vgplay.core.Ints;
import android.util.Log;

public class PlayRunnable extends ShapeRunnable {
    public static final int TYPE = 3;
    public static final int FIRST_FRAME = 0xFFFFFF10;
    public static final int NEXT_FRAME = 0xFFFFFF20;
    private Playings mInternal;
    protected GiCorePlay mPlay;
    private Ints mFrameIndex;
    private int mFlags;

    public PlayRunnable(Playings internal, String path) {
        super(path, TYPE, internal.coreView());
        this.mInternal = internal;
        this.mPlay = new GiCorePlay(internal.coreView().toHandle());
    }

    public final boolean loadFrameIndex() {
        if (mFrameIndex == null)
            mFrameIndex = new Ints();
        return GiCorePlay.loadFrameIndex(mPath, mFrameIndex);
    }

    public final boolean loadFirstFrame(String filename) {
        boolean ret = mPlay.loadFirstFrame(filename) != 0;
        if (ret) {
            Log.d(TAG, "Auto load playing shapes from " + filename);
            applyFrame(0);
        }
        return ret;
    }

    @Override
    protected boolean beforeStopped() {
        final LogHelper log = new LogHelper("GiCoreView.class synchronized");
        boolean ret = mInternal.onStopped(this);
        if (ret) {
            synchronized (mCoreView) {
                mCoreView.stopRecord(false);
            }
        }
        log.r(ret);
        return ret;
    }

    @Override
    protected void afterStopped(boolean normal) {
        if (!normal) {
            mInternal = null;
            Log.w(TAG, "Stopped without onPlayEnded notify");
            return;
        }
        if (!mCoreView.isStopping()) {
            mInternal.onPlayEnded();
        }
        mInternal = null;
    }

    @Override
    protected void process(int tick, int change, int doc, int shapes) {
        if (tick == FIRST_FRAME) {
            mFlags = mPlay.loadFirstFrame();
            if (mFlags == 0) {
                mStopping = true;
            } else {
                applyFrame(mCoreView.getFrameTick());
                requestRecord(NEXT_FRAME);
            }
        } else if (tick == NEXT_FRAME) {
            mFlags = mPlay.loadNextFrame(mFrameIndex, getTick());
            if (mFlags == 0) {
                Log.d(TAG, "Playing ended");
                if (!isPlayStopping() && mInternal.onPlayWillEnd()) {
                    mCoreView.onPause(getTick());
                } else {
                    mStopping = true;
                }
            } else if (!mStopping) {
                applyFrame(mCoreView.getFrameTick());
                requestRecord(NEXT_FRAME);
            }
        }
    }

    private void applyFrame(int tick) {
        while (!mStopping && mPlay.frameNeedWait(getTick())) {
            synchronized (mFrameIndex) {
                try {
                    mFrameIndex.wait(10);
                } catch (InterruptedException e) {
                    Log.d(TAG, "applyFrame", e);
                }
            }
        }
        if (!mStopping) {
            synchronized (mCoreView) {
                mPlay.applyFrame(mFlags);
            }
        }
    }

    private boolean isPlayStopping() {
        return mStopping || mCoreView == null || mCoreView.isStopping();
    }
}
