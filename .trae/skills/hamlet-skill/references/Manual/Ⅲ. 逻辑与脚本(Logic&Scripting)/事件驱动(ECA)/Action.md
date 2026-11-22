# 行为 (Action) 概述

行为（Action）是指在代码中主动调用的指令或方法，用于改变游戏世界的状态、驱动角色表现、操作网络对象或修改 UI。
本手册对虚拟世界 SDK 中常见的执行行为进行了多维度拆解。

---

## 1. 角色行为 (Character Action)

控制玩家角色（Actor）在游戏内的位移、动画和交互状态。

| 方法 | 归属模块 | 描述 |
| --- | --- | --- |
| `Jump()` | `DouyinActor` | 令角色执行跳跃行为。 |
| `MoveContinuously(dir)` | `DouyinActor` | 令角色朝指定方向持续移动。 |
| `StopMove()` | `DouyinActor` | 停止角色的持续移动。 |
| `Teleport(position)` | `DouyinActor` | 瞬间将角色传送到指定位置。 |
| `Immobilize(bool)` | `DouyinActor` | 禁止/恢复角色的摇杆输入，不影响重力和碰撞。 |
| `StartFly()` / `StopFly()` | `DouyinActor` | 令角色开始飞行 / 停止飞行并落回地面。 |
| `SetFlyMode(mode)` | `DouyinActor` | 设置角色飞行的模式规则。 |
| `SitDown()` / `StandUp()` | `DouyinActor` | 令角色坐在指定的椅子或位置上 / 从座位上站起。 |
| `Pickup(item)` / `Drop()` | `DouyinActor` | 拾取指定的物体拿在手中 / 丢弃当前手中的物品。 |
| `PlayAnimation()` / `StopAnimation()` | `DouyinActor` | 播放 / 停止指定的动作片段。 |
| `SetOverrideAnimation()` | `DouyinActor` | 覆盖角色默认的特定动画表现（例如替换待机动画）。 |
| `SetOverrideAnimationController()` | `DouyinActor` | 完全替换角色的动画控制器 (Animator Controller)。 |
| `PlayEmoji()` | `DouyinActor` | 播放指定的表情。 |
| `Respawn()` | `DouyinActor` | 让角色死亡/重置并回到指定的复活点（Spawn Point）。 |
| `SetSpeed(speed)` | `DouyinActor` | 动态修改角色的移动速度。 |

---

## 2. 交互控制与权限管理 (Interaction & Permission)

针对交互行为的禁用/启用及主权与控制权的请求，包括双人互动和标签管理。

| 方法 | 归属模块 | 描述 |
| --- | --- | --- |
| `DisableInteraction()` / `EnableInteraction()`| `DouyinScript` | 禁用/启用物体上的默认交互功能。 |
| `DisableFly()` / `EnableFly()` | `DouyinActor` | 禁用/启用角色的飞行能力。 |
| `DisableHoldHand()` / `EnableHoldHand()` | `DouyinActor` | 禁用/启用角色的牵手能力。 |
| `SetStateEnabled(state, bool)` | `DouyinActor` | 动态启用或禁用角色的特定状态（如交互、跳跃等）。 |
| `AcceptDuoInteraction()` / `InviteDuoInteraction()` | `DouyinActor` | 接受双人交互请求 / 发起双人交互邀请。 |
| `StopDuoInteraction()` / `StopDuoInteractionWaiting()` | `DouyinActor` | 主动结束正在进行的双人交互 / 取消正在等待的双人交互邀请。 |
| `SetActorTag()` / `ClearActorTags()` | `DouyinActor` | 为角色打上特定的自定义标签 / 清除角色的所有自定义标签。 |
| `RequestOwnership(callback)` | `DouyinScript` | 主动向当前主权方（或服务器）申请网络对象的**主权**。 |
| `SetOwner(player)` | `DouyinScript` | 强制将对象的**主权**指派给指定玩家（仅主权方或服务器可调用）。 |
| `RequestControllership(callback)`| `DouyinScript` | 主动申请网络对象的**控制权**。 |

---

## 3. 网络与同步行为 (Network & Synchronization)

管理对象的生成/销毁、RPC 通信以及数据快照的同步。

