# Trigger 结算去重（CSharp）最佳实践

> 💡 **理论与机制指引**：关于 Trigger 入口回调、单一入口原则、trigger 尺寸建议，请参考手册规则文档：[物理结算与实体去重约束](../../Manual/%E2%85%A2.%20%E9%80%BB%E8%BE%91%E4%B8%8E%E8%84%9A%E6%9C%AC(Logic%26Scripting)/%E7%BC%96%E7%A0%81%E7%BA%A6%E6%9D%9F%E4%B8%8E%E5%BC%80%E5%8F%91%E8%A7%84%E8%8C%83/%E7%89%A9%E7%90%86%E7%BB%93%E7%AE%97%E4%B8%8E%E5%AE%9E%E4%BD%93%E5%8E%BB%E9%87%8D%E7%BA%A6%E6%9D%9F.md)、[碰撞与触发器规范](../../Manual/%E2%85%A2.%20%E9%80%BB%E8%BE%91%E4%B8%8E%E8%84%9A%E6%9C%AC(Logic%26Scripting)/%E7%BC%96%E7%A0%81%E7%BA%A6%E6%9D%9F%E4%B8%8E%E5%BC%80%E5%8F%91%E8%A7%84%E8%8C%83/%E7%A2%B0%E6%92%9E%E4%B8%8E%E8%A7%A6%E5%8F%91%E5%99%A8%E8%A7%84%E8%8C%83.md) 与 [碰撞体与触发器](../../Manual/%E2%85%A0.%20%E6%A0%B8%E5%BF%83%E7%B3%BB%E7%BB%9F(Core)/%E7%89%A9%E7%90%86/%E7%A2%B0%E6%92%9E%E4%BD%93%E4%B8%8E%E8%A7%A6%E5%8F%91%E5%99%A8.md)。

---

## 1. Detector 侧：实体级归一化

**为什么要归一化**：结算去重的粒度是**玩法实体**，不是底层 Collider。嵌套模型（一个 Rigidbody 下挂多个子 Collider，例如球的多层碰撞、复合收集品的各个 mesh）触发 Trigger 时，物理层会为每个子 Collider 单独回调一次。如果按 Collider 去重（`reportedInside[collider]`），复合模型的多个子 collider 会各被识别为独立"新实体"，业务逻辑会重复执行。

**归一化优先级**（`NormalizeToEntity` 按顺序尝试）：

1. `col.attachedRigidbody.gameObject`——同一 Rigidbody 下的所有子 collider 都归为同一个实体。
2. 沿 `col.transform.parent` 向上找到最顶层 GameObject。

**例外**：如果 collider 本身就是独立玩法对象（如巨型收集品由 10 个独立小球组成、每球独立记分），可以走 collider-level 去重（见后文"每个 collider 本身就是独立玩法对象"变体），但要在实现说明中显式声明这个例外。

```csharp
using System.Collections.Generic;
using UnityEngine;

public struct Outcome
{
    public int round;
    public string source;
    public int target;
    public string outcomeType;
    // payload...
}

public class OutcomeDetector : DouyinMonoBehaviour
{
    // 归一化到玩法实体：优先 attachedRigidbody.gameObject，其次场景对象根节点
    private static GameObject NormalizeToEntity(Collider col)
    {
        if (col == null) return null;
        if (col.attachedRigidbody != null)
        {
            return col.attachedRigidbody.gameObject;
        }
        // 兜底：找到当前场景层级中的最上层对象
        Transform t = col.transform;
        while (t.parent != null) t = t.parent;
        return t.gameObject;
    }

    // Detector 本地降噪：按实体 + roundId 记录已上报
    private readonly Dictionary<int, int> reportedEntities = new Dictionary<int, int>();
    private int currentRoundId = 1;

    public string detectorId = "goal-detector-1";  // 本 detector 的稳定 id

    private void OnTriggerEnter(Collider other)
    {
        var entity = NormalizeToEntity(other);
        if (entity == null) return;

        int entityKey = entity.GetInstanceID();

        // 本地降噪：同一 round 内同一实体只上报一次
        if (reportedEntities.TryGetValue(entityKey, out int reportedAt) && reportedAt == currentRoundId) return;
        reportedEntities[entityKey] = currentRoundId;

        // 交给集中结算组件做最终仲裁
        OutcomeManager.Instance?.ReportOutcome(new Outcome
        {
            round = currentRoundId,
            source = detectorId,
            target = entityKey,       // 玩法实体的稳定 id
            outcomeType = "goal",
            // payload...
        });
    }

    public void OnNewRound(int roundId)
    {
        currentRoundId = roundId;
        reportedEntities.Clear();
    }
}
```

