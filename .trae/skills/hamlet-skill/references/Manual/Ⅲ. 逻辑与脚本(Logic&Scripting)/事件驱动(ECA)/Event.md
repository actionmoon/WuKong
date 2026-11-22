# 事件 (Event) 概述

事件（Event）是触发逻辑执行的起点，当特定的状态改变或行为发生时会被调用。
本手册结合虚拟世界 SDK，从不同维度拆解了常用的事件及其应用场景，方便开发者在不同模块中快速定位并监听需要的事件。

---

## 1. 房间与玩家事件 (Room & Player)

处理玩家进入、离开房间，以及角色对象的生成与销毁。

| 事件方法 | 归属模块 | 描述 |
| --- | --- | --- |
| `OnPlayerJoined` | 玩家生命周期 | 当有玩家进入房间时触发。 |
| `OnPlayerLeft` | 玩家生命周期 | 当有玩家离开房间或断线时触发。 |
| `OnPlayerRejoined` | 玩家生命周期 | 当断线玩家重新连接进入房间时触发。 |
| `OnActorSpawned` | 角色生命周期 | 玩家对应的角色（Actor）在场景中生成完毕时触发。**一定在 OnPlayerJoined 之后执行**。 |
| `OnActorDespawned` | 角色生命周期 | 玩家对应的角色（Actor）被销毁（通常由于退房）时触发。 |
| `OnActorRespawn` | 角色生命周期 | 玩家角色重生时触发。 |
| `OnActorLoaded` | 角色状态 | 角色资源（模型/特效等）加载完成时触发。 |

---

## 2. 角色行为事件 (Character Action)

监听角色自身执行的具体动作和状态改变。

| 事件方法 | 归属模块 | 描述 |
| --- | --- | --- |
| `onJump` | `DouyinActor` | 角色起跳时触发。 |
| `onFallingGround` | `DouyinActor` | 角色从空中落地时触发。 |
| `onFlyStart` / `onFlyStop` | `DouyinActor` | 角色开始/停止飞行时触发。 |
| `onSwimStart` / `onSwimStop` | `DouyinActor` | 角色开始/停止游泳时触发。 |
| `onSitDown` / `onStandUp` | `DouyinActor` | 角色坐下/站起时触发。 |
| `onPickup` / `onDrop` | `DouyinActor` | 角色拾取/丢弃物品时触发。 |
| `onHoldHandStart` / `onHoldHandStop` | `DouyinActor` | 角色开始/停止牵手时触发。 |
| `onDuoInteractionStart` / `onDuoInteractionEnd` / `onDuoInteractionWaiting` | `DouyinActor` | 角色开始/结束双人交互（如拥抱等），或处于等待双人交互状态时触发。 |
| `onActionPlay` / `onEmotionPlay` | `DouyinActor` | 角色播放特定动作或表情时触发。 |

---

## 3. 网络与数据事件 (Network & Data)

管理网络同步、断线重连、RPC调用及主权转移等底层网络事件。

| 事件方法 | 归属模块 | 描述 |
| --- | --- | --- |
| `OnNetworkSettled` | `DouyinNetService` | 全局事件，表示本地数据与服务器已完全同步完成（通常在进入房间后触发一次）。 |
| `onDisconnect` / `onReconnect` | `DouyinNetService` | 客户端断开连接 / 重新连接成功时触发。 |
| `onClientEvent` / `onServerEvent` | `DouyinRemoteEvent` | 监听从服务端发送到客户端的事件 / 从客户端发送到服务端的事件。 |
| `onClientInvoke` / `onServerInvoke` | `DouyinRemoteFunction`| 监听客户端调用的 RPC 函数 / 服务端调用的 RPC 函数。 |
| `OnNetSpawned` / `OnNetDestroy` | 网络对象生命周期 | 动态网络对象初始化完成 / 网络对象销毁时触发。 |
| `OnOwnershipRequest` | 主权管理 | 收到其他玩家请求当前物体主权时触发。 |
| `OnOwnershipTransferred` | 主权管理 | 网络对象的主权发生转移时触发。 |
| `OnControllershipTransferred` | 控制权管理 | 网络对象的控制权发生转移时触发。 |
| `OnValueChange` | 同步变量 | 绑定的网络同步变量数据发生变更时触发。 |

