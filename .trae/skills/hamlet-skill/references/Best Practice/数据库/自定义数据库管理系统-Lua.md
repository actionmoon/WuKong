# 自定义数据库管理系统 — Lua 实践

## 目标

本文说明如何在 Lua 中从零搭建一套自定义数据库管理系统，用于统一管理平台数据的持久化访问，例如金币、背包、成就、精灵属性等业务数据。

在涉及数据持久化的业务开发中，若在各处业务逻辑内分散调用原生 Datastore API，往往会产生大量重复代码，并容易引发协程与回调上下文使用不当、序列化遗漏、错误码处理不完整等问题。

本最佳实践的核心在于：在原生数据存储 API 之上，封装一层统一的**数据访问管理层**（Datastore Manager），对外提供一致的接口规范、集中的异常处理与统一的缓存策略。封装完成后，上层业务仅需调用管理层提供的读、写、自增、读改写、删除等方法，即可完成全部数据存取，无需再关注协程包裹、JSON 序列化与错误码判断等细节。

文中管理层自身的方法名（如 `GetData`、`DouyinDataStoreManager`）仅用于说明职责，可根据项目习惯自行命名；而平台原生接口（如 `DouyinDataService.GetDataStore`、`store:GetData` 及错误码 `-10001` 等）为真实 API，需按实际名称使用。

> **阅读前提**：本文仅说明实现方式，不涉及概念解释。数据存储的基础概念（Name/Scope/Key）、容量与频控限制、错误码全表等内容，请先查阅 Manual：[数据库概述](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据库概述.md)、[数据存储DataStore](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据存储DataStore.md)。
>
> **性质说明**：该数据访问管理层为开发者自行封装的代码层，并非平台内置模块；其内部仍调用平台原生接口，仅在其上统一封装了通用逻辑。
>
> **Lua 关键约束**：所有 `store:XxxData` 读写操作必须置于 `DATASTORE(function() ... end)` 块内执行，否则将返回错误码 `-10034`。

## 操作流程

按以下步骤依次实现。前七步完成后管理层即可独立使用，第八、九步用于封装维度与验证：

1. **搭建管理层骨架** —— 创建脚本、注册全局访问入口、初始化 store 缓存表。
2. **实现"获取 store"函数** —— 统一获取并缓存 store，供后续各方法复用。
3. **实现 GetData（读）** —— 第一个对外方法，新账号首次读取也不会报错。
4. **实现 SetData（写）** —— 写入前自动序列化，可存储任意数据结构。
5. **实现 IncrementData（自增）** —— 用于金币、积分等数值的增减。
6. **实现 RemoveData（删除）** —— 删除一条数据。
7. **实现 UpdateData（读改写）** —— 基于旧值计算新值后写回；至此五个方法全部完成。
8. **封装"维度"层** —— 统一拼接 scope，业务调用时无需再关注 scope。
9. **验证** —— 按场景逐项确认行为符合预期。


## 第一步：搭建管理层骨架

首先创建一个空的管理层脚本：在 `Awake` 中将自身注册到全局变量 `_G["DouyinDataStoreManager"]`，使任意业务脚本均可直接调用；同时初始化一个空表 `script.stores`，用于按 scope 缓存已获取的 store（下一步使用）；脚本销毁时清空该缓存。

```lua
function Awake()
    script.stores = {}                         -- 按 scope 缓存已拿到的 store，避免重复获取
    _G["DouyinDataStoreManager"] = script
end

function OnDestroy()
    script.stores = {}                         -- 对象销毁时清空缓存，下次重新拿
    _G["DouyinDataStoreManager"] = nil
end
```

再准备两个辅助函数：一个用于校验入口参数，另一个用于将 table 序列化为 JSON 文本（写入数据时使用）。

```lua
-- 入口参数校验：storeName / scopeName / dataKey 任一为空就不往下走
local function CheckDataStoreName(storeName)
    return storeName and type(storeName) == "string" and storeName ~= ""
end

local function CheckScopeName(scopeName)
    return scopeName and type(scopeName) == "string" and scopeName ~= ""
end

local function CheckKeyName(dataKey)
    return dataKey and type(dataKey) == "string" and dataKey ~= ""
end

-- 要存的是 table 就转成 JSON 文本；数字/字符串/布尔原样返回
local function ConvertData(value)
    if type(value) == "table" then
        return true, dkjson.encode(value)
    else
        return true, value
    end
end
```

## 第二步：实现"获取 store"函数

每次读写前都需要先获取对应的 store。由于获取 store 存在开销，同一个 scope 重复获取会造成浪费，因此用一个内部函数统一处理：先查缓存，命中则直接返回；未命中则调用原生 `DouyinDataService.GetDataStore` 获取，返回值 `ok == 0` 表示成功，成功后存入缓存再返回。**获取失败时不写入缓存**，否则该 scope 将始终返回无效结果。

