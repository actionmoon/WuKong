# 数据存储 OrderedDataStore — Lua 实践

有序数值存储 `DouyinOrderedDataStore` 的 Lua 写法，用于排行榜 / TOP-N。它与普通 DataStore 同源，但 **value 只能是数字**（存非数字报 `-10040`），并额外提供 `GetSortedData` 按值排序分页读取。Lua 侧同样是**协程同步式**：所有读写必须包裹在 `DATASTORE(function() ... end)` 块内，否则返回 `-10034`。

> 概念（Name/Scope/Key、容量与键数上限、排序分页语义、错误码全表）见 Manual：[数据存储OrderedDataStore](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据存储OrderedDataStore.md)。C# 版见 [数据存储OrderedDataStore - C#](数据存储OrderedDataStore-CSharp.md)。普通键值对存储见 [数据存储DataStore - Lua](数据存储DataStore-Lua.md)。
>
> **DS 模式**：DedicatedServer 网络模式下仅服务端可操作，客户端发起报 `-11002`。

## 真实 API 形态

- **入口**：`local ok, store = DouyinDataService.GetOrderedDataStore(name, scope)`。`name` / `scope` 均 ≤ 50 字符；相同 `name + scope` 复用同一实例。
- **实例方法**（均返回 `ok, value, info`，`ok == 0` 成功）：`store:SetData(key, number)`、`store:GetData(key)`、`store:IncrementData(key, delta)`、`store:UpdateData(key, update_func)`、`store:RemoveData(key)`。value 只能是数字，且**不接受** `options`（传了报 `-10036`）。
- **排序分页**：`store:GetSortedData(ascending, pageSize [, minVal, maxVal])`，`ascending=false` 为降序（榜单常用），`pageSize` 取值 `(0, 1024]`。返回 `DouyinDataPages`，用 `pages:GetCurrentPage()` 取当前页、`pages:AdvanceToNextPage()` 翻页。
- **附带信息**：value 只存分数，昵称 / 头像等需另开普通 DataStore 关联，或用 `DouyinUserService.GetUserInfo(playerOpenID, cb)` / `GetUserInfos(list, cb)` 反查。

## 写 / 读 / 自增 / 取最大值 / 删除

```lua
DATASTORE(function()
    local ok, store = DouyinDataService.GetOrderedDataStore("Leaderboard", "GoldRank")
    if ok ~= 0 then
        logError(string.format("GetOrderedDataStore 失败：%d", ok))
        return
    end

    local player = DouyinPlayerService.GetLocalPlayer()
    if not player then return end
    local key = player.playerOpenID

    -- 写：直接覆盖为最新分数（value 必须是 number）
    store:SetData(key, 1500)

    -- 读：-10001 表示玩家尚未上榜，属正常分支
    local ok2, value = store:GetData(key)
    if ok2 == 0 then print("我的分数 =", value) end

    -- 自增：在原分数上 +100（key 不存在则从 0 起）
    store:IncrementData(key, 100)

    -- 取最大值：只有新分更高才写回（最高分榜常用）。update_func 内只做纯计算，不要再调 DataStore
    store:UpdateData(key, function(curVal, info)
        local newScore = 1800
        return (curVal == nil or newScore > curVal) and newScore or curVal
    end)

    -- 删除该玩家条目
    store:RemoveData(key)
end)
```

## 按分数排序分页读取（GetSortedData）

```lua
DATASTORE(function()
    local ok, store = DouyinDataService.GetOrderedDataStore("Leaderboard", "GoldRank")
    if ok ~= 0 then return end

    -- 降序、单页 100 条
    local ok2, pages = store:GetSortedData(false, 100)
    if ok2 ~= 0 then return end

    local rank = 0
    local maxPage = 10   -- 防御性上限：榜单可能上百页，扫全表会耗尽 API 配额
    local pageIndex = 0
    repeat
        pageIndex = pageIndex + 1
        if pageIndex > maxPage then break end
        local pOk, pageValues = pages:GetCurrentPage()
        if pOk == 0 and pageValues then
            for openID, item in pairs(pageValues) do
                rank = rank + 1
                print(string.format("#%d %s score=%s", rank, openID, tostring(item.value)))
            end
        end
    until not pages:AdvanceToNextPage()
end)
```

## 完整示例：金币榜管理器

