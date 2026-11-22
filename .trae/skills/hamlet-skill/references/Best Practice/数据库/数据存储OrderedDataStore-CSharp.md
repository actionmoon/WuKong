# 数据存储 OrderedDataStore — C# 实践

有序数值存储 `DouyinOrderedDataStore` 的 C# 写法，用于排行榜 / TOP-N。C# 侧是**回调式**：没有 `async/await`，也不抛异常，一律通过回调结果 `DouyinDataRes` 的整数错误码 `res.Code` 判断成败（`0` 成功，`-10001` 表示数据不存在 / 未上榜）。value 只能是 `double`，并额外提供 `GetSortedData` 按值排序分页读取。

> 概念（Name/Scope/Key、容量与键数上限、排序分页语义、错误码全表）见 Manual：[数据存储OrderedDataStore](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据存储OrderedDataStore.md)。Lua 版见 [数据存储OrderedDataStore - Lua](数据存储OrderedDataStore-Lua.md)。普通键值对存储见 [数据存储DataStore - C#](数据存储DataStore-CSharp.md)。
>
> **DS 模式**：DedicatedServer 网络模式下仅服务端可操作，客户端发起报 `-11002`。

## 真实 API 形态

- **入口**：全局静态方法 `DouyinDataStoreService.GetOrderedDataStore(name, scope, Action<DouyinDataRes> cb)`。`name` / `scope` 均 ≤ 50 字符。
- **拿实例（关键）**：回调里 `storeRes.Store` 的实际类型是 `DouyinOrderedDataStore`（继承自 `DouyinDataStore`），**需向下转型**：`var store = storeRes.Store as DouyinOrderedDataStore;`，否则调 `GetSortedData` 编译不过。
- **实例方法**（均为回调式）：`store.Get(key, cb)`、`store.Set(key, double, options, cb)`、`store.Increment(key, double, options, cb)`、`store.Remove(key, cb)`、`store.GetSortedData(isAsce, pageSize, minVal, maxVal, cb)`。`options` 固定传 `null`——OrderedDataStore 不支持 SetOptions（传非空报 `-10036`）。**C# 侧无 `UpdateData`**，“取最大值”需自己组合 `Get` + `Set`。
- **读取结果**：单条分数取 `res.ValueOrderedDataInfo.value`（`double`）；`GetSortedData` 回调里 `res.Page` 是 `DouyinDataPages`，每页数据在 `res.ListOrderedDataInfo`（每项有 `.key` / `.value`）。
- **附带信息**：value 只存分数，昵称 / 头像等需另开普通 DataStore 关联，或用 `DouyinUserService.GetUserInfos(list, cb)` 反查（`DouyinUserInfo` 字段为 `openID` / `name` / `portraitUrl`；模拟器下不返回数据）。

## 写 / 读 / 自增 / 取最大值 / 删除

```csharp
using UnityEngine;

public class OrderedStoreSample
{
    public void Run(string playerOpenID)
    {
        DouyinDataStoreService.GetOrderedDataStore("Leaderboard", "GoldRank", storeRes =>
        {
            if (storeRes.Code != 0)
            {
                CommonDebug.LogError($"[OrderedDS] GetOrderedDataStore 失败 code={storeRes.Code} msg={storeRes.Msg}");
                return;
            }
            var store = storeRes.Store as DouyinOrderedDataStore;   // 必须向下转型

            // 写：value 必须是 double；options 固定传 null（否则 -10036）
            store.Set(playerOpenID, 1500.0, null, res => { if (res.Code != 0) CommonDebug.LogError($"Set 失败 {res.Code}"); });

            // 读：-10001 表示玩家尚未上榜，属正常分支
            store.Get(playerOpenID, res =>
            {
                if (res.Code == 0) CommonDebug.Log($"我的分数 = {res.ValueOrderedDataInfo.value}");
                else if (res.Code != -10001) CommonDebug.LogError($"Get 失败 {res.Code}");
            });

            // 自增：delta 必须是 double（key 不存在则从 0 起）
            store.Increment(playerOpenID, 100.0, null, res => { if (res.Code == 0) CommonDebug.Log($"分数 = {res.ValueOrderedDataInfo.value}"); });

            // 取最大值：C# 无 UpdateData，用 Get + Set 组合（并发担忧时应对同 key 串行化写入）
            store.Get(playerOpenID, getRes =>
            {
                double cur = getRes.Code == 0 ? getRes.ValueOrderedDataInfo.value : 0;   // -10001 视为 0
                double newScore = 1800.0;
                if (newScore > cur)
                    store.Set(playerOpenID, newScore, null, _ => { });
            });

            // 删除该玩家条目
            store.Remove(playerOpenID, _ => { });
        });
    }
}
```

## 按分数排序分页读取（GetSortedData）

回调式没有 `while` / `await`，翻页用回调链驱动。

```csharp
using System;

public void ReadLeaderboard(DouyinOrderedDataStore store)
{
    // 降序（isAsce=false，榜单常用）、每页 100 条；不做值过滤时用 ±Infinity
    store.GetSortedData(false, 100, double.NegativeInfinity, double.PositiveInfinity, res =>
    {
        if (res.Code != 0) { CommonDebug.LogError($"[OrderedDS] GetSortedData 失败 {res.Code}"); return; }

        var page = res.Page;
        page.Store = store;   // 关键：分页对象跨网络返回后 Store 为 null，翻页前必须手动回填

        ReadPage(page, 10, 0);   // 最多读 10 页，防御性上限，避免扫全表耗尽配额
    });
}

// 逐页递归读取
private void ReadPage(DouyinDataPages page, int maxPage, int rank)
{
    page.GetCurrentPage(pageRes =>
    {
        if (pageRes.Code == 0 && pageRes.ListOrderedDataInfo != null)
        {
            foreach (var item in pageRes.ListOrderedDataInfo)
            {
                rank++;
                CommonDebug.Log($"[OrderedDS] #{rank} key={item.key} score={item.value}");
            }
        }
        // page.PageIndex / page.PageCount 由平台在翻页时维护
        if (page.PageIndex + 1 < page.PageCount && page.PageIndex + 1 < maxPage)
        {
            page.PageIndex += 1;
            ReadPage(page, maxPage, rank);
        }
    });
}
```

## 完整示例：金币榜管理器

覆盖“提交分数（取最大值）、拉取 TOP-N、查询自己名次”，复用实例缓存，并用 `DouyinUserService` 补齐昵称 / 头像。挂在场景里一个 `MonoBehaviour` 上使用。

```csharp
using System;
using System.Collections.Generic;
using UnityEngine;

public class LeaderboardRow
{
    public string PlayerOpenID;
    public double Score;
    public int Rank;
    public string Nickname;
    public string AvatarUrl;
}

public class LeaderboardManager : MonoBehaviour
{
    private const string LeaderboardName = "Leaderboard";
    private const string DefaultScope = "GoldRank";
    private const int PageSize = 100;      // (0, 1024]
    private const int MaxScanPage = 10;    // 排名扫描最多页数（保护配额）

    private readonly Dictionary<string, DouyinOrderedDataStore> _stores = new();

    // 获取（带缓存）
    private void WithStore(string scope, Action<DouyinOrderedDataStore> onReady)
    {
        if (_stores.TryGetValue(scope, out var cached) && cached != null) { onReady(cached); return; }
        DouyinDataStoreService.GetOrderedDataStore(LeaderboardName, scope, storeRes =>
        {
            if (storeRes.Code != 0)
            {
                CommonDebug.LogError($"[Leaderboard] GetOrderedDataStore 失败 code={storeRes.Code} msg={storeRes.Msg}");
                onReady(null);
                return;
            }
            var store = storeRes.Store as DouyinOrderedDataStore;
            _stores[scope] = store;
            onReady(store);
        });
    }

    // 提交分数（取最大值）
    public void SubmitScore(string playerOpenID, double newScore, Action<bool, double> onDone = null)
    {
        WithStore(DefaultScope, store =>
        {
            if (store == null) { onDone?.Invoke(false, 0); return; }
            store.Get(playerOpenID, getRes =>
            {
                double cur = getRes.Code == 0 ? getRes.ValueOrderedDataInfo.value : 0;   // -10001 视为 0
                if (getRes.Code != 0 && getRes.Code != -10001)
                {
                    CommonDebug.LogError($"[Leaderboard] Get 失败 {getRes.Code}");
                    onDone?.Invoke(false, cur);
                    return;
                }
                if (newScore <= cur) { onDone?.Invoke(true, cur); return; }
                store.Set(playerOpenID, newScore, null, setRes =>
                    onDone?.Invoke(setRes.Code == 0, setRes.Code == 0 ? setRes.ValueOrderedDataInfo.value : cur));
            });
        });
    }

    // 拉取 TOP-N（降序），并补齐昵称/头像
    public void GetTopN(int topN, Action<bool, List<LeaderboardRow>> onDone)
    {
        WithStore(DefaultScope, store =>
        {
            if (store == null) { onDone?.Invoke(false, null); return; }
            store.GetSortedData(false, PageSize, double.NegativeInfinity, double.PositiveInfinity, res =>
            {
                if (res.Code != 0) { CommonDebug.LogError($"[Leaderboard] GetSortedData 失败 {res.Code}"); onDone?.Invoke(false, null); return; }
                var page = res.Page;
                page.Store = store;   // 关键：回填 Store

                var rows = new List<LeaderboardRow>();
                ScanPages(page,
                    item => { rows.Add(new LeaderboardRow { PlayerOpenID = item.key, Score = item.value }); return rows.Count < topN; },
                    () =>
                    {
                        for (int i = 0; i < rows.Count; i++) rows[i].Rank = i + 1;
                        FillUserInfo(rows, () => onDone?.Invoke(true, rows));
                    });
            });
        });
    }

    // 查询个人排名（扫描榜单查匹配项）
    public void GetMyRank(string playerOpenID, Action<bool, int, double> onDone)
    {
        WithStore(DefaultScope, store =>
        {
            if (store == null) { onDone?.Invoke(false, -1, 0); return; }
            store.GetSortedData(false, PageSize, double.NegativeInfinity, double.PositiveInfinity, res =>
            {
                if (res.Code != 0) { CommonDebug.LogError($"[Leaderboard] GetSortedData 失败 {res.Code}"); onDone?.Invoke(false, -1, 0); return; }
                var page = res.Page;
                page.Store = store;

                int rank = 0; double myScore = 0; bool found = false;
                ScanPages(page,
                    item => { rank++; if (item.key == playerOpenID) { myScore = item.value; found = true; return false; } return true; },
                    () => onDone?.Invoke(true, found ? rank : -1, myScore));
            });
        });
    }

    // 通用分页扫描：onItem 返回 false 表示提前停止；onFinish 扫描结束回调
    private void ScanPages(DouyinDataPages page, Func<DouyinOrderedDataInfo, bool> onItem, Action onFinish)
    {
        page.GetCurrentPage(pageRes =>
        {
            bool wantMore = true;
            if (pageRes.Code == 0 && pageRes.ListOrderedDataInfo != null)
            {
                foreach (var item in pageRes.ListOrderedDataInfo)
                    if (!onItem(item)) { wantMore = false; break; }
            }
            if (wantMore && page.PageIndex + 1 < page.PageCount && page.PageIndex + 1 < MaxScanPage)
            {
                page.PageIndex += 1;
                ScanPages(page, onItem, onFinish);
            }
            else onFinish();
        });
    }

    // 补齐昵称/头像（OrderedDataStore 只存分数，附加信息另取）
    private void FillUserInfo(List<LeaderboardRow> rows, Action onDone)
    {
        if (rows == null || rows.Count == 0) { onDone(); return; }
        var openIDs = new List<string>();
        foreach (var r in rows) openIDs.Add(r.PlayerOpenID);

        // 模拟器下 GetUserInfos 不返回数据，仅真机/线上有效
        DouyinUserService.GetUserInfos(openIDs, infos =>
        {
            if (infos != null)
            {
                var map = new Dictionary<string, DouyinUserInfo>();
                foreach (var info in infos) map[info.openID] = info;
                foreach (var r in rows)
                    if (map.TryGetValue(r.PlayerOpenID, out var info)) { r.Nickname = info.name; r.AvatarUrl = info.portraitUrl; }
            }
            onDone();
        });
    }
}
```

## 相关文档

- Lua 版：[数据存储OrderedDataStore - Lua](数据存储OrderedDataStore-Lua.md)
- 普通键值对存储：[数据存储DataStore - C#](数据存储DataStore-CSharp.md)
- 平台托管榜（只上报）：[排行榜服务 - C#](../平台服务/排行榜服务-CSharp.md)
- Manual（概念、限制、错误码全表）：[数据存储OrderedDataStore](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据存储OrderedDataStore.md)、[数据库概述](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据库概述.md)