```lua
local function GetDataStore(storeName, scopeName)
    if script.stores[scopeName] == nil then
        local ok, store = DouyinDataService.GetDataStore(storeName, scopeName, false)
        if ok == 0 then                        -- ok == 0 才是成功
            script.stores[scopeName] = store
        end
    end
    return script.stores[scopeName]
end
```

## 第三步：实现 GetData（读）

第一个对外方法。执行步骤：校验参数 → 进入 `DATASTORE` 块 → 获取 store → 调用 `store:GetData` 读取 → 处理结果。

处理结果时需注意一个关键点：返回码 `-10001` **并非错误**，它表示"该账号尚未存储过数据"，应作为"读取成功、但数据为空"处理，业务据此判断需要执行初始化。若读取到的是一段 JSON 文本，则反序列化为 table 后再返回。

```lua
function GetData(storeName, scopeName, dataKey, callback)
    if not CheckDataStoreName(storeName) or not CheckScopeName(scopeName) or not CheckKeyName(dataKey) then
        callback(false, "Invalid parameter", nil)
        return
    end

    DATASTORE(function()                       -- 读写必须放在 DATASTORE 块里，否则报 -10034
        local store = GetDataStore(storeName, scopeName)
        if store == nil then
            callback(false, "Failed to get data store", nil)
            return
        end

        local ok, value, info = store:GetData(dataKey)
        if ok ~= 0 then
            if ok == -10001 then
                -- -10001 是新号（还没存过数据），不是错误：当成“成功但数据为空”返回
                callback(true, "New Data", {})
            else
                callback(false, "Failed to get data " .. ok, nil)
            end
        else
            -- 读到形如 JSON 的文本就还原成 table，否则原样返回
            if type(value) == "string" and value:match("^{.*}$") then
                callback(true, "Success", dkjson.decode(value))
            else
                callback(true, "Success", value)
            end
        end
    end)
end
```

完成本步后，即可正常读取数据，且新玩家、新精灵首次读取也不会报错。

## 第四步：实现 SetData（写）

整体结构与读取一致，区别在于写入前需先用 `ConvertData` 将数据转换为可存储的格式（table 转为 JSON 文本，其它类型保持原样）。

```lua
function SetData(storeName, scopeName, dataKey, dataValue, callback)
    if not CheckDataStoreName(storeName) or not CheckScopeName(scopeName) or not CheckKeyName(dataKey) then
        callback(false, "Invalid parameter", nil)
        return
    end

    local ret, jsonData = ConvertData(dataValue)   -- 写之前先转格式
    if not ret then
        callback(false, "Invalid data", nil)
        return
    end

    DATASTORE(function()
        local store = GetDataStore(storeName, scopeName)
        if store == nil then
            callback(false, "Failed to get data store", nil)
            return
        end

        -- 转成文本后别超过约 6000 字符，超了会返回 -10013
        local ok, value, info = store:SetData(dataKey, jsonData)
        if ok ~= 0 then
            callback(false, ok, value)
            return
        end
        callback(true, "Success", value)
    end)
end
```

## 第五步：实现 IncrementData（自增）

金币、积分、次数等数值适合使用自增，无需"读取、加减、再写回"三步操作。需注意自增仅适用于**以数值存储的** key；`amount` 传入负数即为递减。

```lua
function IncrementData(storeName, scopeName, dataKey, amount, callback)
    if not CheckDataStoreName(storeName) or not CheckScopeName(scopeName) or not CheckKeyName(dataKey) then
        callback(false, "Invalid parameter", nil)
        return
    end

    DATASTORE(function()
        local store = GetDataStore(storeName, scopeName)
        if store == nil then
            callback(false, "Failed to get data store", nil)
            return
        end

        -- 只能对“以数字存的”key 用；amount 传负数就是减
        local ok, value, info = store:IncrementData(dataKey, amount)
        if ok ~= 0 then
            callback(false, ok, value)
            return
        end
        callback(true, "Success", value)
    end)
end
```

## 第六步：实现 RemoveData（删除）

结构最为简单，删除一条数据即可。

```lua
function RemoveData(storeName, scopeName, dataKey, callback)
    if not CheckDataStoreName(storeName) or not CheckScopeName(scopeName) or not CheckKeyName(dataKey) then
        callback(false, "Invalid parameter", nil)
        return
    end

    DATASTORE(function()
        local store = GetDataStore(storeName, scopeName)
        if store == nil then
            callback(false, "Failed to get data store", nil)
            return
        end

        local ok, value, info = store:RemoveData(dataKey)
        if ok ~= 0 then
            callback(false, ok, value)
            return
        end
        callback(true, "Success", nil)
    end)
end
```

## 第七步：实现 UpdateData（读改写）

某些场景下新值需基于旧值计算（例如"经验值 + 本局所得"）。Lua 提供了 `store:UpdateData(key, func)`：将"如何计算新值"的函数传入，它会取出旧值并接收你返回的新值。需注意计算出的新值若为 table，写回前同样要转换为 JSON 文本。

