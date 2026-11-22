# C# 版本 DS 模式远程通信

> **阅读指南**：本文仅提供 C# 侧 DS 模式远程通信的代码骨架与最佳实践。
> 关于 `DouyinRemoteEvent` 和 `DouyinRemoteFunction` 的核心机制、前提条件、C# 与 Lua 在回调上的差异，以及双端的常见避坑指南，请务必阅读核心概念手册：
> - [RemoteEvent (单向异步通信)](../../../Manual/Ⅳ.%20多人游戏与网络%28Multiplayer%29/数据与通信/RPC/RemoteEvent.md)
> - [RemoteFunction (双向异步通信)](../../../Manual/Ⅳ.%20多人游戏与网络%28Multiplayer%29/数据与通信/RPC/RemoteFunction.md)

## 示例 A：客户端 -> 服务器 单向通信 (`FireServer`)

### 1. 客户端脚本（放在 `GameScripts/`）
```csharp
using UnityEngine;

public class ClientSideEvent : DouyinMonoBehaviour
{
    // ⚠️ 必须是类字段，不能定义在方法内（GC 后通道会被 Dispose）
    private DouyinRemoteEvent clientToServer = new("ClientToServer");

    private void Update()
    {
        if (Input.GetKeyDown(KeyCode.Alpha1))
        {
            // 只有客户端才发起
            if (DouyinApplication.isServer) return;
            var actor = DouyinActorService.GetLocalActor();
            if (actor != null)
            {
                clientToServer.FireServer(actor.actorID);
            }
        }
    }

    // 场景销毁 / 脚本卸载时手动 Dispose 释放
    public override void OnDestroy()
    {
        base.OnDestroy();
        clientToServer?.Dispose();
        clientToServer = null;
    }
}
```

### 2. 服务器脚本（放在 `ServerScripts/`）
```csharp
using UnityEngine;

public class ServerSideEvent : DouyinMonoBehaviour
{
    // 注意：客户端和服务器必须使用相同的通道名 "ClientToServer"
    private DouyinRemoteEvent clientToServer = new("ClientToServer");

    private void Start()
    {
        if (DouyinApplication.isServer)
        {
            clientToServer.onServerEvent.AddListener(OnServerEventHandle);
        }
    }

    // 服务器收到客户端消息的回调；第一个参数是发起的客户端 player
    private void OnServerEventHandle(DouyinPlayer player, params object[] args)
    {
        if (args != null && args.Length > 0)
        {
            Debug.Log($"服务端收到事件, player: {player.playerOpenID}");
            for (int i = 0; i < args.Length; i++)
            {
                Debug.Log($"服务端收到事件, args[{i}]: {args[i]}");
            }
        }
    }

    public override void OnDestroy()
    {
        base.OnDestroy();
        if (DouyinApplication.isServer)
        {
            clientToServer.onServerEvent.RemoveListener(OnServerEventHandle);
        }
        clientToServer?.Dispose();
        clientToServer = null;
    }
}
```

## 示例 B：服务器 -> 客户端 单向通信 (`FireClient` / `FireAllClients`)

### 1. 服务器脚本（放在 `ServerScripts/`）
```csharp
using UnityEngine;

public class ServerSideBroadcast : DouyinMonoBehaviour
{
    private DouyinRemoteEvent serverToClient = new("ServerToClient");
    private string playerOpenID;  // 缓存目标玩家 OpenID

    private void Update()
    {
        if (!DouyinApplication.isServer) return;
        if (Input.GetKeyDown(KeyCode.Alpha2))
        {
            // 发给指定玩家
            var target = DouyinPlayerService.GetPlayerByOpenID(playerOpenID);
            if (target != null)
            {
                serverToClient.FireClient(target, "参数1", "参数2");
            }
        }
        else if (Input.GetKeyDown(KeyCode.Alpha3))
        {
            // 广播
            serverToClient.FireAllClients("参数3");
        }
    }

    public override void OnPlayerJoined(DouyinPlayer player, PlayerJoinEvent evt)
    {
        base.OnPlayerJoined(player, evt);
        // 只关心非服务器 Player
        if (!DouyinApplication.isServer || player.isServer) return;
        if (playerOpenID == null)
        {
            playerOpenID = player.playerOpenID;
        }
    }

    public override void OnDestroy()
    {
        base.OnDestroy();
        serverToClient?.Dispose();
        serverToClient = null;
    }
}
```

### 2. 客户端脚本（放在 `GameScripts/`）
```csharp
using UnityEngine;

public class ClientSideReceiver : DouyinMonoBehaviour
{
    private DouyinRemoteEvent serverToClient = new("ServerToClient");

    private void Start()
    {
        if (!DouyinApplication.isServer)
        {
            serverToClient.onClientEvent.AddListener(OnClientEventHandle);
        }
    }

    // 服务器推送的参数会以可变参数形式回调
    private void OnClientEventHandle(params object[] args)
    {
        foreach (var arg in args)
        {
            Debug.Log($"客户端收到事件, arg: {arg}");
        }
    }

    public override void OnDestroy()
    {
        base.OnDestroy();
        if (!DouyinApplication.isServer)
        {
            serverToClient.onClientEvent.RemoveListener(OnClientEventHandle);
        }
        serverToClient?.Dispose();
        serverToClient = null;
    }
}
```