覆盖“提交分数（取最大值上榜）、查询自己分数、拉取 TOP-N、查询自己名次”，并复用实例缓存。

```lua
-- LeaderboardManager.lua
local LeaderboardManager = {}

local LEADERBOARD_NAME  = "Leaderboard"
local LEADERBOARD_SCOPE = "GoldRank"
local PAGE_SIZE         = 100    -- 单页拉取数量，(0, 1024]
local MAX_SCAN_PAGE     = 10     -- 排名扫描最多页数（保护配额）

LeaderboardManager.store = nil   -- 缓存实例，避免重复 GetOrderedDataStore

local function InitStore()
    if LeaderboardManager.store ~= nil then return true end
    local ok, store = DouyinDataService.GetOrderedDataStore(LEADERBOARD_NAME, LEADERBOARD_SCOPE)
    if ok ~= 0 then
        logError(string.format("[Leaderboard] GetOrderedDataStore 失败：%d", ok))
        return false
    end
    LeaderboardManager.store = store
    return true
end

-- 提交分数（取最大值）；callback(success, finalScore)
function LeaderboardManager:SubmitScore(score, callback)
    DATASTORE(function()
        local player = DouyinPlayerService.GetLocalPlayer()
        if not player or not InitStore() then if callback then callback(false) end return end

        local ok, value = self.store:UpdateData(player.playerOpenID, function(curVal, info)
            return (curVal == nil or score > curVal) and score or curVal
        end)
        if callback then callback(ok == 0, value) end
    end)
end

-- 拉取 TOP-N（降序）；callback(success, list)，list = { {rank, openID, score}, ... }
function LeaderboardManager:GetTopN(topN, callback)
    DATASTORE(function()
        if not InitStore() then if callback then callback(false) end return end

        local ok, pages = self.store:GetSortedData(false, PAGE_SIZE)
        if ok ~= 0 then if callback then callback(false) end return end

        local result, rank, pageIndex = {}, 0, 0
        repeat
            pageIndex = pageIndex + 1
            if pageIndex > MAX_SCAN_PAGE then break end
            local pOk, pageValues = pages:GetCurrentPage()
            if pOk == 0 and pageValues then
                for openID, item in pairs(pageValues) do
                    rank = rank + 1
                    table.insert(result, { rank = rank, openID = openID, score = item.value })
                    if rank >= topN then break end
                end
            end
            if rank >= topN then break end
        until not pages:AdvanceToNextPage()

        -- 单页内顺序由平台保证；跨页聚合后再统一按分数排一次更稳妥
        table.sort(result, function(a, b) return a.score > b.score end)
        for i, item in ipairs(result) do item.rank = i end
        if callback then callback(true, result) end
    end)
end

-- 查询自己名次；callback(success, rank, score)，未命中时 rank=nil
function LeaderboardManager:GetMyRank(callback)
    DATASTORE(function()
        local player = DouyinPlayerService.GetLocalPlayer()
        if not player or not InitStore() then if callback then callback(false) end return end

        local ok, pages = self.store:GetSortedData(false, PAGE_SIZE)
        if ok ~= 0 then if callback then callback(false) end return end

        local rank, pageIndex = 0, 0
        repeat
            pageIndex = pageIndex + 1
            if pageIndex > MAX_SCAN_PAGE then break end
            local pOk, pageValues = pages:GetCurrentPage()
            if pOk == 0 and pageValues then
                for openID, item in pairs(pageValues) do
                    rank = rank + 1
                    if openID == player.playerOpenID then
                        if callback then callback(true, rank, item.value) end
                        return
                    end
                end
            end
        until not pages:AdvanceToNextPage()

        -- 未在扫描范围内命中：可能未上榜，也可能超出 MAX_SCAN_PAGE 范围
        if callback then callback(true, nil) end
    end)
end

return LeaderboardManager
```

## 相关文档

- C# 版：[数据存储OrderedDataStore - C#](数据存储OrderedDataStore-CSharp.md)
- 普通键值对存储：[数据存储DataStore - Lua](数据存储DataStore-Lua.md)
- 平台托管榜（只上报）：[排行榜服务 - Lua](../平台服务/排行榜服务-Lua.md)
- Manual（概念、限制、错误码全表）：[数据存储OrderedDataStore](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据存储OrderedDataStore.md)、[数据库概述](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据库概述.md)
