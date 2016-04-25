// Copyright (c) 2014-2016 Zhang Yungui, https://github.com/rhcad/vgplay (GPL v3 licensed)

package rhcad.vgplay.internal;

import java.io.File;
import java.util.ArrayList;

import rhcad.touchvg.core.GiCoreView;
import rhcad.touchvg.view.BaseGraphView;
import rhcad.touchvg.view.internal.BaseViewAdapter;
import rhcad.vgplay.PlayingHelper.OnPlayEndedListener;
import rhcad.vgplay.PlayingHelper.PlayProvider;
import android.os.Bundle;
import android.util.Log;

public class Playings {
    private static final String TAG = "touchvg";
    private BaseViewAdapter mViewAdapter;
    private ArrayList<OnPlayEndedListener> playEndedListeners;
    private ArrayList<ProviderRunnable> providers;
    private ArrayList<SyncPlayRunnable> syncPlayings;
    private PlayRunnable mPlayer;

    public Playings(BaseViewAdapter adapter) {
        this.mViewAdapter = adapter;
        adapter.setOnPlayingListener(new BaseViewAdapter.OnPlayingListener() {

            @Override
            public void onRestorePlayingState(Bundle savedState) {
                if (mPlayer != null) {
                    return;
                }
                Log.d(TAG, "Start playing..." + savedState.getInt("recordTick"));

                final String path = savedState.getString("recordPath");
                mPlayer = new PlayRunnable(Playings.this, path);
                new Thread(mPlayer, "touchvg.play").start();

                if (mPlayer.loadFrameIndex()) {
                    getGraphView().getImageCache().setPlayPath(path);
                    mPlayer.loadFirstFrame(savedState.getString("playFile"));
                    mPlayer.requestRecord(PlayRunnable.NEXT_FRAME);
                } else {
                    mPlayer.stop();
                }
            }

            @Override
            public void onShapeDeleted(int sid) {
                // Do nothing
            }

            @Override
            public void onStopped() {
                stopPlay();
                ProviderRunnable.stopAll(providers);
            }});
    }

    public BaseViewAdapter viewAdapter() {
        return mViewAdapter;
    }

    public GiCoreView coreView() {
        return mViewAdapter.coreView();
    }

    public BaseGraphView getGraphView() {
        return mViewAdapter.getGraphView();
    }

    public void setOnPlayEndedListener(OnPlayEndedListener listener) {
        if (playEndedListeners == null) {
            playEndedListeners = new ArrayList<OnPlayEndedListener>();
        }
        playEndedListeners.add(listener);
    }

    public boolean isPlaying() {
        return mPlayer != null;
    }

    public String getPlayPath() {
        return mPlayer != null ? mPlayer.getPath() : null;
    }

    public boolean startPlay(String path) {
        if (mViewAdapter == null || mViewAdapter.getSavedState() != null) {
            return false;
        }
        if (isPlaying() || coreView().isPlaying()) {
            return false;
        }
        if (!new File(path).exists()) {
            Log.e(TAG, "Path not exist: " + path);
        }

        mViewAdapter.hideContextActions();

        synchronized (coreView()) {
            if (!coreView().startRecord(path, 0, false, BaseViewAdapter.getTick())) {
                return false;
            }
        }

        mPlayer = new PlayRunnable(this, path);
        new Thread(mPlayer, "touchvg.play").start();

        Log.d(TAG, "Start playing...");
        if (mPlayer.loadFrameIndex()) {
            getGraphView().getImageCache().setPlayPath(path);
            mPlayer.requestRecord(PlayRunnable.FIRST_FRAME);
            return true;
        } else {
            mPlayer.stop();
        }

        return false;
    }

    public void stopPlay() {
        if (mPlayer != null && coreView() != null) {
            synchronized (coreView()) {
                mPlayer.stop();
            }
        }
    }

    private SyncPlayRunnable findSyncPlaying(int cid) {
        if (syncPlayings != null) {
            for (SyncPlayRunnable p : syncPlayings) {
                if (p.getTag() == cid) {
                    return p;
                }
            }
        }
        return null;
    }

    public boolean startSyncPlay(int cid, String path) {
        if (findSyncPlaying(cid) != null) {
            return false;
        }

        final SyncPlayRunnable player = new SyncPlayRunnable(this, path, cid);

        if (syncPlayings == null) {
            syncPlayings = new ArrayList<SyncPlayRunnable>();
        }
        syncPlayings.add(player);
        new Thread(player, "touchvg.syncplay").start();

        return true;
    }

    public void applySyncPlayFrame(int cid, int index) {
        final SyncPlayRunnable player = findSyncPlaying(cid);
        if (player != null) {
            player.requestRecord(index);
        }
    }

    public void stopSyncPlay(int cid) {
        final SyncPlayRunnable player = findSyncPlaying(cid);
        if (player != null && coreView() != null) {
            synchronized (coreView()) {
                player.stop();
            }
        }
    }

    public void stopSyncPlayings() {
        if (syncPlayings != null) {
            synchronized (coreView()) {
                for (SyncPlayRunnable p : syncPlayings) {
                    p.stop();
                }
            }
            syncPlayings = null;
        }
    }

    public boolean onStopped(Runnable r) {
        if (mPlayer == r) {
            mPlayer = null;
        }
        if (syncPlayings != null) {
            syncPlayings.remove(r);
        }
        return coreView() != null;
    }

    private boolean onPlayRet;
    public boolean onPlayWillEnd() {
        onPlayRet = false;

        if (playEndedListeners != null) {
            final Runnable runnable = new Runnable() {
                @Override
                public void run() {
                    mViewAdapter.removeCallbacks(this);
                    for (OnPlayEndedListener listener : playEndedListeners) {
                        onPlayRet = listener.onPlayWillEnd(getGraphView()) || onPlayRet;
                    }
                    synchronized (this) {
                        this.notify();
                    }
                }
            };
            synchronized (runnable) {
                mViewAdapter.getActivity().runOnUiThread(runnable);
                try {
                    runnable.wait();
                } catch (InterruptedException e) {
                    Log.d(TAG, "wait", e);
                }
            }
        }

        return onPlayRet;
    }

    public void onPlayEnded() {
        mViewAdapter.postDelayed(new Runnable() {
            @Override
            public void run() {
                mViewAdapter.removeCallbacks(this);
                mViewAdapter.regenAll(false);
                if (playEndedListeners != null) {
                    for (OnPlayEndedListener listener : playEndedListeners) {
                        listener.onPlayEnded(getGraphView(), 0, null);
                    }
                }
            }
        }, 50);
    }

    public boolean addPlayProvider(PlayProvider p, int tag, Object extra) {
        if (providers == null) {
            providers = new ArrayList<ProviderRunnable>();
        }
        new Thread(new ProviderRunnable(providers, getGraphView(), p, tag, extra),
                "touchvg.provider").start();
        return true;
    }

    public int getPlayProviderCount() {
        if (providers == null) {
            return 0;
        }
        synchronized (providers) {
            return providers.size();
        }
    }

    public void stopProviders() {
        ProviderRunnable.stopAll(providers);
    }
}
