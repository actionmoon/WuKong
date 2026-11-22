# 拾取系统（Lua）

本文提供拾取系统的 Lua 代码示例。使用代码示例前，必须阅读 [基础交互](../../Manual/Ⅰ.%20核心系统%28Core%29/交互/基础交互.md)、[触发交互最佳实践](./触发交互-最佳实践.md)和[自定义拾取最佳实践](./自定义拾取-最佳实践.md)。

> **开始实现前必须阅读**：[自定义拾取最佳实践中的常见错误](./%E8%87%AA%E5%AE%9A%E4%B9%89%E6%8B%BE%E5%8F%96-%E6%9C%80%E4%BD%B3%E5%AE%9E%E8%B7%B5.md#常见错误)。该清单说明多人同步、物理和位姿对齐中最容易遗漏的问题。

## 一、最小化写法（命中即首步落地，扩展只能叠加，不得替换）

**执行顺序（硬约束）**：命中"拾取"需求时，负责当前拾取物逻辑的 Lua 脚本必须**先**把下面这段代码整体逐字落地，形成一个可自洽跑通的最小闭环；**再**在代码中显式标记的「扩展点」上叠加投掷、状态同步、armed / 引信等业务逻辑。

以下三种"看似等价"的改写全部视为主体被替换，一律**禁止**：

- **改函数名**：把 `tryPickupOrDrop` 改成 `TryPickup` / `DoPickup` / `RequestPickup` 等；把 `OnPickup` / `OnDrop` 拆成子函数再对外重命名。
- **拆分/合并分支**：只保留 `else` 里的 pickup 分支，砍掉 `isHeldByLocal()` → `Drop` 分支；或把 pickup / drop 拆成两个函数分别对外暴露。
- **等价代码替换**：用 `actor:IsPickup()` / `currentPlayer ~= nil` 替换 `isHeldByLocal()`；用 `not actor.isLocal` 提前 return 掉 `OnPickup` / `OnDrop`；用 `Matrix4x4.TRS(gripPoint.localPosition, ...)` 替换 `computeGripMatrix`。

本模块的完整闭环必须包含**辅助函数、Trigger / 焦点 / 按钮入口、`tryPickupOrDrop` 入口、`OnPickup` / `OnDrop` 回调**四部分，缺一不可；上述函数名、参数、分支结构与主体代码完全一致。基础按钮必须在已确认拾取后从“拾取”切为“放下”，并在已确认放下后切回“拾取”；不得将这条状态链路降级为可选扩展。

```lua
---@var gripAnchorName:string = "GripPoint" -- 物体上代表手柄位置的子物体名称
---@end

local gripPoint = nil
local rigidbody = nil
local isKinematic = false
local bodyColliders = {}   -- 物体自身的实体碰撞体（排除 isTrigger），持握期间整体关闭
local currentPlayer = nil
local localActorId = nil
local prevParent = nil
local pickupHand = CS.HandType.Right
local interactionButton = nil

-- 1. 物理闭环辅助函数
-- 采集物体自身的实体碰撞体（排除 isTrigger 交互范围触发器）；运行时碰撞体不变，Start 调一次缓存。
local function collectBodyColliders()
  local result = {}
  local colliders = self.gameObject:GetComponentsInChildren(typeof(CS.UnityEngine.Collider))
  if colliders ~= nil then
    for i = 0, colliders.Length - 1 do
      local col = colliders[i]
      if col ~= nil and not col.isTrigger then
        result[#result + 1] = col
      end
    end
  end
  return result
end

-- 统一开关实体碰撞体；bodyColliders 在 Start 缓存（已排除 isTrigger）。
local function setBodyCollidersEnabled(enabled)
  for _, col in ipairs(bodyColliders) do
    if col ~= nil then
      col.enabled = enabled
    end
  end
end

-- 物理开关：拾取期间强制 kinematic，并关闭实体碰撞体。
-- 关碰撞体是关键——玩家站在本物体上拾取时，角色胶囊(CharacterController)把它当脚下地面，
-- 物体挂到手骨并瞬移到掌心后这块「地面」随人移动又与人刚性绑定 → 每帧被顶飞。
-- 幂等：会被调用两次（tryPickupOrDrop 请求前预关 + OnPickup 确认后），重复关无副作用。
local function disablePhysical()
  if rigidbody ~= nil then
    rigidbody.isKinematic = true
  end
  setBodyCollidersEnabled(false)
end

-- drop 时恢复 Start 记录的初始 isKinematic（而非写死），并重新启用实体碰撞体。
local function enablePhysical()
  if rigidbody ~= nil then
    rigidbody.isKinematic = isKinematic
  end
  setBodyCollidersEnabled(true)
end

-- 用掌心世界矩阵 × pickupMatrix（平台传回的 pickUpPoint.inverse）求最终世界位姿。
local function updateTransform(handType, pickupMatrix)
  if currentPlayer == nil then return end
  local isLeft = handType == CS.HandType.Left
  local palmPosition, palmRotation = currentPlayer:CalculatePalmTransform(isLeft)
  local palmWorldMatrix = CS.UnityEngine.Matrix4x4.TRS(
    palmPosition,
    palmRotation,
    CS.UnityEngine.Vector3.one
  )
  -- XLua 不一定暴露 Matrix4x4.op_Multiply，必须用 * 运算符。
  local finalMatrix = palmWorldMatrix * pickupMatrix
  self.transform.position = finalMatrix:GetPosition()
  self.transform.rotation = finalMatrix.rotation
end

-- 计算 pickup 时传给平台的 matrix：GripPoint 缺失时退化为 identity。
-- 两个矩阵都用 scale=1 构造，结果的位置项天然带上 self 的世界缩放，
-- 与 C# Transform.LocalMatrix() 的 Vector3.Scale(parent.lossyScale, localPosition) 约定一致。
local function computeGripMatrix()
  if gripPoint == nil then
    return CS.UnityEngine.Matrix4x4.identity
  end
  local selfMat = CS.UnityEngine.Matrix4x4.TRS(
    self.transform.position,
    self.transform.rotation,
    CS.UnityEngine.Vector3.one
  )
  local gripMat = CS.UnityEngine.Matrix4x4.TRS(
    gripPoint.position,
    gripPoint.rotation,
    CS.UnityEngine.Vector3.one
  )
  return selfMat.inverse * gripMat
end

-- 按钮文案只表示“本物体是否由本地玩家持有”，不能代表全局持有状态。
local function setButtonText(text)
  if interactionButton == nil then return end

  local label = interactionButton:GetComponentInChildren(
    typeof(CS.UnityEngine.UI.Text), true)
  if label ~= nil then
    label.text = text
  end
end

function Start()
  gripPoint = self.transform:Find(gripAnchorName)
  rigidbody = self.gameObject:GetComponent(typeof(CS.UnityEngine.Rigidbody))
  if rigidbody ~= nil then
    isKinematic = rigidbody.isKinematic
  end
  bodyColliders = collectBodyColliders()
end

-- 2. Trigger 生命周期入口：只为本地玩家开启/关闭拾取交互。
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

-- “本物体是否由本地玩家持有”——按钮分支与文案的唯一依据。
-- 多人下 currentPlayer 可能是远端玩家（OnPickup 对每端任意 actor 都会跑并写 currentPlayer），
-- 只看 currentPlayer ~= nil 会把“别人持有”误判成“我持有”。
local function isHeldByLocal()
  return currentPlayer ~= nil and currentPlayer.isLocal
end

-- 3. 焦点和按钮入口：最小闭环固定提供一个“拾取 / 放下”切换按钮。
function OnFocus(handType)
  if interactionButton == nil then
    interactionButton = self:AddInteractorButton()
  end
  setButtonText(isHeldByLocal() and "放下" or "拾取")
end

function OnLostFocus(handType)
  if interactionButton ~= nil then
    self:RemoveInteractorButton(interactionButton)
    interactionButton = nil
  end
end

function OnInteractorButtonClick(index)
  if index ~= 1 or localActorId == nil then return end

  local actor = DouyinActorService.GetActorById(localActorId)
  if actor == nil then return end

  tryPickupOrDrop(actor)
end

-- 4. tryPickupOrDrop 入口（供按钮点击调用）
function tryPickupOrDrop(actor)
  if actor == nil then return end
  if isHeldByLocal() then
    actor:Drop(self.gameObject)
  else
    -- Pickup 只是发起请求，OnPickup 要等服务端确认才回来；这段窗口内刚体仍在模拟、
    -- 碰撞体仍是硬的，玩家若正站在本物体上会被一起顶飞。故请求前先本地关一次物理，
    -- OnPickup 回来时再关一次（disablePhysical 幂等，无害）。
    disablePhysical()
    actor:Pickup(self.gameObject, pickupHand, computeGripMatrix())
  end
end

-- 5. Pickup / Drop 回调（严禁 isLocal 过滤）
function OnPickup(actor, handType, pickUpPoint)
  -- 不 guard actor.isLocal：远端玩家拾取时本端也必须同步执行挂手，否则物体会丢失驱动。
  if actor == nil then return end
  
  local resolvedHandType = handType or pickupHand
  disablePhysical()
  currentPlayer = actor

  local animator = actor.gameObject:GetComponentInChildren(typeof(CS.UnityEngine.Animator))
  if animator ~= nil then
    local bone = nil
    if resolvedHandType == CS.HandType.Left then
      bone = animator:GetBoneTransform(CS.UnityEngine.HumanBodyBones.LeftHand)
    else
      bone = animator:GetBoneTransform(CS.UnityEngine.HumanBodyBones.RightHand)
    end
    if bone ~= nil then
      prevParent = self.transform.parent
      self.transform:SetParent(bone)
    end
  end

  local pickupMatrix = pickUpPoint ~= nil and pickUpPoint.inverse or CS.UnityEngine.Matrix4x4.identity
  updateTransform(resolvedHandType, pickupMatrix)
  -- 文案是“我方”概念：远端拾取不能把本端按钮误刷成“放下”。
  if actor.isLocal then
    setButtonText("放下")
  end
  self:DisableInteraction()
  -- 在这里补充投掷状态 / armed / 引信等扩展逻辑
end

function OnDrop(actor, handType)
  -- actor ~= currentPlayer 是去掉 isLocal 后唯一的状态门。
  if actor == nil or actor ~= currentPlayer then return end
  -- 不得判断 prevParent 是否为 nil；为 nil 时仍须调用 SetParent 以清空父节点。
  self.transform:SetParent(prevParent)
  prevParent = nil
  enablePhysical()
  currentPlayer = nil
  if actor.isLocal then
    setButtonText("拾取")
  end
  -- 在这里补充投掷状态 / armed / 引信等扩展逻辑
end
```

***

## 二、可选：用 varSync 同步持有态（晚进房可见 / 防重复拾取）

> 仅当用户明确要求"已被别人拾走的物品不能再被拾取""晚进房玩家也要知道物体已被持有"时叠加，不属默认组合。varSync 的声明 / 读写 / 时序规则以 `custom-variable-module` 为准，这里只给与本模块的接线。

基础闭环已经固定包含“拾取 / 放下”按钮状态：`isHeldByLocal()` 是其唯一事实来源；不得只看 `currentPlayer ~= nil`（多人下会把别人持有误判成我持有），也不要回头看 `actor:IsPickup()`。文案只在 `OnFocus` / `OnPickup` / `OnDrop` 三个时机切换，且回调中须先确认 `actor.isLocal`；不要在 `tryPickupOrDrop` 中提前改。

烟雾弹、手雷等“拾取后还能投掷或引爆”的道具，也必须保留该基础闭环：首个按钮用于“拾取 / 放下”，投掷、引爆等是持有期间叠加的独立操作，不能用只有“拾取”的单向按钮替代放下分支。

最小化写法里的 `currentPlayer` 已经能反映"物体当前被谁持有"——但它**只对拾取发生时在场的玩家有效**：平台不会给**晚进房玩家**补派历史 `OnPickup`，其 `currentPlayer` 恒为 `nil`，于是会把已被持有的物体误当成可拾取。补这层用一个 `---@varSync` 持有标志：

```lua
---@varSync held:bool   -- 是否已被某玩家持有（晚进房玩家的唯一可靠来源）
---@end

function OnNetSpawned()
  -- 晚进房玩家靠这次首发对齐"已被持有"，据此置灰/隐藏按钮。
  held:OnValueChange(function(curVal, preVal)
    -- curVal == true -> 已被持有；按需更新可拾取性 / 按钮态
  end)
end
```

持有标志只由**持有者**写（`Pickup` 已把主权转给持有者，此处 `actor.isLocal` 即主权方，可安全 `SetValue`）：

```lua
function OnPickup(actor, handType, pickUpPoint)
  -- ...最小化写法主体（含 actor == nil guard、挂手骨、对齐）对任意 actor 照常执行...
  if actor ~= nil and actor.isLocal then
    held:SetValue(true)
  end
end

function OnDrop(actor, handType)
  -- ...最小化写法主体（含 actor ~= currentPlayer guard、还原父节点/物理）照常执行...
  if actor ~= nil and actor.isLocal then
    held:SetValue(false)
  end
end
```

防重复拾取在 `tryPickupOrDrop` 里加一道闸（覆盖晚进房：其 `currentPlayer == nil` 但 `held == true`）：

```lua
local function tryPickupOrDrop(actor)
  if actor == nil then return end
  if isHeldByLocal() then
    actor:Drop(self.gameObject)
  elseif held:GetValue() then
    return  -- 已被别人持有：拒绝重复拾取
  else
    disablePhysical()  -- 同基础版：请求前预关物理，盖住确认窗口，避免站在物体上被顶飞
    actor:Pickup(self.gameObject, pickupHand, computeGripMatrix())
  end
end
```

要点：

- `held` 只解决"已被持有则不可再拾 + 晚进房按钮态正确"。**晚进房端把物体真正重新挂到持有者手上**还需把持有者标识也同步出去（`held:bool` 换成 `holderId:string`）、并据此解析持有者 actor 后重跑一遍 `OnPickup` 的挂手骨，属更大改动，不在本段范围。
- `SetValue` 只由 `actor.isLocal`（即持有者 / 主权方）写；其它端靠 `OnValueChange` 同步，不要在非主权端写 `held`。
- `held` 是给"在场没拾起过此物的玩家 + 晚进房玩家"的事实来源；"我方是否持有"仍用 `isHeldByLocal()`，二者各司其职。

***

## 三、模块边界

本模块真正的外部接入点不是 `OnPickup` / `OnDrop`，而是由外部逻辑（例如按钮模块）发起的：

```lua
localActor:Pickup(self.gameObject, pickupHand, matrix)
localActor:Drop(self.gameObject)
```

本模块**不负责**以下内容：

- 物体自身在非拾取期间的物理驱动（属于其它模块或脚本本体）。
- 主权与状态同步（参见 [主权与控制权](../../Manual/Ⅳ.%20多人游戏与网络%28Multiplayer%29/网络基础/主权与控制权.md)）。本模块只在每端各自把物体挂手 / 还原——因为平台会把 `OnPickup` / `OnDrop` 按拾取者的 API 调用派发到每台客户端——但不负责"谁有资格修改网络对象"（主权）、也不负责**晚进房玩家**的持有态重建（其进房前物体已被持有，平台不会对其补派 `OnPickup`，本端不挂手；需后续"同步最小持有态"方案，暂不在本模块范围内）。

降级与失败边界：

- `gripPoint == nil`：保留 pickup 流程，pickup matrix 用 `Matrix4x4.identity`，物体原点直接对齐掌心。
- `pickUpPoint == nil`：保留 OnPickup 流程，`updateTransform` 使用 identity。
- `rigidbody == nil`：`disablePhysical` / `enablePhysical` 跳过 `isKinematic` 部分，但**实体碰撞体的开关照常执行**（顶飞问题与刚体无关，靠关碰撞体解决）。
- `bodyColliders` 为空（物体无实体碰撞体，或全是 trigger）：碰撞体开关为空操作，拾取流程不受影响。
- `Animator == nil` 或手骨缺失：跳过 SetParent，保持原父节点。

***

## 四、Lua 常见错误

### 1. 直接访问 `pickUpPoint.inverse` 而不判空

Lua 接收到的 `pickUpPoint` 可能为 `nil`，直接访问 `pickUpPoint.inverse` 会报错；必须先判空，缺失时降级使用 `Matrix4x4.identity`。
