# 主权最佳实践 (C#)

> 本文提供 C# 侧主权 (Ownership) 的标准代码骨架与常见套路。关于主权的核心概念、生命周期与避坑指南，请参阅 [主权与控制权](../../Manual/Ⅳ.%20多人游戏与网络%28Multiplayer%29/网络基础/主权与控制权.md)。

## 1. 常用状态判定套路

### 1.1 前置检查三件套
```csharp
public void TrySetHp(float value)
{
    // 1. 网络对象是否已 Spawn
    if (!IsSpawned) return;
    // 2. 网络环境是否就绪（可选，OnNetworkSpawn 之后基本可信）
    if (!DouyinNetService.isNetworkSettled) return;
    // 3. 只有主权方才能写入同步变量
    if (!IsOwner) return;

    hp.Value = value;
}
```

### 1.2 请求主权的兜底封装
```csharp
public void TryRequestOwnership()
{
    if (!IsSpawned) return;
    // 已经是主权方：直接跳过
    if (IsOwner) return;

    // ⚠️ 同步返回枚举 —— 不是回调式
    var status = NetworkObject.RequestOwnership();
    switch (status)
    {
        case OwnershipRequestStatus.AlreadyOwner:
            Debug.Log("已经是主权方");
            break;
        case OwnershipRequestStatus.RequestSent:
            // 请求已发送，等待 OnOwnershipRequestResponse 拿最终结果
            Debug.Log("请求已发送");
            break;
        case OwnershipRequestStatus.Failed:
            Debug.LogError("请求主权失败（网络异常 / 对象未 Spawn）");
            break;
    }
}

public override void OnNetworkSpawn()
{
    base.OnNetworkSpawn();

    NetworkObject.OnOwnershipRequestResponse += (succeed, msg) =>
    {
        if (succeed)
        {
            Debug.Log($"主权请求成功：{msg}");
        }
        else
        {
            Debug.LogError($"主权请求失败：{msg}");
        }
    };
}
```

### 1.3 转移后接管 / 清理
```csharp
// ⚠️ 推荐：直接用 OnGainedOwnership / OnLostOwnership，不需要 wasOwner 缓存
public override void OnGainedOwnership()
{
    base.OnGainedOwnership();
    // 刚拿到主权，启动权威逻辑
    StartAuthorityLogic();
}

public override void OnLostOwnership()
{
    base.OnLostOwnership();
    // 刚失去主权，清理权威逻辑
    StopAuthorityLogic();
}

// OnOwnershipChanged 在所有端触发，一般只用于日志监听
protected override void OnOwnershipChanged(ulong previous, ulong current)
{
    base.OnOwnershipChanged(previous, current);
    Debug.Log($"主权变化: {previous} -> {current}");
}
```

---

## 2. 经典业务场景骨架

### 2.1 最小可用的同步变量写入
```csharp
using Douyin.Netcode;
using UnityEngine;

public class HpUpdater : DouyinMonoBehaviour
{
    private NetworkVariable<float> hp = new(100f);

    private void Update()
    {
        if (!IsSpawned || !DouyinNetService.isNetworkSettled) return;
        
        // 非主权方直接跳过，不参与逻辑推进
        if (!IsOwner) return;

        hp.Value -= 1;
    }

    public override void OnNetworkSpawn()
    {
        base.OnNetworkSpawn();
        
        // 所有端都会收到 OnValueChanged，用于表现层同步
        // ⚠️ C# 侧参数顺序是 (oldVal, newVal)
        hp.OnValueChanged += (oldVal, newVal) =>
        {
            Debug.Log($"血量变化：{oldVal} -> {newVal}");
        };
    }
}
```

### 2.2 非主权方转发写入
```csharp
using Douyin.Netcode;
using UnityEngine;

public class DamageDealer : DouyinMonoBehaviour
{
    private NetworkVariable<float> hp = new(100f);

    public void OnClickTakeDamage(float damage)
    {
        if (!IsSpawned) return;

        if (IsOwner)
        {
            ApplyDamage(damage);
        }
        else
        {
            // ⚠️ Rpc 不保证送达，只用于"一次性副作用"
            ApplyDamageRpc(damage);
        }
    }

    private void ApplyDamage(float damage)
    {
        if (!IsOwner) return;  // 兜底
        hp.Value = Mathf.Max(0, hp.Value - damage);
    }

    [Rpc(SendTo.Owner)]
    private void ApplyDamageRpc(float damage)
    {
        if (!IsOwner) return;  // 兜底
        hp.Value = Mathf.Max(0, hp.Value - damage);
    }
}
```

