# Physics 碰撞过滤（CSharp）最佳实践

> 💡 **理论与机制指引**：关于碰撞过滤优先级（pair-wise 首选、Layer-based 兜底、IgnoreRaycast 常见误区）、有限重试与阻塞判断、保留 trigger 触发信号，请参考手册规则文档：[碰撞与触发器规范](../../Manual/%E2%85%A2.%20%E9%80%BB%E8%BE%91%E4%B8%8E%E8%84%9A%E6%9C%AC(Logic%26Scripting)/%E7%BC%96%E7%A0%81%E7%BA%A6%E6%9D%9F%E4%B8%8E%E5%BC%80%E5%8F%91%E8%A7%84%E8%8C%83/%E7%A2%B0%E6%92%9E%E4%B8%8E%E8%A7%A6%E5%8F%91%E5%99%A8%E8%A7%84%E8%8C%83.md) 与 [碰撞体与触发器](../../Manual/%E2%85%A0.%20%E6%A0%B8%E5%BF%83%E7%B3%BB%E7%BB%9F(Core)/%E7%89%A9%E7%90%86/%E7%A2%B0%E6%92%9E%E4%BD%93%E4%B8%8E%E8%A7%A6%E5%8F%91%E5%99%A8.md)。
> 本文仅提供碰撞过滤在 C# 侧的标准代码骨架 + 场景变体。

---

## 1. 状态变量

```csharp
using System.Collections.Generic;
using UnityEngine;

public class CollisionFilterController : DouyinMonoBehaviour
{
    private const float RETRY_INTERVAL = 0.5f;  // 重试间隔（秒）
    private const int MAX_RETRY_COUNT = 6;      // 最大重试次数（3 秒后阻塞）

    public string targetObjectName = "TargetObject";  // 目标场景对象名称
    private bool ignorePairsDone;
    private int retryCount;
    private float elapsed;
}
```

---

## 2. pair-wise IgnoreCollision helper

```csharp
// 获取一个 GameObject 子树内的所有实体 Collider（排除 trigger）
private static List<Collider> CollectSolidColliders(Transform root)
{
    var result = new List<Collider>();
    if (root == null) return result;
    var cols = root.GetComponentsInChildren<Collider>();
    foreach (var col in cols)
    {
        if (col != null && !col.isTrigger) result.Add(col);
    }
    return result;
}

// 逐对忽略两个物体的实体碰撞；保留双方的 trigger 触发信号
private static bool IgnoreCollisionBetween(Transform rootA, Transform rootB)
{
    var colsA = CollectSolidColliders(rootA);
    var colsB = CollectSolidColliders(rootB);
    if (colsA.Count == 0 || colsB.Count == 0) return false;

    foreach (var a in colsA)
    {
        foreach (var b in colsB)
        {
            Physics.IgnoreCollision(a, b, true);
        }
    }
    return true;
}
```

---

## 3. 有限重试发现对方资源

```csharp
// 尝试按已配置的名称找到目标场景对象
private Transform TryFindTarget()
{
    var target = GameObject.Find(targetObjectName);
    return target == null ? null : target.transform;
}

private void TryApplyIgnorePairs()
{
    if (ignorePairsDone) return;
    var target = TryFindTarget();
    if (target == null)
    {
        retryCount++;
        if (retryCount >= MAX_RETRY_COUNT)
        {
            // 无法稳定发现另一方 → 阻塞并在完成说明里标未完成，不降级
            Debug.LogWarning($"[collision-filtering] target not found: '{targetObjectName}', retries={retryCount}");
            return;
        }
        // 有限重试（下一个间隔再试）
        return;
    }

    if (IgnoreCollisionBetween(transform, target))
    {
        ignorePairsDone = true;
        Debug.Log($"[collision-filtering] pairs applied to {targetObjectName}");
    }
}

private void Start()
{
    TryApplyIgnorePairs();
}

// 有限重试:Update 里按间隔重试，达到 MAX_RETRY_COUNT 或成功后停止
private void Update()
{
    if (ignorePairsDone || retryCount >= MAX_RETRY_COUNT) return;
    elapsed += Time.deltaTime;
    if (elapsed >= RETRY_INTERVAL)
    {
        elapsed = 0f;
        TryApplyIgnorePairs();
    }
}
```

---

