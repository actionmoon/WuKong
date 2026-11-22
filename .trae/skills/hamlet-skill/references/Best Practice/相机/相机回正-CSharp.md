# 相机回正（CSharp）最佳实践

> 💡 **理论与机制指引**：关于 yaw 渐进回正的四条硬约束、Look 输入监听时序、扩展点契约、通用硬约束、常见坑，请参考手册：[相机视角控制.md](../../Manual/%E2%85%A0.%20%E6%A0%B8%E5%BF%83%E7%B3%BB%E7%BB%9F(Core)/%E7%8E%A9%E5%AE%B6%E7%BD%91%E7%BB%9C%E5%AF%B9%E8%B1%A1/%E7%9B%B8%E6%9C%BA%E6%8E%A7%E5%88%B6/%E7%9B%B8%E6%9C%BA%E8%A7%86%E8%A7%92%E6%8E%A7%E5%88%B6.md)。
> 本文仅提供相机回正在 C# 侧的标准代码骨架 + 三个业务变体。

---

## 1. 最小可用骨架（完整闭环）

由 6 段代码组成：状态字段、Look 输入注册 / 解绑、`Start` / `OnDestroy` 集成、`LateUpdate` 渐进对齐、宿主扩展点默认实现。业务变体只覆写扩展点，**不要**改动本骨架结构。

### 1.1 状态字段（类顶部）

```csharp
using Douyin.Netcode;
using UnityEngine;
using UnityEngine.Events;

public class CameraAlignController : DouyinMonoBehaviour
{
    [SerializeField] private float cameraAlignSpeed = 90f;   // 回正最大角速度（度/秒）
    [SerializeField] private float cameraAlignGrace = 0.5f;  // 玩家最近一次操作视角后的冷却时间（秒）

    // 通用硬约束 #6：顶层声明
    private bool isLookingActive;
    private float lastLookTime = float.NegativeInfinity;

    // 保存 handler 引用（通用硬约束 #5：精准解绑）
    private UnityAction _onLookStart;
    private UnityAction<Vector2> _onLookPerform;
    private UnityAction _onLookCancel;

    // ...（后续 §1.2 – §1.6 方法定义）
}
```

### 1.2 Look 输入注册

```csharp
private void RegisterCameraAlignInputListeners()
{
    _onLookStart = () =>
    {
        isLookingActive = true;
        lastLookTime = Time.time;
    };
    _onLookPerform = _ =>
    {
        isLookingActive = true;
        lastLookTime = Time.time;
    };
    _onLookCancel = () =>
    {
        isLookingActive = false;
        lastLookTime = Time.time;
    };

    DouyinInputService.onLookInputStart.AddListener(_onLookStart);
    DouyinInputService.onLookInputPerform.AddListener(_onLookPerform);
    DouyinInputService.onLookInputCancel.AddListener(_onLookCancel);
}
```

### 1.3 Look 输入解绑

```csharp
private void RemoveCameraAlignInputListeners()
{
    if (_onLookStart != null)
    {
        DouyinInputService.onLookInputStart.RemoveListener(_onLookStart);
    }
    if (_onLookPerform != null)
    {
        DouyinInputService.onLookInputPerform.RemoveListener(_onLookPerform);
    }
    if (_onLookCancel != null)
    {
        DouyinInputService.onLookInputCancel.RemoveListener(_onLookCancel);
    }
}
```

### 1.4 `Start` / `OnDestroy` 集成

```csharp
private void Start()
{
    // ...宿主自身的输入 / 业务初始化...
    RegisterCameraAlignInputListeners();  // Manual §4.3：宿主输入之后再注册
}

private void OnDestroy()
{
    // ...宿主自身的输入 / 业务销毁...
    RemoveCameraAlignInputListeners();    // Manual §4.3：宿主输入解绑之后再清理
}
```

### 1.5 `LateUpdate` 渐进对齐

