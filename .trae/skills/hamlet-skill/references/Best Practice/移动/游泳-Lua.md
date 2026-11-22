# 游泳 - Lua

> Lua 代码骨架。
>
> 使用前阅读 Manual 中的角色移动、飞行与游泳，以及角色控制开发约束。

---

## 一、游泳骨架

### 1.1 监听游泳开始 / 结束事件

```lua
local localActor = nil

local function OnSwimStartCallback()
  print("[swim] 玩家开始游泳")
  -- 扩展点：播放水花特效 / 切换 UI / 通知其它系统
end

local function OnSwimStopCallback()
  print("[swim] 玩家停止游泳")
end

function OnActorSpawned(actor)
  if actor == nil or not actor.isLocal then return end
  localActor = actor
  actor.onSwimStart:AddListener(OnSwimStartCallback)
  actor.onSwimStop:AddListener(OnSwimStopCallback)
end

function OnDestroy()
  if localActor ~= nil then
    localActor.onSwimStart:RemoveListener(OnSwimStartCallback)
    localActor.onSwimStop:RemoveListener(OnSwimStopCallback)
  end
end
```

### 1.2 游泳期间禁用拾取按钮

```lua
local localActor = nil

function OnActorTriggerEnter(actor)
  if actor == nil or not actor.isLocal then return end
  localActor = actor
  self:EnableInteraction()
end

function OnFocus(handType)
  -- 游泳期间不显示拾取按钮
  if localActor ~= nil and localActor:IsSwimming() then
    return   -- 直接不建按钮
  end

  interactionButton = self:AddInteractorButton()
  setButtonText("拾取")
end
```


### 1.3 游泳期间禁飞

```lua
function OnActorSpawned(actor)
  if actor == nil or not actor.isLocal then return end
  localActor = actor
  actor.onSwimStart:AddListener(function()
    actor:DisableFly(true)  -- 隐藏飞行按钮
  end)
  actor.onSwimStop:AddListener(function()
    if actor:CanFly() then
      actor:EnableFly()
    end
  end)
end
```

### 1.4 检查是否可以进入水体

```lua
function OnActorTriggerEnter(actor)
  if actor == nil or not actor.isLocal then return end
  if not actor:CanSwim() then
    print("[swim] 当前角色不允许游泳")
    -- 扩展点：弹提示 / 阻止进入 / 传送出水域
    return
  end
end
```
