//! \file PlayingHelper.java
//! \brief 图形播放管理类
// Copyright (c) 2014-2016 Zhang Yungui, https://github.com/rhcad/vgplay (GPL v3 licensed)

package rhcad.vgplay;

import java.util.Locale;

import rhcad.touchvg.IGraphView;
import rhcad.touchvg.view.BaseGraphView;
import rhcad.touchvg.view.internal.BaseViewAdapter;
import rhcad.vgplay.core.GiCorePlay;
import rhcad.vgplay.internal.Playings;
import android.util.Log;

/**
 * \ingroup GROUP_ANDROID
 * 图形播放管理类.
 * 每个绘图视图对象(IGraphView)可有最多一个 PlayingHelper 对象.
 * TODO: 每次更新Java代码后发布前 JARVERSION 加1
 */
public class PlayingHelper {
    private BaseGraphView mView;
    private Playings mInternal;
    public static final int JARVERSION = 2;
    public static final int FRAMEFLAGS_DYN = 8;

    //! 播放结束的通知，在 startPlay() 和 stopPlay() 之间回调
    public static interface OnPlayEndedListener {
        //! 播放完成，待用户结束播放: 返回false表示不拦截，true表示暂停在最后一帧，后续由应用来调用 stopPlay()
        public boolean onPlayWillEnd(IGraphView view);

        //! 播放结束，应用可更新界面布局、销毁附加的 extra 对象
        public void onPlayEnded(IGraphView view, int tag, Object extra);
    }

    //! 播放源接口，由应用提供显示内容
    public static interface PlayProvider {
        //! 向动态图形列表(hShapes)提供当前帧的图形内容
        //! @return 0表示当前时刻还没有新帧，负数表示播放结束，正数表示已填充当前帧图形
        public int provideFrame(IGraphView view, int tag, Object extra, int hShapes, int tick, int lastTick);

        //! 播放结束，应用可更新界面布局、销毁附加的 extra 对象
        public void onPlayEnded(IGraphView view, int tag, Object extra);
    }

    static {
        System.loadLibrary("vgplay");
        Log.i("touchvg", "TouchVGPlay R" + JARVERSION + "." + GiCorePlay.getVersion());
    }

    //! 指定视图的构造函数，每个绘图视图对象可有一个 PlayingHelper 对象
    public PlayingHelper(IGraphView view) {
        mView = (BaseGraphView)view;
        mInternal = new Playings(internalAdapter());
    }

    //! 得到本库的版本号
    public static String getVersion() {
        return String.format(Locale.US, "%d.%d", JARVERSION, GiCorePlay.getVersion());
    }

    //! 添加播放结束的观察者，在 startPlay() 和 stopPlay() 之间回调
    public void setOnPlayEndedListener(OnPlayEndedListener listener) {
        mInternal.setOnPlayEndedListener(listener);
    }

    //! 停止所有播放项，包含 startPlay/startSyncPlay/addPlayProvider 对应项
    public void stop() {
        mInternal.stopPlay();
        mInternal.stopSyncPlayings();
    }

    //! 开始播放指定的目录下录制的图形
    public boolean startPlay(String path) {
        return mView != null && mInternal.startPlay(path);
    }

    //! 停止播放
    public void stopPlay() {
        mInternal.stopPlay();
    }

    //! 暂停播放
    public boolean playPause() {
        return mView != null && mView.coreView().onPause(BaseViewAdapter.getTick());
    }

    //! 继续播放
    public boolean playResume() {
        return mView != null && mView.coreView().onResume(BaseViewAdapter.getTick());
    }

    //! 返回已播放的相对毫秒数
    public int getPlayTicks() {
        int tick = BaseViewAdapter.getTick();
        return mView != null ? mView.coreView().getRecordTick(false, tick) : 0;
    }

    //! 开始同步播放，待播放的图形将缓存在指定的目录
    public boolean startSyncPlay(int cid, String path) {
        return mInternal.startSyncPlay(cid, path);
    }

    //! 同步播放一帧，此帧(*.vgr)已缓存到指定的目录
    public void applySyncPlayFrame(int cid, int index) {
        mInternal.applySyncPlayFrame(cid, index);
    }

    //! 停止同步播放
    public void stopSyncPlay(int cid) {
        mInternal.stopSyncPlay(cid);
    }

    //! 停止所有同步播放
    public void stopSyncPlayings() {
        mInternal.stopSyncPlayings();
    }

    //! 添加播放源，可指定应用所需的附加对象
    public boolean addPlayProvider(PlayProvider p, int tag, Object extra) {
        return mInternal.addPlayProvider(p, tag, extra);
    }

    //! 返回播放源的个数
    public int getPlayProviderCount() {
        return mInternal.getPlayProviderCount();
    }

    //! 停止所有播放源
    public void stopProviders() {
        mInternal.stopProviders();
    }

    private BaseViewAdapter internalAdapter() {
        if (mView == null || mView.getMainView() == null) {
            return null;
        }
        return (BaseViewAdapter)((BaseGraphView)mView.getMainView()).viewAdapter();
    }
}
