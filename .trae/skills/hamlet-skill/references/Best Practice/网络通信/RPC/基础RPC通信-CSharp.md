# C# 版本基础 RPC 通信

> **阅读指南**：本文仅提供基础 RPC 通信的代码骨架与最佳实践。
> 关于 RPC 的分派规则、参数类型限制、SendTo 目标区别以及常见坑点（如生命周期调用失败、参数不支持复杂类型等），请务必阅读核心概念手册：[SendMessage 与 [Rpc] (消息互通)](../../../Manual/Ⅳ.%20多人游戏与网络%28Multiplayer%29/数据与通信/RPC/SendMessage.md)。

## 示例 A：`[Rpc(SendTo.Owner)]` — 通知主权方

```csharp
using Douyin.Netcode;
using UnityEngine;

public class OwnerRpcSample : NetworkBehaviour
{
    private void Update()
    {
        if (!DouyinNetService.isNetworkSettled) return;
        if (Input.GetKeyDown(KeyCode.Alpha1))
        {
            Debug.Log("--DouyinNetSample:发送消息给主权方");
            SendToOwnerRpc(1);
        }
    }

    // 主权方（自己或另一玩家）会执行到此
    [Rpc(SendTo.Owner)]
    private void SendToOwnerRpc(int index)
    {
        // 兜底：主权方独占的写入必须先查一次 IsOwner
        if (!IsOwner) return;
        Debug.Log($"--DouyinNetSample:收到 SendToOwnerRpc 消息 {index}");
    }
}
```

## 示例 B：`[Rpc(SendTo.Everyone)]` — 广播给所有人（含自己）

```csharp
using Douyin.Netcode;
using UnityEngine;

public class EveryoneRpcSample : NetworkBehaviour
{
    private void Update()
    {
        if (!DouyinNetService.isNetworkSettled) return;
        if (Input.GetKeyDown(KeyCode.Alpha1))
        {
            Debug.Log("--DouyinNetSample:发送消息给所有玩家");
            SendToEveryoneRpc(2, default);
        }
    }

    // 所有玩家都会执行到此，包括发送者自己
    [Rpc(SendTo.Everyone)]
    private void SendToEveryoneRpc(int index, RpcParams rpcParams = default)
    {
        Debug.Log($"--DouyinNetSample:收到 SendToEveryoneRpc 消息 {index}, SenderClientId={rpcParams.SenderClientId}");
    }
}
```

## 示例 C：`[Rpc(SendTo.NotMe)]` — 广播（不含自己）

```csharp
using Douyin.Netcode;
using UnityEngine;

public class NotMeRpcSample : NetworkBehaviour
{
    private void Update()
    {
        if (!DouyinNetService.isNetworkSettled) return;
        if (Input.GetKeyDown(KeyCode.Alpha1))
        {
            // 本地立即处理
            DoLocalEffect(3);
            // 通知其他人做同样的处理
            Debug.Log("--DouyinNetSample:发送消息给除了自己外的其他玩家");
            SendToNotMeRpc(3, default);
        }
    }

    private void DoLocalEffect(int index)
    {
        Debug.Log($"--DouyinNetSample:本地立即处理 {index}");
    }

    [Rpc(SendTo.NotMe)]
    private void SendToNotMeRpc(int index, RpcParams rpcParams = default)
    {
        Debug.Log($"--DouyinNetSample:收到 SendToNotMeRpc 消息 {index}, SenderClientId={rpcParams.SenderClientId}");
    }
}
```

## 示例 D：`[Rpc(SendTo.SpecifiedInParams)]` — 点对点消息

```csharp
using System.Collections.Generic;
using Douyin.Netcode;
using UnityEngine;

public class SelectedRpcSample : NetworkBehaviour
{
    private void Update()
    {
        if (!DouyinNetService.isNetworkSettled) return;
        if (Input.GetKeyDown(KeyCode.Alpha1))
        {
            // 单个目标：发给当前 NetworkObject 的主权方
            SendToSelectedRpc("hello single", RpcTarget.Single(OwnerPlayerId), default);
        }
        else if (Input.GetKeyDown(KeyCode.Alpha2))
        {
            // 一组目标
            var group = new List<ulong>() { OwnerPlayerId /* , otherClientId... */ };
            SendToSelectedRpc("hello group", RpcTarget.Group(group), default);
        }
    }

    [Rpc(SendTo.SpecifiedInParams)]
    private void SendToSelectedRpc(string message, RpcTarget rpcTarget, RpcParams rpcParams = default)
    {
        Debug.Log($"--DouyinNetSample:收到 SendToSelectedRpc 消息 {message}, SenderClientId={rpcParams.SenderClientId}");
    }
}
```

## 示例 E：模拟 `OwnerCall` — 用 `NetworkVariable` 记结果

```csharp
using Douyin.Netcode;
using UnityEngine;

public class OwnerCallReplacement : NetworkBehaviour
{
    // 结果通过同步变量对齐；ulong 表示"最后一次请求的发起方 ClientId"，避免多次请求混淆
    private NetworkVariable<string> lastConsumeResult = new("");
    private NetworkVariable<ulong> lastRequestClientId = new(0);

    public override void OnNetworkSpawn()
    {
        base.OnNetworkSpawn();

        lastConsumeResult.OnValueChanged += (oldVal, newVal) =>
        {
            // 只有当前是该次请求的发起方，才响应结果
            if (lastRequestClientId.Value != NetworkObjectId /* 或本地 clientId */) return;
            Debug.Log($"--OwnerCallReplacement: 主权方处理完成，结果={newVal}");
        };
    }

    private void Update()
    {
        if (!DouyinNetService.isNetworkSettled) return;
        if (Input.GetKeyDown(KeyCode.Alpha1))
        {
            // 请求主权方处理
            ConsumeItemRequestRpc(5, default);
        }
    }

    [Rpc(SendTo.Owner)]
    private void ConsumeItemRequestRpc(int itemId, RpcParams rpcParams = default)
    {
        if (!IsOwner) return;

        // 主权方独占的业务逻辑
        bool ok = itemId > 0;
        string result = ok ? $"Consumed {itemId}" : "Failed";

        // 把结果写入同步变量，所有端会通过 OnValueChanged 感知
        lastRequestClientId.Value = rpcParams.SenderClientId;
        lastConsumeResult.Value = result;
    }
}
```

## 示例 F：使用 `RpcParams.SenderClientId` 识别发送方

```csharp
using Douyin.Netcode;
using UnityEngine;

public class SenderRpcSample : NetworkBehaviour
{
    private void Update()
    {
        if (!DouyinNetService.isNetworkSettled) return;
        if (Input.GetKeyDown(KeyCode.Alpha1))
        {
            ReportRpc("hello", default);
        }
    }

    [Rpc(SendTo.Everyone)]
    private void ReportRpc(string message, RpcParams rpcParams)
    {
        Debug.Log($"来自 ClientId={rpcParams.SenderClientId} 的消息：{message}");
    }
}
```

