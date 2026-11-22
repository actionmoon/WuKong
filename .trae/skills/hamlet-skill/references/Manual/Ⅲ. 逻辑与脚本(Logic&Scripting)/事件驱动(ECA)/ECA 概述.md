# Event-Condition-Action (ECA) 概述

在虚拟世界 SDK 的开发中，我们通常采用 **ECA（Event-Condition-Action，事件-条件-行为）** 架构模式来组织业务逻辑。这种模式可以帮助开发者清晰地解耦逻辑，使得代码更易于维护和扩展。

## 核心概念

* **Event（事件）**：**“当发生了什么”**。它是逻辑的起点，由系统、用户输入或网络通信触发（例如：玩家进入房间、角色落地、UI被点击）。详细列表请参考 [事件 (Event) 手册](./Event.md)。
* **Condition（条件）**：**“是否允许执行”**。在事件触发后，真正执行动作前进行的状态和权限校验（例如：判断当前玩家是否拥有控制权、角色是否在地面上）。详细列表请参考 [条件 (Condition) 手册](./Condition.md)。
* **Action（行为）**：**“去执行什么”**。满足条件后，主动调用的系统指令或方法，用于改变游戏世界的状态（例如：让角色跳跃、生成网络对象、显示UI）。详细列表请参考 [行为 (Action) 手册](./Action.md)。

---

## ECA 维度对比表

根据完整的 SDK API 参考，我们将常用的功能按照核心维度进行梳理，形成如下的对比矩阵。此表旨在帮助开发者在构思业务逻辑时，快速找到对应的“触发器”、“校验器”和“执行器”：

| 功能维度 | Event (事件 - 触发契机) | Condition (条件 - 状态与权限校验) | Action (行为 - 主动执行指令) |
| :--- | :--- | :--- | :--- |
| **房间与玩家<br>(Room & Player)** | `OnPlayerJoined` (玩家加入)<br>`OnActorSpawned` (角色生成)<br>`OnActorLoaded` (资源加载完成) | `isLocal` (是否为本地端)<br>`isServer` (是否为服务端) | `Respawn()` (角色重生)<br>`Quit()` (退出虚拟世界) |
| **角色行为<br>(Character)** | `onJump` (角色起跳)<br>`onFallingGround` (角色落地)<br>`onActionPlay` (动作播放) | `IsGrounded()` (是否在地面)<br>`IsFlying()` (是否在飞行)<br>`GetStateEnabled()` (某状态是否启用) | `Jump()` (执行跳跃)<br>`Immobilize()` (限制移动)<br>`SetOverrideAnimation()` (替换动画) |
| **网络与同步<br>(Network)** | `OnNetworkSettled` (网络同步完成)<br>`OnOwnershipTransferred` (主权转移)<br>`OnValueChange` (同步变量改变) | `HasOwnership()` (是否拥有主权)<br>`IsSpawned()` (是否已网络生成)<br>`isNetworkSettled` (网络是否就绪) | `NetSpawn()` (动态生成网络对象)<br>`RequestOwnership()` (请求主权)<br>`SetValue()` (修改同步变量) |
| **界面与输入<br>(UI & Input)** | `On3DClick` (点击3D物体)<br>`onTouchEvent` (屏幕触控)<br>`OnFocus` (UI获得焦点) | `isSimulator` (是否在模拟器)<br>`IsPhotographMode()` (是否在拍照模式) | `SetUIVisible()` (显示/隐藏UI)<br>`DownloadImage()` (下载网络图片)<br>`StartPhotograph()` (开启拍照模式) |
| **物理与环境<br>(Physics & Env)** | `OnCollisionEnter` (物理碰撞发生)<br>`OnActorTriggerEnter` (进入触发器)<br>`Awake`/`Update` (生命周期) | `disableActorCollider` (碰撞体是否禁用)<br>`allowPushByOtherActor` (是否允许被推) | `Change()` (改变场景环境)<br>`SetFootstepAudioClips()` (设置脚步声)<br>`SetData()` (读写持久化数据) |
| **交互与社交<br>(Interaction)**| `OnOwnershipRequest` (收到主权请求)<br>`onDuoInteractionWaiting` (等待双人交互)<br>`onMasterTranferred` (宠物主人转移) | `HasControllership()` (是否有控制权)<br>`isPet`/`isMaster` (宠物身份识别)<br>`allowActorChange` (是否允许切换形象) | `DisableInteraction()` (禁用交互)<br>`AcceptDuoInteraction()` (接受双人交互)<br>`Follow()` (关注创作者)|
| **商业化<br>(Commerce)** | `onPurchaseResult` (购买结果返回)<br>`onStarLightChanged` (星光货币变化) | `hasMore` (商品列表是否有下一页) | `Purchase()` (发起购买)<br>`OpenRechargePage()` (打开充值页) |

---

## 典型应用场景示例

通过 ECA 模式组合实现一个**“只有主权方才能点击开启的宝箱”**逻辑：

1. **Event (事件)**: 监听玩家点击宝箱的事件 (`On3DClick`)。
2. **Condition (条件)**: 检查当前玩家是否拥有宝箱的主权 (`HasOwnership()`)，并且当前没有处于无法交互的状态 (`GetStateEnabled()`)。
3. **Action (行为)**: 如果条件为真，执行打开宝箱的动作 (`PlayAnimation()` 播放开启特效，并 `SetValue()` 修改同步变量，将开启状态同步广播给其他人)。