### 2.3 请求主权 + 审批接管完整链路
```csharp
using Douyin.Netcode;
using UnityEngine;

public class OwnershipDemo : DouyinMonoBehaviour
{
    private NetworkVariable<bool> isBusy = new(false);

    public override void OnNetworkSpawn()
    {
        base.OnNetworkSpawn();
        NetworkObject.OnOwnershipRequested += OnOwnershipRequestedHandler;
        NetworkObject.OnOwnershipRequestResponse += OnOwnershipRequestResponseHandler;
    }

    public override void OnNetworkDespawn()
    {
        base.OnNetworkDespawn();
        NetworkObject.OnOwnershipRequested -= OnOwnershipRequestedHandler;
        NetworkObject.OnOwnershipRequestResponse -= OnOwnershipRequestResponseHandler;
    }

    public void TryRequestOwnership()
    {
        if (IsOwner) return;
        var status = NetworkObject.RequestOwnership();
    }

    // 审批端（当前主权方）
    private bool OnOwnershipRequestedHandler(ulong clientRequesting)
    {
        if (!IsOwner) return false;  // 兜底：非主权方不参与审批
        if (isBusy.Value) return false;
        return true;
    }

    // 请求发起端响应
    private void OnOwnershipRequestResponseHandler(bool succeed, string msg)
    {
        if (!succeed) Debug.LogError($"请求主权失败或被拒绝：{msg}");
    }

    // 接管 / 清理端
    public override void OnGainedOwnership()
    {
        base.OnGainedOwnership();
        StartAuthorityLogic();
    }

    public override void OnLostOwnership()
    {
        base.OnLostOwnership();
        StopAuthorityLogic();
    }
    
    private void StartAuthorityLogic() { /* 启动权威逻辑 */ }
    private void StopAuthorityLogic() { /* 停止权威逻辑 */ }
}
```

### 2.4 主权方主动指派（白名单机制）
C# 无直接的 `SetOwner` API，需通过白名单 + RPC 间接实现。
```csharp
using System.Collections.Generic;
using Douyin.Netcode;
using UnityEngine;

public class OwnershipAssignByWhitelist : DouyinMonoBehaviour
{
    private readonly HashSet<ulong> allowedClientIds = new();

    public override void OnNetworkSpawn()
    {
        base.OnNetworkSpawn();
        NetworkObject.OnOwnershipRequested += OnOwnershipRequestedHandler;
    }

    public override void OnNetworkDespawn()
    {
        base.OnNetworkDespawn();
        NetworkObject.OnOwnershipRequested -= OnOwnershipRequestedHandler;
    }

    // 主权方调用：把某玩家加入白名单，并通知其发起申请
    public void AllowClientTakeOwnership(ulong clientId)
    {
        if (!IsOwner) return;
        allowedClientIds.Add(clientId);
        NotifyTargetToRequestRpc(clientId);
    }

    [Rpc(SendTo.Everyone)]
    private void NotifyTargetToRequestRpc(ulong targetClientId, RpcParams rpcParams = default)
    {
        var localClientId = /* 获取本端 clientId */ 0UL;
        if (targetClientId != localClientId) return;

        NetworkObject.RequestOwnership();
    }

    // 主权方审批：只放行白名单
    private bool OnOwnershipRequestedHandler(ulong clientRequesting)
    {
        if (!IsOwner) return false;

        if (allowedClientIds.Contains(clientRequesting))
        {
            allowedClientIds.Remove(clientRequesting);
            return true;
        }
        return false;
    }
}
```

