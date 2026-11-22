# 控制权最佳实践 (Lua)

> 本文提供 Lua 侧控制权 (Controllership) 的标准代码骨架与常见套路。关于控制权的核心概念、生命周期与避坑指南，请参阅 [主权与控制权](../../Manual/Ⅳ.%20多人游戏与网络%28Multiplayer%29/网络基础/主权与控制权.md)。

## 1. 常用状态判定套路

### 1.1 请求控制权的兜底封装
```lua
function TryRequestControllership()
    if not DouyinNetService.isNetworkSettled then return end
    if self:IsNull() then return end
    
    -- 已经拥有控制权就无需请求
    if self:HasControllership() then return end

    self:RequestControllership(function(success)
        -- 回调时对象可能已被销毁，兜底一次
        if self:IsNull() then return end
        if success then
            print("请求控制权成功")
        else
            print("请求控制权失败（可能已被他人持有）")
        end
    end)
end
```

### 1.2 转移后接管 / 清理
```lua
local isController = false

function OnControllershipTransferred(prevPlayer, currentPlayer)
    -- ⚠️ 参数在极端场景下可能为 nil（例如 Release 时 currentPlayer 为 nil），读取前先判空
    if prevPlayer and currentPlayer then
        print(string.format("控制权：%s -> %s", prevPlayer.playerOpenID, currentPlayer.playerOpenID))
    end

    -- ⚠️ 唯一真相源是 HasControllership()，不要依赖参数是否为 nil 推断
    local nowController = self:HasControllership()
    if nowController and not isController then
        StartControlLogic()
    elseif not nowController and isController then
        StopControlLogic()
    end
    isController = nowController
end
```

---

## 2. 经典业务场景骨架

### 2.1 最小可用的控制权请求
展示"请求 → 回调 → 释放"的最短链路。
```lua
function Update()
    if not DouyinNetService.isNetworkSettled then return end
    
    if UnityEngine.Input.GetKeyDown("1") then
        TryRequestControllership()
    end
    if UnityEngine.Input.GetKeyDown("2") then
        ReleaseIfHold()
    end
end

function TryRequestControllership()
    if self:HasControllership() then return end

    self:RequestControllership(function(success)
        if self:IsNull() then return end
        if success then
            -- ⚠️ 请求成功后自动获得主权，可以直接写同步变量
            print("请求控制权成功（同时获得主权）")
        end
    end)
end

function ReleaseIfHold()
    if self:HasControllership() then
        self:ReleaseControllership()
        print("已释放控制权")
    end
end
```

### 2.2 控制权转移的接管与清理
把"是否是控制方"作为业务逻辑开关，控制权转移时正确接管和清理。
```lua
local isController = false

function OnControllershipTransferred(prevPlayer, currentPlayer)
    local nowController = self:HasControllership()
    if nowController and not isController then
        StartControlLogic()
    elseif not nowController and isController then
        StopControlLogic()
    end
    isController = nowController
end

function StartControlLogic()
    -- 例：绑定本地输入
    print("成为控制方，开启输入监听")
end

function StopControlLogic()
    print("失去控制方角色，关闭输入监听")
end
```

### 2.3 SharedMode 载具物理控制

载具驾驶同时涉及座椅对象和载具根对象，必须分开处理：

- `SitDown` / `StandUp` 由座椅框架处理座椅对象的控制权；
- 载具根对象的 `Rigidbody` 物理控制由驾驶业务处理；
- `HasOwnership()` 表示同步变量写权限，`HasControllership()` 表示当前端是否能控制对象；
- SharedMode 下 `RequestControllership()` 会同时取得控制权和主权，不能用 `RequestOwnership()` 代替；
- 必须在 `OnSeatEntered` 之后延迟申请根对象控制权，避免和座椅框架同帧握手竞争；
- 申请失败时不能解除 `Rigidbody.isKinematic` 或写入速度、旋转；
- 离座必须清零输入并调用 `ReleaseControllership()`，否则下一名驾驶员可能被旧控制者阻塞。

