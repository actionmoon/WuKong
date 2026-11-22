# 用户维度数据存储方式 — C# 实践

以 `player` 对象为入口，在底层 [自定义数据库管理系统](../自定义数据库管理系统-CSharp.md)（`DataStoreManager`，回调式）之上再包一层：把玩家身份解析为 `"player_" + playerOpenID` 作 scope，转调 Manager 的读写方法。上层业务只面向 `player` 读写，无需关心 scope 拼接、在线校验与缓存。

> **前置依赖**：需先有 C# 版 `DataStoreManager`（见 [自定义数据库管理系统 - C#](../自定义数据库管理系统-CSharp.md)）。回调统一 `Action<bool, string, object>`，无 `async/await`。概念与限制见 Manual：[用户维度数据存储方式](../../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据存储方式/用户维度数据存储方式.md)。

## 完整框架

```csharp
using System;
using System.Collections.Generic;

// 用户维度数据访问层：解析 player -> "player_"+openID 作 scope -> 转调 DataStoreManager
public static class PlayerDataStore
{
    public static bool UseCachedData = false;
    private static readonly Dictionary<string, object> _datas = new Dictionary<string, object>();

    private static string GetDataName(string storeName, string scope, string dataKey)
        => storeName + "_" + scope + "_" + dataKey;

    // 维度前缀 + openID（加前缀做维度隔离，全项目统一用 player_）
    private static string GetScope(string playerOpenID) => "player_" + playerOpenID;

    public static void GetData(DouyinPlayer player, string storeName, string dataKey, Action<bool, string, object> callback)
    {
        if (player == null) { callback(false, "Invalid player", null); return; }

        // 读写前先校验玩家在线/有效，拿不到直接失败
        var online = DouyinPlayerService.GetPlayerByOpenID(player.playerOpenID);
        if (online == null) { callback(false, "Failed to get player", null); return; }

        string scope = GetScope(online.playerOpenID);

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

    public static void SetData(DouyinPlayer player, string storeName, string dataKey, object data, Action<bool, string, object> callback)
    {
        if (player == null) { callback(false, "Invalid player", null); return; }

        var online = DouyinPlayerService.GetPlayerByOpenID(player.playerOpenID);
        if (online == null) { callback(false, "Failed to get player", null); return; }

        string scope = GetScope(online.playerOpenID);
        if (UseCachedData) _datas[GetDataName(storeName, scope, dataKey)] = data;

        DataStoreManager.SetData(storeName, scope, dataKey, data, callback);
    }

    public static void IncrementData(DouyinPlayer player, string storeName, string dataKey, double value, Action<bool, string, object> callback)
    {
        if (player == null) { callback(false, "Invalid player", null); return; }

        var online = DouyinPlayerService.GetPlayerByOpenID(player.playerOpenID);
        if (online == null) { callback(false, "Failed to get player", null); return; }

        string scope = GetScope(online.playerOpenID);
        DataStoreManager.IncrementData(storeName, scope, dataKey, value, callback);
    }

    public static void UpdateData(DouyinPlayer player, string storeName, string dataKey, Func<object, object> transform, Action<bool, string, object> callback)
    {
        if (player == null) { callback(false, "Invalid player", null); return; }

        var online = DouyinPlayerService.GetPlayerByOpenID(player.playerOpenID);
        if (online == null) { callback(false, "Failed to get player", null); return; }

        string scope = GetScope(online.playerOpenID);
        DataStoreManager.UpdateData(storeName, scope, dataKey, transform, callback);
    }

    public static void RemoveData(DouyinPlayer player, string storeName, string dataKey, Action<bool, string, object> callback)
    {
        if (player == null) { callback(false, "Invalid player", null); return; }

        var online = DouyinPlayerService.GetPlayerByOpenID(player.playerOpenID);
        if (online == null) { callback(false, "Failed to get player", null); return; }

        string scope = GetScope(online.playerOpenID);
        if (UseCachedData) _datas.Remove(GetDataName(storeName, scope, dataKey));

        DataStoreManager.RemoveData(storeName, scope, dataKey, callback);
    }
}
```

## 生命周期预加载

在玩家加入时预加载账号级数据，减少首次读取延迟：

```csharp
// 玩家加入时预加载账号级数据
public void OnPlayerJoined(DouyinPlayer player)
{
    PlayerDataStore.GetData(player, "backpack", "items", (success, message, data) =>
    {
        if (success) _playerData = data;
    });
}
```

## 相关文档

- Lua 版：[用户维度数据存储方式 - Lua](用户维度数据存储方式-Lua.md)
- 精灵维度：[精灵维度数据存储方式 - C#](精灵维度数据存储方式-CSharp.md)
- 底层框架：[自定义数据库管理系统 - C#](../自定义数据库管理系统-CSharp.md)
- Manual：[用户维度数据存储方式](../../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据存储方式/用户维度数据存储方式.md)
