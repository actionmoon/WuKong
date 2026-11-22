# 输送带（CSharp）最佳实践

> 本文仅提供 C# 侧输送带的实现骨架。场景物理边界请参考 [刚体与运动模型](../../Manual/%E2%85%A0.%20核心系统%28Core%29/物理/刚体与运动模型.md)、[碰撞体与触发器](../../Manual/%E2%85%A0.%20核心系统%28Core%29/物理/碰撞体与触发器.md) 和 [触发器生命周期约束](../../Manual/%E2%85%A2.%20逻辑与脚本%28Logic%26Scripting%29/编码约束与开发规范/触发器生命周期约束.md)。

---

## 0. 前置配置

输送带使用两个独立的 Trigger 区域，分别驱动交互与接触驱动逻辑：

| Trigger | isTrigger | 脚本 | 用途 |
| --- | --- | --- | --- |
| Interaction Trigger | `true` | `ConveyorBelt` | 玩家靠近后显示启停按钮 |
| Contact Trigger | `true` | `BeltDrive` | 玩家/刚体接触带面后驱动位移 |

- 两个 Trigger 都是 `isTrigger=true`，**不共用同一个 Collider**。
- Interaction Trigger 与 `ConveyorBelt` 挂在同一个 GameObject 上，用于 Hamlet 的 `OnActorTriggerEnter/Exit`。
- Contact Trigger 与 `BeltDrive` 挂在同一个 GameObject 上（例如子节点 `DriveZone`）。父节点脚本不会收到子节点 Collider 的 Hamlet Actor 回调。
- Contact Trigger 的尺寸应**沿输送方向完整覆盖前后两端滚筒**（前后各外扩至少一个滚筒半径 + 一点余量），避免玩家/刚体走到滚筒上方时脱离 Trigger 而失去驱动、卡在滚筒顶部推不动。
- 带面（BeltSurface）本身可以再挂一个 `isTrigger=false` 的实体 BoxCollider 提供 Actor / Cube 的站立支撑；`BeltDrive` 不依赖它。

---

## 1. ConveyorBelt 脚本

### 1.1 字段声明

```csharp
using UnityEngine;

public class ConveyorBelt : DouyinMonoBehaviour
{
    [SerializeField] private Transform beltSurface;
    [SerializeField] private Transform rollerFront;
    [SerializeField] private Transform rollerBack;
    [SerializeField] private Renderer beltRenderer;
    [SerializeField] private float moveSpeed = 1.5f;
    [SerializeField] private float rollerRadius = 0.175f;

    // 通过项目现有同步变量 API 声明 isRunning:bool = true
    private bool isRunning = true;

    private float uvOffset;
    private ulong? localActorId;
    private Button interactionButton;
    private bool ownershipPending;
}
```

### 1.2 Layer 初始化

```csharp
private void Start()
{
    SetLayerRecursive(transform, 0);
}

private static void SetLayerRecursive(Transform current, int layer)
{
    if (current == null) return;
    current.gameObject.layer = layer;
    for (int i = 0; i < current.childCount; i++)
    {
        SetLayerRecursive(current.GetChild(i), layer);
    }
}
```

### 1.3 OnNetworkSpawn

```csharp
private void OnNetworkSpawn()
{
    // 按项目现有同步变量 API 注册 isRunning 变化回调，回调内调用 RefreshButtonText()。
    RefreshButtonText();
}
```

### 1.4 视觉 FixedUpdate（滚筒旋转 + UV 滚动）

```csharp
private void FixedUpdate()
{
    if (!isRunning) return;

    float dt = Time.fixedDeltaTime;
    float angleDeg = moveSpeed / Mathf.Max(rollerRadius, 0.001f)
        * dt * Mathf.Rad2Deg;

    if (rollerFront != null)
    {
        rollerFront.Rotate(0f, angleDeg, 0f, Space.Self);
    }
    if (rollerBack != null)
    {
        rollerBack.Rotate(0f, angleDeg, 0f, Space.Self);
    }

    if (beltRenderer != null)
    {
        uvOffset += moveSpeed * dt;
        if (uvOffset >= 1f) uvOffset -= 1f;
        beltRenderer.material.SetTextureOffset(
            "_BaseMap",
            new Vector2(0f, -uvOffset));
    }
}
```

