> **📖 理论与机制**：关于动态创建的核心机制、主权流转、销毁与避坑指南，请参考 [Manual：网络对象的动态创建](../../../Manual/Ⅳ.%20多人游戏与网络%28Multiplayer%29/网络基础/网络对象的动态创建.md)
> **💡 本文档定位**：纯代码骨架与最佳实践，仅保留 SharedMode 下房间对象动态创建与销毁的核心链路代码。

### 1. 动态网络对象脚本 (BloodView_1.lua)

```lua
---@var offsetY:float = 1
---@varSync bloodValue:float=10
---@varSync targetActorId:int
---@end

local Vector3 = UnityEngine.Vector3
local bloodText
local bloodTrans
local targetCamera
local targetTrans

-- 在这里初始化网络对象
function OnNetSpawned()
    InitBlood(GetTargetActorId())
end

function InitBlood(targetActorIdValue)
    local targetActor = DouyinActorService.GetActorById(targetActorIdValue)
    -- 可能会出现下线玩家的残留，不判空会报错
    if not targetActor then
        return
    end
    
    -- 注册到 PlayerBloodController_1 管理器中
    if _G["__playerblood_controller__"] then
        _G["__playerblood_controller__"].RegisterBloodView(targetActorIdValue, self)
    end
    
    self.transform:SetParent(targetActor.gameObject.transform)
    self.transform.localPosition = Vector3(0, offsetY, 0)
    bloodText = self.transform:Find("text"):GetComponent(typeof(CS.TMPro.TextMeshPro))
    if bloodText then
        bloodText.text = GetBloodValue()
        bloodTrans = bloodText.transform
    end
    targetCamera = DouyinCameraService.GetCamera()
    if targetCamera then
        targetTrans = targetCamera.transform
    end
end

function GetTargetActorId()
    return targetActorId:GetValue()
end

function SetTargetActorId(actorId)
    targetActorId:SetValue(actorId)
end

function GetBloodValue()
    return bloodValue:GetValue()
end

function SetBloodValue(blood)
    if self:HasOwnership() then
        bloodValue:SetValue(blood)
    else
        self:SendMessageToOwner("SetBloodValue", blood)
    end
end

function ReduceBlood(reducedValue)
    local curblood = GetBloodValue()
    local endBlood = curblood - reducedValue > 0 and curblood - reducedValue or 0
    SetBloodValue(endBlood)
end

function AddBlood(addValue)
    local curblood = GetBloodValue()
    local endBlood = curblood + addValue < 10 and curblood + addValue or 10
    SetBloodValue(endBlood)
end

function Start()
    -- 注册血量变更回调，血量变更时刷新血量显示
    bloodValue:OnValueChange(function(curVal, preVal)
        if bloodText then
            bloodText.text = curVal
        end
    end)
end

function Update()
    if not DouyinNetService.isNetworkSettled then return end

    if GetTargetActorId() ~= 0 then
        local actor = DouyinActorService.GetActorById(GetTargetActorId())
        -- SharedMode 下，通过主权方兜底销毁退房玩家残留的房间网络对象
        if actor == nil and self:HasOwnership() then
            DouyinObjectService.NetDestroy(self.gameObject)
        end
    end
end

function OnActorDespawned(actor)
    -- 销毁前必须先解除父子关系
    if actor.actorID == GetTargetActorId() then
        self.transform:SetParent(nil)
    end
end

-- 在对象销毁时，将自己从管理器中移除
function OnDestroy()
    if _G["__playerblood_controller__"] then
        _G["__playerblood_controller__"].UnRegisterBloodView(GetTargetActorId())
    end
end
```

### 2. 动态网络对象管理器 (PlayerBloodController_1.lua)

```lua
---@var bloodViewKeyname:string
---@end

local bloodTable = {} -- 管理房间内所有的血条，key: actorID value: BloodView

function Awake()
    -- 暴露为全局对象
    _G["__playerblood_controller__"] = self.script
end

-- 在 OnActorSpawned 中创建，每个客户端只为自己的 Actor 发起创建
function OnActorSpawned(actor)
    if not actor.isLocal then
        return
    else
        -- 断线重连时，会重复调用 OnActorSpawned，避免重复创建
        if bloodTable[actor.actorID] then return end
        
        DouyinObjectService.NetSpawn(bloodViewKeyname, function(go, id)
            local bloodView = go:GetDouyinScript("BloodView_1")
            if not bloodView or not bloodView.script then return end
            
            -- 在回调中注入参数，OnNetSpawned 时可获取到
            bloodView.script.SetTargetActorId(actor.actorID)
        end)
    end
end

function RegisterBloodView(actorID, bloodV)
    if actorID == nil or bloodV == nil then return end
    bloodTable[actorID] = bloodV
end

function UnRegisterBloodView(actorID)
    if actorID == nil then return end
    bloodTable[actorID] = nil
end

-- 其他模块可调用以下接口加/减血
function AddPlayerBlood(actorID, addvalue)
    if actorID and addvalue then
        local targetBlood = bloodTable[actorID]
        if targetBlood and targetBlood.script then
            targetBlood.script.AddBlood(addvalue)
        end
    end
end

function ReducePlayerBlood(actorID, reducevalue)
    if actorID and reducevalue then
        local targetBlood = bloodTable[actorID]
        if targetBlood and targetBlood.script then
            targetBlood.script.ReduceBlood(reducevalue)
        end
    end
end
```