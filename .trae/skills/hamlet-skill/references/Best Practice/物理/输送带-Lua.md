# 输送带（Lua）最佳实践

> 本文仅提供 Lua 侧输送带的实现骨架。场景物理边界请参考 [刚体与运动模型](../../Manual/%E2%85%A0.%20核心系统%28Core%29/物理/刚体与运动模型.md)、[碰撞体与触发器](../../Manual/%E2%85%A0.%20核心系统%28Core%29/物理/碰撞体与触发器.md) 和 [触发器生命周期约束](../../Manual/Ⅲ.%20逻辑与脚本%28Logic%26Scripting%29/编码约束与开发规范/触发器生命周期约束.md)。

---

## 0. 前置配置

输送带使用两个独立的 Trigger 区域，分别驱动交互与接触驱动逻辑：

| Trigger | isTrigger | 脚本 | 用途 |
| --- | --- | --- | --- |
| Interaction Trigger | `true` | `ConveyorBelt.lua` | 玩家靠近后显示启停按钮 |
| Contact Trigger | `true` | `BeltDrive.lua` | 玩家/刚体接触带面后驱动位移 |

- 两个 Trigger 都是 `isTrigger=true`，**不共用同一个 Collider**。
- Interaction Trigger 与 `ConveyorBelt.lua` 挂在同一个 GameObject 上，用于 Hamlet 的 `OnActorTriggerEnter/Exit`。
- Contact Trigger 与 `BeltDrive.lua` 挂在同一个 GameObject 上（例如子节点 `DriveZone`）。父节点脚本不会收到子节点 Collider 的 Hamlet Actor 回调。
- Contact Trigger 的尺寸应**沿输送方向完整覆盖前后两端滚筒**（前后各外扩至少一个滚筒半径 + 一点余量），避免玩家/刚体走到滚筒上方时脱离 Trigger 而失去驱动、卡在滚筒顶部推不动。
- 带面（Belt_Surface）本身可以再挂一个 `isTrigger=false` 的实体 BoxCollider 提供 Actor / Cube 的站立支撑；`BeltDrive.lua` 不依赖它。

---

## 1. ConveyorBelt.lua

### 1.1 字段声明

```lua
---@var beltSurface:UnityEngine.Transform
---@var rollerFront:UnityEngine.Transform
---@var rollerBack:UnityEngine.Transform
---@var beltRenderer:UnityEngine.Renderer
---@var moveSpeed:float = 1.5
---@var rollerRadius:float = 0.175
---@varSync isRunning:bool = true
---@end
```

### 1.2 状态变量

```lua
local DEFAULT_LAYER = 0
local uvOffset = 0
local localActorId = nil
local interactionButton = nil
local ownershipPending = false
```

### 1.3 Start

```lua
local function setLayerRecursive(trans, layer)
    if trans == nil then return end
    trans.gameObject:SetLayer(layer)
    for i = 0, trans.childCount - 1 do
        setLayerRecursive(trans:GetChild(i), layer)
    end
end

function Start()
    setLayerRecursive(self.transform, DEFAULT_LAYER)
end
```

### 1.4 OnNetSpawned

```lua
function OnNetSpawned()
    isRunning:OnValueChange(function(cur, prev)
        refreshButtonText()
    end)
end
```

### 1.5 视觉 FixedUpdate（滚筒旋转 + UV 滚动）

```lua
function FixedUpdate()
    if isRunning == nil or not isRunning:GetValue() then return end

    local dt = CS.UnityEngine.Time.fixedDeltaTime
    local angleDeg = (moveSpeed * dt / math.max(rollerRadius, 0.001))
        * (180 / math.pi)

    if rollerFront ~= nil then
        rollerFront:Rotate(
            CS.UnityEngine.Vector3(0, angleDeg, 0),
            CS.UnityEngine.Space.Self)
    end
    if rollerBack ~= nil then
        rollerBack:Rotate(
            CS.UnityEngine.Vector3(0, angleDeg, 0),
            CS.UnityEngine.Space.Self)
    end

    if beltRenderer ~= nil then
        uvOffset = uvOffset + moveSpeed * dt
        if uvOffset >= 1 then uvOffset = uvOffset - 1 end
        beltRenderer.material:SetTextureOffset(
            "_BaseMap",
            CS.UnityEngine.Vector2(0, -uvOffset))
    end
end
```