### 1.5 Interaction Trigger

```csharp
public override void OnActorTriggerEnter(DouyinActor actor)
{
    if (actor == null || !actor.isLocal) return;
    localActorId = actor.actorID;
    EnableInteraction();
}

public override void OnActorTriggerExit(DouyinActor actor)
{
    if (actor == null || !actor.isLocal) return;
    DisableInteraction();
    localActorId = null;
}
```

### 1.6 交互按钮

```csharp
private void RefreshButtonText()
{
    if (interactionButton == null) return;
    var label = interactionButton.GetComponentInChildren<UnityEngine.UI.Text>(true);
    if (label == null) return;
    label.text = isRunning ? "关闭输送带" : "启动输送带";
}

private void OnFocus()
{
    interactionButton = AddInteractorButton();
    RefreshButtonText();
}

private void OnLostFocus()
{
    RemoveAllInteractorButtons();
    interactionButton = null;
}
```

### 1.7 启停状态

```csharp
private void OnInteractorButtonClick(int index)
{
    if (index != 1 || !localActorId.HasValue) return;
    var actor = DouyinActorService.GetActorById(localActorId.Value);
    if (actor == null) return;
    actor.Interact(gameObject);
}

private void OnInteract(DouyinActor actor)
{
    if (actor == null) return;
    EnsureOwnership(() => SetRunning(!isRunning));
}

private void SetRunning(bool value)
{
    if (!IsNetworkSettled || !IsOwner) return;
    isRunning = value;
    RefreshButtonText();
}

private void EnsureOwnership(System.Action action)
{
    if (action == null || !IsNetworkSettled) return;

    if (IsOwner)
    {
        action();
        return;
    }

    if (ownershipPending) return;
    ownershipPending = true;
    RequestOwnership(success =>
    {
        ownershipPending = false;
        if (success) action();
    });
}
```

### 1.8 OnNetworkDespawn

```csharp
private void OnNetworkDespawn()
{
    RemoveAllInteractorButtons();
    interactionButton = null;
    localActorId = null;
}
```

---

## 2. BeltDrive 脚本（双通道驱动）

带面上的接触对象分两类，用两条独立通道处理：

- **通道 A**：本地 `DouyinActor` — 通过 Hamlet 的 `OnActorTriggerEnter/Exit` 收集，`FixedUpdate` 里 `actor.position = actor.position + delta`。
- **通道 B**：非 Actor 的普通 `Rigidbody` — 通过 Unity 原生 `OnTriggerEnter/Exit` + `attachedRigidbody` 收集，`FixedUpdate` 里 `rb.MovePosition(rb.position + delta)`。

Actor 的 Rigidbody 会同时触发两条通道，用 `actorRbIds` 集合把它从通道 B 里排除，避免双重驱动。

### 2.1 字段声明

```csharp
using System.Collections.Generic;
using UnityEngine;

public class BeltDrive : DouyinMonoBehaviour
{
    [SerializeField] private ConveyorBelt conveyor;
    [SerializeField] private Transform beltForwardRef;
    [SerializeField] private float moveSpeed = 1.5f;

    private readonly Dictionary<int, Rigidbody> activeBodies = new();
    private readonly Dictionary<ulong, DouyinActor> activeActors = new();
    private readonly HashSet<int> actorRbIds = new();

    private readonly List<int> deadBodies = new();
    private readonly List<ulong> deadActors = new();
}
```

### 2.2 启停读取

```csharp
private bool IsRunning()
{
    return conveyor != null && conveyor.IsRunning;
}
```

### 2.3 通道 A：本地 Actor

```csharp
public override void OnActorTriggerEnter(DouyinActor actor)
{
    if (actor == null || !actor.isLocal) return;
    if (!activeActors.TryAdd(actor.actorID, actor)) return;

    if (actor.gameObject != null)
    {
        var rb = actor.gameObject.GetComponent<Rigidbody>();
        if (rb != null) actorRbIds.Add(rb.GetInstanceID());
    }
}

public override void OnActorTriggerExit(DouyinActor actor)
{
    if (actor == null || !actor.isLocal) return;
    if (!activeActors.Remove(actor.actorID)) return;

    if (actor.gameObject != null)
    {
        var rb = actor.gameObject.GetComponent<Rigidbody>();
        if (rb != null) actorRbIds.Remove(rb.GetInstanceID());
    }
}
```

