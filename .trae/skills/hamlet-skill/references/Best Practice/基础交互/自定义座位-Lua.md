# 座位系统（Lua）

本文提供座位系统的 Lua 实现。使用代码前，必须阅读 [基础交互](../../Manual/Ⅰ.%20核心系统%28Core%29/交互/基础交互.md)、[触发交互最佳实践](./触发交互-最佳实践.md)和[自定义座位最佳实践](./自定义座位-最佳实践.md)。

> **开始实现前必须阅读**：[自定义座位最佳实践中的常见错误](./%E8%87%AA%E5%AE%9A%E4%B9%89%E5%BA%A7%E4%BD%8D-%E6%9C%80%E4%BD%B3%E5%AE%9E%E8%B7%B5.md#常见错误)。该清单说明多人、移动座位、动画过渡和父级缩放中最容易遗漏的问题。

> **座椅模型硬约束**：一个座椅 NetworkObject 配置一个 `SeatAnchor` 和一个逻辑 `CurrentPlayer`；多座椅车辆必须为每个座椅创建独立 NetworkObject 和独立座椅脚本。

## 一、最小化写法（先完整落地，再叠加扩展）

命中“玩家坐下并跟随座位移动”需求时，先完整保留下面的交互、挂载、持续对齐和离座闭环。自定义动画、载具输入和状态同步只能加到标出的扩展点，不能另写同名回调覆盖主体。

完整闭环包含：

- Trigger、焦点和按钮入口；
- `resolveSeatTrans()` 座位锚点扩展点；
- 挂载、Hips 对齐、缩放和碰撞体辅助函数；
- `OnSeatEntered` / `OnSeatExited` 全端表现回调；
- `LateUpdate` 在座持续对齐。

```lua
---@var seatEnterTrans:UnityEngine.Transform  -- 默认座位锚点
---@var seatExitTrans:UnityEngine.Transform   -- 显式离座锚点，可为空
---@end

local interactionButton = nil
local localActorId = nil
local hasPassenger = false

-- 在座 Actor -> 对应座位锚点。
local seatedActors = {}
-- 以下缓存都按 Actor 保存，远端 Avatar 也必须完成同一套表现闭环。
local savedScale = {}
local savedPosition = {}
local savedRotation = {}
local savedColliderEnabled = {}

local function setButtonText(text)
  if interactionButton == nil then return end
  local label = interactionButton:GetComponentInChildren(
    typeof(CS.UnityEngine.UI.Text), true)
  if label ~= nil then
    label.text = text
  end
end

local function ensureInteractionButton()
  if interactionButton == nil then
    interactionButton = self:AddInteractorButton()
  end
  setButtonText(hasPassenger and "站起" or "坐下")
end

local function removeInteractionButton()
  if interactionButton ~= nil then
    self:RemoveInteractorButton(interactionButton)
    interactionButton = nil
  end
end

-- 扩展点：返回当前座椅唯一的 SeatAnchor。
function resolveSeatTrans()
  return seatEnterTrans
end

local function alignActorHipsToSeat(actor, target)
  target = target or resolveSeatTrans()
  if actor == nil or target == nil then return end

  local trans = actor.gameObject.transform
  trans:SetParent(target)
  trans.localPosition = CS.UnityEngine.Vector3.zero
  trans.localRotation = CS.UnityEngine.Quaternion.identity

  -- 先抵消锚点父链缩放，再读取 Hips 世界位置。
  local original = savedScale[actor] or CS.UnityEngine.Vector3.one
  local parentScale = target.lossyScale
  trans.localScale = CS.UnityEngine.Vector3(
    original.x / parentScale.x,
    original.y / parentScale.y,
    original.z / parentScale.z
  )

  local animator = actor.gameObject:GetComponentInChildren(
    typeof(CS.UnityEngine.Animator))
  if animator == nil then return end

  local hips = animator:GetBoneTransform(CS.UnityEngine.HumanBodyBones.Hips)
  if hips == nil then return end

  local hipsPosition = hips.position
  local actorPosition = trans.position
  trans.position = CS.UnityEngine.Vector3(
    actorPosition.x - (hipsPosition.x - actorPosition.x),
    actorPosition.y - (hipsPosition.y - actorPosition.y),
    actorPosition.z - (hipsPosition.z - actorPosition.z)
  )
end

local function setActorColliderEnabled(actor, enabled)
  if actor == nil or actor.gameObject == nil then return end
  local collider = actor.gameObject:GetComponent(typeof(CS.UnityEngine.Collider))
  if collider == nil then return end

  if not enabled then
    savedColliderEnabled[actor] = collider.enabled
    collider.enabled = false
  else
    local previous = savedColliderEnabled[actor]
    collider.enabled = previous == nil or previous
    savedColliderEnabled[actor] = nil
  end
end

local function placeActorAtStandPoint(actor)
  if actor == nil then return end

  local trans = actor.gameObject.transform
  trans:SetParent(nil)

  -- 必须在解除父子关系后恢复，避免 SetParent 再次烘焙 localScale。
  if savedScale[actor] ~= nil then
    trans.localScale = savedScale[actor]
    savedScale[actor] = nil
  end

  if seatExitTrans ~= nil then
    actor.position = seatExitTrans.position
    actor.rotation = seatExitTrans.rotation
  elseif savedPosition[actor] ~= nil then
    actor.position = savedPosition[actor]
    actor.rotation = savedRotation[actor]
  else
    local right = self.transform.right
    actor.position = CS.UnityEngine.Vector3(
      self.transform.position.x + right.x,
      self.transform.position.y,
      self.transform.position.z + right.z
    )
    actor.rotation = self.transform.rotation
  end

  savedPosition[actor] = nil
  savedRotation[actor] = nil
end

function OnActorTriggerEnter(actor)
  if actor == nil or not actor.isLocal then return end
  localActorId = actor.actorID
  self:EnableInteraction()
end

function OnActorTriggerExit(actor)
  if actor == nil or not actor.isLocal then return end

  -- 在座时保留 Actor ID 和交互通道，避免移动座位离开原 Trigger 后无法站起。
  if not hasPassenger then
    self:DisableInteraction()
    localActorId = nil
  end
end

function OnFocus(handType)
  ensureInteractionButton()
end

function OnLostFocus(handType)
  removeInteractionButton()
end

function OnInteractorButtonClick(index)
  if index ~= 1 or localActorId == nil then return end

  local actor = DouyinActorService.GetActorById(localActorId)
  if actor == nil then return end

  if hasPassenger then
    actor:StandUp(self.gameObject)
  else
    if actor:IsFlying() or resolveSeatTrans() == nil then return end
    actor:SitDown(self.gameObject)
  end
end

function OnSeatEntered(actor, handType)
  -- 不得用 not actor.isLocal 整体 return；远端 Avatar 也要在本端挂载。
  if actor == nil then return end

  local target = resolveSeatTrans()
  if target == nil then return end

  local trans = actor.gameObject.transform
  savedPosition[actor] = trans.position
  savedRotation[actor] = trans.rotation
  savedScale[actor] = trans.localScale

  alignActorHipsToSeat(actor, target)
  seatedActors[actor] = target
  setActorColliderEnabled(actor, false)

  if actor.isLocal then
    hasPassenger = true
    -- 上车后即使焦点发生切换，也要保留可站起的交互通道。
    self:EnableInteraction()
    ensureInteractionButton()
  end

  -- 扩展点：播放自定义坐姿动画、禁用飞行按钮、写入占用同步状态。
end

function OnSeatExited(actor)
  if actor == nil then return end

  -- 先停止 LateUpdate 对齐，否则离座后的 Actor 会在下一帧被拉回。
  seatedActors[actor] = nil
  placeActorAtStandPoint(actor)
  setActorColliderEnabled(actor, true)

  if actor.isLocal then
    hasPassenger = false
    setButtonText("坐下")
  end

  -- 扩展点：停止自定义动画、恢复飞行按钮、清空载具输入和占用状态。
end

-- 坐姿动画会持续改变 Hips 相对根节点的位置，必须在动画更新后重对齐。
function LateUpdate()
  for actor, target in pairs(seatedActors) do
    alignActorHipsToSeat(actor, target)
  end
end
```

要点：

- `OnSeatEntered` / `OnSeatExited` 的表现主体对任意非 nil Actor 执行，只有按钮和 `hasPassenger` 使用 `actor.isLocal` 门控。
- `seatedActors` 保存当前座椅的 `SeatAnchor`。`LateUpdate` 使用保存的引用，避免运动平台中途改变对齐目标。
- `savedScale` 必须在 `SetParent` 前记录，并在离座 `SetParent(nil)` 后恢复。
- `seatExitTrans` 为空时优先回到落座前的位置；缓存也不存在时才使用座位右侧偏移。

## 二、扩展写法

### 2.1 自定义坐姿动画

不要重新声明座位回调。只在最小化写法标出的两个扩展点插入：

```lua
-- OnSeatEntered 末尾：
if CustomSittingAnimation ~= nil then
  actor:PlayAnimation(CustomSittingAnimation)
end

-- OnSeatExited 末尾：
if CustomSittingAnimation ~= nil then
  actor:StopAnimation()
end
```

### 2.2 多座椅车辆

多座椅车辆不能让一个 NetworkObject 承载两个逻辑座位并让两个玩家分别调用同一个 `SitDown`。正确拓扑是载具根对象和多个独立座椅对象：

```text
VehicleRoot NetworkObject
├── DriverSeat NetworkObject + DriverSeat.lua
└── GunnerSeat NetworkObject + GunnerSeat.lua
```

每个座椅对象独立负责 Trigger、按钮、座椅回调和平台座位生命周期；业务占用状态仅在确有远端展示、晚进房恢复或统计需求时按需增加：

```lua
-- DriverSeat.lua
actor:SitDown(self.gameObject, true)

-- GunnerSeat.lua
actor:SitDown(self.gameObject, true)
```

两个 `self.gameObject` 必须是不同的座椅 NetworkObject。载具根脚本只负责物理、主权和输入桥接；座椅脚本在 `OnSeatEntered` / `OnSeatExited` 中通知根脚本。若同一个 Actor 从炮手座切到驾驶座，才使用 `switchSeat=true`；目标座椅被其他 Actor 占用时平台会拒绝请求。

### 2.3 SharedMode 载具驾驶控制权

驾驶座的落座和载具物理控制是两条独立链路：

```text
点击驾驶座按钮
  → actor:SitDown(driverSeat.gameObject, true)
  → OnSeatEntered 确认落座
  → 延迟 RequestControllership(载具根对象)
  → 成功后 HasOwnership + HasControllership 均为 true
  → 解除 Rigidbody.isKinematic，消费驾驶输入
  → OnSeatExited 清零输入并 ReleaseControllership()
```

规则：

1. 不要在点击驾驶座按钮前等待载具根对象的 `RequestOwnership` 回调，否则非主权玩家可能一直无法落座。
2. `RequestControllership` 应在 `OnSeatEntered` 后调用，避免和座椅框架的控制权切换同帧竞争。
3. 物理更新必须同时检查 `HasOwnership()` 和 `HasControllership()`；只满足其中一个时保持 Kinematic，不写入速度和旋转。
4. `RequestControllership` 失败时不能假设已经获得控制权；等待新的确认或结束本次控制流程。
5. 驾驶员离座时必须清零本地输入并调用 `ReleaseControllership()`，否则下一名玩家可能被旧控制者阻塞。

### 2.4 可选：摇杆拖动自动站起

仅在需求明确时订阅主移动摇杆。按照当前 API，获取摇杆需要同时传入 `HandType` 和 `UIType`：

```lua
local moveJoystick = nil

function Start()
  moveJoystick = CS.DouyinUIService.GetJoyStickControl(
    CS.HandType.Right, CS.UIType.MoveJoyStick)
  if moveJoystick ~= nil then
    moveJoystick:OnUIDrag(OnUIDragMainMoveUI)
  end
end

function OnDisable()
  if moveJoystick ~= nil then
    moveJoystick:OffUIDrag(OnUIDragMainMoveUI)
    moveJoystick = nil
  end
end

function OnUIDragMainMoveUI(pointer)
  if not hasPassenger or localActorId == nil then return end

  local actor = DouyinActorService.GetActorById(localActorId)
  if actor == nil then return end
  actor:StandUp(self.gameObject)
end
```

如果当前 SDK 版本没有提供 `OffUIDrag`，不要启用该扩展，改用该版本支持成对注册 / 注销的输入接口。

### 2.5 可选：同步占用状态

平台座椅的 `CurrentPlayer` 已经负责防止同一座椅被重复占用。只有明确需要远端占用可见、晚进房恢复或业务统计时才增加同步变量。同步变量只表达业务占用，不替代平台座位回调：

```lua
---@varSync occupiedBy:int = 0 -- 0 表示空闲
---@end

function OnNetSpawned()
  occupiedBy:OnValueChange(function(current, previous)
    -- 按需刷新“已占用”表现或按钮可用性。
  end)
end
```

在最小化写法的回调扩展点中，仅由座椅对象主权方写入；非主权端应通过项目统一的主权方代写入口请求，不能直接赋值：

```lua
-- OnSeatEntered 的 actor.isLocal 分支：
if self:HasOwnership() then
  occupiedBy:SetValue(actor.actorID)
end

-- OnSeatExited 的 actor.isLocal 分支：
if self:HasOwnership() and occupiedBy:GetValue() == actor.actorID then
  occupiedBy:SetValue(0)
end
```

多座椅车辆应为每个独立座椅对象分别同步占用者。

## 三、模块边界

座位对齐闭环的外部入口只有：

```lua
actor:SitDown(self.gameObject)
actor:StandUp(self.gameObject)
```

本模块不负责载具物理驱动、通用输入监听、主权扩展或晚进房状态重建。座位附带这些能力时，应在基础闭环的扩展点组合对应模块，不得替换 `OnSeatEntered` / `OnSeatExited` 主体。

降级与失败边界：

- `resolveSeatTrans() == nil`：按钮点击不发起 `SitDown`。
- `Animator == nil` 或 Hips 缺失：保留挂载和粗对齐，跳过 Hips 精修。
- Actor 根节点没有 Collider：碰撞体开关为空操作，不影响座位流程。
- `SeatAnchor` 父级非均匀缩放：按 `lossyScale` 反算只能减轻坐姿期形变；要完全消除剪切，应在资产层保证 `SeatAnchor` 世界缩放为 1。离座恢复缓存 scale 仍然有效。
- 晚进房玩家：平台不会补派其进房前发生的 `OnSeatEntered`；需要同步占用者和座位对象状态后主动重建表现。

## 四、Lua 常见错误

### 1. 扩展示例重复定义座位回调

Lua 中后定义的同名函数会覆盖前一个函数。自定义动画、禁飞或占用同步必须写入最小化回调的扩展点，不能再定义一份 `OnSeatEntered` / `OnSeatExited`。

### 2. `LateUpdate` 重新解析座位锚点

持续对齐必须使用 `seatedActors` 中保存的当前座位 `SeatAnchor`。每帧重新解析座位锚点可能导致移动座位上的 Actor 对齐不稳定。

### 3. 使用 `GetLocalActor()` 绕过 Trigger 缓存

按钮和摇杆回调使用 Trigger 缓存的 `actorID`，再通过 `GetActorById` 取回 Actor。不要混用长期 Actor 引用或无条件 `GetLocalActor()`，否则交互范围和目标 Actor 状态会脱节。