---

## 4. 界面与输入事件 (UI & Input)

处理屏幕触摸、点击、拖拽以及 UI 界面的分辨率变化等。

| 事件方法 | 归属模块 | 描述 |
| --- | --- | --- |
| `On3DClick` / `On3DTouchBegin` | `DouyinScript` | 玩家点击/触摸 3D 场景中的对象时触发。 |
| `On3DTouchDrag` / `On3DTouchEnd` | `DouyinScript` | 玩家在 3D 对象上拖动/结束触摸时触发。 |
| `OnBeginDrag` / `OnDrag` / `OnEndDrag` | `DouyinScript` (UI) | UI 元素的拖拽生命周期事件。 |
| `OnMouseDown` / `OnMouseDrag` | `DouyinScript` | 鼠标按下 / 鼠标拖拽事件。 |
| `OnInteract` / `OnCancel` | `DouyinScript` | UI/物体交互被确认 / 交互被取消时触发。 |
| `OnFocus` / `OnLostFocus` | `DouyinScript` | UI 元素获得焦点 / 失去焦点时触发。 |
| `OnInteractorButtonClick` | 交互按钮 | 玩家点击动态添加的交互按钮时触发。 |
| `onScreenResolutionChanged` | `DouyinUIService` | 屏幕分辨率发生改变（如横竖屏切换）时触发。 |
| `onCameraModeChanged` | `DouyinCameraService` | 相机模式（如进入/退出拍照模式）发生改变时触发。 |
| `onJumpInputStart` / `Perform` / `Cancel`| `DouyinInputService`| 玩家按下/按住/松开跳跃键时触发。 |
| `onMoveInputStart` / `Perform` / `Cancel`| `DouyinInputService`| 玩家拨动/保持/松开移动摇杆时触发。 |
| `onLookInputStart` / `Perform` / `Cancel`| `DouyinInputService`| 玩家开始/保持/结束滑动屏幕控制视角时触发。 |
| `onTouchEvent` / `onZoomInput`| `DouyinInputService`| 玩家在屏幕上进行触控/双指缩放操作时触发。 |

---

## 5. 物理与碰撞事件 (Physics)

处理游戏对象之间的物理碰撞和触发器检测。

| 事件方法 | 归属模块 | 描述 |
| --- | --- | --- |
| `OnCollisionEnter` / `OnCollisionExit` | `DouyinScript` | 物理碰撞体接触/分离时触发。 |
| `OnActorCollisionEnter` / `Exit` | `DouyinScript` | 玩家角色（Actor）与当前物体的碰撞体接触/分离时触发。 |
| `OnActorTriggerEnter` / `Exit` | `DouyinScript` | 玩家角色（Actor）进入/离开当前物体的触发器（Trigger）时触发。 |

---

## 6. 系统生命周期事件 (Lifecycle)

Unity / DouyinScript 的原生脚本生命周期。

| 事件方法 | 归属模块 | 描述 |
| --- | --- | --- |
| `Awake` / `Start` | `DouyinScript` | 脚本实例被加载 / 第一次更新前触发。 |
| `OnEnable` / `OnDisable` | `DouyinScript` | 脚本组件被启用 / 禁用时触发。 |
| `FixedUpdate` / `LateUpdate` | `DouyinScript` | 固定物理帧更新 / 所有 Update 执行完后触发。 |
| `OnDestroy` | `DouyinScript` | 脚本或挂载的游戏对象被销毁时触发。 |

---

## 7. 商业化事件 (Commerce) (拓展维度)

处理虚拟世界中的商品购买和支付相关事件。

| 事件方法 | 归属模块 | 描述 |
| --- | --- | --- |
| `onPurchaseResult` | `DouyinMarketingService` | 商品购买流程结束并返回结果时触发。 |
| `onOrderPayment` | `DouyinMarketingService` | 订单支付状态发生变化时触发。 |
| `onStarLightChanged` | `DouyinMarketingService` | 玩家的星光（货币）数量发生变化时触发。 |