```lua
-- func(curVal, info) 返回 newVal[, newOption]
function UpdateData(storeName, scopeName, dataKey, func, callback)
    if not CheckDataStoreName(storeName) or not CheckScopeName(scopeName) or not CheckKeyName(dataKey) then
        callback(false, "Invalid parameter", nil)
        return
    end

    DATASTORE(function()
        local store = GetDataStore(storeName, scopeName)
        if store == nil then
            callback(false, "Failed to get data store", nil)
            return
        end

        local ok, value, info = store:UpdateData(dataKey, function(curVal, info)
            local newVal, newOption = func(curVal, info)
            local ret, jsonData = ConvertData(newVal)   -- 新值是 table 时转 JSON
            if not ret then
                return newVal, newOption
            end
            return jsonData, newOption
        end)
        if ok ~= 0 then
            callback(false, ok, value)
            return
        end
        callback(true, "Success", value)
    end)
end
```

完成本步后，五个方法全部就绪，管理层本体已可独立使用。以下为调用示例：

```lua
-- 读取（新号时 data 为 {}）
DouyinDataStoreManager.GetData("backpack", "items", "item", function(success, message, data)
    if success then
        print("GetData ok:", data)
    else
        print("GetData failed:", message)
    end
end)

-- 覆盖写入（table 会自动转 JSON）
DouyinDataStoreManager.SetData("backpack", "items", "item", { gold = 100 }, function(success, message)
    print("SetData:", success, message)
end)

-- 数值自增
DouyinDataStoreManager.IncrementData("backpack", "items", "count", 1, function(success, message, data)
    print("IncrementData:", success, data)
end)

-- 读改写：基于旧值算新值
DouyinDataStoreManager.UpdateData("backpack", "items", "count", function(curValue, info)
    return (curValue or 0) + 1
end, function(success, message, data)
    print("UpdateData:", success, data)
end)
```

## 第八步：封装"维度"层

管理层此时已可使用，但每次调用都需自行拼接 scope，容易出错。玩家数据与精灵数据的 scope 拼接规则是固定的，因此在管理层之上再封装一层，统一完成拼接：

| 维度 | scope 拼接方式 | 隔离对象 |
| --- | --- | --- |
| 用户维度 | 基于 `playerOpenID` 拼接，例如 `player_<openID>` | 各玩家自身的数据 |
| 精灵维度 | 基于 `petOpenID` 拼接，例如 `pet_<openID>` | 各精灵（小火人）的数据 |

该层不重复实现读写逻辑，仅在拼接好 scope 后转调下层管理层。完整实现见 [用户维度数据存储方式 - Lua](数据存储方式/用户维度数据存储方式-Lua.md) / [精灵维度数据存储方式 - Lua](数据存储方式/精灵维度数据存储方式-Lua.md)。

## 第九步：验证

至少覆盖以下场景，确认实现的行为符合预期：

| 场景 | 测试方式 | 预期结果 |
| --- | --- | --- |
| 新账号首次读取 | 对从未写入过的 key 调用 `GetData` | 读取成功，返回空数据（`{}`），不报错 |
| 写入后读取 | 先 `SetData` 存入一个 table，再 `GetData` 读取 | 读回的结构与写入时一致 |
| 复用 store | 对同一 scope 连续读写多次 | 仅首次实际获取 store，其后命中缓存 |
| 自增 | 对数值 key 调用 `IncrementData` | 返回自增后的新值；对非数值 key 调用则失败 |
| 读改写 | 使用 `UpdateData` 基于旧值计算新值 | 写回的值基于最新值计算得出 |
| 超长数据 | 存入序列化后超长的数据 | 返回 `-10013`，不会被静默截断 |
| 删除 | `RemoveData` 后再次 `GetData` | 读取结果为"新账号/空数据" |

## 进阶扩展（选做）

完成以上九步后即为一套完整可用的管理层。若项目规模更大，可在此基础上进一步扩展（相关原理与取舍见 Manual [数据库概述](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据库概述.md)）：

- **内存缓存**：将已读取的数据在内存中保留一份，后续优先读取内存，减少网络请求。
- **定期落库**：玩家在线期间改动先写入内存，进入时读取一次、离线时统一写回，避免高频写入触发频控（`-11001`）。
- **失败重试**：对网络类错误按 1s→2s→4s 的间隔退避重试若干次，仍失败则降级处理。
- **版本字段**：在数据中记录 `_ver` 字段，当字段结构变更时，读取旧数据可自动升级。

## 相关文档

- C# 版：[自定义数据库管理系统 - C#](自定义数据库管理系统-CSharp.md)
- 上层维度封装：[用户维度数据存储方式 - Lua](数据存储方式/用户维度数据存储方式-Lua.md) / [精灵维度数据存储方式 - Lua](数据存储方式/精灵维度数据存储方式-Lua.md)
- 原生键值对存储实践：[数据存储DataStore - Lua](数据存储DataStore-Lua.md)
- Manual（概念、限制、错误码）：[数据库概述](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据库概述.md)、[数据存储DataStore](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据存储DataStore.md)
