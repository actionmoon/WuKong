# Lua 版本 Dedicated Server 落地实操

> 本文提供 Lua 侧 Dedicated Server 模式下服务端启动入口、ServerSpawn 以及通用请求套路的代码骨架。
> 相关的理论概念、避坑指南及 API 规则请参阅 Manual 目录下的《网络模型-Dedicated Server》。

## 一、开发工具配置

### Unity Editor 配置

> **适用范围**：当 [hamlet-preferences.md](../../../hamlet-preferences.md) 中 `DevTool=UnityEditor` 时阅读。
> `DevTool` 的详细说明请参考[开发工具概述](../../Manual/VI.%20开发工具/开发工具概述.md)。

将以下脚本文件放在 `DouyinServerScriptLoader` 登记的目录里，并挂载到场景中 `DouyinServerRoot` 节点下。

## 二、 最小可用的 DS 服务脚本

```lua
function Start()
    if not DouyinApplication.isServer then return end
    print("DS ServerBoot: 服务器脚本启动")
end

---@param player DouyinPlayer
function OnPlayerJoined(player, evt)
    -- ⚠️ 过滤掉 DS 虚拟服务器 Player
    if player.isServer then return end
    print("DS ServerBoot: 玩家加入 " .. player.playerOpenID)
end

---@param player DouyinPlayer
function OnPlayerLeft(player, evt)
    -- ⚠️ 过滤掉 DS 虚拟服务器 Player
    if player.isServer then return end
    print("DS ServerBoot: 玩家离开 " .. player.playerOpenID)
end
```

## 三、 ServerSpawn / ServerDestroy 完整流程

展示服务器端专属网络对象的生成与销毁。

```lua
local Vector3 = UnityEngine.Vector3
local Quaternion = UnityEngine.Quaternion
local Input = UnityEngine.Input

-- 记录已生成的服务器专属对象，便于统一销毁
local serverObjs = {}

function Start()
    if not DouyinApplication.isServer then return end

    ServerCreateNetObj_1()
    ServerCreateNetObj_2()
    ServerCreateNetObj_3()
    ServerCreateNetObj_4()
end

function Update()
    if Input.GetKeyDown("1") then
        ServerDestroyNetObjs()
    end
end

-- 变体一：默认位姿
function ServerCreateNetObj_1()
    DouyinObjectService.ServerSpawn("NetObj_1", function(netObj, netObjId)
        print("ServerSpawn 变体1 Success, netObj: " .. netObj.name)
        table.insert(serverObjs, netObj)
    end)
end

-- 变体二：指定位置
function ServerCreateNetObj_2()
    DouyinObjectService.ServerSpawn("NetObj_1", Vector3(1, 0, 0), function(netObj, netObjId)
        print("ServerSpawn 变体2 Success, netObj: " .. netObj.name)
        table.insert(serverObjs, netObj)
    end)
end

-- 变体三：位置 + 欧拉角
function ServerCreateNetObj_3()
    DouyinObjectService.ServerSpawn("NetObj_1", Vector3(2, 0, 0), Vector3(45, 45, 45), function(netObj, netObjId)
        print("ServerSpawn 变体3 Success, netObj: " .. netObj.name)
        table.insert(serverObjs, netObj)
    end)
end

-- 变体四：位置 + 四元数
function ServerCreateNetObj_4()
    DouyinObjectService.ServerSpawn("NetObj_1", Vector3(3, 0, 0), Quaternion.identity, function(netObj, netObjId)
        print("ServerSpawn 变体4 Success, netObj: " .. netObj.name)
        table.insert(serverObjs, netObj)
    end)
end

-- 反向遍历删除，避免打乱下标
function ServerDestroyNetObjs()
    for i = #serverObjs, 1, -1 do
        local netObj = serverObjs[i]
        DouyinObjectService.ServerDestroy(netObj)
        table.remove(serverObjs, i)
    end
    print("ServerDestroy 全部销毁完成")
end
```

## 四、 客户端请求服务器生成对象的通用套路

```lua
-- 1. 客户端端（DouyinScriptLoader 共享 Loader 中）
local SpawnReqEvent = DouyinRemoteEvent("ReqServerSpawn")

function RequestSpawn(pos)
    if DouyinApplication.isServer then return end
    SpawnReqEvent:FireServer(pos.x, pos.y, pos.z)
end

-- 2. 服务器端（DouyinServerScriptLoader 中）
local SpawnReqEvent = DouyinRemoteEvent("ReqServerSpawn")
local Vector3 = UnityEngine.Vector3

function Start()
    if DouyinApplication.isServer then
        SpawnReqEvent.onServerEvent:AddListener(OnClientRequestSpawn)
    end
end

function OnClientRequestSpawn(player, x, y, z)
    -- ⚠️ 必须过滤服务器自身
    if player == nil or player.isServer then return end

    -- 业务侧鉴权：例如冷却检查、位置合法性
    if not CanPlayerSpawn(player) then return end

    DouyinObjectService.ServerSpawn("NetObj_1", Vector3(x, y, z), function(netObj)
        print("服务端为玩家 " .. player.playerOpenID .. " 生成对象")
    end)
end

function CanPlayerSpawn(player)
    return true
end
```