### 1.6 Interaction Trigger

```lua
function OnActorTriggerEnter(actor)
    if actor == nil or not actor.isLocal then return end
    localActorId = actor.actorID
    self:EnableInteraction()
end

function OnActorTriggerExit(actor)
    if actor == nil or not actor.isLocal then return end
    self:DisableInteraction()
    localActorId = nil
end
```

### 1.7 交互按钮

```lua
local function refreshButtonText()
    if interactionButton == nil then return end
    local label = interactionButton:GetComponentInChildren(
        typeof(CS.UnityEngine.UI.Text), true)
    if label == nil then return end

    local running = isRunning ~= nil and isRunning:GetValue()
    label.text = running and "关闭输送带" or "启动输送带"
end

function OnFocus(handType)
    interactionButton = self:AddInteractorButton()
    refreshButtonText()
end

function OnLostFocus(handType)
    self:RemoveAllInteractorButtons()
    interactionButton = nil
end
```

### 1.8 启停状态

```lua
local function ensureOwnership(action)
    if action == nil then return end
    if not DouyinNetService.isNetworkSettled then return end

    if self:HasOwnership() then
        action()
        return
    end

    if ownershipPending then return end
    ownershipPending = true
    self:RequestOwnership(function(ok)
        ownershipPending = false
        if ok then action() end
    end)
end

function OnInteractorButtonClick(index)
    if index ~= 1 or localActorId == nil then return end
    local actor = DouyinActorService.GetActorById(localActorId)
    if actor == nil then return end
    actor:Interact(self.gameObject)
end

function OnInteract(actor)
    if actor == nil then return end
    ensureOwnership(function()
        isRunning:SetValue(not isRunning:GetValue())
    end)
end
```

### 1.9 OnNetDestroy

```lua
function OnNetDestroy()
    if interactionButton ~= nil then
        self:RemoveAllInteractorButtons()
        interactionButton = nil
    end
    localActorId = nil
end
```

---

## 2. BeltDrive.lua（双通道驱动）

带面上的接触对象分两类，用两条独立通道处理：

- **通道 A**：本地 `DouyinActor` — 通过 Hamlet 的 `OnActorTriggerEnter/Exit` 收集，`FixedUpdate` 里 `actor.position = actor.position + delta`。
- **通道 B**：非 Actor 的普通 `Rigidbody` — 通过 Unity 原生 `OnTriggerEnter/Exit` + `attachedRigidbody` 收集，`FixedUpdate` 里 `rb:MovePosition(rb.position + delta)`。

Actor 的 Rigidbody 会同时触发两条通道，用 `actorRbIds` 集合把它从通道 B 里排除，避免双重驱动。

### 2.1 字段声明

```lua
---@var conveyorScript:DouyinScript
---@var beltForwardRef:UnityEngine.Transform
---@var moveSpeed:float = 1.5
---@end
```

### 2.2 状态变量

```lua
local activeBodies = {}      -- [instanceId] = UnityEngine.Rigidbody
local activeBodyCount = 0

local activeActors = {}      -- [actorID] = DouyinActor
local activeActorCount = 0

local actorRbIds = {}        -- [instanceId] = true，用于通道 B 排除 Actor Rigidbody
```

### 2.3 启停读取

```lua
local function isRunning()
    if conveyorScript == nil then return false end
    local s = conveyorScript.script
    if s == nil or s.isRunning == nil then return false end
    return s.isRunning:GetValue()
end
```

### 2.4 通道 A：本地 Actor

```lua
function OnActorTriggerEnter(actor)
    if actor == nil or not actor.isLocal then return end
    if activeActors[actor.actorID] ~= nil then return end

    activeActors[actor.actorID] = actor
    activeActorCount = activeActorCount + 1

    if actor.gameObject ~= nil then
        local rb = actor.gameObject:GetComponent(typeof(CS.UnityEngine.Rigidbody))
        if rb ~= nil then
            actorRbIds[rb:GetInstanceID()] = true
        end
    end
end

function OnActorTriggerExit(actor)
    if actor == nil or not actor.isLocal then return end
    if activeActors[actor.actorID] == nil then return end

    activeActors[actor.actorID] = nil
    activeActorCount = activeActorCount - 1

    if actor.gameObject ~= nil then
        local rb = actor.gameObject:GetComponent(typeof(CS.UnityEngine.Rigidbody))
        if rb ~= nil then
            actorRbIds[rb:GetInstanceID()] = nil
        end
    end
end
```

