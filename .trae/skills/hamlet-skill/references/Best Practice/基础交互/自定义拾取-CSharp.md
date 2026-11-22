# 拾取系统（C#）
本文提供拾取系统的 C# 代码示例，覆盖按钮、拾取、挂手、放下、持有态同步、允许被偷和掉落销毁。

> **使用前提**：脚本类必须继承 `DouyinMonoBehaviour` 并放在 `GameScripts/` 目录下。`DouyinMonoBehaviour` 会通过 `[RequireComponent(typeof(NetworkObject))]` 自动添加 `NetworkObject`，也可以由父节点提供。
>
> **C# 实现前必须阅读并完整遵守** [基础交互](../../Manual/Ⅰ.%20核心系统%28Core%29/交互/基础交互.md)、[触发交互最佳实践](./触发交互-最佳实践.md)和[自定义拾取最佳实践](./自定义拾取-最佳实践.md)。其中的约束与流程同样适用于 C#，必须按对应的 C# 语法落实。
>
> **开始实现前必须阅读**：[自定义拾取最佳实践中的常见错误](./%E8%87%AA%E5%AE%9A%E4%B9%89%E6%8B%BE%E5%8F%96-%E6%9C%80%E4%BD%B3%E5%AE%9E%E8%B7%B5.md#常见错误)。该清单说明多人同步、物理和位姿对齐中最容易遗漏的问题。

---

## 一、常用状态判定套路
拾取前的三条防御性检查：
```csharp
private bool CanPickup(DouyinActor actor)
{
    if (actor == null) return false;
    if (actor.IsBusy()) return false;                                    // 忙碌中：不允许交互
    if (actor.GetPickupInHand(HandType.All) != null) return false;       // 已有物品
    if (!string.IsNullOrEmpty(currentHolderActorId)) return false;       // 已被他人拿走
    return true;
}
```

其中 `currentHolderActorId` 是"当前物体的持有者 Actor ID"，由业务通过同步变量维护（见示例 B）。

---

## 二、示例 A：最小可用拾取脚本
下面的最小示例包含拾取请求、GripPoint 位姿计算、挂手、物理开关和放下恢复，不处理防偷、投掷等扩展能力。GripPoint 缺失时会降级为物体原点贴合掌心。
```csharp
using System.Collections.Generic;
using Douyin;
using Douyin.Netcode;
using UnityEngine;
using UnityEngine.UI;

public class SimplePickup : DouyinMonoBehaviour
{
    [SerializeField] private Sprite interactSprite;
    [SerializeField] private string itemName = "Sword";
    [SerializeField] private Transform gripPoint;

    private Button interactionButton;
    private DouyinActor currentPlayer;
    private Transform previousParent;
    private Rigidbody rb;
    private bool originalIsKinematic;
    private readonly List<Collider> bodyColliders = new();

    public override void Awake()
    {
        base.Awake();

        if (gripPoint == null) gripPoint = transform.Find("GripPoint");

        rb = GetComponent<Rigidbody>();
        if (rb != null) originalIsKinematic = rb.isKinematic;

        foreach (var col in GetComponentsInChildren<Collider>())
        {
            if (col != null && !col.isTrigger)
            {
                bodyColliders.Add(col);
            }
        }
    }

    public override void OnPlayerTriggerEnter(DouyinPlayer player)
    {
        if (player == null) return;
        var actor = player.GetActor();
        if (actor == null || !actor.isLocal) return;
        EnableInteraction();
    }

    public override void OnPlayerTriggerExit(DouyinPlayer player)
    {
        if (player == null) return;
        var actor = player.GetActor();
        if (actor == null || !actor.isLocal) return;
        DisableInteraction();
    }

    public override void OnFocus()
    {
        var actor = DouyinActorService.GetLocalActor();
        if (actor == null) return;

        // 本物体不是由本地玩家持有时，才检查忙碌、手中已有物品和远端持有状态。
        if (!IsHeldByLocal()
            && (actor.IsBusy()
                || actor.GetPickupInHand(HandType.All) != null
                || currentPlayer != null))
        {
            return;
        }

        interactionButton = AddInteractorButton();
        if (interactionButton != null)
        {
            // C# 侧 SDK 不自动派发 OnInteractorButtonClick，需手动挂 onClick 监听器
            interactionButton.onClick.AddListener(TryPickupOrDrop);
            var txt = interactionButton.GetComponentInChildren<Text>(true);
            if (txt != null) txt.text = IsHeldByLocal() ? "放下" : "拾取";
        }
    }

    public override void OnLostFocus()
    {
        RemoveInteractionButton();
    }

    private void RemoveInteractionButton()
    {
        if (interactionButton != null)
        {
            interactionButton.onClick.RemoveAllListeners();
            RemoveInteractorButton(interactionButton);
            interactionButton = null;
        }
    }

    private bool IsHeldByLocal()
    {
        return currentPlayer != null && currentPlayer.isLocal;
    }

    private void TryPickupOrDrop()
    {
        var actor = DouyinActorService.GetLocalActor();
        if (actor == null) return;

        if (IsHeldByLocal())
        {
            actor.Drop(gameObject);
            return;
        }

        if (actor.IsBusy()
            || actor.GetPickupInHand(HandType.All) != null
            || currentPlayer != null)
        {
            return;
        }

        // Pickup 返回 OnPickup 前存在确认窗口，请求前先关闭物理。
        DisablePhysical();
        actor.Pickup(gameObject, HandType.Right, ComputeGripMatrix());
    }

    private Matrix4x4 ComputeGripMatrix()
    {
        if (gripPoint == null) return Matrix4x4.identity;

        var selfMatrix = Matrix4x4.TRS(
            transform.position,
            transform.rotation,
            Vector3.one);
        var gripMatrix = Matrix4x4.TRS(
            gripPoint.position,
            gripPoint.rotation,
            Vector3.one);
        return selfMatrix.inverse * gripMatrix;
    }

    private void DisablePhysical()
    {
        if (rb != null) rb.isKinematic = true;
        foreach (var col in bodyColliders)
        {
            if (col != null) col.enabled = false;
        }
    }

    private void EnablePhysical()
    {
        if (rb != null) rb.isKinematic = originalIsKinematic;
        foreach (var col in bodyColliders)
        {
            if (col != null) col.enabled = true;
        }
    }

    private void UpdateTransform(
        DouyinActor actor,
        HandType handType,
        Matrix4x4 pickupMatrix)
    {
        actor.CalculatePalmTransform(
            handType == HandType.Left,
            out Vector3 palmPosition,
            out Quaternion palmRotation);

        var palmWorldMatrix = Matrix4x4.TRS(
            palmPosition,
            palmRotation,
            Vector3.one);
        var finalWorldMatrix = palmWorldMatrix * pickupMatrix;
        transform.position = finalWorldMatrix.GetPosition();
        transform.rotation = finalWorldMatrix.rotation;
    }

    public override void OnPickup(DouyinActor actor, HandType handType, Matrix4x4 pickUpPoint)
    {
        if (actor == null) return;

        DisablePhysical();
        currentPlayer = actor;
        previousParent = transform.parent;

        var animator = actor.gameObject.GetComponentInChildren<Animator>();
        if (animator != null)
        {
            var boneType = handType == HandType.Left
                ? HumanBodyBones.LeftHand
                : HumanBodyBones.RightHand;
            var bone = animator.GetBoneTransform(boneType);
            if (bone != null)
            {
                transform.SetParent(bone);
            }
        }

        UpdateTransform(actor, handType, pickUpPoint.inverse);

        if (actor.isLocal && interactionButton != null)
        {
            var txt = interactionButton.GetComponentInChildren<Text>(true);
            if (txt != null) txt.text = "放下";
        }
        Debug.Log($"Picked up: {itemName}");
    }

    public override void OnDrop(DouyinActor actor, HandType handType)
    {
        if (actor == null
            || currentPlayer == null
            || actor.actorID != currentPlayer.actorID)
        {
            return;
        }

        transform.SetParent(previousParent);
        previousParent = null;
        EnablePhysical();
        currentPlayer = null;

        if (actor.isLocal && interactionButton != null)
        {
            var txt = interactionButton.GetComponentInChildren<Text>(true);
            if (txt != null) txt.text = "拾取";
        }
        Debug.Log($"Dropped: {itemName}");
    }
}
```

---

## 三、示例 B：允许被偷、掉落销毁
关键能力：**AllowTheft** 表示允许他人从当前持有者手中抢走；**DropDestroy** 表示丢弃后经过一段时间自动销毁；**丢弃后玩家离房自动销毁** 用 `DouyinObject.EnableDestroyWhenActorLeft` 保证。
```csharp
using Douyin;
using Douyin.Netcode;
using UnityEngine;

public class AdvancedPickup : DouyinMonoBehaviour
{
    [SerializeField] private bool AllowTheft;
    [SerializeField] private bool AllowDrop = true;
    [SerializeField] private bool DropDestroy = true;
    [SerializeField] private float DestroyTime = 5f;

    // 用同步变量对齐所有客户端的"当前持有者"
    private NetworkVariable<int> currentPlayerActorId = new(0);

    private bool isTimer;
    private float timer;

    public override void OnNetworkSpawn()
    {
        base.OnNetworkSpawn();
        // 业务侧裁决主权抢夺——不要用 douyinObject.SetProperty("AllowTheft","false")（详见本节末尾警告）
        if (NetworkObject != null)
            NetworkObject.OnOwnershipRequested += HandleOwnershipRequested;
    }

    public override void OnNetworkDespawn()
    {
        if (NetworkObject != null)
            NetworkObject.OnOwnershipRequested -= HandleOwnershipRequested;
        base.OnNetworkDespawn();
    }

    private bool HandleOwnershipRequested(ulong clientRequesting)
    {
        // AllowTheft==true：任何请求方都放行；AllowTheft==false：仅未被持有时放行
        if (AllowTheft) return true;
        return currentPlayerActorId.Value == 0;
    }

    public bool IsPickable(DouyinActor actor)
    {
        if (actor == null || !actor.isBindMode) return false;
        if (AllowTheft)
        {
            // 允许被偷：只要不是当前持有者，就能拾取
            return currentPlayerActorId.Value != actor.actorID;
        }
        else
        {
            // 不允许被偷：物体必须没有持有者
            return currentPlayerActorId.Value == 0;
        }
    }

    public override void OnPickup(DouyinActor actor, HandType handType, Matrix4x4 pickUpPoint)
    {
        timer = 0;
        isTimer = false;

        // 只有拥有主权的一端写入同步变量
        if (IsOwner)
        {
            currentPlayerActorId.Value = actor != null ? actor.actorID : 0;
        }

        // 只允许被丢弃的物体，绑定"持有者离房即销毁"
        if (actor != null && actor.isLocal && DropDestroy)
        {
            douyinObject?.EnableDestroyWhenActorLeft(actor.actorID);
        }
    }

    public override void OnDrop(DouyinActor actor, HandType handType)
    {
        if (actor == null || actor.actorID != currentPlayerActorId.Value) return;

        if (IsOwner)
        {
            currentPlayerActorId.Value = 0;
        }

        if (DropDestroy)
        {
            isTimer = true;           // 启动销毁倒计时
            timer = 0;
        }
    }

    private void Update()
    {
        // 只在拥有主权的一端执行销毁计时，避免多客户端同时销毁
        if (!IsOwner) return;
        if (!isTimer || !DropDestroy) return;

        timer += Time.deltaTime;
        if (timer > DestroyTime)
        {
            DouyinObjectService.NetDestroy(gameObject, true);
            isTimer = false;
        }
    }
}
```

> ⚠️ **不要用** **`douyinObject.SetProperty("AllowTheft", "false")` 实现互斥**。SDK 服务端在收到 `AllowTheft=false` 属性后会**直接拒绝所有 ownership 请求**（包括首次拾取的合法请求），业务侧回调也不会派发，表现为"点击拾取无反应"。
> 正确做法：**不写** **`SetProperty`**，业务在 `NetworkObject.OnOwnershipRequested` 回调里根据 `currentPlayerActorId != 0` 返回 `false` 即可实现"已被持有就不能抢"。这套语义由业务全权控制，避免 SDK 服务端过早拦截。

---

## 四、C# 常见错误
### 1. `Awake` 必须调用 `base.Awake()`
`DouyinMonoBehaviour.Awake` 负责初始化 CS 脚本上下文；派生类 `Awake` 里第一句必须调用 `base.Awake()`，否则一些内部事件监听不会被注册，`OnActorTriggerEnter/Exit` 等回调可能失效。
### 2. 网络对象 Prefab 只需挂 `NetworkObject`（`Douyin.Netcode.NetworkObject`）
`DouyinMonoBehaviour` 上有 `[RequireComponent(typeof(NetworkObject))]`，挂脚本时会自动带上 `NetworkObject`。**不需要**额外挂 `DouyinObjectSync` 或 `DouyinNetworkGuid`（那两个是 Lua 侧 `---@require(DouyinObjectSync)` 遗留写法在 C# Prefab 里的常见误挂，实测在 C# 场景下并非必需）。此规则适用于所有 C# 网络对象：动态 Spawn 的拾取物（如 `EnergyBall`）、场景内固定放置的交互物（如 `ChargingStation`）都一样。
**前置检查**：Prefab / 场景对象上有 `NetworkObject` + `isTrigger` Collider + 业务脚本，就足以触发 `OnPlayerTriggerEnter`；
**反例症状**：如果缺 `NetworkObject`，SDK 不会派发 `OnPlayerTriggerEnter`，进入触发区没有任何回调、按钮不弹出。
### 3. C# 侧 SDK 不自动派发 `OnInteractorButtonClick`
Lua 侧写 `function OnInteractorButtonClick() ... end` 就能响应按钮点击；C# 侧 `override` 这个回调**永远不会被调用**。正确做法：在 `OnFocus` 里获得 `AddInteractorButton()` 返回值后，手挂 `onClick.AddListener(...)`；在 `OnLostFocus` / 移除按钮前先 `RemoveAllListeners()` 清理避免闭包泄漏。
