# 玩家网络对象的Actor模式开发约束

## 1. 概念 (Concept)
Hamlet 世界支持两种对象关系模型，分别用于不同的玩法场景：
- **合养精灵 (Pet) 模式**：玩家“操控”合养精灵，一只精灵可归属两个玩家，同一时刻由其中一位主控，存在控制权切换。入口为 `DouyinPetService` / `DouyinPet`。
- **虚拟形象 (Avatar) 模式**：玩家与显示对象“一对一”，不存在共享形象与控制权切换。

## 2. 边界 (Boundary)
- **操作态 ≠ 网络主权**：在 Pet 模式下，判断主控方 / 观察者时，**不能使用网络对象的 `HasOwnership()` 或 `HasControllership()` 作为依据**。这两个 API 描述的是当前脚本所挂网络对象的主权 / 控制权，不等同于 Pet Actor 的主控态。精灵的主控 (`isMasterMode`)、观察 (`isObserverMode`) 等字段仅表示当前玩家和精灵的操控视觉关系。如果要判断某个网络对象归谁所有、谁能控制，仍然必须使用 `HasOwnership` / `IsOwner`。
- **兜底对象的复用限制**：在 Pet 模式观察者端兜底获取到的 `actor` 虽然可以用于主控/观察状态的判断（`isObserverMode == true`），但**不得**直接复用到网络对象产球、主权写入、拾取执行等需要"本端可操作 Actor"的底层路径。
- **控制权联动主权**：在 Pet 模式下，当玩家 A 和 B 切换精灵控制权时（例如 B 从观察者变成了主控方），网络对象 D 的控制权会自动转移到 B，同时 **D 的主权也会随之自动转移给 B**。
- **断线与主权/控制权的迁移**：
  - **断线转移**：主权拥有者意外断线后，主权会转移给房间内其他在线玩家，但**控制权状态保留**，不发生转移。
  - **重连恢复**：断线玩家重连成功后，系统会自动将主权**交还给该玩家**（前提是断线期间控制权未被其他人主动抢走）。

## 3. 机制与规范 (Mechanism & Specification)
- **交互与控制权切换标准流程**：合养精灵模式下，必须将“交互范围生命周期”和“Pet 主控状态生命周期”分开处理，遵循以下规则：
  1. **建立交互上下文**：仅在 `OnActorTriggerEnter(actor)` 或 `OnPlayerTriggerEnter(douyinPlayer)` 中校验本地玩家、Actor 有效性、`isBindMode` 和 `isMasterMode`，然后记录当前本地 Actor / 玩家并建立 `isInteractable` 等交互上下文。只有交互上下文建立后，才允许调用 `EnableInteraction()`。
  2. **清理交互上下文**：仅在对应的 `OnActorTriggerExit(actor)` 或 `OnPlayerTriggerExit(douyinPlayer)` 中清理当前本地 Actor / 玩家和 `isInteractable` 状态，并调用 `DisableInteraction()`。对象禁用、玩家离开或交互条件失效时，也必须执行同等清理。
  3. **处理主控变化**：`OnActorOperationChanged(actor)` 只用于同步已经存在的交互上下文，不得被当作进入范围事件。该回调可能在玩家进房初始化时执行，因此必须先确认 Actor 已绑定且当前仍处于有效交互上下文（例如 `isInteractable == true` 或已记录当前本地 Actor）。
  4. **状态恢复/清理**：在有效交互上下文内切回主控时，恢复此前已经存在的交互 UI、按钮、动作和组件状态；切换为观察者时，关闭、隐藏或重置这些状态。若当前没有有效交互上下文，主控状态变化不得创建交互按钮、不得调用 `EnableInteraction()`，也不得模拟一次 Trigger Enter。

## 4. 黄金法则与避坑指南 (Golden Rules & Pitfalls)
- **🚫 避坑：Avatar 模式专属 API 黑名单**
  在 Avatar 模式下，**严禁使用**任何 Pet 相关的语义。包括 `DouyinPetService`、`DouyinPet` 整个类，以及 Actor 上的 `onGetPetMessage`、`isBindMode`、`isMasterMode`、`isObserverMode`、`isPet`、`douyinPet` 属性，和 `OnActorOperationChanged` 回调。违反此规则会导致逻辑建立在不存在的前提上，引发严重 Bug。
- **💡 黄金法则：观察者端的兜底获取**
  在合养精灵模式下，观察者端调用 `DouyinActorService.GetLocalActor()` 可能会返回 `nil`。此时状态判断需要通过 `DouyinPlayerService:GetLocalPlayer():GetActor()` 进行兜底。
- **🚫 避坑：动态网络对象请求控制权的时序陷阱**
  在 Pet 模式下，客户端创建的动态网络对象，其控制权**并不默认归属创建者**，需要创建者主动请求。由于请求控制权是网络接口，必须在网络环境准备好之后调用，在 `OnNetSpawned` 中直接请求大概率会失败。通常建议在同步变量的 `OnValueChange` 回调中（确保网络通道已就绪），且加入短暂的延时（如 `setTimeout`），再调用 `RequestControllership()`。
- **💡 黄金法则：对象判空机制的开发提示**
  对于 `DouyinPlayer`、`DouyinPet`、`DouyinActor` 等底层对象，在 Lua 侧脚本中判空时，除了使用 `obj == nil` 外，还需要使用 `CS.System.Object.ReferenceEquals(obj, nil)` 进行底层判断。