### 2.5 断线 / 切后台 / 离房自动迁移的接管
```csharp
using System.Collections;
using Douyin.Netcode;
using UnityEngine;

public class AuthorityLoopExample : DouyinMonoBehaviour
{
    private NetworkVariable<float> bloodValue = new(10f);
    private Coroutine authorityCoroutine;

    public override void OnNetworkSpawn()
    {
        base.OnNetworkSpawn();
        if (IsOwner) StartAuthorityLoop();
    }

    public override void OnNetworkDespawn()
    {
        base.OnNetworkDespawn();
        StopAuthorityLoop();
    }

    public override void OnGainedOwnership()
    {
        base.OnGainedOwnership();
        StartAuthorityLoop();
    }

    public override void OnLostOwnership()
    {
        base.OnLostOwnership();
        StopAuthorityLoop();
    }

    private void StartAuthorityLoop()
    {
        if (authorityCoroutine != null) return;  // 幂等：防重入
        authorityCoroutine = StartCoroutine(AuthorityCoroutine());
    }

    private void StopAuthorityLoop()
    {
        if (authorityCoroutine != null)
        {
            StopCoroutine(authorityCoroutine);
            authorityCoroutine = null;
        }
    }

    private IEnumerator AuthorityCoroutine()
    {
        while (this != null && IsSpawned)
        {
            yield return new WaitForSeconds(1f);
            // 兜底：迁移中主权可能瞬时变化
            if (!IsOwner) yield break;
            bloodValue.Value = Mathf.Max(0, bloodValue.Value - 1);
        }
    }
}
```

### 2.6 Rpc 与 NetworkVariable 组合获取远程结果
替代 Lua 中 `OwnerCall` 回调的推荐写法，结果必定可靠同步。
```csharp
using Douyin.Netcode;
using UnityEngine;

public class OwnerCallReplacement : DouyinMonoBehaviour
{
    private NetworkVariable<int> lastConsumeResult = new(0);
    private NetworkVariable<ulong> lastRequestClientId = new(0);

    public override void OnNetworkSpawn()
    {
        base.OnNetworkSpawn();

        // 监听结果更新
        lastConsumeResult.OnValueChanged += (oldVal, newVal) =>
        {
            var localClientId = /* 获取本端 clientId */ 0UL;
            if (lastRequestClientId.Value != localClientId) return;
            
            Debug.Log($"[OwnerCallReplacement] 远程消耗结果：{newVal}");
        };
    }

    public void TryConsumeItem(int itemId)
    {
        if (!IsSpawned) return;

        if (IsOwner)
        {
            var result = ConsumeItemInternal(itemId);
            lastConsumeResult.Value = result;
        }
        else
        {
            var localClientId = /* 获取本端 clientId */ 0UL;
            TryConsumeItemRpc(itemId, localClientId);
        }
    }

    [Rpc(SendTo.Owner)]
    private void TryConsumeItemRpc(int itemId, ulong requesterClientId)
    {
        if (!IsOwner) return;
        var result = ConsumeItemInternal(itemId);
        
        lastRequestClientId.Value = requesterClientId;
        lastConsumeResult.Value = result;
    }

    private int ConsumeItemInternal(int itemId)
    {
        return itemId > 0 ? 1 : -1;
    }
}
```

---

## 3. 与 `Pickup / SitDown` 交互接口的边界
`DouyinActor.Pickup / Drop / SitDown / StandUp` 由框架接管主权。业务侧**禁止**手工调用 `NetworkObject.RequestOwnership()`。
```csharp
using Douyin.Netcode;
using UnityEngine;

public class SimplePickupItem : DouyinMonoBehaviour
{
    public override void OnInteractorButtonClick(int index)
    {
        base.OnInteractorButtonClick(index);
        var actor = DouyinActorService.GetLocalActor();
        if (actor == null || actor.IsPickup()) return;
        
        // ✅ 直接调用 Actor 接口，主权由框架处理
        // ⚠️ 禁止在此调用 NetworkObject.RequestOwnership()
        actor.Pickup(gameObject, HandType.Right);
    }

    public override void OnPickup(DouyinActor actor, HandType hand, Matrix4x4 matrix)
    {
        base.OnPickup(actor, hand, matrix);
        transform.SetParent(actor.gameObject.transform);
    }

    public override void OnDrop(DouyinActor actor, HandType hand)
    {
        base.OnDrop(actor, hand);
        transform.SetParent(null);
    }
}
```
