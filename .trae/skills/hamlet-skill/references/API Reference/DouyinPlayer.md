在阅读此类前，请参阅[玩家与合养精灵](unknown)章节，以了解更多关于玩家和合养精灵的背景信息。
# 描述
玩家类，用来定义一个玩家对象，并获取这些玩家的数据。 每个玩家都与一个 DouyinPlayer 对象关联。

* 包含玩家的一些基础属性，比如ID、昵称、头像、GameObject等。
* 当玩家的角色加入、离开时，将对应触发 OnPlayerJoined、OnPlayerLeft 事件。您可以在与 DouyinScript 关联的 Lua 脚本中监听这些事件，并处理相关业务逻辑。

# 公开属性
| 属性 | 描述 |
| --- | --- |
| [gameObject](./DouyinPlayer/DouyinPlayer.gameObject.md) | 与玩家关联的 GameObject |
| [playerID](./DouyinPlayer/DouyinPlayer.playerID.md) | 房间内玩家实例ID，每次进房都会重新生成，客户端可以用该ID来标识玩家。 |
| [playerOpenID](./DouyinPlayer/DouyinPlayer.playerOpenID.md) | 房间内玩家的抖音开放ID，玩家ID的唯一标识 |
| [playerName](./DouyinPlayer/DouyinPlayer.playerName.md) | 玩家名称 |
| [isLocal](./DouyinPlayer/DouyinPlayer.isLocal.md) | 是否是MainPlayer，本地玩家 |
| [isServer](./DouyinPlayer/DouyinPlayer.isServer.md) | 是否是Dedicated Server的DouyinPlayer；Dedicated Server 是特殊的DouyinPlayer； |
# 公开方法
| 方法 | 描述 |
| --- | --- |
| [GetActor](./DouyinPlayer/DouyinPlayer.GetActor.md) | 获取此玩家当前控制的Actor对象实例，返回可能为Null，表示还没有控制的Actor对象实例 |
| [GetPlayerPortrait](./DouyinPlayer/DouyinPlayer.GetPlayerPortrait.md) | 获取玩家头像 |
