# 触发交互 - Lua

> Lua 代码骨架。

> **开始实现前必须阅读**：[触发交互最佳实践中的常见错误](./触发交互-最佳实践.md)。该清单说明本地 Actor 过滤、C 区交互用途、Exit 边界和平台交互开关中最容易遗漏的问题。
>

## 一、最小生命周期骨架

需要在区域 Enter / Exit 中维护本地玩家或区域上下文时，先保留以下骨架，再在标记的扩展点添加区域逻辑。

```lua
local localActor = nil

function OnActorTriggerEnter(actor)
  if actor == nil or not actor.isLocal then
    return
  end

  localActor = actor
  -- Enter 扩展点：区域提示、陷阱、传送、C 区交互或其它直接绑定 Enter 的逻辑
end

function OnActorTriggerExit(actor)
  if actor == nil or not actor.isLocal then
    return
  end

  -- Exit 扩展点：关闭区域提示、撤销高亮、清理当前区域上下文
  -- 持续交互中的 localActor 是否清空，按对应模块规则决定。
  localActor = nil
end
```

## 二、按需扩展

### 2.1 C 区交互入口

仅当区域进入后需要玩家获得焦点并操作 C 区按钮时，叠加 `EnableInteraction()` / `DisableInteraction()`。按钮创建、点击和具体业务继续使用通用交互、拾取或座位模块。

```lua
function OnActorTriggerEnter(actor)
  if actor == nil or not actor.isLocal then
    return
  end

  localActor = actor
  self:EnableInteraction()
end

function OnActorTriggerExit(actor)
  if actor == nil or not actor.isLocal then
    return
  end

  self:DisableInteraction()
  localActor = nil
end
```

### 2.2 区域状态、提示或高亮

仅在业务确实需要时声明状态变量。变量服务于当前区域上下文，离开区域时一并收口。

```lua
local localActor = nil
local currentInside = false
local enterTime = 0
local currentTarget = nil

function OnActorTriggerEnter(actor)
  if actor == nil or not actor.isLocal then
    return
  end

  localActor = actor
  currentInside = true
  enterTime = CS.UnityEngine.Time.time
  currentTarget = self.gameObject
  -- 扩展点：显示提示或开启高亮
end

function OnActorTriggerExit(actor)
  if actor == nil or not actor.isLocal then
    return
  end

  currentInside = false
  currentTarget = nil
  localActor = nil
  -- 扩展点：关闭提示或撤销高亮
end
```

### 2.3 进入或离开区域直接触发玩法

陷阱、传送或伤害区等玩法可直接使用 Enter / Exit 作为业务入口，不要求调用 `EnableInteraction()`。区域效果写在标记的函数中，持续逻辑仍由对应玩法模块负责。

```lua
local localActor = nil

local function applyEnterEffect(actor)
  -- 扩展点：执行与进入当前区域直接绑定的陷阱、传送或区域效果
end

local function clearExitEffect(actor)
  -- 扩展点：清理与离开当前区域直接绑定的提示或区域效果
end

function OnActorTriggerEnter(actor)
  if actor == nil or not actor.isLocal then
    return
  end

  localActor = actor
  applyEnterEffect(actor)
end

function OnActorTriggerExit(actor)
  if actor == nil or not actor.isLocal then
    return
  end

  clearExitEffect(actor)
  localActor = nil
end
```

## 三、模块边界

- C 区按钮：使用通用交互、拾取或座位模块的 `OnFocus`、`OnLostFocus` 和点击入口。
- 拾取：使用 `Pickup` / `Drop` 与 `OnPickup` / `OnDrop`，不要在 Enter 中直接挂手。
- 座位：使用 `SitDown` / `StandUp` 与 `OnSeatEntered` / `OnSeatExited`，在座时是否保留交互通道遵循座位规则。
- 持续物理、输入监听、动画和网络同步：由对应玩法模块在其生命周期中处理，不在 Trigger 回调中代替实现。
