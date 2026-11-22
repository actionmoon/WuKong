> **📖 理论与机制**：关于动态创建的核心机制、DS主权拦截、双端差异与避坑指南，请参考 [Manual：网络对象的动态创建](../../../Manual/Ⅳ.%20多人游戏与网络%28Multiplayer%29/网络基础/网络对象的动态创建.md)
> **💡 本文档定位**：纯代码骨架与最佳实践，仅保留 DS 房间对象动态创建与销毁的核心链路代码。

### 1. 动态网络对象脚本 (DemoPetDSEnergyBall.lua)

```lua
---@varSync ballNetId:int = 0
---@varSync holderActorId:int = 0
---@end

function GetBallNetId()
    return ballNetId:GetValue()
end

function GetHolderActorId()
    return holderActorId:GetValue()
end

-- ★ 关键：DS 房间公共对象必须显式拒绝客户端的主权请求，防止客户端抢占主权篡改同步变量
function OnOwnershipRequest(senderID)
    return false
end

-- 服务端裁决通过后调用：写 holderActorId 同步变量
function SetHolderOnServer(actorId)
    if not self:HasOwnership() then return end
    holderActorId:SetValue(actorId or 0)
end

function InitOnServer(netId, creatorActorId)
    if not self:HasOwnership() then return end
    ballNetId:SetValue(netId)
end

function OnNetSpawned()
    -- 同步变量 OnValueChange 在初始化时不触发，需要手动落地一次
    ApplyHolderVisual()

    -- 监听后续变化
    holderActorId:OnValueChange(function()
        ApplyHolderVisual()
    end)
end

-- 各端本地表现：把球 SetParent 到持有者的右手骨骼
function ApplyHolderVisual()
    local holder = holderActorId:GetValue()
    if holder == 0 then
        self.transform:SetParent(nil)
        return
    end

    local actor = DouyinActorService.GetActorById(holder)
    if actor == nil then return end
    local bone = actor:GetBoneTransform(HumanBodyBones.RightHand)
    if bone == nil then return end
    
    self.transform:SetParent(bone, false)
    self.transform.localPosition = Vector3.zero
    self.transform.localRotation = Quaternion.identity
end
```

### 2. DS 服务端房间管理器 (DemoPetDSServer.lua)

```lua
---@var energyBallSpawnKey:string = "EnergyBall"
---@var spawnPoint:UnityEngine.Transform
---@end

-- key: GameObject（唯一稳定），value: { id, go, script, creatorActorId }
local ballEntries = {}
local spawnedForActor = {} -- 断线重连防重

local PickupReqEvent = DouyinRemoteEvent("MyGame_PickupReq")

function Awake()
    _G["__demo_pet_ds_server__"] = self.script
end

function Start()
    if not DouyinApplication.isServer then return end
    PickupReqEvent.onServerEvent:AddListener(OnPickupRequest)
end

function RegisterBallEntry(go, id, script, creatorActorId)
    if go == nil then return end
    ballEntries[go] = {
        id = id,
        go = go,
        script = script,
        creatorActorId = creatorActorId,
    }
end

function UnregisterBallEntry(go)
    if go == nil then return end
    ballEntries[go] = nil
end

function OnActorSpawned(actor)
    if not DouyinApplication.isServer then return end
    if spawnedForActor[actor.actorID] then return end   -- 断线重连防重
    spawnedForActor[actor.actorID] = true
    SpawnBall(actor.actorID)
end

function SpawnBall(creatorActorId)
    if not DouyinApplication.isServer then return end

    DouyinObjectService.NetSpawn(energyBallSpawnKey, function(go, id)
        if go == nil then return end
        local comp = go:GetDouyinScript("DemoPetDSEnergyBall")
        if comp == nil or comp.script == nil then return end

        -- 在回调中的设置，会在 Awake() 之后、OnNetSpawned() 之前执行，适合注入创建参数
        comp.script.InitOnServer(id, creatorActorId)

        -- 注册到管理器表：key 用 go（稳定引用），value 存 script 模块
        RegisterBallEntry(go, id, comp.script, creatorActorId)
    end)
end

function OnPickupRequest(player, args)
    if not DouyinApplication.isServer then return end
    local netId = tonumber(args[1]) or 0
    
    local targetEntry = nil
    for _, entry in pairs(ballEntries) do
        if entry.id == netId then
            targetEntry = entry
            break
        end
    end
    if targetEntry == nil then return end
    if targetEntry.script.GetHolderActorId() ~= 0 then return end   -- 已被别人拿

    local actor = player:GetActor()
    if actor == nil then return end
    
    -- 校验通过，服务端写同步变量
    targetEntry.script.SetHolderOnServer(actor.actorID)
end

function OnActorDespawned(actor)
    if not DouyinApplication.isServer then return end
    spawnedForActor[actor.actorID] = nil

    for go, entry in pairs(ballEntries) do
        if entry.creatorActorId == actor.actorID then
            -- 创建者离场 -> 销毁球
            DestroyBallOnServer(go)
        elseif entry.script.GetHolderActorId() == actor.actorID then
            -- 该玩家离场时正持有别人的球 -> 释放（球落地重新可拾取）
            entry.script.SetHolderOnServer(0)
        end
    end
end

function DestroyBallOnServer(go)
    if not DouyinApplication.isServer then return end
    if go == nil then return end
    UnregisterBallEntry(go)
    DouyinObjectService.NetDestroy(go)
end

function OnDestroy()
    if PickupReqEvent ~= nil then
        if DouyinApplication.isServer then
            PickupReqEvent.onServerEvent:RemoveListener(OnPickupRequest)
        end
        PickupReqEvent:Dispose()
        PickupReqEvent = nil
    end
end
```

### 3. 客户端发起请求 (ClientPickupSender.lua)

```lua
-- RPC 通道必须放模块级，方法内定义会被 GC 变 nil
local PickupReqEvent = DouyinRemoteEvent("MyGame_PickupReq")

function RequestPickup(netId)
    if DouyinApplication.isServer then return end
    PickupReqEvent:FireServer(netId)   -- 只发请求，不做本地裁决
end

function OnDestroy()
    if PickupReqEvent ~= nil then
        PickupReqEvent:Dispose()
        PickupReqEvent = nil
    end
end
```