### 2.5 通道 B：非 Actor Rigidbody

```lua
local function normalizeToBody(other)
    if other == nil then return nil end
    return other.attachedRigidbody
end

function OnTriggerEnter(other)
    local rb = normalizeToBody(other)
    if rb == nil then return end
    local key = rb:GetInstanceID()
    if actorRbIds[key] then return end
    if activeBodies[key] == nil then
        activeBodies[key] = rb
        activeBodyCount = activeBodyCount + 1
    end
end

function OnTriggerExit(other)
    local rb = normalizeToBody(other)
    if rb == nil then return end
    local key = rb:GetInstanceID()
    if activeBodies[key] ~= nil then
        activeBodies[key] = nil
        activeBodyCount = activeBodyCount - 1
    end
end
```

`other.attachedRigidbody` 会顺着子 Collider 找到实体 Rigidbody，复合模型（多个子 Collider 挂在同一 Rigidbody 下）天然去重。静态无 Rigidbody 的 Collider 返回 `nil`，直接跳过。

### 2.6 FixedUpdate（双通道驱动）

```lua
function FixedUpdate()
    if not isRunning() then return end
    if beltForwardRef == nil then return end
    if activeBodyCount <= 0 and activeActorCount <= 0 then return end

    local dt = CS.UnityEngine.Time.fixedDeltaTime
    local fwd = beltForwardRef.forward
    local delta = CS.UnityEngine.Vector3(
        fwd.x * moveSpeed * dt,
        0,
        fwd.z * moveSpeed * dt)

    for key, rb in pairs(activeBodies) do
        if rb == nil then
            activeBodies[key] = nil
            activeBodyCount = activeBodyCount - 1
        else
            rb:MovePosition(rb.position + delta)
        end
    end

    for actorId, actor in pairs(activeActors) do
        if actor == nil then
            activeActors[actorId] = nil
            activeActorCount = activeActorCount - 1
        else
            local p = actor.position
            actor.position = CS.UnityEngine.Vector3(
                p.x + delta.x, p.y, p.z + delta.z)
        end
    end
end
```

关键点：
- **通道 A 用 `actor.position` 叠加**：`DouyinActor` 有自己的运动控制器，`Rigidbody.MovePosition` 对它无效。
- **通道 B 用 `MovePosition`**：普通刚体（如 `ConveyorCube`）走 Unity 物理引擎的运动学位移，保留碰撞检测。
- **`delta.y = 0`**：只叠 XZ；Y 方向见后文" Y 方向策略"单独处理。
- **循环内 `nil` 检查**：Rigidbody / Actor 被销毁时清理集合。

### 2.7 OnDisable / OnDestroy

```lua
local function clearAll()
    activeBodies = {}
    activeBodyCount = 0
    activeActors = {}
    activeActorCount = 0
    actorRbIds = {}
end

function OnDisable()
    clearAll()
end

function OnDestroy()
    clearAll()
end
```

---

## 3. Y 方向策略

- 每帧的位移增量 `delta` 强制置 `y = 0`：`Vector3(fwd.x * v * dt, 0, fwd.z * v * dt)`。
- Actor 的 Y 完全由 Actor 自身控制器维护（重力、跳跃、着地判定）。
  - 缓斜带面（坡度 < `DouyinActor.minSlopeAngleLimit`）无需手动写 Y：Actor 会自动贴地、顺 XZ 方向沿斜面移动。
  - 陡坡（超过 `minSlopeAngleLimit`）会打滑：需另起 "射线贴地 + 沿切向推" 方案。
  - 垂直电梯：只能走 `actor:Immobilize(true)` + 完全接管 `actor.position`，玩家在电梯上无法自由走动，不在本骨架范围内。
