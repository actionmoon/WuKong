# 右下角操作按钮（Lua）

本文提供右下角操作按钮的 Lua 实现。使用代码前，先阅读 Manual 中的[操作按钮](../../Manual/Ⅱ.%20界面与交互(UI)/系统交互按钮/操作按钮.md)。

## 一、初始化内容

在业务脚本顶层声明 import 和按钮状态变量：

```lua
local DouyinUIService = CS.DouyinUIService
local UIType = CS.UIType
local EventTrigger = CS.UnityEngine.EventSystems.EventTrigger
local EventTriggerType = CS.UnityEngine.EventSystems.EventTriggerType

-- 按钮引用（由 SetupActionButton 赋值，HideButton 后置 nil）
local ascendBtn = nil
local ascendTrigger = nil
local descendBtn = nil
local descendTrigger = nil

-- 按住态（由 PointerDown / PointerUp 回调更新）
local btnAscend = false
local btnDescend = false
```

当前 Lua runtime 不支持 `require`。本模板使用的 `DouyinUIService`、`UIType`、`EventTrigger` 和 `EventTriggerType` 需要在业务脚本中直接声明。

若使用长按检测，额外声明：

```lua
local longPressThreshold = 0.5  -- 长按判定阈值（秒）
local longPressTimer = 0
local isLongPressing = false
```

## 二、最小化写法

以下 5 个工具函数 + 业务侧调用 + `FixedUpdate` 消费 + 生命周期接入是完整最小闭环。**只能在标注的扩展点添加业务逻辑**。

### 2.1 工具函数（内联到业务脚本顶部）

```lua
local DouyinUIService = CS.DouyinUIService
local UIType = CS.UIType
local EventTrigger = CS.UnityEngine.EventSystems.EventTrigger
local EventTriggerType = CS.UnityEngine.EventSystems.EventTriggerType

-- 清空按钮的 EventTrigger.triggers 列表（互斥保障）
local function ClearTrigger(trigger)
  if trigger == nil then return end
  if trigger.triggers ~= nil then
    trigger.triggers:Clear()
  end
end

-- 绑定 PointerDown / PointerUp 到按钮的 EventTrigger 组件
local function BindTrigger(btn, onDown, onUp)
  if btn == nil or btn.gameObject == nil then return nil end
  local trigger = btn.gameObject:GetComponent(typeof(EventTrigger))
  if trigger == nil then
    trigger = btn.gameObject:AddComponent(typeof(EventTrigger))
  end
  ClearTrigger(trigger)

  local entryDown = EventTrigger.Entry()
  entryDown.eventID = EventTriggerType.PointerDown
  entryDown.callback:AddListener(function(_) onDown() end)
  trigger.triggers:Add(entryDown)

  local entryUp = EventTrigger.Entry()
  entryUp.eventID = EventTriggerType.PointerUp
  entryUp.callback:AddListener(function(_) onUp() end)
  trigger.triggers:Add(entryUp)

  return trigger
end

-- 更新按钮文案（子节点上的 Text 组件）
local function SetButtonText(btn, text)
  if btn == nil then return end
  local label = btn:GetComponentInChildren(typeof(CS.UnityEngine.UI.Text), true)
  if label ~= nil then
    label.gameObject:SetActive(true)
    label.text = text
  end
end

-- 激活按钮、设置样式并绑定事件
local function SetupActionButton(uiType, btnText, onDown, onUp)
  local btn = DouyinUIService.GetInteractionButton(uiType)
  if btn == nil then return nil, nil end
  btn.gameObject:SetActive(true)
  btn.transition = CS.UnityEngine.UI.Selectable.Transition.None
  local tween = btn.gameObject:GetComponentInChildren(typeof(CS.ButtonTweenEffect), true)
  if tween ~= nil then
    tween.enabled = false
  end
  SetButtonText(btn, btnText)
  local trigger = BindTrigger(btn, onDown, onUp)
  return btn, trigger
end

-- 隐藏按钮并清理事件
local function HideButton(btn, trigger)
  if trigger ~= nil then ClearTrigger(trigger) end
  if btn ~= nil then btn.gameObject:SetActive(false) end
end
```

**代码要求：**

- `BindTrigger` 每次绑定前都要调用 `ClearTrigger`，避免旧玩法回调残留。
- `SetupActionButton` 获取不到按钮时必须返回，不要继续访问 `nil`。
- 如果按钮预制体带有默认按下动画，应关闭 `btn.transition` 并禁用 `ButtonTweenEffect`。

### 2.2 状态变量（按钮引用 + 按住态）

```lua
-- 按钮引用（由 SetupActionButton 赋值，HideButton 后置 nil）
local ascendBtn = nil
local ascendTrigger = nil
local descendBtn = nil
local descendTrigger = nil

-- 按住态（由 PointerDown / PointerUp 回调更新，FixedUpdate 消费）
local btnAscend = false
local btnDescend = false
```

