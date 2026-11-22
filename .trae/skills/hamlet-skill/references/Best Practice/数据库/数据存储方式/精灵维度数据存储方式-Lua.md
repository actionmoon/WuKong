# 精灵维度数据存储方式 — Lua 实践

以 `pet` 对象为入口，在底层 [自定义数据库管理系统](../自定义数据库管理系统-Lua.md)（`DouyinDataStoreManager`）之上再包一层：把精灵身份解析为 `"pet_" .. petOpenID` 作 scope，转调 Manager 的读写方法。数据随精灵本体走，不因合养玩家账号切换或离线而丢失；上层业务只面向 `pet` 读写，无需关心 scope 拼接、在线校验与缓存。

> **前置依赖**：需先挂载 `DouyinDataStoreManager`（见 [自定义数据库管理系统 - Lua](../自定义数据库管理系统-Lua.md)）。概念与限制见 Manual：[精灵维度数据存储方式](../../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据存储方式/精灵维度数据存储方式.md)。

## 完整框架

```lua
-- DouyinPetDataStore.lua
-- 精灵维度数据访问层：解析 pet 身份 -> "pet_"+openID 作 scope -> 转调 DouyinDataStoreManager
---@var UseCachedData:boolean
---@end

function Awake()
    _G["DouyinPetDataStore"] = script
    script.datas = {}                       -- 可选内存缓存
end

function OnDestroy()
    _G["DouyinPetDataStore"] = nil
    script.datas = {}
end

-- 缓存 key：storeName_scope_dataKey
local function GetDataName(storeName, scopeName, dataKey)
    return storeName .. "_" .. scopeName .. "_" .. dataKey
end

-- 维度前缀 + openID 作 scope（加前缀做维度隔离，全项目统一用 pet_）
local function GetScope(petOpenID)
    return "pet_" .. petOpenID
end

function GetData(pet, storeName, dataKey, callback)
    if pet == nil then callback(false, "Invalid pet", nil) return end

    -- 读写前先校验精灵在线/有效，拿不到直接失败
    local onlinePet = DouyinPetService.GetPet(pet.petID)
    if onlinePet == nil then callback(false, "Failed to get pet", nil) return end

    local scope = GetScope(onlinePet.petOpenID)

    if UseCachedData then
        local cacheKey = GetDataName(storeName, scope, dataKey)
        if script.datas[cacheKey] ~= nil then
            callback(true, "Success", script.datas[cacheKey])
            return
        end
    end

    DouyinDataStoreManager.GetData(storeName, scope, dataKey, callback)
end

function SetData(pet, storeName, dataKey, data, callback)
    if pet == nil then callback(false, "Invalid pet", nil) return end

    local onlinePet = DouyinPetService.GetPet(pet.petID)
    if onlinePet == nil then callback(false, "Failed to get pet", nil) return end

    local scope = GetScope(onlinePet.petOpenID)

    if UseCachedData then
        script.datas[GetDataName(storeName, scope, dataKey)] = data
    end

    DouyinDataStoreManager.SetData(storeName, scope, dataKey, data, callback)
end

function IncrementData(pet, storeName, dataKey, value, callback)
    if pet == nil then callback(false, "Invalid pet", nil) return end

    local onlinePet = DouyinPetService.GetPet(pet.petID)
    if onlinePet == nil then callback(false, "Failed to get pet", nil) return end

    local scope = GetScope(onlinePet.petOpenID)

    if UseCachedData then
        local cacheKey = GetDataName(storeName, scope, dataKey)
        if script.datas[cacheKey] ~= nil then
            script.datas[cacheKey] = script.datas[cacheKey] + value   -- 缓存同步自增
        end
    end

    DouyinDataStoreManager.IncrementData(storeName, scope, dataKey, value, callback)
end

function UpdateData(pet, storeName, dataKey, func, callback)
    if pet == nil then callback(false, "Invalid pet", nil) return end

    local onlinePet = DouyinPetService.GetPet(pet.petID)
    if onlinePet == nil then callback(false, "Failed to get pet", nil) return end

    local scope = GetScope(onlinePet.petOpenID)

    if UseCachedData then
        local cacheKey = GetDataName(storeName, scope, dataKey)
        if script.datas[cacheKey] ~= nil then
            script.datas[cacheKey] = func(script.datas[cacheKey])
        end
    end

    DouyinDataStoreManager.UpdateData(storeName, scope, dataKey, func, callback)
end

function RemoveData(pet, storeName, dataKey, callback)
    if pet == nil then callback(false, "Invalid pet", nil) return end

    local onlinePet = DouyinPetService.GetPet(pet.petID)
    if onlinePet == nil then callback(false, "Failed to get pet", nil) return end

    local scope = GetScope(onlinePet.petOpenID)

    if UseCachedData then
        script.datas[GetDataName(storeName, scope, dataKey)] = nil
    end

    DouyinDataStoreManager.RemoveData(storeName, scope, dataKey, callback)
end
```

## 生命周期预加载

在精灵生成事件里获取 `douyinPet` 并预加载实体级数据，减少首次读取延迟：

```lua
-- 精灵生成时获取网络对象的 douyinPet 组件并预加载其实体级数据
function OnActorSpawn(actor)
    local pet = actor.douyinPet
    if pet == nil then return end

    DouyinPetDataStore.GetData(pet, "backpack", "items", function(success, message, data)
        if success then
            petData = data       -- 缓存到业务层，供后续使用
        end
    end)
end
```

## 相关文档

- C# 版：[精灵维度数据存储方式 - C#](精灵维度数据存储方式-CSharp.md)
- 用户维度：[用户维度数据存储方式 - Lua](用户维度数据存储方式-Lua.md)
- 底层框架：[自定义数据库管理系统 - Lua](../自定义数据库管理系统-Lua.md)
- Manual：[精灵维度数据存储方式](../../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据存储方式/精灵维度数据存储方式.md)