| 方法 | 归属模块 | 描述 |
| --- | --- | --- |
| `NetSpawn()` | `DouyinObjectService` | 在网络上动态生成（实例化）一个网络对象，并同步给所有玩家。 |
| `NetDestroy()` | `DouyinObjectService` | 销毁网络对象并从所有客户端移除（必须拥有控制权或主权）。 |
| `ServerSpawn()` / `ServerDestroy()` | `DouyinObjectService` | 仅限服务端（DS）调用的对象生成和销毁方法。 |
| `FireClient()` / `FireAllClients()` | `DouyinRemoteEvent` | 服务端向特定客户端 / 所有客户端发送网络事件。 |
| `FireServer()` | `DouyinRemoteEvent` | 客户端向服务端发送网络事件。 |
| `InvokeServer()` / `InvokeClient()` | `DouyinRemoteFunction`| 发起 RPC 函数调用，并在执行完毕后等待返回值。 |
| `SetValue(val)` | 同步变量 | 主权方调用，修改同步变量的值并自动网络广播。 |

---

## 4. 界面与显示行为 (UI & Display)

管理官方 UI 或自定义 UI 的显示和隐藏，以及相机的控制和视觉表现。

| 方法 | 归属模块 | 描述 |
| --- | --- | --- |
| `SetNativeUIVisible(bool)` | `DouyinUIService` | 隐藏或显示所有非 Unity 层的官方原生界面。 |
| `SetUIVisible(bool)` | `DouyinUIService` | 隐藏或显示 Unity 渲染层的界面。 |
| `AddInteractorButton()` | `DouyinScript` | 在右侧中间区域 (基础交互区)动态添加一个交互按钮。 |
| `ShowNameplate()` | `DouyinActor` | 强制显示或刷新角色的头顶昵称面板。 |
| `SetVisible(bool)` | `DouyinActor` | 隐藏或显示玩家角色的模型整体。 |
| `SetAlpha(alpha)` | `DouyinActor` | 动态设置角色模型的透明度。 |
| `DownloadImage(url, callback)` | `DouyinImageService` | 异步下载网络图片并回调，用于自定义 UI 头像/封面加载。 |
| `SetDistance()` / `SetPitch()` / `SetYaw()` / `SetOffset()` | `DouyinCameraService`| 动态调整相机的距离、俯仰角、偏航角以及中心偏移。 |
| `StartPhotograph()` / `StopPhotograph()` | `DouyinCameraService` | 主动进入 / 退出相机的拍照模式。 |
| `Follow()` / `OpenCreatorInformation()` | `DouyinCreatorService` | 关注世界创作者 / 打开创作者的个人主页资料面板。 |

---

## 5. 数据存储与环境控制 (Data & Environment)

读写持久化数据和控制场景环境效果，以及音频控制。

| 方法 | 归属模块 | 描述 |
| --- | --- | --- |
| `SetData()` / `GetData()` | `DouyinDataStore` | 存储/读取数据存储中的指定键值对。 |
| `IncrementData()` | `DouyinDataStore` | 对数据存储中的数值进行原子级的增加/减少操作。 |
| `RemoveData()` | `DouyinDataStore` | 移除数据存储中的指定数据记录。 |
| `SetRankData()` | `DouyinRankService` | 写入排行榜数据，用于构建世界排行榜。 |
| `SetFootstepAudioClips()` | `DouyinActor` | 动态设置角色的脚步声切片。 |
| `SetJumpAudioClip()` | `DouyinActor` | 动态设置角色的跳跃音效。 |
| `Change(settings)` | `DouyinSceneEnvironment`| 动态改变场景的天空盒、雾效、光照、后处理等环境参数。 |
| `LoadJson(asset)` | `DouyinSceneEnvironment`| 从指定的 JSON 配置文件加载环境设定。 |
| `Quit()` | `DouyinApplication` | 退出当前的虚拟世界。 |

---

## 6. 商业化行为 (Commerce) (拓展维度)

触发商业化相关的订单或页面。

| 方法 | 归属模块 | 描述 |
| --- | --- | --- |
| `Purchase(productID)` | `DouyinMarketingService`| 发起指定商品 ID 的购买支付流程。 |
| `OpenRechargePage()` | `DouyinMarketingService`| 打开虚拟世界内置的充值页面。 |
| `ConfirmOrder()` / `BackOrder()` | `DouyinMarketingService`| 确认订单完成或处理补单逻辑。 |