## 示例 C：客户端 -> 服务器 -> 客户端 双向通信 (`InvokeServer`)

### 1. 客户端脚本（放在 `GameScripts/`）
```csharp
using UnityEngine;

public class ClientRequest : DouyinMonoBehaviour
{
    // ⚠️ 必须是类字段（方法内声明会被 GC）
    private DouyinRemoteFunction cscFunction = new("ClientToServerToClient");

    private void Update()
    {
        if (Input.GetKeyDown(KeyCode.Alpha1))
        {
            ClientRequestServer("Client-Request-参数1", "Client-Request-参数2");
        }
    }

    private void ClientRequestServer(params object[] args)
    {
        // 第一个参数是响应回调；后续是要传给服务器的可变参数
        cscFunction.InvokeServer((responseArgs) =>
        {
            foreach (var arg in responseArgs)
            {
                Debug.Log($"服务器返回结果, arg: {arg}");
            }
        }, args);
    }

    public override void OnDestroy()
    {
        base.OnDestroy();
        cscFunction?.Dispose();
        cscFunction = null;
    }
}
```

### 2. 服务器脚本（放在 `ServerScripts/`）
```csharp
using UnityEngine;

public class ServerRequestHandler : DouyinMonoBehaviour
{
    private DouyinRemoteFunction cscFunction = new("ClientToServerToClient");

    private void Start()
    {
        if (DouyinApplication.isServer)
        {
            cscFunction.onServerInvoke.AddListener(OnServerResponseHandle);
        }
    }

    // 服务器处理客户端请求；⚠️ 必须显式调用 SetServerResponse 把响应回传
    private void OnServerResponseHandle(DouyinPlayer player, params object[] args)
    {
        Debug.Log($"服务器收到客户端请求, player: {player.playerOpenID}");
        foreach (var arg in args)
        {
            Debug.Log($"请求参数: {arg}");
        }

        // ⚠️ 关键：显式发送响应（不能用 return！）
        cscFunction.SetServerResponse(player, "Server-Response-参数1", "Server-Response-参数2");
    }

    public override void OnDestroy()
    {
        base.OnDestroy();
        if (DouyinApplication.isServer)
        {
            cscFunction.onServerInvoke.RemoveListener(OnServerResponseHandle);
        }
        cscFunction?.Dispose();
        cscFunction = null;
    }
}
```

## 示例 D：服务器 -> 客户端 -> 服务器 双向通信 (`InvokeClient`)

### 1. 服务器脚本（放在 `ServerScripts/`）
```csharp
using UnityEngine;

public class ServerRequest : DouyinMonoBehaviour
{
    private DouyinRemoteFunction scsFunction = new("ServerToClientToServer");

    private void Update()
    {
        if (!DouyinApplication.isServer) return;
        if (Input.GetKeyDown(KeyCode.Alpha2))
        {
            var allPlayers = DouyinPlayerService.GetPlayers();
            if (allPlayers != null && allPlayers.Length > 0)
            {
                var player = allPlayers[0];
                ServerRequestClient(player, "Server-Request-参数1");
            }
        }
    }

    private void ServerRequestClient(DouyinPlayer targetPlayer, params object[] args)
    {
        // 响应回调第一个参数是回复的玩家，后续是可变参数
        scsFunction.InvokeClient(targetPlayer, (player, responseArgs) =>
        {
            Debug.Log($"客户端响应，player: {player.playerOpenID}");
            foreach (var arg in responseArgs)
            {
                Debug.Log($"返回值: {arg}");
            }
        }, args);
    }

    public override void OnDestroy()
    {
        base.OnDestroy();
        scsFunction?.Dispose();
        scsFunction = null;
    }
}
```

### 2. 客户端脚本（放在 `GameScripts/`）
```csharp
using UnityEngine;

public class ClientResponseHandler : DouyinMonoBehaviour
{
    private DouyinRemoteFunction scsFunction = new("ServerToClientToServer");

    private void Start()
    {
        if (!DouyinApplication.isServer)
        {
            scsFunction.onClientInvoke.AddListener(OnClientResponseHandle);
        }
    }

    // 客户端处理服务器请求；⚠️ 必须显式调用 SetClientResponse 把响应回传
    private void OnClientResponseHandle(params object[] args)
    {
        foreach (var arg in args)
        {
            Debug.Log($"客户端收到服务器请求, arg: {arg}");
        }

        // ⚠️ 关键：显式发送响应（不能用 return！）
        scsFunction.SetClientResponse("Client-Response-参数1", "Client-Response-参数2");
    }

    public override void OnDestroy()
    {
        base.OnDestroy();
        if (!DouyinApplication.isServer)
        {
            scsFunction.onClientInvoke.RemoveListener(OnClientResponseHandle);
        }
        scsFunction?.Dispose();
        scsFunction = null;
    }
}
```

