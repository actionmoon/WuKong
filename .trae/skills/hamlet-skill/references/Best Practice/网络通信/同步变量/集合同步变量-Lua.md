# 集合同步变量（Lua）最佳实践

> 💡 **理论与机制指引**：关于集合同步变量的类型限制、与基础同步变量的回调差异，以及相关避坑指南，请参考手册：[同步变量.md](../../../Manual/Ⅳ.%20多人游戏与网络%28Multiplayer%29/数据与通信/同步变量.md)。
> 本文仅提供集合同步变量在 Lua 侧开发时的标准代码骨架。

---

## 1. 最小可用集合同步变量骨架

```lua
-- 1. 声明集合同步变量
---@varSync listSync:List<int>
---@varSync dictionarySync:Dictionary<int,string>
---@end

function OnNetSpawned()
    -- 2. 集合的 handler 没有参数
    listSync:OnValueChange(function()
        print("listSync changed, count =", listSync:Count())
        -- ForEach 遍历，返回 true 可以中断
        listSync:ForEach(function(value, idx)
            print(string.format("  index=%d value=%s", idx, tostring(value)))
        end)
    end)

    dictionarySync:OnValueChange(function()
        print("dictionarySync changed, count =", dictionarySync:Count())
        dictionarySync:ForEach(function(value, key)
            print(string.format("  key=%s value=%s", tostring(key), tostring(value)))
        end)
    end)
end

-- 3. 业务触发入口：处理主权方与非主权方的写入逻辑
function TryAppendListItem(v)
    if not self:HasOwnership() then
        -- 非主权方转发请求
        self:SendMessageToOwner("TryAppendListItem", v)
        return
    end
    -- 主权方执行追加
    listSync:Add(v)
end

function TrySetDictItem(key, val)
    if not self:HasOwnership() then
        self:SendMessageToOwner("TrySetDictItem", key, val)
        return
    end
    -- 主权方新增或覆盖
    dictionarySync:SetValue(key, val)
end
```

---

## 2. 缓存快照对比（感知增删改）

集合 `OnValueChange` 不带参数，业务如果需要知道“哪些元素被新增/移除”，必须在 handler 结束时自行缓存快照，留给下次使用。

```lua
---@varSync listSync:List<int>
---@end

-- 进程内变量：上一次 handler 观察到的快照
local prevList = {}

function OnNetSpawned()
    -- 初始快照缓存
    CachePrevList()

    listSync:OnValueChange(function()
        local curList = {}
        listSync:ForEach(function(value, idx)
            table.insert(curList, value)
        end)

        -- 对比找出新增的元素
        local addedItems = DiffAdded(prevList, curList)
        for _, v in ipairs(addedItems) do
            print("added:", v)
        end

        -- 更新缓存供下次比较
        prevList = curList
    end)
end

function CachePrevList()
    prevList = {}
    listSync:ForEach(function(value, idx)
        table.insert(prevList, value)
    end)
end

function DiffAdded(prev, cur)
    local prevSet = {}
    for _, v in ipairs(prev) do prevSet[v] = true end
    local added = {}
    for _, v in ipairs(cur) do
        if not prevSet[v] then table.insert(added, v) end
    end
    return added
end
```

---

## 3. 排行榜/状态表（Dictionary 典型业务）

以玩家 openId 作为 key，同步玩家在房间内的分数。

```lua
---@varSync scoreBoard:Dictionary<string,int>
---@end

function OnNetSpawned()
    scoreBoard:OnValueChange(function()
        RefreshScoreboardUi()   -- 所有端刷新 UI
    end)
    RefreshScoreboardUi()       -- 首次进入也主动刷新一次
end

-- 任意端触发分数变化
function OnPlayerScoreChanged(openId, newScore)
    if not self:HasOwnership() then
        self:SendMessageToOwner("OnPlayerScoreChanged", openId, newScore)
        return
    end
    scoreBoard:SetValue(openId, newScore)
end

-- 主权方负责清理离房玩家的残留数据
function OnPlayerLeft(player, evt)
    if not self:HasOwnership() then return end
    if scoreBoard:ContainsKey(player.openId) then
        scoreBoard:Remove(player.openId)
    end
end

function RefreshScoreboardUi()
    -- 表现层逻辑
    local rows = {}
    scoreBoard:ForEach(function(score, openId)
        table.insert(rows, { openId = openId, score = score })
    end)
    -- ...
end
```

## 4. List 的增删改查

List 可以按索引读取和修改，也可以追加、插入、删除或清空元素。索引从 `0` 开始，写操作必须由主权方执行。

```lua
---@varSync itemList:List<int>
---@end

function OnNetSpawned()
    -- 读取单个元素和集合长度
    local itemCount = itemList:Count()
    if itemCount > 0 then
        local firstItem = itemList:GetValue(0)
        print("first item =", tostring(firstItem))
    end
    print("item count =", itemCount)

    -- 遍历当前集合
    itemList:ForEach(function(value, idx)
        print(string.format("index=%d value=%s", idx, tostring(value)))
    end)
end

function TryUpdateList()
    if not self:HasOwnership() then
        self:SendMessageToOwner("TryUpdateList")
        return
    end

    -- 修改指定索引的元素；空集合先追加初始元素
    if itemList:Count() > 0 then
        itemList:SetValue(0, 111)
    else
        itemList:Add(111)
    end
    -- 追加元素
    itemList:Add(200)
    -- 在指定索引处插入元素
    itemList:Insert(1, 300)
    -- 删除指定索引的元素
    itemList:RemoveAt(1)
end

function TryClearList()
    if not self:HasOwnership() then
        self:SendMessageToOwner("TryClearList")
        return
    end
    itemList:Clear()
end
```

## 5. Dictionary 的增删改查

Dictionary 可以按 key 读取和修改。修改已存在的 key 会覆盖原值，删除和清空操作也必须由主权方执行。

```lua
---@varSync itemMap:Dictionary<int,string>
---@end

function OnNetSpawned()
    local key = 100

    if itemMap:ContainsKey(key) then
        print("current value =", tostring(itemMap:GetValue(key)))
    end

    itemMap:ForEach(function(value, currentKey)
        print(string.format("key=%s value=%s", tostring(currentKey), tostring(value)))
    end)
    print("item count =", itemMap:Count())
end

function TryUpdateDictionary(key, value)
    if not self:HasOwnership() then
        self:SendMessageToOwner("TryUpdateDictionary", key, value)
        return
    end

    -- 新增 key，或覆盖已有 key 的值
    itemMap:SetValue(key, value)
end

function TryRemoveDictionaryItem(key)
    if not self:HasOwnership() then
        self:SendMessageToOwner("TryRemoveDictionaryItem", key)
        return
    end

    if itemMap:ContainsKey(key) then
        itemMap:Remove(key)
    end
end

function TryClearDictionary()
    if not self:HasOwnership() then
        self:SendMessageToOwner("TryClearDictionary")
        return
    end
    itemMap:Clear()
end
```
