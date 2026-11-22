# RemoteFunction (双向异步通信)

在 Dedicated Server (DS) 模式下，`DouyinRemoteFunction` 对象用于在客户端与服务器之间进行**异步双向通信**。调用方发起请求后，可以通过回调函数处理另一方的响应结果。

## 通信方式

`DouyinRemoteFunction` 支持以下两个方向的通信：
- **CSC (Client -> Server -> Client)**：客户端调用服务器（`InvokeServer`），并等待服务器返回结果。
- **SCS (Server -> Client -> Server)**：服务器调用指定的客户端（`InvokeClient`），并等待客户端返回结果。

## 事件监听与返回结果 (双端差异)

### Lua 侧
- **事件**：`onServerInvoke` (服务器监听) / `onClientInvoke` (客户端监听)。
- **返回响应**：处理器函数直接使用 `return v1, v2, ...`，底层会自动将返回值发回给发起方的回调。

### C# 侧 (⚠️ 易错点)
- **事件**：`onServerInvoke` (服务器监听) / `onClientInvoke` (客户端监听)。
- **返回响应**：由于 C# 的事件处理器签名是返回 `void` 的委托，**不能使用 `return` 语法**。必须在处理逻辑完成后，显式调用相应的响应方法：
  - CSC 响应：`SetServerResponse(DouyinPlayer player, params object[] response)`
  - SCS 响应：`SetClientResponse(params object[] response)`

## 参数限制与注意事项

- 参数限制与 `DouyinRemoteEvent` 相同，仅支持基础数据类型，不支持 table (Lua) 或 class/List (C#) 等复杂类型。
- **生命周期约束**：必须保证 `DouyinRemoteFunction` 对象作为类成员变量持续存在，并在 `OnDestroy` 显式 `Dispose`。若在方法内部声明会导致被垃圾回收从而丢失回调。

## 客户端 -> 服务器 -> 客户端 示例 (CSC)

### C# 示例
**1. 客户端逻辑 (GameScripts 程序集)**
```csharp
using UnityEngine;

public class ClientTest : MonoBehaviour
{
    private DouyinRemoteFunction _c2sFunction;

    void Start()
    {
        _c2sFunction = new DouyinRemoteFunction("C2S_Function");
    }

    void Update()
    {
        if (Input.GetKeyDown(KeyCode.F) && !DouyinApplication.isServer)
        {
            // 调用服务端，并监听回调返回
            _c2sFunction.InvokeServer((responseArgs) => {
                Debug.Log($"收到服务端计算结果: {string.Join(", ", responseArgs)}");
            }, "request_data", 100);
        }
    }
    
    void OnDestroy()
    {
        _c2sFunction?.Dispose();
        _c2sFunction = null;
    }
}
```

**2. 服务端逻辑 (ServerScripts 程序集)**
```csharp
using UnityEngine;

public class ServerTest : MonoBehaviour
{
    private DouyinRemoteFunction _c2sFunction;

    void Start()
    {
        if (DouyinApplication.isServer)
        {
            _c2sFunction = new DouyinRemoteFunction("C2S_Function");
            _c2sFunction.onServerInvoke.AddListener(OnServerInvokeHandle);
        }
    }

    private void OnServerInvokeHandle(DouyinPlayer player, params object[] requestArgs)
    {
        Debug.Log($"收到玩家 {player.playerOpenID} 请求: {string.Join(", ", requestArgs)}");
        
        // ⚠️ 关键：必须显式发送响应（不能用 return！）
        _c2sFunction.SetServerResponse(player, "success", 200);
    }
    
    void OnDestroy()
    {
        if (DouyinApplication.isServer)
        {
            _c2sFunction.onServerInvoke.RemoveListener(OnServerInvokeHandle);
        }
        _c2sFunction?.Dispose();
        _c2sFunction = null;
    }
}
```

### Lua 示例
**1. 客户端逻辑 (发起请求并处理响应)**
```lua
local CSToCFunction = DouyinRemoteFunction("ClientToServerToClient")

function ClientRequestServer(...)
    CSToCFunction:InvokeServer(function (...)
        local responseArgs = {...}
        for _, arg in ipairs(responseArgs) do
            print("服务器返回结果:", arg)
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

**2. 服务端逻辑 (处理请求并返回结果)**
```lua
local CSToCFunction = DouyinRemoteFunction("ClientToServerToClient")

function Start()
    if DouyinApplication.isServer then
        CSToCFunction.onServerInvoke:AddListener(OnServerResponseHandle)
    end
end

-- 接收请求并直接 return 多个结果
function OnServerResponseHandle(player, ...)
    local requestArgs = {...}
    print("收到客户端请求，玩家:", player.playerOpenID)
    return "Server-Response-1", "Server-Response-2"
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

## 服务器 -> 客户端 -> 服务器 示例 (SCS)

### C# 示例
```csharp
// 1. 服务端发起请求
_s2cFunction.InvokeClient(targetPlayer, (player, responseArgs) => {
    Debug.Log($"收到玩家 {player.playerOpenID} 响应: {string.Join(", ", responseArgs)}");
}, "check_status");

// 2. 客户端处理请求并返回结果
_s2cFunction.onClientInvoke.AddListener((requestArgs) => {
    Debug.Log($"处理服务端下发任务: {string.Join(", ", requestArgs)}");
    // ⚠️ 关键：必须显式发送响应
    _s2cFunction.SetClientResponse("client_status_ok");
});
```

### Lua 示例
**1. 服务端逻辑 (发起请求并处理响应)**
```lua
local SCToSFunction = DouyinRemoteFunction("ServerToClientToServer")

function ServerRequestClient(targetPlayer, ...)
    SCToSFunction:InvokeClient(targetPlayer, function (player, ...)
        local responseArgs = {...}
        print("收到客户端响应，玩家:", player.playerOpenID)
    end, ...)
end
```

**2. 客户端逻辑 (处理请求并返回结果)**
```lua
local SCToSFunction = DouyinRemoteFunction("ServerToClientToServer")

function Start()
    if not DouyinApplication.isServer then
        SCToSFunction.onClientInvoke:AddListener(OnClientResponseHandle)
    end
end

function OnClientResponseHandle(...)
    local requestArgs = {...}
    return "Client-Response-1", "Client-Response-2"
end
```

## 常见坑点与避坑指南 (FAQ)

### 坑 1：C# 侧把 Lua 的 `return` 照搬
**现象**：`onServerInvoke` 处理器直接写 `return;` 或者尝试改变签名返回数组，结果客户端的响应回调永远收不到。
**原因**：C# handler 是 `void` 委托，不支持返回值语法；底层必须通过主动调用 `SetServerResponse / SetClientResponse` 来完成网络回传。
**修复**：在处理逻辑的末尾显式调用对应的 `SetXxxResponse` 方法。

### 坑 2：期望响应回调 100% 触发
**现象**：服务器明明执行了处理并回传了响应，但客户端 `InvokeServer` 的回调并没有执行。
**原因**：由于网络异常、接收方异常或异步特性，`DouyinRemoteFunction` 的响应回调**不保证被执行**。
**修复**：**千万不要用回调去处理关键的必须一致的数据**（如获取抽奖结果、更新余额）。关键结果必须由服务器统一写入**同步变量**，所有端通过 `OnValueChange` 事件来可靠地感知结果，`InvokeServer` 的回调仅作为次要的 UI 提示用途。
