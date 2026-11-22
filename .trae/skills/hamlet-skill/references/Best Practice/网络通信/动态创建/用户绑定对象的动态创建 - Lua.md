> **📖 理论与机制**：关于动态创建的核心机制、主权流转、销毁与避坑指南，请参考 [Manual：网络对象的动态创建](../../../Manual/Ⅳ.%20多人游戏与网络%28Multiplayer%29/网络基础/网络对象的动态创建.md)
> **💡 本文档定位**：纯代码骨架与最佳实践，仅保留玩家绑定对象动态创建的核心链路代码。

### 1. 玩家绑定对象的创建 (PlayerBloodController.lua)

```lua
local bloodTable = {}

-- 在 OnActorSpawned 中创建，每个客户端只为自己的 Actor 发起创建
function OnActorSpawned(actor)
    -- 确保每位玩家只为自己创建绑定对象
    if not actor.isLocal then
        return
    else
        -- 断线重连时会重复调用 OnActorSpawned，避免重复创建血条
        if bloodTable[actor.actorID] then return end
        
        -- ★ 用 actor:NetSpawn 而不是 DouyinObjectService.NetSpawn
        actor:NetSpawn(bloodViewKeyname, function(go, id)
            local bloodView = go:GetDouyinScript("BloodView")
            if not bloodView or not bloodView.script then return end
            
            -- 回调仅在创建端本地执行，Awake 之后、OnNetSpawned 之前
            -- 适合注入初始参数
            bloodView.script.SetTargetActorId(actor.actorID)
        end)
    end
end
```

### 2. 玩家绑定对象的销毁 (手动干预)

**注：`DouyinActor.NetSpawn` 创建的对象在 Actor 销毁时会自动销毁，通常无需手动干预。**
如因特殊业务需要**手动提前销毁**，可以调用 `DouyinActor.NetDestroy`：

```lua
-- 1. 获取目标 Actor
local actor = DouyinActorService.GetLocalActor()

-- 2. 手动销毁玩家绑定对象
local bloodView = bloodTable[actor.actorID]
if not bloodView then 
    return 
end

if actor then
    actor:NetDestroy(bloodView)
end
```