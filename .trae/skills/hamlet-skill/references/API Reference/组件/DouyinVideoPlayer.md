# 描述
视频播放组件

# 公开属性
| 属性 | 描述 |
| --- | --- |
| [isSync](./DouyinVideoPlayer/DouyinVideoPlayer.isSync.md) | 是否同步 |
| [videoPlaybackMode](./DouyinVideoPlayer/DouyinVideoPlayer.videoPlaybackMode.md) | 视频播放方式 |
| [videoUrls](./DouyinVideoPlayer/DouyinVideoPlayer.videoUrls.md) | 视频链接列表 |
| [screenRenderer](./DouyinVideoPlayer/DouyinVideoPlayer.screenRenderer.md) | 渲染目标（只读） |
| [totalTime](./DouyinVideoPlayer/DouyinVideoPlayer.totalTime.md) | 当前视频总时长· |
| [playingTime](./DouyinVideoPlayer/DouyinVideoPlayer.playingTime.md) | 当前视频的播放时长 |
# 公开方法
| 方法 | 描述 |
| --- | --- |
| [PlayVideo](./DouyinVideoPlayer/DouyinVideoPlayer.PlayVideo.md) | 视频开始播放（重头播放） |
| [PauseVideo](./DouyinVideoPlayer/DouyinVideoPlayer.PauseVideo.md) | 视频暂停 |
| [ResumeVideo](./DouyinVideoPlayer/DouyinVideoPlayer.ResumeVideo.md) | 视频恢复播放（当前的进度开始播放） |
| [PlayeNextVideo](./DouyinVideoPlayer/DouyinVideoPlayer.PlayNextVideo.md) | 播放下一个视频 |
| [PlayVideoByIndex](./DouyinVideoPlayer/DouyinVideoPlayer.PlayVideoByIndex.md) | 播放指定列表的索引的视频 |
| [SetPlaybackMode](./DouyinVideoPlayer/DouyinVideoPlayer.SetPlaybackMode.md) | 切换视频播放模式 |
# 公开事件
| 事件 | 描述 |
| --- | --- |
| [onVideoPlayStarted](./DouyinVideoPlayer/DouyinVideoPlayer.onVideoPlayStarted.md) | 视频开始播放的时间 |
| [onVideoPlayPaused](./DouyinVideoPlayer/DouyinVideoPlayer.onVideoPlayPaused.md) | 视频暂停播放的事件 |
| [onVideoPlayResumed](./DouyinVideoPlayer/DouyinVideoPlayer.onVideoPlayResumed.md) | 视频恢复播放的事件 |
| [onVideoPlayEnded](./DouyinVideoPlayer/DouyinVideoPlayer.onVideoPlayEnded.md) |  视频结束播放的事件 |
| [onAllVideosPlayEnded](./DouyinVideoPlayer/DouyinVideoPlayer.onAllVideosPlayEnded.md) | 列表所有视频结束的事件(仅顺序播放模式且没有下一个视频时触发) |