---

## 2. 结算管理器：幂等仲裁

会修改**全局状态**的结果（得分、通关、发奖）应交给唯一的结算管理器做最终幂等仲裁。Detector 只做本地降噪和上报。

**幂等 key 至少包含 4 个字段**：`round + source + target + outcomeType`

- `round`：当前结算轮次（`roundId`）。
- `source`：本 detector 的稳定 id。
- `target`：玩法实体的稳定 id（`entity.GetInstanceID()` 或 registry id）。
- `outcomeType`：`"goal"` / `"hit"` / `"pickup"` 等。

**多 detector 场景**：单 source 场景 `round + source + target + type` 组合唯一；多 detector 报同一 outcome（场景里有 3 个 goal detector 都能触发进球）时，若希望**只**接受第一个上报，key 里去掉 `source`；若希望每个 detector 独立记录，key 里保留 `source`。默认建议**保留 source**，再由结算逻辑决定是否二次仲裁。

**重复上报直接返回 `rejected reason`**，不重复改分数或状态。

```csharp
public class OutcomeManager : DouyinMonoBehaviour
{
    public static OutcomeManager Instance;

    private readonly Dictionary<string, bool> settledOutcomes = new Dictionary<string, bool>();  // { ["round=1|source=goal|target=ball|type=goal"] = true }
    private bool isSettled;
    private bool pendingReset;

    private static string MakeIdempotentKey(Outcome outcome)
    {
        return $"round={outcome.round}|source={outcome.source}|target={outcome.target}|type={outcome.outcomeType}";
    }

    public struct ReportResult { public bool accepted; public string reason; }

    public ReportResult ReportOutcome(Outcome outcome)
    {
        var key = MakeIdempotentKey(outcome);

        // 重复上报直接拒绝
        if (settledOutcomes.ContainsKey(key))
        {
            return new ReportResult { accepted = false, reason = "duplicate" };
        }
        if (isSettled || pendingReset)
        {
            return new ReportResult { accepted = false, reason = "window_closed" };
        }

        settledOutcomes[key] = true;
        isSettled = true;
        pendingReset = true;

        // 处理结算逻辑（加分、播动画、通知 UI 等）
        ApplyScore(outcome);

        // 派发 reset，但 reset 完成后开闸必须跨帧
        ScheduleReset();

        return new ReportResult { accepted = true };
    }

    private void ApplyScore(Outcome outcome) { /* ... */ }
    private void ScheduleReset() { /* ... */ }
}
```

---

## 3. Reset 跨帧开闸（关键）

结算管理器接受结果后，如果同步派发 `reset` / `animation` / `display` / `cleanup` 事件，下游回调**不得在同一调用栈里**把当前 round 重新打开。以下调用链是常见误区：

```
ReportOutcome → DispatchReset → target handler → CompleteReset → settled = false ↓
                                                                             同栈解锁
                                                                             ↓
                                                                             剩余 collider 遍历
                                                                             ↓
                                                                             再次触发结算
```

**关键规则**：`isSettled = false` / `pendingReset = false` / `roundId++` / `reportedEntities.Clear()` 这类**开闸动作必须跨过当前物理帧和剩余 collider 遍历**。两种实现方式：写法 A 跨帧 tick、写法 B 短冷却窗口。

**错误示例**（同栈解锁）：

```csharp
// ❌ 常见误区：ReportOutcome → DispatchReset → CompleteReset 同栈解锁
public void CompleteReset()
{
    isSettled = false;         // ❌ 与 ReportOutcome 同一调用栈
    pendingReset = false;      // ❌ 剩余 collider 遍历会当作新 round 命中
    currentRoundId += 1;       // ❌ 同帧 round 自增
}
```

**正确写法 A（跨帧 tick）**：

```csharp
public class OutcomeManager : DouyinMonoBehaviour
{
    public static OutcomeManager Instance;

    private readonly Dictionary<string, bool> settledOutcomes = new Dictionary<string, bool>();
    private bool isSettled;
    private bool pendingReset;
    private bool nextRoundPending;
    private int currentRoundId = 1;

    public OutcomeDetector[] detectors;  // 编辑器里挂上所有需要感知 round 切换的 detector

    public void CompleteReset()
    {
        // 只标记"reset 已完成"，不开闸
        nextRoundPending = true;
    }

    // 跨帧 tick 里检查 nextRoundPending，把 round 推到下一帧
    private void Update()
    {
        if (!nextRoundPending) return;
        nextRoundPending = false;
        isSettled = false;
        pendingReset = false;
        currentRoundId += 1;
        // 通知所有 Detector"新 round 开始"（如果 Detector 需要感知）
        if (detectors != null)
        {
            foreach (var d in detectors)
            {
                if (d != null) d.OnNewRound(currentRoundId);
            }
        }
    }
}
```

