> **📖 理论与机制**：关于动态创建的核心机制、DS主权拦截、双端差异与避坑指南，请参考 [Manual：网络对象的动态创建](../../../Manual/Ⅳ.%20多人游戏与网络%28Multiplayer%29/网络基础/网络对象的动态创建.md)
> **💡 本文档定位**：纯代码骨架与最佳实践，仅保留 DS 房间对象动态创建与销毁的核心链路代码。

### 1. 动态网络对象脚本 (GameScripts/DemoPetDSEnergyBall.cs)

```csharp
using Douyin.Netcode;
using UnityEngine;

public class DemoPetDSEnergyBall : DouyinMonoBehaviour
{
    private NetworkVariable<int> ballNetId = new(0);
    private NetworkVariable<int> holderActorId = new(0);

    public int GetBallNetId() => ballNetId.Value;
    public int GetHolderActorId() => holderActorId.Value;

    public override void OnNetworkSpawn()
    {
        base.OnNetworkSpawn();

        // ★ 关键：DS 房间公共对象必须显式拒绝客户端的主权请求，防止客户端抢占主权篡改同步变量
        NetworkObject.OnOwnershipRequested += _ => false;

        // 各端本地表现初始化
        ApplyHolderVisual();

        // 监听后续变化
        holderActorId.OnValueChanged += (oldV, newV) => ApplyHolderVisual();
    }

    // 服务端调用：写入同步变量注入初始参数
    public void InitOnServer(int netId, int creatorActorId)
    {
        if (!IsOwner) return;
        ballNetId.Value = netId;
    }

    // 服务端调用：裁决拾取逻辑并修改持有者
    public void SetHolderOnServer(int actorId)
    {
        if (!IsOwner) return;
        holderActorId.Value = actorId;
    }

    // 各端本地表现：把球 SetParent 到持有者的右手骨骼
    private void ApplyHolderVisual()
    {
        int holder = holderActorId.Value;
        if (holder == 0)
        {
            transform.SetParent(null);
            return;
        }

        var actor = DouyinActorService.GetActorById(holder);
        if (actor == null) return;
        var animator = actor.gameObject.GetComponentInChildren<Animator>();
        if (animator == null) return;
        var bone = animator.GetBoneTransform(HumanBodyBones.RightHand);
        if (bone == null) return;

        transform.SetParent(bone, false);
        transform.localPosition = Vector3.zero;
        transform.localRotation = Quaternion.identity;
    }
}
```

### 2. DS 服务端房间管理器 (ServerScripts/DemoPetDSServer.cs)

```csharp
using System.Collections.Generic;
using Douyin.Netcode;
using UnityEngine;

// ⚠️ 注意：挂在 DouyinServerRoot 子树下的脚本，必须使用 MonoBehaviour，禁止挂载 NetworkObject
public class DemoPetDSServer : MonoBehaviour
{
    public static DemoPetDSServer Instance { get; private set; }

    private class BallEntry
    {
        public int Id;
        public GameObject Go;
        public DemoPetDSEnergyBall Script;
        public int CreatorActorId;
    }

    // key: GameObject（唯一稳定引用），value: BallEntry
    private readonly Dictionary<GameObject, BallEntry> ballEntries = new();
    
    // 用于断线重连防重
    private readonly HashSet<int> spawnedForActor = new();

    [SerializeField] private string energyBallSpawnKey = "EnergyBall";

    private DouyinRemoteEvent pickupReq = new("MyGame_PickupReq");

    private void Awake()
    {
        Instance = this;
    }
    
    private void Start()
    {
        if (!DouyinApplication.isServer) return;
        pickupReq.onServerEvent.AddListener(OnPickupRequest);
        
        // 由于不能继承 DouyinMonoBehaviour，使用 Update 轮询模拟 OnActorSpawned
        // 此处省略轮询逻辑代码，假设已被调用
    }

    public void OnActorSpawned(DouyinActor actor)
    {
        if (!DouyinApplication.isServer) return;
        
        // 断线重连防重
        if (spawnedForActor.Contains(actor.actorID)) return;   
        spawnedForActor.Add(actor.actorID);
        
        SpawnBall(actor.actorID);
    }

    private void SpawnBall(int creatorActorId)
    {
        if (!DouyinApplication.isServer) return;

        // DS 服务端发起创建
        var go = DouyinObjectService.NetSpawn(energyBallSpawnKey, out int id, (spawned, spawnedId) =>
        {
            if (spawned == null) return;
            var comp = spawned.GetComponent<DemoPetDSEnergyBall>();
            if (comp == null) return;

            // 回调仅在创建端（服务端）本地执行，适合做参数注入
            comp.InitOnServer(spawnedId, creatorActorId);
            
            // 注册到管理器
            if (comp != null)
            {
                ballEntries[spawned] = new BallEntry
                {
                    Id = spawnedId, Go = spawned, Script = comp, CreatorActorId = creatorActorId
                };
            }
        });
    }

    public void OnPickupRequest(DouyinPlayer player, params object[] args)
    {
        if (args == null || args.Length == 0) return;
        int netId = System.Convert.ToInt32(args[0]);
        
        // 根据 netId 查找
        BallEntry targetEntry = null;
        foreach (var e in ballEntries.Values)
        {
            if (e.Id == netId) targetEntry = e;
        }
        if (targetEntry == null) return;
        
        if (targetEntry.Script.GetHolderActorId() != 0) return;   // 已被别人拿

        // 玩家身份以 player.GetActor() 为准（防伪造）
        var actor = player.GetActor();
        if (actor == null) return;

        // 校验通过，服务端写入同步变量
        targetEntry.Script.SetHolderOnServer(actor.actorID);
    }

    public void OnActorDespawned(DouyinActor actor)
    {
        if (!DouyinApplication.isServer) return;
        spawnedForActor.Remove(actor.actorID);

        // 创建者离场时的销毁与清理处理
        var toRemove = new List<GameObject>();
        foreach (var kv in ballEntries)
        {
            var entry = kv.Value;
            if (entry.CreatorActorId == actor.actorID)
            {
                // 创建者离场 → 销毁球
                toRemove.Add(kv.Key);
            }
            else if (entry.Script.GetHolderActorId() == actor.actorID)
            {
                // 玩家离场时正持有别人的球 → 释放（落地重新可拾取）
                entry.Script.SetHolderOnServer(0);
            }
        }
        foreach (var go in toRemove)
        {
            if (go == null) continue;
            ballEntries.Remove(go);
            DouyinObjectService.NetDestroy(go); // 服务端主动销毁
        }
    }

    private void OnDestroy()
    {
        if (DouyinApplication.isServer)
        {
            pickupReq.onServerEvent.RemoveListener(OnPickupRequest);
        }
        pickupReq?.Dispose();
        pickupReq = null;
    }
}
```

### 3. 客户端发起请求 (GameScripts/ClientPickupSender.cs)

```csharp
using UnityEngine;

public class ClientPickupSender : DouyinMonoBehaviour
{
    // RPC 通道必须是类字段，不能定义在方法内（会被 GC 释放）
    private DouyinRemoteEvent pickupReq = new("MyGame_PickupReq");

    public void RequestPickup(int netId)
    {
        if (DouyinApplication.isServer) return;
        pickupReq.FireServer(netId);   // 客户端只发请求，不做本地裁决
    }

    public override void OnDestroy()
    {
        base.OnDestroy();
        pickupReq?.Dispose();
        pickupReq = null;
    }
}
```
