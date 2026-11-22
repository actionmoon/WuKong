# 排行榜服务 - Lua

> 本篇带你从 0 到 1 用 Lua 跑通平台托管排行榜上报：结算上报封装 → 只在分数提升时上报（防刷/幂等）→ `alias` 段位榜 → 失败有限重试 → 有奖榜可信校验。
>
> `DouyinRankService` 是**全局注入对象**（Lua 侧直接调用），只有 `SetRankData(score, alias, function(success) end)` 一个回调式方法——**没有** `GetRankData` / `GetRankList` / `ClearRank` / 分页 / 事件，需要读回榜单明细请改用 OrderedDataStore。`score` / `alias` 语义、与 OrderedDataStore 的选型见 Manual：[排行榜服务](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/排行榜服务.md)。

---

## 一、结算上报 helper（只升不降 + 并发拦截 + 有限重试）

把以下 helper 放在脚本顶部公共区。对局结束时调用 `ReportScore(finalScore)` 即可。

```lua
local DouyinRankService = DouyinRankService
local DouyinUtility = DouyinUtility

-- 本地记录的历史最优分数（也可从自建 DataStore 读初值）
local bestScore = nil
local reportPending = false
local MAX_RETRY = 2  -- 失败重试上限，避免无限重试

-- 内部：真正发起一次上报，带有限次重试
local function doSetRankData(score, alias, retryLeft, onFinished)
    reportPending = true
    -- alias 为空时 score 兼作外显；非空时 alias 外显、score 只参与排序（段位榜）
    DouyinRankService.SetRankData(score, alias or "", function(success)
        if success then
            reportPending = false
            bestScore = score
            if onFinished ~= nil then onFinished(true) end
            return
        end

        -- 失败：有限次重试，超限提示，不静默丢弃
        if retryLeft > 0 then
            doSetRankData(score, alias, retryLeft - 1, onFinished)
        else
            reportPending = false
            DouyinUtility.Toast("排行榜上报失败")
            if onFinished ~= nil then onFinished(false) end
        end
    end)
end

-- 对外：只在分数提升时上报（只在对局结束/质变时调用，切勿放 Update）
local function ReportScore(score, alias, onFinished)
    if score == nil then return end

    -- 只升不降：不高于历史最优则跳过，防低分覆盖 + 防重复
    if bestScore ~= nil and score <= bestScore then
        if onFinished ~= nil then onFinished(true) end
        return
    end

    -- 并发拦截：一次上报未回调前不重复发起
    if reportPending then return end

    doSetRankData(score, alias, MAX_RETRY, onFinished)
end
```

---

## 二、入口组合示例

### 对局结束上报分数榜

```lua
function OnGameOver(finalScore)
    ReportScore(finalScore, "", function(success)
        if success then
            DouyinUtility.Toast("成绩已上榜")
        end
    end)
end
```

### 段位榜（alias 外显）

`alias` 作外显、`score` 作排序权重。例如“黄金”权重 3 高于“白银”权重 2：

```lua
-- rankTier = { name = "黄金", weight = 3 }
function ReportTier(rankTier)
    ReportScore(rankTier.weight, rankTier.name, function(success)
        if success then
            DouyinUtility.Toast("段位已更新：" .. rankTier.name)
        end
    end)
end
```

---

## 三、可信校验（有奖 / 竞技榜）

竞技或有奖榜单，最终分数应由服务端计算校验后再上报，客户端只做展示，避免伪造。上报调用本身可放客户端，但**分数来源**要可信：

```lua
-- 服务端算好后下发 verifiedScore，客户端只负责上报
function OnVerifiedScore(verifiedScore)
    ReportScore(verifiedScore, "")
end
```

---

## 四、相关文档

- C# 版：[排行榜服务 - C#](排行榜服务-CSharp.md)
- Manual（`score`/`alias` 语义、托管 vs 自建选型、FAQ）：[排行榜服务](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/排行榜服务.md)
- 自建有序榜（读回 / 分页）：[数据存储OrderedDataStore - Lua](../数据库/数据存储OrderedDataStore-Lua.md)
- API Reference：[DouyinRankService.SetRankData](../../API%20Reference/DouyinRankService/DouyinRankService.SetRankData.md)
