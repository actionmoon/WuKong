# RemoteEvent (单向异步通信)

在 Dedicated Server (DS) 模式下，除了各玩家客户端之外，还多了一个**官方托管的独立服务器进程**。客户端与服务器之间不能直接用普通的 `SendMessage` 或 `[Rpc]`（那是玩家/主权方之间的消息通道），而是需要专门的全局通道对象进行通信。
`DouyinRemoteEvent` 对象用于在客户端与服务器之间进行**异步单向通信**，调用方发送消息后无需等待响应。

> **💡 C# 架构建议 (ServerScripts)**：与继承 `NetworkBehaviour` 的 `[Rpc]` 不同，`[Rpc]` 要求发送方和接收方必须挂载在同一个 `NetworkObject` 实例上。而 `DouyinRemoteEvent` 可以作为纯逻辑对象实例化。为了极大地提高代码安全性，在 C# 中强烈建议将服务端的事件监听逻辑放置在 `ServerScripts` 专属程序集内，从而对客户端完全隐藏处理机制。

## 核心机制与分工
- **框架接管**：命名通道路由、消息序列化、C/S 分派。
- **业务侧负责**：对象的生命周期维护（必须是类字段，不能在方法内定义为局部变量）、`DouyinApplication.isServer` 判断、`onServerEvent / onClientEvent` 监听、显式 `Dispose` 清理。

## 通信方式

`DouyinRemoteEvent` 支持以下几种通信方式：
- **FireServer**：从客户端发送至服务器。
- **FireClient**：从服务器发送至单个指定的客户端。
- **FireAllClients**：从服务器广播至所有客户端。

> ⚠️ **调用方限制**：`FireServer` 只允许客户端调用，`FireClient / FireAllClients` 只允许服务器调用；违反会打错误日志且不生效。

## 参数限制与注意事项