按钮引用由显示函数赋值，退出函数清理；`btnAscend` / `btnDescend` 只表示当前是否按住按钮，不要把按钮文案当作状态源。

### 2.3 业务侧调用（显示 / 隐藏）

```lua
local function ShowActionButtons()
  ascendBtn, ascendTrigger = SetupActionButton(
    UIType.CustomMain, "上升",
    function() if hasPassenger then btnAscend = true end end,
    function() btnAscend = false end
  )
  descendBtn, descendTrigger = SetupActionButton(
    UIType.CustomSub, "下降",
    function() if hasPassenger then btnDescend = true end end,
    function() btnDescend = false end
  )
end

local function HideActionButtons()
  HideButton(ascendBtn, ascendTrigger)
  ascendBtn = nil
  ascendTrigger = nil
  HideButton(descendBtn, descendTrigger)
  descendBtn = nil
  descendTrigger = nil
  btnAscend = false
  btnDescend = false
end
```

**代码要求：**

- 只在当前玩法取得控制权后调用 `ShowActionButtons()`，不要在每个实例的 `Start()` 中无条件调用。
- `HideActionButtons()` 必须隐藏按钮、清空引用，并将所有按住状态归零。

### 2.4 `FixedUpdate` 消费按住态

```lua
function FixedUpdate()
  if not hasPassenger then return end

  -- 合并键盘与右下角操作按钮输入（多输入源汇入同一 helper）
  local pressUp = CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.E) or btnAscend
  local pressDown = CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.Q) or btnDescend

  -- 扩展点：基于 pressUp / pressDown 的升降 / 加速 / 发射逻辑
end
```

**要点**：`PointerDown` / `PointerUp` 回调**只设标志位**，不直接调物理 / 状态切换（回调不在 `FixedUpdate` 中，时机不确定）。真正的业务在 `FixedUpdate` 统一消费。

### 2.5 生命周期接入（座位 / 载具场景常见组合）

```lua
function OnSeatEntered(actor, handType)
  if actor == nil then return end
  -- ... 座位对齐逻辑（对任意非 nil actor 执行，不要 guard isLocal 后 return）...
  if actor.isLocal then
    ShowActionButtons()
  end
end

function OnSeatExited(actor)
  if actor == nil then return end
  -- ... 座位脱离逻辑 ...
  if actor.isLocal then
    HideActionButtons()
  end
end

function OnDestroy()
  HideActionButtons()
end
```

**多实例天然互斥**：场景里有 N 个可交互对象，但业务只在当前活跃的那个实例中调用 `SetupActionButton`。此时按钮的 `EventTrigger` 回调被替换为当前实例的 handler，上一实例的 handler 自动失效（`ClearTrigger` 清空了旧列表）。不需要全局 `_G.activeXxx` 焦点变量。

---

## 三、长按检测扩展

场景：蓄力攻击、长按确认、按住连发。区分"短按（点击）"与"长按（按住超过阈值）"两种语义。

实现思路：`PointerDown` 记录按下时刻，`FixedUpdate` 追踪持续时长，`PointerUp` 根据时长判断走短按分支还是长按结束分支。

```lua
-- 状态变量（加到 2.2 后面）
local longPressThreshold = 0.5  -- 长按判定阈值（秒）
local longPressTimer = 0
local isLongPressing = false
local btnAttackDown = false

-- PointerDown：记录按下时刻，开始计时
local function OnAttackDown()
  if not hasPassenger then return end
  btnAttackDown = true
  longPressTimer = 0
  isLongPressing = false
end

-- PointerUp：根据时长判断短按 / 长按结束
local function OnAttackUp()
  if not hasPassenger then return end
  btnAttackDown = false

  if not isLongPressing then
    OnShortPress()          -- 短按：未达到阈值就松手
  else
    OnLongPressEnd()        -- 长按结束
  end

  longPressTimer = 0
  isLongPressing = false
end

-- FixedUpdate 中追踪长按（合入原有 FixedUpdate 体内）
function FixedUpdate()
  if not hasPassenger then return end

  if btnAttackDown then
    longPressTimer = longPressTimer + CS.UnityEngine.Time.fixedDeltaTime
    if not isLongPressing and longPressTimer >= longPressThreshold then
      isLongPressing = true
      OnLongPressStart()    -- 首次达到阈值
    end
    if isLongPressing then
      OnLongPressing()      -- 每帧持续触发（如连发）
    end
  end
end
```

**要点**：
- `longPressTimer` 在 `PointerDown` 时归零，在 `FixedUpdate` 累加 `Time.fixedDeltaTime`。
- `isLongPressing` 只在首次达到阈值时置 `true`，避免重复触发 `OnLongPressStart`。
- `PointerUp` 时根据 `isLongPressing` 判断走短按分支还是长按结束分支。
- 短按 / 长按的业务逻辑（`OnShortPress` / `OnLongPressStart` / `OnLongPressing` / `OnLongPressEnd`）由宿主脚本实现，本模块只提供检测框架。

