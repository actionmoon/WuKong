> **📖 理论与机制**：关于动态创建的核心机制、主权流转、销毁与避坑指南，请参考 [Manual：网络对象的动态创建](../../../Manual/Ⅳ.%20多人游戏与网络%28Multiplayer%29/网络基础/网络对象的动态创建.md)
> **💡 本文档定位**：纯代码骨架与最佳实践，仅保留玩家绑定对象动态创建的核心链路代码。

### 1. 玩家绑定对象的创建与管理 (PlayerBloodController.cs)

```csharp
using System.Collections.Generic;
using Douyin.Netcode;
using UnityEngine;

public class PlayerBloodController : DouyinMonoBehaviour
{
    public static PlayerBloodController Instance { get; private set; }

    // 管理房间内所有的血条，key: actorID  value: BloodView
    private readonly Dictionary<int, BloodView> bloodTable = new();

    [SerializeField] private string bloodViewKey = "BloodView";

    public override void Awake()
    {
        base.Awake();
        Instance = this;
    }

    // 在 OnActorSpawned 中创建，每个客户端只为自己的 Actor 发起创建
    public override void OnActorSpawned(DouyinActor actor)
    {
        base.OnActorSpawned(actor);
        
        // 确保每位玩家只为自己创建绑定对象
        if (!actor.isLocal) return;

        // 断线重连时会重复调用 OnActorSpawned，避免重复创建血条
        if (bloodTable.ContainsKey(actor.actorID)) return;

        // ★ 用 actor.NetSpawn 而不是 DouyinObjectService.NetSpawn
        var go = actor.NetSpawn(bloodViewKey, out int id, (spawned, spawnedId) =>
        {
            var bloodView = spawned.GetComponent<BloodView>();
            if (bloodView != null)
            {
                // 回调仅在创建端本地执行，Awake 之后、OnNetworkSpawn 之前
                // 适合注入初始参数
                bloodView.SetTargetActorId(actor.actorID);
            }
        });
    }

    public void RegisterBloodView(int actorId, BloodView view)
    {
        if (view != null) bloodTable[actorId] = view;
    }

    public void UnregisterBloodView(int actorId)
    {
        bloodTable.Remove(actorId);
    }
}
```

### 2. 玩家绑定对象的销毁 (手动干预)

**注：`DouyinActor.NetSpawn` 创建的对象在 Actor 销毁时会自动销毁，通常无需手动干预。**
如因特殊业务需要**手动提前销毁**，可以调用 `actor.NetDestroy`：

```csharp
// 1. 获取目标 Actor
var actor = DouyinActorService.GetLocalActor();

// 2. 获取玩家绑定对象
var bloodView = bloodTable[actor.actorID];
if (bloodView == null) return;

// 2. 主权方手动销毁玩家绑定对象
actor?.NetDestroy(bloodView);

// 3. 或非主权方发起销毁（自动请求主权后再销毁）
actor?.NetDestroy(bloodView, autoRequest: true);
```