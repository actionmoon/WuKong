# Lua 版本 DS 模式远程通信

> **阅读指南**：本文仅提供 Lua 侧 DS 模式远程通信的代码骨架与最佳实践。
> 关于 `DouyinRemoteEvent` 和 `DouyinRemoteFunction` 的核心机制、前提条件、C# 与 Lua 在回调上的差异，以及双端的常见避坑指南，请务必阅读核心概念手册：
> - [RemoteEvent (单向异步通信)](../../../Manual/Ⅳ.%20多人游戏与网络%28Multiplayer%29/数据与通信/RPC/RemoteEvent.md)
> - [RemoteFunction (双向异步通信)](../../../Manual/Ⅳ.%20多人游戏与网络%28Multiplayer%29/数据与通信/RPC/RemoteFunction.md)

## 示例 A：客户端 -> 服务器 单向通信 (`FireServer`)

### 1. 客户端脚本
```lua
-- ⚠️ 这个对象必须定义在文件顶层（脚本模块级），不能定义在方法内
local ClientToServerEvent = DouyinRemoteEvent("ClientToServer")

local Input = UnityEngine.Input

function Update()
    if Input.GetKeyDown("1") then
        -- 客户端才发起，服务器不发
        if DouyinApplication.isServer then return end
        local actor = DouyinActorService.GetLocalActor()
        if actor then
            ClientToServerEvent:FireServer(actor.actorID)
        end
    end
end

-- 场景销毁 / 脚本卸载时手动 Dispose 释放
function OnDestroy()
    if ClientToServerEvent ~= nil then
        ClientToServerEvent:Dispose()
        ClientToServerEvent = nil
    end
end
```

### 2. 服务器脚本
```lua
-- 注意：客户端和服务器需要使用相同的通道名 "ClientToServer"
local ClientToServerEvent = DouyinRemoteEvent("ClientToServer")

function Start()
    if DouyinApplication.isServer then
        ClientToServerEvent.onServerEvent:AddListener(OnServerEventHandle)
    end
end

-- 服务器收到客户端消息的回调；第一个参数是发起的客户端 player
function OnServerEventHandle(player, args)
    if args ~= nil then
        print("服务端收到事件, player: " .. player.playerOpenID)
        print("服务端收到事件, args: ", args)
    end
end

function OnDestroy()
    if DouyinApplication.isServer then
        ClientToServerEvent.onServerEvent:RemoveListener(OnServerEventHandle)
    end
    if ClientToServerEvent ~= nil then
        ClientToServerEvent:Dispose()
        ClientToServerEvent = nil
    end
end
```

## 示例 B：服务器 -> 客户端 单向通信 (`FireClient` / `FireAllClients`)

### 1. 服务器脚本
```lua
local ServerToClientEvent = DouyinRemoteEvent("ServerToClient")
local playerOpenID -- 缓存目标玩家 OpenID

local Input = UnityEngine.Input

function Update()
    if not DouyinApplication.isServer then return end
    if Input.GetKeyDown("2") then
        -- 发给指定玩家
        local target = DouyinPlayerService.GetPlayerByOpenID(playerOpenID)
        if target then
            ServerToClientEvent:FireClient(target, "参数1", "参数2")
        end
    elseif Input.GetKeyDown("3") then
        -- 广播
        ServerToClientEvent:FireAllClients("参数3")
    end
end

function OnPlayerJoined(player, evt)
    -- 只关心非服务器 Player
    if not DouyinApplication.isServer or player.isServer then return end
    if playerOpenID == nil then
        playerOpenID = player.playerOpenID
    end
end

function OnDestroy()
    if ServerToClientEvent ~= nil then
        ServerToClientEvent:Dispose()
        ServerToClientEvent = nil
    end
end
```

### 2. 客户端脚本
```lua
local ServerToClientEvent = DouyinRemoteEvent("ServerToClient")

function Start()
    if not DouyinApplication.isServer then
        ServerToClientEvent.onClientEvent:AddListener(OnClientEventHandle)
    end
end

-- 服务器推送的参数会以可变参数形式回调
function OnClientEventHandle(...)
    local args = {...}
    for _, arg in pairs(args) do
        print("客户端收到事件, arg: ", arg)
    end
end

function OnDestroy()
    if not DouyinApplication.isServer then
        ServerToClientEvent.onClientEvent:RemoveListener(OnClientEventHandle)
    end
    if ServerToClientEvent ~= nil then
        ServerToClientEvent:Dispose()
        ServerToClientEvent = nil
    end
end
```