### 2.4 通道 B：非 Actor Rigidbody

```csharp
private void OnTriggerEnter(Collider other)
{
    var rb = other != null ? other.attachedRigidbody : null;
    if (rb == null) return;
    int key = rb.GetInstanceID();
    if (actorRbIds.Contains(key)) return;
    activeBodies[key] = rb;
}

private void OnTriggerExit(Collider other)
{
    var rb = other != null ? other.attachedRigidbody : null;
    if (rb == null) return;
    activeBodies.Remove(rb.GetInstanceID());
}
```

`other.attachedRigidbody` 会顺着子 Collider 找到实体 Rigidbody，复合模型（多个子 Collider 挂在同一 Rigidbody 下）天然去重。静态无 Rigidbody 的 Collider 返回 `null`，直接跳过。

### 2.5 FixedUpdate（双通道驱动）

```csharp
private void FixedUpdate()
{
    if (!IsRunning() || beltForwardRef == null) return;
    if (activeBodies.Count == 0 && activeActors.Count == 0) return;

    float dt = Time.fixedDeltaTime;
    Vector3 fwd = beltForwardRef.forward;
    Vector3 delta = new Vector3(
        fwd.x * moveSpeed * dt,
        0f,
        fwd.z * moveSpeed * dt);

    deadBodies.Clear();
    foreach (var kv in activeBodies)
    {
        if (kv.Value == null) { deadBodies.Add(kv.Key); continue; }
        kv.Value.MovePosition(kv.Value.position + delta);
    }
    foreach (var k in deadBodies) activeBodies.Remove(k);

    deadActors.Clear();
    foreach (var kv in activeActors)
    {
        if (kv.Value == null) { deadActors.Add(kv.Key); continue; }
        Vector3 p = kv.Value.position;
        kv.Value.position = new Vector3(p.x + delta.x, p.y, p.z + delta.z);
    }
    foreach (var k in deadActors) activeActors.Remove(k);
}
```

关键点：
- **通道 A 用 `actor.position` 叠加**：`DouyinActor` 有自己的运动控制器，`Rigidbody.MovePosition` 对它无效。
- **通道 B 用 `MovePosition`**：普通刚体（如 `ConveyorCube`）走 Unity 物理引擎的运动学位移，保留碰撞检测。
- **`delta.y = 0`**：只叠 XZ；Y 方向见后文" Y 方向策略"单独处理。
- **循环内 `null` 检查**：Rigidbody / Actor 被销毁时清理集合；`deadBodies` / `deadActors` 复用避免遍历中修改字典报错。

### 2.6 OnDisable / OnDestroy

```csharp
private void ClearAll()
{
    activeBodies.Clear();
    activeActors.Clear();
    actorRbIds.Clear();
}

private void OnDisable()
{
    ClearAll();
}

private void OnDestroy()
{
    ClearAll();
}
```

---

## 3. Y 方向策略

- 每帧的位移增量 `delta` 强制置 `y = 0`：`new Vector3(fwd.x * v * dt, 0f, fwd.z * v * dt)`。
- Actor 的 Y 完全由 Actor 自身控制器维护（重力、跳跃、着地判定）。
  - 缓斜带面（坡度 < `DouyinActor.minSlopeAngleLimit`）无需手动写 Y：Actor 会自动贴地、顺 XZ 方向沿斜面移动。
  - 陡坡（超过 `minSlopeAngleLimit`）会打滑：需另起 "射线贴地 + 沿切向推" 方案。
  - 垂直电梯：只能走 `actor.Immobilize(true)` + 完全接管 `actor.position`，玩家在电梯上无法自由走动，不在本骨架范围内。
- 非 Actor Rigidbody 同样只叠 XZ：`rb.MovePosition(rb.position + delta)` 的 `delta.y` 为 0，Y 归 Unity 物理引擎（重力 + 碰撞）。

