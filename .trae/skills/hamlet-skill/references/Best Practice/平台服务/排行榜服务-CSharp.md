# 排行榜服务 - C#

> 本篇带你从 0 到 1 用 C# 跑通平台托管排行榜上报：结算上报封装 → 只在分数提升时上报（防刷/幂等）→ `alias` 段位榜 → 失败有限重试 → 有奖榜可信校验。
>
> C# 侧 `DouyinRankService` 是**全局静态类**，只有 `SetRankData(float score, string alias, Action<bool> callback)` 一个回调式方法（非 `async/await`，无返回 `Task`）——**没有** `GetRankData` / `GetRankList` / `ClearRank` / 分页 / 事件 / `Instance` 单例，需要读回榜单明细请改用 OrderedDataStore。`score` / `alias` 语义、与 OrderedDataStore 的选型见 Manual：[排行榜服务](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/排行榜服务.md)。

---

## 一、结算上报封装（只升不降 + 并发拦截 + 有限重试）

把以下 helper 放在业务脚本中。对局结束时调用 `ReportScore(finalScore)` 即可。

```csharp
using System;
using UnityEngine;

public class RankReporter
{
    // 本地记录的历史最优分数（也可从自建 DataStore 读初值）
    private float? _bestScore;
    private bool _pending;
    private const int MaxRetry = 2; // 失败重试上限，避免无限重试

    // 内部：发起一次上报，带有限次重试
    private void DoSetRankData(float score, string alias, int retryLeft, Action<bool> onFinished)
    {
        _pending = true;
        // alias 为空时 score 兼作外显；非空时 alias 外显、score 只参与排序（段位榜）
        DouyinRankService.SetRankData(score, alias ?? "", success =>
        {
            if (success)
            {
                _pending = false;
                _bestScore = score;
                onFinished?.Invoke(true);
                return;
            }

            // 失败：有限次重试，超限提示，不静默丢弃
            if (retryLeft > 0)
            {
                DoSetRankData(score, alias, retryLeft - 1, onFinished);
            }
            else
            {
                _pending = false;
                DouyinUtility.Toast("排行榜上报失败");
                onFinished?.Invoke(false);
            }
        });
    }

    // 对外：只在分数提升时上报（只在对局结束/质变时调用，切勿放 Update）
    public void ReportScore(float score, string alias = "", Action<bool> onFinished = null)
    {
        // 只升不降：不高于历史最优则跳过，防低分覆盖 + 防重复
        if (_bestScore.HasValue && score <= _bestScore.Value)
        {
            onFinished?.Invoke(true);
            return;
        }

        // 并发拦截：一次上报未回调前不重复发起
        if (_pending)
        {
            return;
        }

        DoSetRankData(score, alias, MaxRetry, onFinished);
    }
}
```

---

## 二、业务接入示例

### 对局结束上报分数榜

```csharp
private readonly RankReporter _rank = new RankReporter();

public void OnGameOver(float finalScore)
{
    _rank.ReportScore(finalScore, "", success =>
    {
        if (success)
        {
            DouyinUtility.Toast("成绩已上榜");
        }
    });
}
```

### 段位榜（alias 外显）

`alias` 作外显、`score` 作排序权重（“黄金”权重 3 高于“白银”权重 2）：

```csharp
public void ReportTier(string tierName, float weight)
{
    _rank.ReportScore(weight, tierName, success =>
    {
        if (success)
        {
            DouyinUtility.Toast($"段位已更新：{tierName}");
        }
    });
}
```

---

## 三、可信校验（有奖 / 竞技榜）

竞技或有奖榜单，最终分数应由服务端计算校验后再上报，客户端只做展示。上报调用本身可放客户端，但**分数来源**要可信：

```csharp
// 服务端算好后下发 verifiedScore，客户端只负责上报
public void OnVerifiedScore(float verifiedScore)
{
    _rank.ReportScore(verifiedScore);
}
```

---

## 四、相关文档

- Lua 版：[排行榜服务 - Lua](排行榜服务-Lua.md)
- Manual（`score`/`alias` 语义、托管 vs 自建选型、FAQ）：[排行榜服务](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/排行榜服务.md)
- 自建有序榜（读回 / 分页）：[数据存储OrderedDataStore - C#](../数据库/数据存储OrderedDataStore-CSharp.md)
- API Reference：[DouyinRankService.SetRankData](../../API%20Reference/DouyinRankService/DouyinRankService.SetRankData.md)