---

## 四、其他扩展

### 4.1 与 trigger 联动（仅在玩家进入区域时显示按钮）

场景：玩家走进炮台触发器才出现"开火"按钮，离开后隐藏。

```lua
local fireBtn, fireTrigger

local function OnFireDown() isFiring = true end
local function OnFireUp()   isFiring = false end

function OnActorTriggerEnter(actor)
  if actor == nil or not actor.isLocal then return end
  fireBtn, fireTrigger = SetupActionButton(UIType.CustomMain, "开火", OnFireDown, OnFireUp)
end

function OnActorTriggerExit(actor)
  if actor == nil or not actor.isLocal then return end
  HideButton(fireBtn, fireTrigger)
  fireBtn = nil
  fireTrigger = nil
  isFiring = false
end
```

### 4.2 按钮禁用（保留显示但不可点）

场景：技能冷却中，按钮显示灰态且点不动。

```lua
fireBtn.interactable = false  -- 冷却开始
fireBtn.interactable = true   -- 冷却结束
```

`interactable = false` 时 UGUI 的 `onClick` 不会派发；`EventTrigger` 的 `PointerDown / PointerUp` 是否同步阻断以平台实际行为为准，必要时在 handler 内自行判断 `fireBtn.interactable`。

### 4.3 隐藏官方按钮（避免 UI 冲突）

场景：自定义玩法接管跳跃 / 飞行键，需要隐藏官方按钮。

```lua
local jumpBtn = CS.DouyinUIService.GetInteractionButton(CS.UIType.Jump)
if jumpBtn ~= nil then jumpBtn.gameObject:SetActive(false) end

local flyBtn = CS.DouyinUIService.GetInteractionButton(CS.UIType.Fly)
if flyBtn ~= nil then flyBtn.gameObject:SetActive(false) end
```

切出玩法上下文后建议还原 `SetActive(true)`，避免污染全局 UI 状态。

---

## Lua 实现常见错误

### 1. 把右下角操作按钮当场景交互气泡按钮使用

**问题：** 靠近物体才出现的“拾取 / 对话 / 上车”用了 `SetupActionButton`。

```lua
function OnActorTriggerEnter(actor)
  pickupBtn, _ = SetupActionButton(UIType.CustomMain, "拾取", ...)
end
```

**为什么错：** 靠近物体弹出的按钮应走 `self:AddInteractorButton()` + `OnFocus / OnLostFocus`。右下角按钮是全局单例，用于持续性玩法上下文。

### 2. 忘记在退出时清理按钮

**问题：** 下机 / 退出玩法后没有调用 `HideButton`，按钮仍然显示并响应旧回调。

```lua
function OnSeatExited(actor)
  if actor == nil or not actor.isLocal then return end
  -- 只做了座位脱离，忘记 HideButton
end
```

**为什么错：** 按钮的 `EventTrigger` 回调仍然指向已退出的实例，可能导致空引用或错误行为。

### 3. 多实例同时调用 SetupActionButton

**问题：** 场景里 N 个对象同时在 `Start` 中调用 `SetupActionButton`。

```lua
function Start()
  SetupActionButton(UIType.CustomMain, "开火", ...)
end
```

**为什么错：** 按钮是全局单例，最后一个 `SetupActionButton` 会覆盖前面的绑定。只应在“当前活跃的玩法上下文”中调用。

### 4. 在 PointerDown 回调中直接执行业务逻辑而不设标志位

**问题：** 在 `PointerDown` 回调里直接调用物理或状态切换逻辑。

```lua
SetupActionButton(UIType.CustomMain, "上升",
  function() rb.velocity = Vector3.up * speed end,  -- 直接在回调里写物理
  function() end
)
```

**为什么错：** 回调不在 `FixedUpdate` 中执行，物理写入时机不确定。应在回调中只设标志位（`btnAscend = true`），在 `FixedUpdate` 中统一消费。

### 5. 忘记关闭 Transition 动画

**问题：** 按钮按下时出现 Unity UGUI 自带的缩放动画，与 `PointerDown` / `PointerUp` 事件体验冲突。

```lua
local function SetupActionButton(uiType, btnText, onDown, onUp)
  local btn = DouyinUIService.GetInteractionButton(uiType)
  if btn == nil then return nil, nil end
  btn.gameObject:SetActive(true)
  -- 缺少 transition = None 和 ButtonTweenEffect 禁用
  SetButtonText(btn, btnText)
  ...
end
```

**为什么错：** 按钮预制体上可能配置了 `Transition = Animation` 或挂载了 `ButtonTweenEffect` 组件，导致按下时自动播放缩放动画。必须在 `SetupActionButton` 中关闭 `transition` 并禁用 `ButtonTweenEffect`。