**正确写法 B（短冷却窗口）**：

```csharp
public class OutcomeManager : DouyinMonoBehaviour
{
    private const float RESET_COOLDOWN = 0.2f;  // 200ms
    private float resetCompletedAt = -999f;

    private bool isSettled;
    private bool pendingReset;
    private int currentRoundId = 1;

    public OutcomeDetector[] detectors;

    public void CompleteReset()
    {
        resetCompletedAt = Time.time;
    }

    private void Update()
    {
        if (resetCompletedAt > 0f && Time.time - resetCompletedAt >= RESET_COOLDOWN)
        {
            resetCompletedAt = -999f;
            isSettled = false;
            pendingReset = false;
            currentRoundId += 1;
            if (detectors != null)
            {
                foreach (var d in detectors)
                {
                    if (d != null) d.OnNewRound(currentRoundId);
                }
            }
        }
    }
}
```

---

## 4. 场景变体

### 4.1 每个 collider 本身就是独立玩法对象（少见）

例如：一个巨型收集品由 10 个独立小球组成，每小球独立记分。此时可以走 collider-level 去重（第 1 节归一化规则允许的例外）：

```csharp
private readonly Dictionary<int, bool> reportedColliders = new Dictionary<int, bool>();

private void OnTriggerEnter(Collider other)
{
    int key = other.GetInstanceID();
    if (reportedColliders.ContainsKey(key)) return;
    reportedColliders[key] = true;
    OutcomeManager.Instance?.ReportOutcome(new Outcome { target = key /* ... */ });
}
```

**但要在实现说明中明确声明这个例外**——默认应走实体级归一化。

### 4.2 多个 Detector 报同一 outcome

例如场景里有 3 个 goal detector 都能触发进球判定。key 组成决定结算管理器的仲裁策略：

```csharp
// Detector A 先上报：round=1|source=A|target=ball|type=goal → accepted
// Detector B 同帧上报：round=1|source=B|target=ball|type=goal → 也会 accepted？
// 如果不希望 B 也 accepted，key 里去掉 source，只用 round|target|type
```

按业务需要决定 key 组成。默认建议 **key 里保留 source**，再由结算逻辑决定是否二次仲裁。

---

## 5. 常见坑 FAQ

| 现象 | 违反约束 | 修复 |
| --- | --- | --- |
| 一次进球被算成 3 ~ 5 分 | 未归一化到玩法实体，多个子 collider / detector 各上报一次 | 上报前归一化到实体 root，且结算管理器的幂等 key 保留 `target = entity.id` |
| Reset 后同一帧再次进球又被算一次 | 同帧内清了 dedup set 但 `currentRoundId` 未自增，剩余 collider 遍历会当新一轮命中 | 先 `currentRoundId += 1` 再清 set，或使用短冷却窗口拦截同帧再触发 |
| 同 pair 二次上报被结算管理器接受 | 幂等 key 组成缺失，未包含 `roundId` 或 `type` | 幂等 key 必须包含 `roundId \| source \| target \| type` 四字段 |
| 嵌套模型每个子 mesh 都触发一次 OnTriggerEnter | 未归一化，走到了 collider 级 | 通过 `other.attachedRigidbody.gameObject` 归一化到玩法实体 root |
| `currentRoundId` 在多个 Reset 场景里被重复设为同一值 | 跨帧 tick 时未保证单调自增 | `currentRoundId` 始终自增，不复用旧值；Reset 只增 id + 清 set |
| 一次接触被算成 3 ~ 5 次冲量 | 上报侧未去重，且 trigger 半径过大导致重复 Enter | 上报侧幂等 + 检查 trigger 半径是否过大，避免瞬时反复穿越 |
| Trigger 反复 Enter / Exit 抖动 | trigger 尺寸太贴近实体边界，边缘抖动导致反复 Enter/Exit | 适度放大 trigger，或加短冷却窗口过滤震荡 |
| `reportedColliders` 只针对 collider ID 去重，换个子 collider 就漏 | 走了 collider-level 去重；除非 collider 本身就是独立玩法对象，否则一律归一化到 entity id | 除非该 collider 本身就是独立玩法对象（"每个 collider 本身就是独立玩法对象"变体），否则一律归一化到 entity id |
