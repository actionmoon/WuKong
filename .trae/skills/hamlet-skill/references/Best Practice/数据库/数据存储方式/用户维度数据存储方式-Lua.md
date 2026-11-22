# 用户维度数据存储方式 — Lua 实践

以 `player` 对象为入口，在底层 [自定义数据库管理系统](../自定义数据库管理系统-Lua.md)（`DouyinDataStoreManager`）之上再包一层：把玩家身份解析为 `"player_" .. playerOpenID` 作 scope，转调 Manager 的读写方法。这样上层业务只面向 `player` 读写，无需关心 scope 拼接、在线校验与缓存。

> **前置依赖**：需先挂载 `DouyinDataStoreManager`（见 [自定义数据库管理系统 - Lua](../自定义数据库管理系统-Lua.md)）。概念与限制见 Manual：[用户维度数据存储方式](../../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据存储方式/用户维度数据存储方式.md)。

## 完整框架

```lua
-- DouyinPlayerDataStore.lua
-- 用户维度数据访问层：解析 player 身份 -> "player_"+openID 作 scope -> 转调 DouyinDataStoreManager
---@var UseCachedData:boolean
---@end

function Awake()
    _G["DouyinPlayerDataStore"] = script
    script.datas = {}                       -- 可选内存缓存
end

function OnDestroy()
    _G["DouyinPlayerDataStore"] = nil
    script.datas = {}
end

-- 缓存 key：storeName_scope_dataKey
local function GetDataName(storeName, scopeName, dataKey)
    return storeName .. "_" .. scopeName .. "_" .. dataKey
end

-- 维度前缀 + openID 作 scope（加前缀做维度隔离，全项目统一用 player_）
local function GetScope(playerOpenID)
    return "player_" .. playerOpenID
end

function GetData(player, storeName, dataKey, callback)
    if player == nil then callback(false, "Invalid player", nil) return end

    -- 读写前先校验玩家在线/有效，拿不到直接失败
    local onlinePlayer = DouyinPlayerService.GetPlayerByOpenID(player.playerOpenID)
    if onlinePlayer == nil then callback(false, "Failed to get player", nil) return end

    local scope = GetScope(onlinePlayer.playerOpenID)

    if UseCachedData then
        local cacheKey = GetDataName(storeName, scope, dataKey)
        if script.datas[cacheKey] ~= nil then
            callback(true, "Success", script.datas[cacheKey])
            return
        end
    end

    DouyinDataStoreManager.GetData(storeName, scope, dataKey, callback)
end

function SetData(player, storeName, dataKey, data, callback)
    if player == nil then callback(false, "Invalid player", nil) return end

    local onlinePlayer = DouyinPlayerService.GetPlayerByOpenID(player.playerOpenID)
    if onlinePlayer == nil then callback(false, "Failed to get player", nil) return end

    local scope = GetScope(onlinePlayer.playerOpenID)

    if UseCachedData then
        script.datas[GetDataName(storeName, scope, dataKey)] = data
    end

    DouyinDataStoreManager.SetData(storeName, scope, dataKey, data, callback)
end

function IncrementData(player, storeName, dataKey, value, callback)
    if player == nil then callback(false, "Invalid player", nil) return end

    local onlinePlayer = DouyinPlayerService.GetPlayerByOpenID(player.playerOpenID)
    if onlinePlayer == nil then callback(false, "Failed to get player", nil) return end

    local scope = GetScope(onlinePlayer.playerOpenID)

    if UseCachedData then
        local cacheKey = GetDataName(storeName, scope, dataKey)
        if script.datas[cacheKey] ~= nil then
            script.datas[cacheKey] = script.datas[cacheKey] + value   -- 缓存同步自增
        end
    end

    DouyinDataStoreManager.IncrementData(storeName, scope, dataKey, value, callback)
end

function UpdateData(player, storeName, dataKey, func, callback)
    if player == nil then callback(false, "Invalid player", nil) return end

    local onlinePlayer = DouyinPlayerService.GetPlayerByOpenID(player.playerOpenID)
    if onlinePlayer == nil then callback(false, "Failed to get player", nil) return end

    local scope = GetScope(onlinePlayer.playerOpenID)

    if UseCachedData then
        local cacheKey = GetDataName(storeName, scope, dataKey)
        if script.datas[cacheKey] ~= nil then
            script.datas[cacheKey] = func(script.datas[cacheKey])
        end
    end

    DouyinDataStoreManager.UpdateData(storeName, scope, dataKey, func, callback)
end

function RemoveData(player, storeName, dataKey, callback)
    if player == nil then callback(false, "Invalid player", nil) return end

    local onlinePlayer = DouyinPlayerService.GetPlayerByOpenID(player.playerOpenID)
    if onlinePlayer == nil then callback(false, "Failed to get player", nil) return end

    local scope = GetScope(onlinePlayer.playerOpenID)

    if UseCachedData then
        script.datas[GetDataName(storeName, scope, dataKey)] = nil
    end

    DouyinDataStoreManager.RemoveData(storeName, scope, dataKey, callback)
end
```

## 生命周期预加载

在玩家加入事件里预加载账号级数据，减少首次读取延迟：

```lua
-- 玩家加入时预加载其账号级数据
function OnPlayerJoined(player)
    DouyinPlayerDataStore.GetData(player, "backpack", "items", function(success, message, data)
        if success then
            playerData = data       -- 缓存到业务层，供后续使用
        end
    end)
end
```

## 相关文档

- C# 版：[用户维度数据存储方式 - C#](用户维度数据存储方式-CSharp.md)
- 精灵维度：[精灵维度数据存储方式 - Lua](精灵维度数据存储方式-Lua.md)
- 底层框架：[自定义数据库管理系统 - Lua](../自定义数据库管理系统-Lua.md)
- Manual：[用户维度数据存储方式](../../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据存储方式/用户维度数据存储方式.md)
