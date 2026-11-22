# 座位系统（C#）
> 本文聚焦"玩家坐到某个对象上、再站起来离开"这条链路。C# 版示例。
> 使用本文代码前，必须先阅读 [基础交互](../../Manual/Ⅰ.%20核心系统%28Core%29/交互/基础交互.md)、[触发交互最佳实践](./触发交互-最佳实践.md) 和 [自定义座位最佳实践](./自定义座位-最佳实践.md)；本文只补充座位特有的 C# 实现。
>
> **开始实现前必须阅读**：[自定义座位最佳实践中的常见错误](./%E8%87%AA%E5%AE%9A%E4%B9%89%E5%BA%A7%E4%BD%8D-%E6%9C%80%E4%BD%B3%E5%AE%9E%E8%B7%B5.md#常见错误)。该清单说明多人、移动座位、动画过渡和父级缩放中最容易遗漏的问题。

> **座椅模型硬约束**：一个座椅 NetworkObject 配置一个 `SeatAnchor` 和一个逻辑 `CurrentPlayer`；多座椅车辆必须为每个座椅使用独立 NetworkObject 和独立座椅组件。

---

## 一、座位系统是什么
座位系统允许 **本地玩家坐到指定 GameObject 上，并以坐姿的动画和位置跟随该 GameObject 运动**。典型场景：椅子、沙发、载具驾驶座、观众席、载客单车后座。
座位有三个关键语义：
**占用互斥**：同一座位同一时刻只能有一个玩家使用；
**动画锁定**：SDK 会自动切换 Actor 到坐姿动画，业务侧也可以指定 `CustomSittingAnimation`；
**状态互斥**：坐下期间飞行被禁用，业务侧不需要额外处理，但要理解这条约束。
主权、控制权、动画和位置同步由 SDK 内部接管；业务侧负责：
检查前置状态（是否已坐、是否飞行）；座位是否已被占用由平台 `CurrentPlayer` 处理；
调用 `actor.SitDown / actor.StandUp`；
在 `OnSeatEntered / OnSeatExited` 中做位置绑定、按钮切换、附加动画。
> ⚠️ 脚本类必须继承 `DouyinMonoBehaviour` 且文件放在 `GameScripts/` 目录。

---
## 二、示例 A：最小可用座位脚本
```csharp
using Douyin;
using UnityEngine;
using UnityEngine.UI;

public class SimpleSeat : DouyinMonoBehaviour
{
    [SerializeField] private Transform seatEnterTrans;   // 坐下时 Actor 应处的位置
    [SerializeField] private Transform seatExitTrans;    // 站起时 Actor 应处的位置

    private int localActorId;
    private bool hasLocalActorId;
    private bool hasPassenger;
    private Button interactionButton;

    public override void OnActorTriggerEnter(DouyinActor actor)
    {
        if (actor == null || !actor.isLocal) return;
        localActorId = actor.actorID;
        hasLocalActorId = true;
        EnableInteraction();
    }

    public override void OnActorTriggerExit(DouyinActor actor)
    {
        if (actor == null || !actor.isLocal) return;
        // 座位特例：坐下后即使跟随座位离开 Trigger，也要保留下车按钮通道。
        if (!hasPassenger)
        {
            hasLocalActorId = false;
            DisableInteraction();
        }
    }

    public override void OnFocus()
    {
        interactionButton = AddInteractorButton();
        if (interactionButton == null) return;
        interactionButton.onClick.AddListener(HandleSeatButtonClick);
        var txt = interactionButton.GetComponentInChildren<Text>(true);
        if (txt != null)
        {
            txt.text = hasPassenger ? "站起" : "坐下";
        }
    }

    public override void OnLostFocus()
    {
        if (interactionButton != null)
        {
            interactionButton.onClick.RemoveAllListeners();
            RemoveInteractorButton(interactionButton);
            interactionButton = null;
        }
    }

    private void HandleSeatButtonClick()
    {
        if (!hasLocalActorId) return;
        var actor = DouyinActorService.GetActorById(localActorId);
        if (actor == null) return;

        if (hasPassenger)
        {
            actor.StandUp(gameObject);
        }
        else
        {
            // 前置检查：飞行中不能直接坐
            if (actor.IsFlying()) return;
            actor.SitDown(gameObject);
        }
    }

    public override void OnSeatEntered(DouyinActor actor)
    {
        if (actor == null) return;
        var trans = actor.gameObject.transform;
        // 挂到座位的入场点，锁定位置
        trans.SetParent(seatEnterTrans);
        trans.localPosition = Vector3.zero;
        trans.localRotation = Quaternion.identity;
        // 用 Hips 骨骼校正，避免不同角色高度导致的下沉/悬空
        var animator = actor.gameObject.GetComponentInChildren<Animator>();
        if (animator != null)
        {
            var hipsBone = animator.GetBoneTransform(HumanBodyBones.Hips);
            if (hipsBone != null)
            {
                var offset = hipsBone.position - trans.position;
                trans.position = trans.position - offset;
            }
        }

        if (actor.isLocal)
        {
            hasPassenger = true;
            SetButtonText("站起");
        }
    }

    public override void OnSeatExited(DouyinActor actor)
    {
        if (actor == null) return;
        var trans = actor.gameObject.transform;
        trans.SetParent(null);
        // 离场时把 Actor 摆到指定位置
        if (seatExitTrans != null)
        {
            actor.position = seatExitTrans.position;
            actor.rotation = seatExitTrans.rotation;
        }

        if (actor.isLocal)
        {
            hasPassenger = false;
            SetButtonText("坐下");
        }
    }

    private void SetButtonText(string text)
    {
        if (interactionButton == null) return;
        var txt = interactionButton.GetComponentInChildren<Text>(true);
        if (txt != null) txt.text = text;
    }
}
```

---

## 三、示例 B：自定义坐姿动画
```csharp
using Douyin;
using UnityEngine;

public class AnimatedSeat : DouyinMonoBehaviour
{
    [SerializeField] private AnimationClip CustomSittingAnimation;

    public override void OnSeatEntered(DouyinActor actor)
    {
        // ... 位置绑定同上 ...

        if (CustomSittingAnimation != null)
        {
            actor.PlayAnimation(CustomSittingAnimation);   // 播放自定义坐姿
        }
    }

    public override void OnSeatExited(DouyinActor actor)
    {
        // ... 位置还原同上 ...

        if (CustomSittingAnimation != null)
        {
            actor.StopAnimation();                          // 站起时清除自定义动画
        }
    }
}
```

---

## 四、示例 C：飞行与座位互斥
飞行和坐下互斥。C# 侧手写时，应在 `OnSeatEntered` 里调用 `actor.DisableFly(true)`，在 `OnSeatExited` 里调用 `actor.EnableFly()`：
```csharp
using Douyin;
using UnityEngine;

public class FlySafeSeat : DouyinMonoBehaviour
{
    private void SetFlyButtonEnable(DouyinActor actor, bool state)
    {
        if (actor == null || !actor.isBindMode) return;
        if (state) actor.EnableFly();
        else actor.DisableFly(true);
    }

    public override void OnSeatEntered(DouyinActor actor)
    {
        // ... 位置绑定 ...
        SetFlyButtonEnable(actor, false);   // 坐下时禁飞
    }

    public override void OnSeatExited(DouyinActor actor)
    {
        // ... 位置还原 ...
        SetFlyButtonEnable(actor, true);    // 站起时恢复飞行能力
    }
}
```

此外，如果业务需要"玩家发起飞行时自动站起"，可以在座位组件里监听 Actor 的 `onFlyStart` 事件：
```csharp
public override void OnFocus()
{
    var bindActor = DouyinActorService.GetLocalActor(); // 或 GetBindActor
    if (bindActor != null)
    {
        bindActor.onFlyStart.AddListener(() =>
        {
            // 隐藏坐下/站起按钮，避免飞行中还能坐下
        });
    }
}
```

---

## 五、示例 D：切换座位（SwitchSeat）
`SitDown` 的第二个参数 `switchSeat` 为 `true` 时，即使玩家已经坐在其他座位上，也可以直接切换到另一个具体座椅对象。它不会让第二个玩家进入当前已占用的座椅。
```csharp
using Douyin;
using UnityEngine;
using UnityEngine.UI;

public class SwitchableSeat : DouyinMonoBehaviour
{
    [SerializeField] private bool SwitchSeatFromSeat = true;
    private Button switchButton;

    public override void OnFocus()
    {
        switchButton = AddInteractorButton();
        if (switchButton == null) return;
        switchButton.onClick.AddListener(HandleSwitchSeat);
    }

    public override void OnLostFocus()
    {
        if (switchButton == null) return;
        switchButton.onClick.RemoveAllListeners();
        RemoveInteractorButton(switchButton);
        switchButton = null;
    }

    private void HandleSwitchSeat()
    {
        var actor = DouyinActorService.GetLocalActor();
        if (actor == null) return;
        // 允许从其他座位直接切换过来，无需先站起
        actor.SitDown(gameObject, SwitchSeatFromSeat);
    }
}
```

**注意**：`switchSeat = true` 时，SDK 内部会自动先派发原座位的 `OnSeatExited`，再派发新座位的 `OnSeatEntered`，业务侧不需要手动处理"先站起再坐下"。目标 GameObject 必须是另一个独立的座椅 NetworkObject，不能传 `VehicleRoot` 或 `SeatAnchor`。

---

## 六、示例 E：多座椅车辆

多座椅车辆应拆分为载具根对象和多个独立座椅对象：

```text
VehicleRoot NetworkObject
├── DriverSeat NetworkObject + DriverSeat : DouyinMonoBehaviour
└── GunnerSeat NetworkObject + GunnerSeat : DouyinMonoBehaviour
```

两个座椅组件分别调用自己的目标对象：

```csharp
// DriverSeat 组件
actor.SitDown(gameObject, true);

// GunnerSeat 组件
actor.SitDown(gameObject, true);
```

这里的两个 `gameObject` 必须是两个不同的座椅 NetworkObject。根载具组件只负责物理、主权和输入桥接；每个座椅组件独立处理 Trigger、按钮、`OnSeatEntered` 和 `OnSeatExited`。座椅占用以该对象的 `CurrentPlayer` 为准，业务占用变量按需增加。

当前 C# 侧没有开放 `RequestControllership` API。不要为了驾驶物理臆造或复制 Lua 的控制权调用；座椅框架负责座椅对象的控制权，载具根对象的物理控制应遵循当前 C# 网络载具实现提供的权限入口。

禁止以下写法：

```csharp
// 错误：同一个 NetworkObject 承载两个逻辑座椅
actor.SitDown(vehicleRoot.gameObject, true);
// 另一个玩家仍然不能进入同一个 vehicleRoot 座椅
```

---

## 七、示例 F：可选占用展示（自定义业务）
如果座位组件外部确实需要一个“当前有谁在坐”的远端展示、晚进房恢复或业务统计接口，可以补一层同步变量。它不用于替代平台 `CurrentPlayer`，也不是防止重复坐下的必需条件：
```csharp
using Douyin;
using Douyin.Netcode;
using UnityEngine;

public class OccupancyTrackedSeat : DouyinMonoBehaviour
{
    private NetworkVariable<int> occupiedBy = new(0); // 当前占用的 actorID，0 表示空闲

    public bool IsOccupied() => occupiedBy.Value != 0;

    public override void Awake()
    {
        base.Awake();

        occupiedBy.OnValueChanged = (prev, cur) =>
        {
            Debug.Log($"座位占用变化: {prev} -> {cur}");
        };
    }

    public override void OnSeatEntered(DouyinActor actor)
    {
        // ... 位置绑定 ...
        if (IsOwner)
        {
            occupiedBy.Value = actor.actorID;
        }
    }

    public override void OnSeatExited(DouyinActor actor)
    {
        // ... 位置还原 ...
        if (IsOwner && occupiedBy.Value == actor.actorID)
        {
            occupiedBy.Value = 0;
        }
    }
}
```

> ⚠️ 同步变量写入涉及主权；座位对象的主权归属由框架接管，但 `NetworkVariable` 写入仍要遵循"只在拥有主权的一端写"这条通用规则（`IsOwner`）。

---

## 八、C# 常见错误
### 1. `Awake` 必须调用 `base.Awake()`
派生类 `Awake` 里第一句必须调用 `base.Awake()`，否则 SDK 事件监听不会被注册。
