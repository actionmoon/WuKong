> **📖 理论与机制**：关于动态创建的核心机制、主权流转、销毁与避坑指南，请参考 [Manual：网络对象的动态创建](../../../Manual/Ⅳ.%20多人游戏与网络%28Multiplayer%29/网络基础/网络对象的动态创建.md)
> **💡 本文档定位**：纯代码骨架与最佳实践，仅保留 SharedMode 下房间对象动态创建与销毁的核心链路代码。

### 1. 动态网络对象脚本 (BloodView.cs)

```csharp
using Douyin.Netcode;
using TMPro;
using UnityEngine;

public class BloodView : DouyinMonoBehaviour
{
    [SerializeField] private float offsetY = 1;

    // 同步变量：血量 / 目标 ActorID
    private NetworkVariable<float> bloodValue = new(10);
    private NetworkVariable<int> targetActorId = new(0);

    private TextMeshPro bloodText;
    private Transform bloodTrans;
    private Camera targetCamera;
    private Transform targetTrans;

    public int GetTargetActorId() => targetActorId.Value;
    public float GetBloodValue() => bloodValue.Value;

    public void SetTargetActorId(int actorId)
    {
        if (IsOwner) targetActorId.Value = actorId;
    }

    public override void OnNetworkSpawn()
    {
        base.OnNetworkSpawn();

        // 所有客户端都会执行的初始化
        InitBlood(GetTargetActorId());

        // 血量变化时刷新显示
        bloodValue.OnValueChanged += (oldV, newV) =>
        {
            if (bloodText != null) bloodText.text = newV.ToString();
        };
    }

    private void InitBlood(int actorId)
    {
        var targetActor = DouyinActorService.GetActorById(actorId);
        // 可能会出现下线玩家的血条残留，不判空会报错
        if (targetActor == null) return;

        // 注册到管理器
        PlayerBloodController.Instance?.RegisterBloodView(actorId, this);

        // 挂到 Actor 骨骼下并调整位置
        transform.SetParent(targetActor.gameObject.transform);
        transform.localPosition = new Vector3(0, offsetY, 0);

        bloodText = transform.Find("text")?.GetComponent<TextMeshPro>();
        if (bloodText != null) bloodText.text = GetBloodValue().ToString();

        bloodTrans = bloodText?.transform;
        targetCamera = DouyinCameraService.GetCamera();
        targetTrans = targetCamera?.transform;
    }

    public void SetBloodValue(float blood)
    {
        if (IsOwner)
        {
            bloodValue.Value = blood;
        }
        else
        {
            // 非主权方：转发给主权方执行
            SetBloodValueRpc(blood);
        }
    }

    [Rpc(SendTo.Owner)]
    private void SetBloodValueRpc(float blood)
    {
        if (!IsOwner) return;
        bloodValue.Value = blood;
    }

    public void ReduceBlood(float reducedValue)
    {
        float cur = GetBloodValue();
        float end = cur - reducedValue > 0 ? cur - reducedValue : 0;
        SetBloodValue(end);
    }

    public void AddBlood(float addValue)
    {
        float cur = GetBloodValue();
        // 最大血量为 10
        float end = cur + addValue < 10 ? cur + addValue : 10;
        SetBloodValue(end);
    }

    private void Update()
    {
        if (!DouyinNetService.isNetworkSettled) return;

        int actorId = GetTargetActorId();
        if (actorId == 0) return;

        var actor = DouyinActorService.GetActorById(actorId);
        if (actor == null && IsOwner)
        {
            // SharedMode 下，通过主权方兜底销毁退房玩家残留的房间网络对象
            DouyinObjectService.NetDestroy(gameObject);
        }
    }

    public override void OnActorDespawned(DouyinActor actor)
    {
        base.OnActorDespawned(actor);
        // 销毁前必须先解除父子关系，一定要置空！
        if (actor.actorID == GetTargetActorId())
        {
            transform.SetParent(null);
        }
    }

    public override void OnDestroy()
    {
        base.OnDestroy();
        PlayerBloodController.Instance?.UnregisterBloodView(GetTargetActorId());
    }
}
```

### 2. 动态网络对象管理器 (PlayerBloodController.cs)

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

    public override void OnActorSpawned(DouyinActor actor)
    {
        base.OnActorSpawned(actor);
        // 本端只为本地玩家发起创建
        if (!actor.isLocal) return;

        // 断线重连时会重复调用 OnActorSpawned，避免重复创建
        if (bloodTable.ContainsKey(actor.actorID)) return;

        // C# 侧 NetSpawn 同步返回 GameObject；同时可用 onSpawn 回调注入初值
        var go = DouyinObjectService.NetSpawn(bloodViewKey, out int id, (spawned, spawnedId) =>
        {
            // NetSpawn 回调仅在创建端本地执行；时序在 Awake 之后、OnNetworkSpawn 之前
            var bv = spawned.GetComponent<BloodView>();
            if (bv != null)
            {
                // 在这里设置 targetActorId，各端在 OnNetworkSpawn 中就能读到
                bv.SetTargetActorId(actor.actorID);
            }
        });
    }

    public void RegisterBloodView(int actorId, BloodView view)
    {
        if (view == null) return;
        bloodTable[actorId] = view;
    }

    public void UnregisterBloodView(int actorId)
    {
        bloodTable.Remove(actorId);
    }

    public bool TryGetBloodView(int actorId, out BloodView view)
    {
        return bloodTable.TryGetValue(actorId, out view);
    }

    public void AddPlayerBlood(int actorId, int addValue)
    {
        if (TryGetBloodView(actorId, out var bv)) bv.AddBlood(addValue);
    }

    public void ReducePlayerBlood(int actorId, int reduceValue)
    {
        if (TryGetBloodView(actorId, out var bv)) bv.ReduceBlood(reduceValue);
    }
}
```