- 仅支持基础数据类型（`bool`, `byte`, `short`, `int`, `long`, `float`, `double`, `string`，C#额外支持 Unity 值类型等）。
- 可通过可变参数 `params object[] args` (C#) 或 `...` (Lua) 传递多个数据，但**不支持 table (Lua) 或 class / List (C#) 等复杂类型**。若需传递复杂结构，请分开传参或序列化为 JSON 字符串。
- **生命周期约束**：必须将 `DouyinRemoteEvent` 声明为模块级局部变量（Lua）或类成员变量（C#）。若在方法体内部定义为局部变量，当方法结束变量被垃圾回收时，会自动触发内部清理，导致事件监听彻底失效。
- **释放清理**：`DouyinRemoteEvent` 是显式资源，不会随宿主对象自动释放。在 `OnDestroy` 中必须手动 `RemoveListener` 并调用 `Dispose()` 置空，否则反复进出场景会导致内存泄漏或重复触发。

## 客户端 -> 服务器 通信示例

### C# 示例
**1. 客户端逻辑 (GameScripts 程序集，发送请求)**
```csharp
using UnityEngine;

public class ClientTest : MonoBehaviour
{
    private DouyinRemoteEvent _clientToServerEvent;

    void Start()
    {
        _clientToServerEvent = new DouyinRemoteEvent("Test_Client2Server");
    }

    void Update()
    {
        if (Input.GetKeyDown(KeyCode.Space) && !DouyinApplication.isServer)
        {
            _clientToServerEvent.FireServer("client_to_server_msg", SystemInfo.deviceName);
        }
    }
    
    void OnDestroy()
    {
        _clientToServerEvent?.Dispose();
        _clientToServerEvent = null;
    }
}
```

**2. 服务端逻辑 (ServerScripts 专属程序集，安全隐藏)**
```csharp
using UnityEngine;

public class ServerTest : MonoBehaviour
{
    private DouyinRemoteEvent _clientToServerEvent;

    void Start()
    {
        if (DouyinApplication.isServer)
        {
            _clientToServerEvent = new DouyinRemoteEvent("Test_Client2Server");
            _clientToServerEvent.onServerEvent.AddListener(OnClientToServerEvent);
        }
    }

    private void OnClientToServerEvent(DouyinPlayer player, params object[] args)
    {
        Debug.Log($"服务端收到玩家 {player?.playerOpenID} 请求: {string.Join(", ", args)}");
    }
    
    void OnDestroy()
    {
        if (DouyinApplication.isServer)
        {
            _clientToServerEvent.onServerEvent.RemoveListener(OnClientToServerEvent);
        }
        _clientToServerEvent?.Dispose();
        _clientToServerEvent = null;
    }
}
```

### Lua 示例
**1. 客户端逻辑 (发送请求)**
```lua
-- ⚠️ 必须定义在文件顶层（脚本模块级），不能定义在方法内
local ClientToServerEvent = DouyinRemoteEvent("ClientToServer")

function Update()
    if UnityEngine.Input.GetKeyDown("1") then
        if not DouyinApplication.isServer then
            local actor = DouyinActorService.GetLocalActor()
            if actor then
                ClientToServerEvent:FireServer(actor.actorID)
            end
        end
    end
end

function OnDestroy()
    if ClientToServerEvent ~= nil then
        ClientToServerEvent:Dispose()
        ClientToServerEvent = nil
    end
end
```

**2. 服务端逻辑 (接收请求)**
```lua
-- 注意：客户端和服务器需要使用相同的通道名
local ClientToServerEvent = DouyinRemoteEvent("ClientToServer")

function Start()
    if DouyinApplication.isServer then
        ClientToServerEvent.onServerEvent:AddListener(OnServerEventHandle)
    end
end

function OnServerEventHandle(player, args)
    if args ~= nil then
        print("服务端收到来自玩家 " .. player.playerOpenID .. " 的事件", args)
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

## 服务器 -> 客户端 通信示例

### C# 示例
```csharp
// 服务端广播
_serverToClientEvent.FireAllClients("broadcast", Time.frameCount);

// 服务端单播
_serverToClientEvent.FireClient(targetPlayer, "single", Time.frameCount);

// 客户端接收
_serverToClientEvent.onClientEvent.AddListener((args) => {
    Debug.Log($"客户端收到: {string.Join(", ", args)}");
});
```

### Lua 示例
```lua
-- 服务端单播与广播
ServerToClientEvent:FireClient(player, ...)
ServerToClientEvent:FireAllClients(...)

-- 客户端接收
ServerToClientEvent.onClientEvent:AddListener(function(...)
    local args = {...}
    print("客户端收到服务端事件:", args[1])
end)
```

## 常见坑点与避坑指南 (FAQ)

### 坑 1：通道名不匹配
**现象**：`FireServer` 成功，但服务器 `onServerEvent` 从未触发。
**原因**：客户端和服务器使用了不同的字符串初始化 `DouyinRemoteEvent`（例如 `A` 和 `B` 是两个完全独立的通道）。
**修复**：确保双端使用完全一致的通道名，建议提取为公共常量（C#）或统一定义避免手误。

### 坑 2：把服务器的虚拟玩家当成真实玩家
**现象**：DS 启动后立即触发一次 `OnPlayerJoined`，业务上出现“莫名多了个玩家”。
**原因**：DS 会插入一个“服务器专属虚拟 Player”。
**修复**：在 `OnPlayerJoined` 中，务必使用 `if (player.isServer) return;` 过滤掉服务器自己，避免影响真实的玩家列表和业务判定。

### 坑 3：`FireAllClients` 导致后加入的玩家错过消息
**现象**：服务器广播事件后，1分钟后才进房的玩家看不到之前的状态。
**原因**：`DouyinRemoteEvent` 消息是一次性的，不会被缓存或回放。
**修复**：对于持续状态（如当前的游戏阶段、排行榜分数），必须使用**同步变量**保存。只有这样，新玩家才能在加入时通过 `OnValueChange` 同步到最新状态。

### 坑 4：未进行幂等设计的 `FireServer`
**现象**：客户端网络抖动时发送了扣款/发货请求，重连后操作丢失，或者多次点击导致服务器重复扣款。
**原因**：`FireServer` 不保证送达。
**修复**：关键操作必须做**幂等设计**。例如客户端发送时携带自增操作 ID，服务器记录已处理过的 ID，遇到重复请求直接返回相同结果，避免重复执行副作用。
