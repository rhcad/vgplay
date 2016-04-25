// Copyright (c) 2014-2016 Zhang Yungui, https://github.com/rhcad/vgplay (GPL v3 licensed)

package rhcad.vgplay.internal;

import java.util.List;

import android.util.Log;

import rhcad.touchvg.core.GiPlaying;
import rhcad.touchvg.view.BaseGraphView;
import rhcad.touchvg.view.internal.BaseViewAdapter;
import rhcad.touchvg.view.internal.LogHelper;
import rhcad.touchvg.view.internal.ShapeRunnable;
import rhcad.vgplay.PlayingHelper.PlayProvider;

public class ProviderRunnable implements Runnable {
    protected static final String TAG = "touchvg";
    private GiPlaying mPlaying;
    private List<ProviderRunnable> mProviders;
    private PlayProvider mProvider;
    private Object mExtra;
    private BaseGraphView mView;
    private int mStartTick = getTick();
    private int mLastTick = 0;

    public ProviderRunnable(List<ProviderRunnable> providers, BaseGraphView view,
            PlayProvider p, int tag, Object extra) {
        this.mPlaying = GiPlaying.create(view.coreView(), tag);
        this.mProviders = providers;
        this.mView = view;
        this.mProvider = p;
        this.mExtra = extra;
        synchronized (providers) {
            providers.add(this);
        }
    }

    protected void finalize() {
        Log.d(TAG, "ProviderRunnable finalize");
    }

    public static void stopAll(List<ProviderRunnable> providers) {
        if (providers != null) {
            synchronized (providers) {
                for (ProviderRunnable r : providers) {
                    r.mPlaying.stop();
                }
            }
        }
    }

    public final void stop() {
        final LogHelper log = new LogHelper();
        mPlaying.stop();
        synchronized (this) {
            try {
                this.wait(1000);
            } catch (InterruptedException e) {
                Log.d(TAG, "stop", e);
            }
        }
        log.r();
    }

    public int acquireShapes() {
        return mPlaying.acquireFrontShapes();
    }

    public static int getTick() {
        return ShapeRunnable.getTick();
    }

    @Override
    public void run() {
        while (!mPlaying.isStopping()) {
            try {
                process();
            } catch (Exception e) {
                Log.d(TAG, "run", e);
            }
        }

        synchronized (mProviders) {
            mProviders.remove(this);
        }
        if (mView.coreView() != null && !mView.coreView().isStopping()) {
            final BaseViewAdapter adapter = (BaseViewAdapter) mView.viewAdapter();
            adapter.getActivity().runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    final LogHelper log = new LogHelper();
                    adapter.removeCallbacks(this);
                    adapter.redraw(false);
                    mProvider.onPlayEnded(mView, mPlaying.getTag(), mExtra);
                    cleanup();
                    log.r();
                }
            });
        } else {
            cleanup();
        }
        synchronized (this) {
            this.notify();
        }
    }

    private void cleanup() {
        Log.d(TAG, "ProviderRunnable exit, tag=" + mPlaying.getTag());
        mPlaying.delete();
        mPlaying = null;
        mProvider = null;
        mProviders = null;
        mExtra = null;
        mView = null;
    }

    private void process() {
        int tick = 0, ret = 0;
        int shapes = mPlaying.getBackShapesHandle(false);

        while (ret == 0 && !mPlaying.isStopping()) {
            synchronized (mPlaying) {
                try {
                    mPlaying.wait(1);
                } catch (InterruptedException e) {
                    Log.d(TAG, "process", e);
                }
            }
            tick = getTick() - mStartTick;
            ret = mProvider.provideFrame(mView, mPlaying.getTag(), mExtra, shapes, tick, mLastTick);
        }
        if (ret < 0) {
            mPlaying.stop();
            return;
        }
        mLastTick = tick;
        synchronized (mProviders) {
            mPlaying.submitBackShapes();
        }
        if (!mPlaying.isStopping()) {
            mView.viewAdapter().redraw(false);
        }
    }
}