```csharp
private void LateUpdate()
{
    // Manual §4.2：逐项 guard
    if (isLookingActive) return;
    if (Time.time - lastLookTime < cameraAlignGrace) return;

    var targetYaw = GetCameraAlignTargetYaw();
    if (targetYaw == null) return;

    var speedScale = GetCameraAlignSpeedScale();
    if (speedScale <= 0) return;

    var currentYaw = DouyinCameraService.GetYaw();
    if (currentYaw == null) return;                                       // 通用硬约束 #1

    // 回正硬约束 #3：Mathf.DeltaAngle 取最短角差
    var delta = Mathf.DeltaAngle(currentYaw.Value, targetYaw.Value);

    // 回正硬约束 #4：按最大步长渐进
    var maxStep = cameraAlignSpeed * speedScale * Time.deltaTime;
    float step;
    if (Mathf.Abs(delta) <= maxStep)
    {
        step = delta;
    }
    else if (delta >= 0)
    {
        step = maxStep;
    }
    else
    {
        step = -maxStep;
    }

    DouyinCameraService.SetYaw(currentYaw.Value + step);
}
```

### 1.6 宿主扩展点（默认空实现）

```csharp
// 返回当前希望对齐到的 yaw（度），不需要对齐时返回 null
protected virtual float? GetCameraAlignTargetYaw() => null;

// 返回 [0, 1] 范围的速度缩放；返回 0 等价于不对齐
protected virtual float GetCameraAlignSpeedScale() => 1f;
```

子类**必须覆写**这两个方法以提供业务语义；不覆写则默认完全不对齐。

---

## 2. 业务变体 A：驾驶载具时回正到车头方向

依赖 `seat-alignment` 提供的 `hasPassenger` 和 `input-listener` 提供的 `moveVec` / `DEAD_ZONE`。只在前进油门时回正，油门越深回正越积极。

```csharp
public class DrivingCameraAlign : CameraAlignController
{
    // 由 seat / input 模块提供
    private bool hasPassenger;
    private Vector2 moveVec;
    private const float DEAD_ZONE = 0.1f;

    protected override float? GetCameraAlignTargetYaw()
    {
        if (!hasPassenger) return null;
        if (moveVec.y < DEAD_ZONE) return null;  // 只在前进油门时对齐
        return transform.rotation.eulerAngles.y;
    }

    protected override float GetCameraAlignSpeedScale()
    {
        if (!hasPassenger) return 0f;
        return Mathf.Clamp01(moveVec.y);  // 油门越深回正越积极
    }
}
```

---

## 3. 业务变体 B：进入触发区强制回正到固定朝向

进入触发区时锁定当前触发器的朝向为目标 yaw，离开时清空。适合剧情引导 / 传送落点。

```csharp
public class TriggerZoneCameraAlign : CameraAlignController
{
    private float? forcedYaw;

    public override void OnActorTriggerEnter(DouyinActor actor)
    {
        base.OnActorTriggerEnter(actor);
        if (actor == null || !actor.isLocal) return;
        forcedYaw = transform.rotation.eulerAngles.y;
    }

    public override void OnActorTriggerExit(DouyinActor actor)
    {
        base.OnActorTriggerExit(actor);
        if (actor == null || !actor.isLocal) return;
        forcedYaw = null;
    }

    protected override float? GetCameraAlignTargetYaw() => forcedYaw;

    protected override float GetCameraAlignSpeedScale() => forcedYaw == null ? 0f : 1f;
}
```

---

## 4. 业务变体 C：朝动态目标对齐（锁定 NPC / UI 焦点）

由外部设置 `cameraTarget`（`Transform`）；模块朝目标的水平方向渐进回正。

```csharp
public class TrackTargetCameraAlign : CameraAlignController
{
    public Transform cameraTarget;

    protected override float? GetCameraAlignTargetYaw()
    {
        if (cameraTarget == null) return null;
        var camera = DouyinCameraService.GetCamera();
        if (camera == null) return null;
        var dir = cameraTarget.position - camera.transform.position;
        if (dir.sqrMagnitude < 0.0001f) return null;
        // 以世界 Y 轴为旋转轴，根据水平方向计算 yaw
        return Mathf.Atan2(dir.x, dir.z) * Mathf.Rad2Deg;
    }

    protected override float GetCameraAlignSpeedScale() => cameraTarget == null ? 0f : 0.6f;
}
```

> ⚠️ **注意**：这里读 `camera.transform.position` 仅用于**计算方向**，没有写入相机姿态，符合"不直接写 `Camera.main.transform`"的通用硬约束 #2。
