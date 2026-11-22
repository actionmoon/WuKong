# 输入监听 - Lua

> Lua 代码骨架。
>
> 使用前阅读 Manual 中的[输入事件与监听机制](../../Manual/%E2%85%A0.%20核心系统%28Core%29/玩家网络对象/输入控制/输入事件与监听机制.md)。多输入源汇流规则见[多输入源协同处理](../../Manual/%E2%85%A0.%20核心系统%28Core%29/玩家网络对象/输入控制/多输入源协同处理.md)。

## 一、输入监听骨架（必须逐字复制）

如果左摇杆用于无人机、机械炮塔、加特林、遥控车、云台或其它控制状态，开始编写前必须同时阅读[遥控状态与角色锁定](../../Manual/%E2%85%A0.%20核心系统%28Core%29/玩家网络对象/输入控制/遥控状态与角色锁定.md)，确认角色移动与被控对象之间的输入分工，以及 `Immobilize(true/false)` 和 `OnDestroy` 兜底要求。

以下代码块只能在标注的扩展点添加业务逻辑，不允许改变结构、参数顺序、guard 顺序。

### 1.1 状态变量（脚本顶部）

```lua
local moveVec = CS.UnityEngine.Vector2.zero
local onMoveInputStart = nil
local onMoveInputPerform = nil
local onMoveInputCancel = nil
```

### 1.2 注册输入监听（`Start`）

```lua
function Start()
  -- onMoveInputStart 无参：不带方向，只标记"开始输入"。方向统一由 Perform 提供
  onMoveInputStart = function()
    -- 可选：起手时先归零，避免残留；也可留空
  end
  -- onMoveInputPerform 带一个 Vector2 参数（方向 + 强度），每帧派发
  onMoveInputPerform = function(vec)
    moveVec = vec
  end
  onMoveInputCancel = function()
    moveVec = CS.UnityEngine.Vector2.zero
  end

  CS.DouyinInputService.onMoveInputStart:AddListener(onMoveInputStart)
  CS.DouyinInputService.onMoveInputPerform:AddListener(onMoveInputPerform)
  CS.DouyinInputService.onMoveInputCancel:AddListener(onMoveInputCancel)
end
```

### 1.3 销毁与解绑（`OnDestroy`）

```lua
function OnDestroy()
  if onMoveInputStart ~= nil then
    CS.DouyinInputService.onMoveInputStart:RemoveListener(onMoveInputStart)
  end
  if onMoveInputPerform ~= nil then
    CS.DouyinInputService.onMoveInputPerform:RemoveListener(onMoveInputPerform)
  end
  if onMoveInputCancel ~= nil then
    CS.DouyinInputService.onMoveInputCancel:RemoveListener(onMoveInputCancel)
  end
end
```

---

## 二、扩展骨架

### 2.1 视角 / Look 输入（拖屏 / 右摇杆）

```lua
local lookVec = CS.UnityEngine.Vector2.zero
local onLookInputStart, onLookInputPerform, onLookInputCancel

function Start()
  onLookInputStart = function() end                     -- 无参
  onLookInputPerform = function(vec) lookVec = vec end   -- 带 Vector2
  onLookInputCancel = function() lookVec = CS.UnityEngine.Vector2.zero end

  CS.DouyinInputService.onLookInputStart:AddListener(onLookInputStart)
  CS.DouyinInputService.onLookInputPerform:AddListener(onLookInputPerform)
  CS.DouyinInputService.onLookInputCancel:AddListener(onLookInputCancel)
end

function OnDestroy()
  if onLookInputStart ~= nil then CS.DouyinInputService.onLookInputStart:RemoveListener(onLookInputStart) end
  if onLookInputPerform ~= nil then CS.DouyinInputService.onLookInputPerform:RemoveListener(onLookInputPerform) end
  if onLookInputCancel ~= nil then CS.DouyinInputService.onLookInputCancel:RemoveListener(onLookInputCancel) end
end
```

### 2.2 跳跃 / 长按蓄力

```lua
local jumpHeldTime = 0
local isJumpHeld = false
local onJumpInputStart, onJumpInputPerform, onJumpInputCancel

function Start()
  onJumpInputStart = function()
    isJumpHeld = true
    jumpHeldTime = 0
  end
  onJumpInputPerform = function()
    if isJumpHeld then
      jumpHeldTime = jumpHeldTime + CS.UnityEngine.Time.deltaTime
    end
  end
  onJumpInputCancel = function()
    if isJumpHeld then
      -- 扩展点：按 jumpHeldTime 决定短跳 / 蓄力跳
      isJumpHeld = false
      jumpHeldTime = 0
    end
  end

  CS.DouyinInputService.onJumpInputStart:AddListener(onJumpInputStart)
  CS.DouyinInputService.onJumpInputPerform:AddListener(onJumpInputPerform)
  CS.DouyinInputService.onJumpInputCancel:AddListener(onJumpInputCancel)
end

function OnDestroy()
  if onJumpInputStart ~= nil then CS.DouyinInputService.onJumpInputStart:RemoveListener(onJumpInputStart) end
  if onJumpInputPerform ~= nil then CS.DouyinInputService.onJumpInputPerform:RemoveListener(onJumpInputPerform) end
  if onJumpInputCancel ~= nil then CS.DouyinInputService.onJumpInputCancel:RemoveListener(onJumpInputCancel) end
end
```

### 2.3 缩放手势 / 触摸事件

```lua
local onZoomInput = nil
local onTouchEvent = nil

function Start()
  onZoomInput = function(zoom)
    -- zoom 是 float，双指缩放系数
  end
  onTouchEvent = function(pos)
    -- pos 直接就是 Vector2 屏幕坐标；没有 timestamp / clickType 字段
  end

  CS.DouyinInputService.onZoomInput:AddListener(onZoomInput)
  CS.DouyinInputService.onTouchEvent:AddListener(onTouchEvent)
end

function OnDestroy()
  if onZoomInput ~= nil then CS.DouyinInputService.onZoomInput:RemoveListener(onZoomInput) end
  if onTouchEvent ~= nil then CS.DouyinInputService.onTouchEvent:RemoveListener(onTouchEvent) end
end
```

---

## 三、Lua 特有常见错误

### 1. 使用错误的输入回调参数结构

`onMoveInputPerform` 的参数直接是 `Vector2`，`onMoveInputStart` 和 `onMoveInputCancel` 无参数。不要使用 `inputEvent.direction` 读取方向。

### 2. 解绑未初始化的 Lua 回调

Lua 回调引用可能因为初始化提前结束而保持 `nil`。调用 `RemoveListener` 前必须检查对应引用。
