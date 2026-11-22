# 精灵维度数据存储方式 — C# 实践

以 `pet` 对象为入口，在底层 [自定义数据库管理系统](../自定义数据库管理系统-CSharp.md)（`DataStoreManager`，回调式）之上再包一层：把精灵身份解析为 `"pet_" + petOpenID` 作 scope，转调 Manager 的读写方法。数据随精灵本体走，不因合养玩家账号切换或离线而丢失；上层业务只面向 `pet` 读写，无需关心 scope 拼接、在线校验与缓存。

> **前置依赖**：需先有 C# 版 `DataStoreManager`（见 [自定义数据库管理系统 - C#](../自定义数据库管理系统-CSharp.md)）。回调统一 `Action<bool, string, object>`，无 `async/await`。概念与限制见 Manual：[精灵维度数据存储方式](../../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据存储方式/精灵维度数据存储方式.md)。

## 完整框架

```csharp
using System;
using System.Collections.Generic;

// 精灵维度数据访问层：解析 pet 身份 -> "pet_"+openID 作 scope -> 转调 DataStoreManager
public static class PetDataStore
{
    public static bool UseCachedData = false;                // 可选内存缓存开关
    private static readonly Dictionary<string, object> _datas = new Dictionary<string, object>();

    // 缓存 key：storeName_scope_dataKey
    private static string GetDataName(string storeName, string scope, string dataKey)
        => storeName + "_" + scope + "_" + dataKey;

    // 维度前缀 + openID 作 scope（加前缀做维度隔离，全项目统一用 pet_）
    private static string GetScope(string petOpenID) => "pet_" + petOpenID;

    public static void GetData(DouyinPet pet, string storeName, string dataKey, Action<bool, string, object> callback)
    {
        if (pet == null) { callback(false, "Invalid pet", null); return; }

        // 读写前先校验精灵在线/有效，拿不到直接失败
        var online = DouyinPetService.GetPet(pet.petID);
        if (online == null) { callback(false, "Failed to get pet", null); return; }

        string scope = GetScope(online.petOpenID);

        if (UseCachedData)
        {
            string cacheKey = GetDataName(storeName, scope, dataKey);
            if (_datas.TryGetValue(cacheKey, out var cached))
            {
                callback(true, "Success", cached);
                return;
            }
        }

        DataStoreManager.GetData(storeName, scope, dataKey, callback);
    }

    public static void SetData(DouyinPet pet, string storeName, string dataKey, object data, Action<bool, string, object> callback)
    {
        if (pet == null) { callback(false, "Invalid pet", null); return; }

        var online = DouyinPetService.GetPet(pet.petID);
        if (online == null) { callback(false, "Failed to get pet", null); return; }

        string scope = GetScope(online.petOpenID);
        if (UseCachedData) _datas[GetDataName(storeName, scope, dataKey)] = data;

        DataStoreManager.SetData(storeName, scope, dataKey, data, callback);
    }

    public static void IncrementData(DouyinPet pet, string storeName, string dataKey, double value, Action<bool, string, object> callback)
    {
        if (pet == null) { callback(false, "Invalid pet", null); return; }

        var online = DouyinPetService.GetPet(pet.petID);
        if (online == null) { callback(false, "Failed to get pet", null); return; }

        string scope = GetScope(online.petOpenID);
        DataStoreManager.IncrementData(storeName, scope, dataKey, value, callback);
    }

    public static void UpdateData(DouyinPet pet, string storeName, string dataKey, Func<object, object> transform, Action<bool, string, object> callback)
    {
        if (pet == null) { callback(false, "Invalid pet", null); return; }

        var online = DouyinPetService.GetPet(pet.petID);
        if (online == null) { callback(false, "Failed to get pet", null); return; }

        string scope = GetScope(online.petOpenID);
        DataStoreManager.UpdateData(storeName, scope, dataKey, transform, callback);
    }

    public static void RemoveData(DouyinPet pet, string storeName, string dataKey, Action<bool, string, object> callback)
    {
        if (pet == null) { callback(false, "Invalid pet", null); return; }

        var online = DouyinPetService.GetPet(pet.petID);
        if (online == null) { callback(false, "Failed to get pet", null); return; }

        string scope = GetScope(online.petOpenID);
        if (UseCachedData) _datas.Remove(GetDataName(storeName, scope, dataKey));

        DataStoreManager.RemoveData(storeName, scope, dataKey, callback);
    }
}
```

## 生命周期预加载

在精灵生成事件里获取 `douyinPet` 并预加载实体级数据，减少首次读取延迟：

```csharp
// 精灵生成时获取网络对象的 douyinPet 组件并预加载其实体级数据
public void OnActorSpawn(DouyinActor actor)
{
    var pet = actor.douyinPet;
    if (pet == null) return;

    PetDataStore.GetData(pet, "backpack", "items", (success, message, data) =>
    {
        if (success) _petData = data;       // 缓存到业务层，供后续使用
    });
}
```

## 相关文档

- Lua 版：[精灵维度数据存储方式 - Lua](精灵维度数据存储方式-Lua.md)
- 用户维度：[用户维度数据存储方式 - C#](用户维度数据存储方式-CSharp.md)
- 底层框架：[自定义数据库管理系统 - C#](../自定义数据库管理系统-CSharp.md)
- Manual：[精灵维度数据存储方式](../../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据存储方式/精灵维度数据存储方式.md)