- 非 Actor Rigidbody 同样只叠 XZ：`rb:MovePosition(rb.position + delta)` 的 `delta.y` 为 0，Y 归 Unity 物理引擎（重力 + 碰撞）。

---

## 4. 约束

- Interaction Trigger 与 Contact Trigger 使用**独立 Collider 和独立脚本**，都是 `isTrigger=true`。
- Interaction Trigger 使用 `OnActorTriggerEnter/Exit`；Contact Trigger 同时使用 `OnActorTriggerEnter/Exit`（通道 A）和 Unity 原生 `OnTriggerEnter/Exit`（通道 B）。
- `OnActorTriggerEnter/Exit` 与 `OnTriggerEnter/Exit` 首先过滤 `nil` 与 `actor.isLocal` / `attachedRigidbody == nil`。
- **本地 Actor 用 `actor.position` 叠加，禁止用 `Rigidbody.MovePosition`**（对 DouyinActor 无效）。
- **非 Actor Rigidbody 用 `rb:MovePosition(rb.position + delta)`**，不要写 `rb.velocity`（会与刚体自身重力/输入打架）。
- 通道 B 必须用 `attachedRigidbody` 归一化到实体，避免复合子 Collider 重复入表。
- `actorRbIds` 排除 Actor 的 Rigidbody，避免同一 Actor 被双通道各推一次。
- `delta.y = 0`：只叠 XZ，Y 交给 Actor 控制器 / Unity 物理。
- `isRunning` 只由主权方写入；驱动逻辑（`FixedUpdate`）不需要主权。
- 不修改远端 Actor（`actor.isLocal` 已过滤）。
- 不移动整棵输送带模型；带面视觉滚动通过 UV `SetTextureOffset` 实现。
- `OnDisable` / `OnDestroy` 时清空三张表和两个计数。

---

## 5. 常见坑 FAQ

| 现象 | 违反 / 误用 | 修复 |
| --- | --- | --- |
| Actor 站上去纹丝不动 | 对 Actor 的 Rigidbody 用了 `MovePosition` | DouyinActor 有自己的运动控制器，Rigidbody 只做碰撞外壳；改用 `actor.position` 叠加（通道 A） |
| Actor 被拽下去 / 跳跃被打断 | 每帧写回 `actor.position.y`（含 `delta.y`） | 只叠 XZ，保留 `p.y`：`Vector3(p.x + dx, p.y, p.z + dz)` |
| 复合模型每接触一次多计几份 | 未用 `attachedRigidbody` 归一化 | `local rb = other.attachedRigidbody; if rb == nil then return end` |
| 同一 Actor 被双通道各推一次 | 未把 Actor rb id 存入 `actorRbIds` | 通道 A Enter 存入 `actorRbIds[rb:GetInstanceID()]`，通道 B Enter 命中即跳过 |
| 关闭输送带后 Actor 仍在滑 | 用了 `MoveContinuously` 却没在 Exit/关闭时 `StopMove` | 本骨架不使用 `MoveContinuously`（会屏蔽玩家摇杆输入）；`actor.position` 叠加天然停 |
| 远端观察者的 Cube 位置飘 | 每端各自本地驱动导致同一 Rigidbody 双端物理各跑一遍 | 主权方 `NetSpawn` 出的对象由 SDK 网络同步 Rigidbody；驱动只在本地跑，同步兜底表现层 |
| 玩家跳起被吸回带面 | `delta.y` 未清 0 或错把 Actor 走了 `MovePosition` 分支 | 严格保持 `delta.y = 0`，通道 A 用 `actor.position`、通道 B 用 `MovePosition` |
| Contact Trigger 反复 Enter/Exit 抖动 | `DriveZone` Trigger 上下厚度过贴带面边缘 | 略放大 Trigger 上下厚度（如 y=0.3），避免玩家轻微上下位移触发抖动 |
| 关闭输送带后 `activeBodies` 没清 | Exit 时未对称移除 | `OnTriggerExit` / `OnActorTriggerExit` 中删 key + 减 count；`OnDisable/OnDestroy` 兜底清空 |
| 运行时 Destroy Rigidbody 报错 | 循环里未处理 `nil` 引用 | `if rb == nil then activeBodies[key] = nil; activeBodyCount = activeBodyCount - 1; else ... end` |