## 4. 场景变体

### 4.1 只过滤“挡板与球门门框”，保留“足球与挡板”

目标碰撞关系：

```
挡板 ↔ 球门门框: ignore
足球 ↔ 挡板: collide (保留)
足球 ↔ 球门门框: collide (保留)
```

只对第一 pair 调 `IgnoreCollisionBetween(挡板root, 球门门框root)`；其它 pair 不动。

### 4.2 抑制"玩家 ↔ 足球"硬挤反作用，保留实体接触施力与交互 Trigger 信号

- 球的实体 collider 走 [Collider-Layer与碰撞矩阵-CSharp](./Collider-Layer%E4%B8%8E%E7%A2%B0%E6%92%9E%E7%9F%A9%E9%98%B5-CSharp.md) 设 `Props(6)` → 玩家踩地检测穿过，实体碰撞仍在但不会顶飞；`OnActorCollisionEnter` 仍可作为接触施力入口。
- 如果对象还需要拾取或靠近交互，独立的大 sphere Trigger 保留 `OnActorTriggerEnter/Exit` 入口；它只负责交互生命周期，不重复施加接触冲量。
- **不用** `Physics.IgnoreCollision(球, 玩家胶囊)` —— `IgnoreCollision` 会同时屏蔽 trigger 与实体碰撞。

### 4.3 未明确目标碰撞关系但当前交互依赖 Trigger

只保留本对象的必要配置：

- 在 属性面板 中配置 Trigger 和实体 Collider。
- 不调用跨对象 `IgnoreCollision`。
- 明确记录尚未确定需要忽略碰撞的对象组合。

### 4.4 双 Collider 与过滤边界

碰撞过滤只处理“哪些实体 Collider pair 不参与求解”，不负责创建缺失的物理或交互入口：

- `isTrigger=false` 实体 Collider 仍是撞地、撞墙和 `OnActorCollisionEnter` 的来源。
- `isTrigger=true` Interaction Trigger 仍是 `OnActorTriggerEnter/Exit` 的来源。
- `Physics.IgnoreCollision` 的实体 Collider 遍历不能被误解为“添加 Trigger”；过滤完成后仍要独立检查交互 Trigger 是否存在。
- 不要通过关闭所有实体 Collider 来解决玩家无法交互，也不要通过只保留 Trigger 来解决物体穿地。

---

## 5. 验证

- 目标对象存在时，确认指定的实体 Collider pair 已忽略碰撞。
- 目标对象缺失时，确认有限重试结束后不再轮询。
- 双方的 Trigger 仍能触发进入和退出回调。
- 未指定的对象组合仍保持原有碰撞关系。

---

## 6. 常见坑 FAQ

| 现象 | 违反约束 | 修复 |
| --- | --- | --- |
| 用 `Physics.IgnoreLayerCollision(6, 8)` 关球 vs 玩家 | 全局层过滤会误伤同层其他对象，粒度过粗 | pair-wise `Physics.IgnoreCollision(ballCol, playerCol)` |
| 关掉玩家 vs 球后踢球触发也失效 | 未区分实体 Collider 与 Trigger，`IgnoreCollision` 把 Trigger 也一并关掉 | trigger 走 `isTrigger = true` 的 Collider，不参与 `IgnoreCollision` 逐对遍历 |
| 找不到对方 collider 时降级为"只过滤事件不实际过滤碰撞" | 事件过滤只掩盖回调，物理接触仍生效，等于没过滤 | 阻塞标记，不降级 |
| 无限轮询 target 直到发现 | 缺少上限，遇到目标不存在会永久轮询 | 有限重试（如 6 次）后阻塞 |
| 用 `gameObject.layer = 2`（IgnoreRaycast）代替 `IgnoreCollision` | `IgnoreRaycast` 只影响射线，不影响求解器接触，无法实现 pair-wise 过滤 | `IgnoreRaycast` 不能替代实体过滤 |
| 过滤后 Play 仍掉到地下 | 资源没有实体 `isTrigger=false` Collider | 补实体 Collider，并确认地面 Layer 与碰撞矩阵 |
| 过滤后无法靠近交互 | 资源没有独立 Interaction Trigger，或脚本不在 Trigger 同节点 | 补 `isTrigger=true` Trigger，并校验 Hamlet 回调组件归属 |