## 示例 C：客户端 -> 服务器 -> 客户端 双向通信 (`InvokeServer`)

### 1. 客户端脚本
```lua
-- ⚠️ 必须模块级定义，方法内声明的会被 GC 回收，导致回调时 Function 为 nil
local CSToCFunction = DouyinRemoteFunction("ClientToServerToClient")

local Input = UnityEngine.Input

function Update()
    if Input.GetKeyDown("1") then
        ClientRequestServer("Client-Request-参数1", "Client-Request-参数2")
    end
end

function ClientRequestServer(...)
    -- 第一个参数是响应回调；后续是要传给服务器的可变参数
    CSToCFunction:InvokeServer(function (...)
        local responseArgs = {...}
        for _, arg in ipairs(responseArgs) do
            print("服务器返回结果, arg: " .. tostring(arg))
        end
    end, ...)
end

function OnDestroy()
    if CSToCFunction ~= nil then
        CSToCFunction:Dispose()
        CSToCFunction = nil
    end
end
```

### 2. 服务器脚本
```lua
local CSToCFunction = DouyinRemoteFunction("ClientToServerToClient")

function Start()
    if DouyinApplication.isServer then
        CSToCFunction.onServerInvoke:AddListener(OnServerResponseHandle)
    end
end

-- 服务器处理客户端请求，返回值会自动传回客户端的 response 回调
function OnServerResponseHandle(player, ...)
    local requestArgs = {...}
    print("服务器收到客户端请求, player: " .. player.playerOpenID)
    for _, arg in ipairs(requestArgs) do
        print("请求参数: " .. tostring(arg))
    end
    -- 多个返回值以逗号列出
    return "Server-Response-参数1", "Server-Response-参数2"
end

function OnDestroy()
    if DouyinApplication.isServer then
        CSToCFunction.onServerInvoke:RemoveListener(OnServerResponseHandle)
    end
    if CSToCFunction ~= nil then
        CSToCFunction:Dispose()
        CSToCFunction = nil
    end
end
```

## 示例 D：服务器 -> 客户端 -> 服务器 双向通信 (`InvokeClient`)

### 1. 服务器脚本
```lua
local SCToSFunction = DouyinRemoteFunction("ServerToClientToServer")

local Input = UnityEngine.Input

function Update()
    if not DouyinApplication.isServer then return end
    if Input.GetKeyDown("2") then
        local allPlayers = DouyinPlayerService.GetPlayers()
        if allPlayers and allPlayers.Length > 0 then
            local player = allPlayers[1]
            ServerRequestClient(player, "Server-Request-参数1")
        end
    end
end

function ServerRequestClient(targetPlayer, ...)
    -- 响应回调第一个参数是回复的玩家，后续是可变参数
    SCToSFunction:InvokeClient(targetPlayer, function (player, ...)
        local responseArgs = {...}
        print("客户端响应，player: " .. player.playerOpenID)
        for _, arg in ipairs(responseArgs) do
            print("返回值: " .. tostring(arg))
        end
    end, ...)
end

function OnDestroy()
    if SCToSFunction ~= nil then
        SCToSFunction:Dispose()
        SCToSFunction = nil
    end
end
```

### 2. 客户端脚本
```lua
local SCToSFunction = DouyinRemoteFunction("ServerToClientToServer")

function Start()
    if not DouyinApplication.isServer then
        SCToSFunction.onClientInvoke:AddListener(OnClientResponseHandle)
    end
end

function OnClientResponseHandle(...)
    local requestArgs = {...}
    for _, arg in ipairs(requestArgs) do
        print("客户端收到服务器请求, arg: " .. tostring(arg))
    end
    return "Client-Response-参数1", "Client-Response-参数2"
end

function OnDestroy()
    if not DouyinApplication.isServer then
        SCToSFunction.onClientInvoke:RemoveListener(OnClientResponseHandle)
    end
    if SCToSFunction ~= nil then
        SCToSFunction:Dispose()
        SCToSFunction = nil
    end
end
```
