# 描述
DouyinObject 类用于表示一个具有唯一标识符（UID）的游戏对象。
提供了对该对象进行同步和销毁设置的方法。
# 公开属性
| 属性 | 描述 |
| --- | --- |
| [UID](./DouyinObject/DouyinObject.UID.md) | 该类实例的唯一标识符，在对象创建时初始化 |
| [gameObject](./DouyinObject/DouyinObject.gameObject.md) | 该类实例关联的 Unity 游戏对象，在对象创建时初始化 |
# 公开方法
| 方法 | 描述 |
| --- | --- |
| [EnableSync](./DouyinObject/DouyinObject.EnableSync.md) | 开或关闭网络同步，默认是开启 |
| [SetDestoryWhenDrop](./DouyinObject/DouyinObject.SetDestroyWhenDrop.md) | 房间内最后一个用户断线的时候，是否当玩家丢弃此对象时立即销毁此对象 |
