# 数据存储 DataStore — Lua 实践

原生键值对存储 `DouyinDataStore` 的 Lua 写法。Lua 侧是**协程同步式**：所有读写必须包裹在 `DATASTORE(function() ... end)` 块内（该宏把函数包成协程并 `resume`，请求靠 `yield`/`resume` 挂起等待），否则返回 `-10034`。

> 概念（Name/Scope/Key 三段式、容量与频控限制、错误码全表）见 Manual：[数据存储DataStore](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据存储DataStore.md)。C# 版见 [数据存储DataStore - C#](数据存储DataStore-CSharp.md)。需要统一封装的读写管理层，见 [自定义数据库管理系统 - Lua](自定义数据库管理系统-Lua.md)。
>
> **DS 模式**：DedicatedServer 网络模式下云端读写**仅允许服务端执行**，客户端发起报 `-11002`。

## 真实 API 形态

- **入口**：`local code, store = DouyinDataService.GetDataStore(name, scope, all_scope)`。`name` ≤ 20 字符、`scope` ≤ 50 字符（如 `"player_" .. playerOpenID`），`all_scope` 通常传 `false`。
- **实例方法**（均返回 `code, value, info`，`code == 0` 成功）：`store:GetData(key)`、`store:SetData(key, value [, options])`、`store:IncrementData(key, delta [, options])`、`store:UpdateData(key, update_func)`、`store:RemoveData(key)`。
- **值类型**：支持数字、布尔、字符串，以及仅含这些类型的表（表需先 `dkjson.encode` 成 JSON 字符串）。数值字段**直接存数字**，不要 `tostring`——否则后续 `IncrementData` 会因类型不符持续失败。
- **延时/重试**：Lua 侧用平台全局 `setTimeout(func, 毫秒)`（返回 id，`clearTimeout(id)` 取消），**没有** `WaitForSeconds`/`StartCoroutine`。延迟后再操作 DataStore，需在回调里**重新开一个 `DATASTORE` 块**。

## 读 / 写 / 自增 / 删除

```lua
DATASTORE(function()
    -- 获取 store：ok == 0 才成功；同一 name+scope 复用同一实例
    local ok, store = DouyinDataService.GetDataStore("sim_game", "player_" .. playerOpenID, false)
    if ok ~= 0 then
        logError(string.format("GetDataStore 失败：%d", ok))
        return
    end

    -- 读：-10001 是“新号/数据不存在”，属正常业务分支，不是错误
    local ok, value, info = store:GetData("coin")
    if ok == -10001 then
        store:SetData("coin", 0)          -- 新号初始化：数值直接存 number
    elseif ok == 0 then
        print("coin =", value)
    end

    -- 写：数值直接传 number；序列化后别超过约 6000 字符，超了返回 -10013
    store:SetData("coin", 100)

    -- 自增：只能对“以数字存的”key 用；delta 传负数即为递减
    store:IncrementData("coin", 10)

    -- 删除
    store:RemoveData("coin")
end)
```

## 读改写：UpdateData（先读再写）

新值依赖旧值时（金币累加、取最大值等）用 `store:UpdateData`，平台内部先读出当前值交给 `update_func` 算出新值再写回，比自己 `Get`+`Set` 更安全。

```lua
DATASTORE(function()
    local ok, store = DouyinDataService.GetDataStore("sim_game", "player_" .. playerOpenID, false)
    if ok ~= 0 then return end

    -- update_func(curVal, info) 返回新值；curVal 在新号时可能为 nil，需兜底
    local code, newVal = store:UpdateData("coin", function(val, info)
        return (tonumber(val) or 0) + 10
    end)
    if code == 0 then print("coin 更新为", newVal) end
end)
```

## 表数据的 JSON 编解码

DataStore 不做泛型自动编解码，表结构需业务自行序列化。

```lua
-- 保存：先序列化再校验长度
local function SaveTable(store, dataKey, tbl)
    local json = dkjson.encode(tbl)
    if #json > 6000 then                  -- 超限写入会失败（-10013）
        logError("数据超长，需拆分或精简")
        return
    end
    store:SetData(dataKey, json)
end

-- 读取：新号返回空表，否则反序列化
local function LoadTable(store, dataKey)
    local ok, json = store:GetData(dataKey)
    if ok == -10001 then return {} end
    if ok ~= 0 then return nil end
    return dkjson.decode(json)
end
```

## 失败重试（网络类错误退避）

只对网络类错误（如 `-10050`）重试；`name`/`scope`/value 超长等校验错误重试再多次也不会成功，应直接失败并修数据。每次重试都在 `setTimeout` 回调里**重新开一个 `DATASTORE` 块**。

```lua
local function SaveWithRetry(name, scope, dataKey, value, retryCount)
    retryCount = retryCount or 0
    local delays = {1000, 2000, 4000}     -- 指数退避（毫秒）：1s, 2s, 4s

    DATASTORE(function()
        local ok, store = DouyinDataService.GetDataStore(name, scope, false)
        if ok == 0 then ok = select(1, store:SetData(dataKey, value)) end

        if ok == 0 then
            print("保存成功")
        elseif ok == -10050 and retryCount < #delays then
            -- 仅网络类错误重试；重开 DATASTORE 块
            setTimeout(function() SaveWithRetry(name, scope, dataKey, value, retryCount + 1) end, delays[retryCount + 1])
        else
            logError(string.format("保存失败，错误码：%d", ok))
        end
    end)
end
```

## 自定义 Metadata（可选）

除平台自动管理的创建/更新时间与版本号外，可用 `CreateDataSetOptions` 附加自定义 metadata，作为写方法的最后一个参数传入。

```lua
DATASTORE(function()
    local ok, store = DouyinDataService.GetDataStore("sim_game", "player_" .. playerOpenID, false)
    if ok ~= 0 then return end

    local opts = DouyinDataService.CreateDataSetOptions()
    opts:SetMetadata("last_source", "daily_reward")   -- key/value 均为字符串
    store:SetData("coin", 100, opts)                  -- Meta 超限报 -10016/-10017，仅必要时使用

    local ok2, value, info = store:GetData("coin")
    if ok2 == 0 and info then
        local meta = info:GetMetadata()
        print("last_source =", meta and meta["last_source"])
    end
end)
```

## 相关文档

- C# 版：[数据存储DataStore - C#](数据存储DataStore-CSharp.md)
- 统一封装：[自定义数据库管理系统 - Lua](自定义数据库管理系统-Lua.md)
- 有序/排行榜存储：[数据存储OrderedDataStore - Lua](数据存储OrderedDataStore-Lua.md)
- Manual（概念、限制、错误码全表）：[数据存储DataStore](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据存储DataStore.md)、[数据库概述](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据库概述.md)
- API Reference：[DouyinDataService.GetDataStore](../../API%20Reference/数据存储/DouyinDataService/DouyinDataService.GetDataStore.md)、[DouyinDataStore](../../API%20Reference/数据存储/DouyinDataStore.md)