---

## 4. 约束

- Interaction Trigger 与 Contact Trigger 使用**独立 Collider 和独立脚本**，都是 `isTrigger=true`。
- Interaction Trigger 使用 `OnActorTriggerEnter/Exit`；Contact Trigger 同时使用 `OnActorTriggerEnter/Exit`（通道 A）和 Unity 原生 `OnTriggerEnter/Exit`（通道 B）。
- `OnActorTriggerEnter/Exit` 与 `OnTriggerEnter/Exit` 首先过滤 `null` 与 `actor.isLocal` / `attachedRigidbody == null`。
- **本地 Actor 用 `actor.position` 叠加，禁止用 `Rigidbody.MovePosition`**（对 DouyinActor 无效）。
- **非 Actor Rigidbody 用 `rb.MovePosition(rb.position + delta)`**，不要写 `rb.velocity`（会与刚体自身重力/输入打架）。
- 通道 B 必须用 `attachedRigidbody` 归一化到实体，避免复合子 Collider 重复入表。
- `actorRbIds` 排除 Actor 的 Rigidbody，避免同一 Actor 被双通道各推一次。
- `delta.y = 0`：只叠 XZ，Y 交给 Actor 控制器 / Unity 物理。
- `isRunning` 只由主权方写入；驱动逻辑（`FixedUpdate`）不需要主权。
- 不修改远端 Actor（`actor.isLocal` 已过滤）。
- 不移动整棵输送带模型；带面视觉滚动通过 UV `SetTextureOffset` 实现。
- `OnDisable` / `OnDestroy` 时清空三张容器。

---

## 5. 常见坑 FAQ

| 现象 | 违反 / 误用 | 修复 |
| --- | --- | --- |
| Actor 站上去纹丝不动 | 对 Actor 的 Rigidbody 用了 `MovePosition` | DouyinActor 有自己的运动控制器，Rigidbody 只做碰撞外壳；改用 `actor.position` 叠加（通道 A） |
| Actor 被拽下去 / 跳跃被打断 | 每帧写回 `actor.position.y`（含 `delta.y`） | 只叠 XZ，保留 `p.y`：`new Vector3(p.x + dx, p.y, p.z + dz)` |
| 复合模型每接触一次多计几份 | 未用 `attachedRigidbody` 归一化 | `var rb = other.attachedRigidbody; if (rb == null) return;` |
| 同一 Actor 被双通道各推一次 | 未把 Actor rb id 存入 `actorRbIds` | 通道 A Enter 存入 `actorRbIds.Add(rb.GetInstanceID())`，通道 B Enter 命中即跳过 |
| 关闭输送带后 Actor 仍在滑 | 用了 `MoveContinuously` 却没在 Exit/关闭时 `StopMove` | 本骨架不使用 `MoveContinuously`（会屏蔽玩家摇杆输入）；`actor.position` 叠加天然停 |
| 远端观察者的 Cube 位置飘 | 每端各自本地驱动导致同一 Rigidbody 双端物理各跑一遍 | 主权方 `NetSpawn` 出的对象由 SDK 网络同步 Rigidbody；驱动只在本地跑，同步兜底表现层 |
| 玩家跳起被吸回带面 | `delta.y` 未清 0 或错把 Actor 走了 `MovePosition` 分支 | 严格保持 `delta.y = 0`，通道 A 用 `actor.position`、通道 B 用 `MovePosition` |
| Contact Trigger 反复 Enter/Exit 抖动 | `DriveZone` Trigger 上下厚度过贴带面边缘 | 略放大 Trigger 上下厚度（如 y=0.3），避免玩家轻微上下位移触发抖动 |
| 关闭输送带后 `activeBodies` 没清 | Exit 时未对称移除 | `OnTriggerExit` / `OnActorTriggerExit` 中 `Remove(key)`；`OnDisable/OnDestroy` 兜底 `ClearAll` |
| 运行时 Destroy Rigidbody 报错 | 遍历字典时未处理 `null` 引用 | 用 `deadBodies` 复用列表收集失效 key，遍历后统一 `Remove`，避免遍历中修改字典 |
