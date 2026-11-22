# 飞行 - Lua

> Lua 代码骨架。
>
> 使用前阅读 Manual 中的角色移动、飞行与游泳，以及角色控制开发约束。

---

## 一、飞行骨架

### 1.1 单点飞行开关

```lua
local localActor = nil

function OnActorTriggerEnter(actor)
  if actor == nil or not actor.isLocal then return end
  localActor = actor
  actor:EnableFly()  -- 打开飞行按钮
end

function OnActorTriggerExit(actor)
  if actor == nil or not actor.isLocal then return end
  actor:DisableFly(true)  -- 隐藏飞行按钮
  if actor:IsFlying() then
    actor:StopFly()       -- 如果玩家离开时正在飞行，强制落地
  end
  localActor = nil
end

function OnDestroy()
  if localActor ~= nil then
    localActor:DisableFly(true)
    if localActor:IsFlying() then localActor:StopFly() end
  end
end
```

### 1.2 立即起飞按钮

```lua
local localActor = nil

function OnInteractorButtonClick(index)
  if localActor == nil then return end
  if not localActor:CanFly() then
    print("[fly] 当前不允许飞行")
    return
  end
  if localActor:IsFlying() then
    localActor:StopFly()
  else
    localActor:StartFly(1.5)  -- 离地 1.5m
  end
end
```

### 1.3 悬浮模式

```lua
function OnInteractorButtonClick(index)
  if localActor == nil then return end
  if not localActor:CanFly() then return end
  localActor:SetFlyMode(0)   -- 0 = 悬浮
  localActor:StartFly(1.5)
end
```

### 1.4 监听飞行开始 / 结束事件

```lua
local localActor = nil

local function OnFlyStartCallback()
  print("[fly] 玩家开始飞行")
  -- 扩展点：切换 UI / 播放特效 / 通知其它系统
end

local function OnFlyStopCallback()
  print("[fly] 玩家停止飞行")
end

function OnActorSpawned(actor)
  if actor == nil or not actor.isLocal then return end
  localActor = actor
  actor.onFlyStart:AddListener(OnFlyStartCallback)
  actor.onFlyStop:AddListener(OnFlyStopCallback)
end

function OnDestroy()
  if localActor ~= nil then
    localActor.onFlyStart:RemoveListener(OnFlyStartCallback)
    localActor.onFlyStop:RemoveListener(OnFlyStopCallback)
  end
end
```

### 1.5 飞行时参数调整

```lua
-- 提速：修改水平 / 垂直飞行速度
localActor.flySpeed = 8.0            -- 默认约 4
localActor.flyVerticalSpeed = 6.0

-- 限制飞行高度范围
localActor.flyMinHeight = 0.5
localActor.flyMaxHeight = 30.0
```
