# 通用交互（Lua）

本文提供通用交互的 Lua 实现。使用代码前，必须阅读 [基础交互](../../Manual/Ⅰ.%20核心系统%28Core%29/交互/基础交互.md)、[触发交互最佳实践](./触发交互-最佳实践.md)和[自定义交互最佳实践](./自定义交互-最佳实践.md)。

> **开始实现前必须阅读**：[自定义交互最佳实践中的常见错误](./%E8%87%AA%E5%AE%9A%E4%B9%89%E4%BA%A4%E4%BA%92-%E6%9C%80%E4%BD%B3%E5%AE%9E%E8%B7%B5.md#常见错误)。该清单说明按钮生命周期、联网事件和多按钮分发里最容易遗漏的问题。

## 一、最小化写法

概念参考：[基础交互](../../Manual/Ⅰ.%20核心系统%28Core%29/交互/基础交互.md)。

命中“玩家靠近物体，出现按钮，点击后执行开关 / 操作 / 对话”等需求时，持久业务必须从本地 `OnInteractorButtonClick` 发起一次状态请求，再由同步变量驱动所有端表现。不要把状态请求、主权申请或同步变量写入放进全端都会执行的 `OnInteract(actor)`。

```lua
---@varSync isActive:bool=false
---@end

local interactionButton = nil
local localActorId = nil

function RefreshButtonText()
  if interactionButton == nil then
    return
  end

  local label = interactionButton:GetComponentInChildren(
    typeof(CS.UnityEngine.UI.Text), true)
  if label ~= nil then
    if isActive:GetValue() then
      -- 按业务含义替换为对应文案，例如“关闭”“停止”“已领取”。
      label.text = "停止"
    else
      -- 按业务含义替换为对应文案，例如“打开”“启动”“领取”。
      label.text = "启动"
    end
  end
end

function OnNetSpawned()
  isActive:OnValueChange(function(curVal, _)
    RefreshButtonText()
  end)
  -- 网络初始化会触发一次 OnValueChange，后进房和重连客户端由该回调恢复展示。
end

function OnActorTriggerEnter(actor)
  if actor == nil or not actor.isLocal then
    return
  end

  localActorId = actor.actorID
  self:EnableInteraction()
end

function OnActorTriggerExit(actor)
  if actor == nil or not actor.isLocal then
    return
  end

  self:DisableInteraction()
  localActorId = nil
end

function OnFocus(handType)
  interactionButton = self:AddInteractorButton()
  -- 焦点重新获得时按已确认同步状态设置按钮文案。
  RefreshButtonText()
end

function OnLostFocus(handType)
  if interactionButton ~= nil then
    self:RemoveInteractorButton(interactionButton)
  end
  interactionButton = nil
end

function OnInteractorButtonClick(index)
  if index ~= 1 or localActorId == nil then
    return
  end

  local actor = DouyinActorService.GetActorById(localActorId)
  if actor == nil then
    return
  end

  if not CS.DouyinNetService.isNetworkSettled then
    return
  end

  if self:HasOwnership() then
    -- 主权端直接切换通用业务状态。
    local currentState = isActive:GetValue()
    isActive:SetValue(not currentState)
    return
  end

  self:RequestOwnership(function(success)
    if success then
      -- 请求成功后再次读取当前状态，再执行一次状态切换。
      local currentState = isActive:GetValue()
      isActive:SetValue(not currentState)
    end
  end)
end

```

> **默认联网口径**：按钮点击只在本地发起一次状态请求；主权方写入同步变量，所有端在 `OnValueChange` 按已确认状态刷新表现。网络初始化也会触发一次该回调，用于后进房和重连恢复。只有需要全端瞬时反馈时，才额外调用 `actor:Interact(self.gameObject)`。

## 二、扩展写法

### 2.1 状态驱动按钮文案

按钮文案应从同步变量的已确认值派生。最小示例的 `RefreshButtonText()` 使用 `isActive` 决定“启动”或“停止”，并用注释标出应按业务替换的位置。`OnFocus` 也应调用该函数设置当前文案；不要用局部布尔变量或按钮文字充当真实状态。

### 2.2 多按钮分发

```lua
local dialogButton = nil
local shopButton = nil

local function RefreshButtonText(button, text)
  if button == nil then
    return
  end

  local label = button:GetComponentInChildren(
    typeof(CS.UnityEngine.UI.Text), true)
  if label ~= nil then
    label.text = text
  end
end

function OnFocus(handType)
  dialogButton = self:AddInteractorButton()
  shopButton = self:AddInteractorButton()
  RefreshButtonText(dialogButton, "对话")
  RefreshButtonText(shopButton, "商店")
end

function OnLostFocus(handType)
  self:RemoveAllInteractorButtons()
  dialogButton = nil
  shopButton = nil
  interactionButton = nil
end

function OnInteractorButtonClick(index)
  if localActorId == nil then
    return
  end

  local actor = DouyinActorService.GetActorById(localActorId)
  if actor == nil then
    return
  end

  if index == 1 then
    -- 扩展点：接入项目已有的对话业务
  elseif index == 2 then
    -- 扩展点：接入项目已有的商店业务
  end
end
```

### 2.3 多人同步与可选瞬时反馈

持久状态请求只从最小示例中的 `OnInteractorButtonClick` 发起：当前端拥有主权时写入 `isActive`，否则申请主权成功后写入。需要即时音效或粒子时，可在该回调的状态请求代码后额外调用 `Interact`，并让 `OnInteract` 仅播放瞬时反馈：

```lua
function OnInteractorButtonClick(index)
  -- 状态请求与主权处理参考最小示例。
  -- 需要全端瞬时反馈时，按需加入：
  actor:Interact(self.gameObject)
end

function OnInteract(actor)
  if actor == nil then
    return
  end

  -- 只处理音效、粒子、短动画等瞬时反馈。
  -- 禁止在这里申请主权、发送状态请求或写入 isActive。
end
```

`actor:Interact(self.gameObject)` 只同步交互事件，不等于自动同步业务数据；门状态、奖励状态等必须由同步变量或其它状态通道维护。后进房客户端通过同步变量初始化触发的 `OnValueChange` 恢复展示，不依赖历史 `OnInteract`。