```lua
local controlRequestPending = false
local controlRequestTimer = nil
local localDriverActorId = nil
local driverInput = UnityEngine.Vector2.zero

function OnSeatEntered(actor)
    if actor == nil or not actor.isLocal then return end
    localDriverActorId = actor.actorID

    controlRequestTimer = setTimeout(function()
        controlRequestTimer = nil
        if not DouyinNetService.isNetworkSettled
            or localDriverActorId == nil
            or controlRequestPending
            or self:HasControllership() then
            return
        end

        controlRequestPending = true
        self:RequestControllership(function(success)
            controlRequestPending = false
            if success
                and self:HasOwnership()
                and self:HasControllership() then
                rigidbody.isKinematic = false
            end
        end)
    end, 100)
end

function OnSeatExited(actor)
    if actor == nil or not actor.isLocal then return end

    if controlRequestTimer ~= nil then
        clearTimeout(controlRequestTimer)
        controlRequestTimer = nil
    end
    controlRequestPending = false
    driverInput = UnityEngine.Vector2.zero
    localDriverActorId = nil
    rigidbody.isKinematic = true

    if self:HasControllership() then
        self:ReleaseControllership()
    end
end

function FixedUpdate()
    if rigidbody == nil or rigidbody.isKinematic then return end
    if localDriverActorId == nil
        or not self:HasOwnership()
        or not self:HasControllership() then
        return
    end

    -- 在这里消费 driverInput，写入物理速度和旋转。
end
```

### 2.4 动态对象请求控制权的可靠时机
动态网络对象（如挂在 Actor 上的血条）必须主动请求控制权。直接在 `OnNetSpawned` 请求容易失败，应延迟到 `OnValueChange` 里请求。
```lua
---@varSync targetActorId:int=0
---@end

function Start()
    -- 通过同步变量的 OnValueChange 来触发请求，能保证网络已经就绪
    targetActorId:OnValueChange(function(actorId, prev)
        HandleTargetActorChanged(actorId)
    end)
end

function HandleTargetActorChanged(actorId)
    if actorId == 0 then return end
    local actor = DouyinActorService.GetActorById(actorId)
    
    -- 只有绑定目标是本地玩家时才请求控制权
    if actor ~= nil and actor.isLocal and not self:HasControllership() then
        -- ⚠️ 延迟一小段时间，规避 OnValueChange 触发时网络尚未完全就绪
        local timer = setTimeout(function()
            if not self:IsNull() then
                RequestControllershipSafe()
            end
            clearTimeout(timer)
            timer = nil
        end, 100)
    end
end

function RequestControllershipSafe()
    self:RequestControllership(function(success)
        if self:IsNull() then return end
        if success then
            print("控制权请求成功")
        end
    end)
end
```

---

## 3. 与 `Pickup / SitDown` 框架接管的边界
`DouyinActor.Pickup / Drop / SitDown / StandUp` 由框架接管对应交互对象的控制权（SharedMode 下通常也会联动主权），业务侧只需要写表现层。对于载具，座椅对象和载具根对象是两个不同的权限对象；根对象的物理控制仍需按 §2.3 单独处理。
```lua
-- 可拾取物：主权与控制权由框架接管，业务侧不写 RequestControllership
function OnInteractorButtonClick(index)
    local actor = DouyinActorService.GetLocalActor()
    if not actor then return end
    if actor:IsPickup() then return end

    -- ✅ 直接调用 Actor 接口，控制权 & 主权由框架处理
    -- ⚠️ 不要在这里写 self:RequestControllership
    DouyinActor.Pickup(self.gameObject, 0)
end

function OnPickup(actor, hand, matrix)
    -- 此时框架已经完成控制权切换（Pickup 自动获取，Drop 自动释放）
    self.transform:SetParent(actor.gameObject.transform)
end

function OnDrop(actor, hand)
    self.transform:SetParent(nil)
end
```

常见误区：

- 在驾驶座按钮点击时先申请载具根对象 `RequestOwnership()`，再调用座椅 `SitDown`；这可能阻塞落座。
- 只检查 `HasOwnership()` 就写入 Rigidbody 物理；非控制者端通常仍是 Kinematic。
- 离座只清空本地输入，不调用 `ReleaseControllership()`。
