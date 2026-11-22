# 自定义数据库管理系统 — C# 实践

## 目标

本文说明如何在 C# 中从零搭建一套自定义数据库管理系统 `DataStoreManager`（静态类），用于统一管理平台数据的持久化访问，例如金币、背包、成就、精灵属性等业务数据。

在涉及数据持久化的业务开发中，若在各处业务逻辑内分散调用原生 Datastore API，往往会产生大量重复代码，并容易引发回调处理不当、序列化遗漏、错误码处理不完整等问题。

本最佳实践的核心在于：在原生数据存储 API 之上，封装一层统一的**数据访问管理层**（Datastore Manager），对外提供一致的接口规范、集中的异常处理与统一的缓存策略。封装完成后，上层业务仅需调用管理层提供的读、写、自增、读改写、删除等方法，即可完成全部数据存取，无需再关注回调处理、JSON 序列化与错误码判断等细节。

文中管理层自身的方法名（如 `GetData`、`DataStoreManager`）仅用于说明职责，可根据项目习惯自行命名；而平台原生接口（如 `DouyinDataStoreService.GetDataStore`、`store.Get` 及错误码 `-10001` 等）为真实 API，需按实际名称使用。

> **阅读前提**：本文仅说明实现方式，不涉及概念解释。数据存储的基础概念（Name/Scope/Key）、容量与频控限制、错误码全表等内容，请先查阅 Manual：[数据库概述](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据库概述.md)、[数据存储DataStore](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据存储DataStore.md)。
>
> **性质说明**：该数据访问管理层为开发者自行封装的代码层，并非平台内置模块；其内部仍调用平台原生接口，仅在其上统一封装了通用逻辑。
>
> **C# 关键约束**：① 数据存储为**回调式**接口（非 `async/await`），每个操作均传入回调、在回调中处理结果，成败统一以 `res.Code == 0` 判断。② 平台**未提供** `UpdateData`，读改写需自行通过 `Get` + `Set` 组合实现。

## 操作流程

按以下步骤依次实现。前八步完成后管理层即可独立使用，第九、十步用于封装维度与验证：

1. **搭建管理层骨架** —— 创建静态类、初始化 store 缓存字典与入口校验方法。
2. **实现"获取 store"方法** —— 统一获取并缓存 store，供后续各方法复用。
3. **实现 GetData（读）** —— 第一个对外方法，新账号首次读取也不会报错。
4. **实现 SetData（写）** —— 写入前自动序列化，可存储任意数据结构。
5. **实现 IncrementData（自增）** —— 用于金币、积分等数值的增减。
6. **实现 RemoveData（删除）** —— 删除一条数据。
7. **实现 UpdateData（读改写）** —— 通过 `Get` + `Set` 组合，基于旧值计算新值后写回。
8. **补充 JSON 辅助方法** —— 实现序列化与反序列化，至此五个方法全部完成。
9. **封装"维度"层** —— 统一拼接 scope，业务调用时无需再关注 scope。
10. **验证** —— 按场景逐项确认行为符合预期。

## 第一步：搭建管理层骨架

首先创建一个空的静态类 `DataStoreManager`，任意业务脚本均可通过 `DataStoreManager.Xxx(...)` 直接调用。类中初始化一个字典，用于按 scope 缓存已获取的 store（下一步使用）；再定义一个入口参数校验方法。

所有对外方法统一采用回调 `Action<bool, string, object>`：首个参数 `success` 为 `true` 时，第三个参数为结果；为 `false` 时，第二个参数为错误码或原因。

```csharp
using System;
using System.Collections.Generic;
using LitJson;                       // 平台内置 JSON（转对象 ↔ 文本）
using UnityEngine;

public static class DataStoreManager
{
    // 按 scope 缓存已拿到的 store，避免重复获取
    private static readonly Dictionary<string, DouyinDataStore> _stores = new Dictionary<string, DouyinDataStore>();

    // 入口参数校验：storeName / scopeName / dataKey 任一为空就不往下走
    private static bool CheckArgs(string storeName, string scopeName, string dataKey)
    {
        return !string.IsNullOrEmpty(storeName)
            && !string.IsNullOrEmpty(scopeName)
            && !string.IsNullOrEmpty(dataKey);
    }
}
```

## 第二步：实现"获取 store"方法

每次读写前都需要先获取对应的 store。由于获取 store 存在开销，同一个 scope 重复获取会造成浪费，因此用一个内部方法统一处理。由于获取 store 本身也是回调式的，该方法通过"成功回调 `onStore` / 失败回调 `onError`"返回结果：先查缓存，命中则直接返回；未命中则调用原生 `DouyinDataStoreService.GetDataStore`，回调中 `res.Code == 0` 且 `res.Store` 非空才算成功，成功后存入缓存。**获取失败时不写入缓存**，否则该 scope 将始终返回无效结果。

```csharp
private static void GetStore(string storeName, string scopeName, Action<DouyinDataStore> onStore, Action<string> onError)
{
    if (_stores.TryGetValue(scopeName, out var cached) && cached != null)
    {
        onStore(cached);
        return;
    }

    DouyinDataStoreService.GetDataStore(storeName, scopeName, res =>
    {
        if (res == null || res.Code != 0 || res.Store == null)
        {
            onError("Failed to get data store: " + (res == null ? "null" : res.Code.ToString()));
            return;
        }
        _stores[scopeName] = res.Store;      // 成功才缓存
        onStore(res.Store);
    });
}
```

## 第三步：实现 GetData（读）

第一个对外方法。执行步骤：校验参数 → 获取 store → 在回调中调用 `store.Get` 读取 → 在读取回调中处理结果。

处理结果时需注意一个关键点：`res.Code == -10001` **并非错误**，它表示"该账号尚未存储过数据"，应作为"读取成功、但数据为空"处理，业务据此判断需要执行初始化。读取到的值位于 `res.ValueString`，若为一段 JSON 文本则反序列化为对象后再返回（反序列化逻辑见后文的 `ParseValue`）。

```csharp
public static void GetData(string storeName, string scopeName, string dataKey, Action<bool, string, object> callback)
{
    if (!CheckArgs(storeName, scopeName, dataKey)) { callback(false, "Invalid parameter", null); return; }

    GetStore(storeName, scopeName,
        store => store.Get(dataKey, res =>
        {
            if (res.Code == 0)
            {
                object data = ParseValue(res.ValueString);
                callback(true, "Success", data);
            }
            else if (res.Code == -10001)
            {
                callback(true, "New Data", new JsonData());   // 新号返回空数据，业务据此做初始化
            }
            else
            {
                callback(false, "Failed to get data " + res.Code, null);
            }
        }),
        err => callback(false, err, null));
}
```

完成本步后，即可正常读取数据，且新玩家、新精灵首次读取也不会报错。

## 第四步：实现 SetData（写）

整体结构与读取一致，区别在于写入前需先将数据转换为可存储的文本（对象序列化为 JSON，其它类型保持原样，转换逻辑见后文的 `ConvertData`）。原生写方法 `store.Set(key, value, options, cb)` 的 `options` 传 `null` 即可。

```csharp
public static void SetData(string storeName, string scopeName, string dataKey, object dataValue, Action<bool, string, object> callback)
{
    if (!CheckArgs(storeName, scopeName, dataKey)) { callback(false, "Invalid parameter", null); return; }

    string value = ConvertData(dataValue);          // 写之前先转文本
    GetStore(storeName, scopeName,
        store => store.Set(dataKey, value, null, res =>       // options 传 null 即可
        {
            // 转成文本后别超过约 6000 字符，超了会返回 -10013
            if (res.Code != 0) { callback(false, res.Code.ToString(), null); return; }
            callback(true, "Success", res.ValueString);
        }),
        err => callback(false, err, null));
}
```

## 第五步：实现 IncrementData（自增）

金币、积分、次数等数值适合使用自增，无需"读取、加减、再写回"三步操作。需注意自增仅适用于**以数值存储的** key；`amount` 传入负数即为递减。自增后的新值位于回调的 `res.ValueDouble`。

```csharp
public static void IncrementData(string storeName, string scopeName, string dataKey, double amount, Action<bool, string, object> callback)
{
    if (!CheckArgs(storeName, scopeName, dataKey)) { callback(false, "Invalid parameter", null); return; }

    GetStore(storeName, scopeName,
        store => store.Increment(dataKey, amount, null, res =>
        {
            // 只能对“以数字存的”key 用；amount 传负数就是减
            if (res.Code != 0) { callback(false, res.Code.ToString(), null); return; }
            callback(true, "Success", res.ValueDouble);
        }),
        err => callback(false, err, null));
}
```

## 第六步：实现 RemoveData（删除）

结构最为简单，删除一条数据即可。

```csharp
public static void RemoveData(string storeName, string scopeName, string dataKey, Action<bool, string, object> callback)
{
    if (!CheckArgs(storeName, scopeName, dataKey)) { callback(false, "Invalid parameter", null); return; }

    GetStore(storeName, scopeName,
        store => store.Remove(dataKey, res =>
        {
            if (res.Code != 0) { callback(false, res.Code.ToString(), null); return; }
            callback(true, "Success", null);
        }),
        err => callback(false, err, null));
}
```

## 第七步：实现 UpdateData（读改写）

某些场景下新值需基于旧值计算（例如"经验值 + 本局所得"）。平台**未提供** `UpdateData`，因此需自行组合实现：先调用第三步的 `GetData` 读取当前值，交由业务的计算函数 `transform` 得出新值，再调用第四步的 `SetData` 写回。由于 `GetData`、`SetData` 均为回调式，此处即为两者的嵌套调用。

```csharp
public static void UpdateData(string storeName, string scopeName, string dataKey, Func<object, object> transform, Action<bool, string, object> callback)
{
    GetData(storeName, scopeName, dataKey, (ok, msg, cur) =>       // 先读
    {
        if (!ok) { callback(false, msg, null); return; }
        object newVal = transform(cur);                            // 业务基于旧值算新值
        SetData(storeName, scopeName, dataKey, newVal, callback);  // 再写回
    });
}
```

## 第八步：补充 JSON 辅助方法

前面的写入与读取分别用到了 `ConvertData`（写入前将对象转为文本）与 `ParseValue`（读取后将文本还原为对象），二者均基于平台内置的 `LitJson.JsonMapper` 实现。读取时若解析失败应容错返回原文，避免单条脏数据中断整个读取流程。

```csharp
// 写之前：对象转文本；字符串/数字/布尔原样
private static string ConvertData(object value)
{
    if (value == null) return "";
    if (value is string s) return s;
    if (value is int || value is long || value is float || value is double || value is bool)
        return value.ToString();
    return JsonMapper.ToJson(value);          // 复杂对象转 JSON
}

// 读之后：形如 JSON 的文本还原成对象，否则原样返回；解析失败容错返回原文
private static object ParseValue(string raw)
{
    if (string.IsNullOrEmpty(raw)) return raw;
    var trimmed = raw.Trim();
    if (trimmed.StartsWith("{") || trimmed.StartsWith("["))
    {
        try { return JsonMapper.ToObject(trimmed); } catch { return raw; }
    }
    return raw;
}
```

将第一至第八步的代码合入同一个 `DataStoreManager` 类后，五个方法全部就绪，管理层本体已可独立使用。以下为调用示例：

```csharp
// 读取（新号时 data 为空 JsonData）
DataStoreManager.GetData("backpack", "items", "item", (success, message, data) =>
{
    if (success) Debug.Log("GetData ok: " + data);
    else         Debug.LogWarning("GetData failed: " + message);
});

// 覆盖写入（对象自动转 JSON）
DataStoreManager.SetData("backpack", "items", "item", new { gold = 100 }, (success, message, data) =>
{
    Debug.Log("SetData: " + success + " " + message);
});

// 数值自增
DataStoreManager.IncrementData("backpack", "items", "count", 1, (success, message, data) =>
{
    Debug.Log("IncrementData: " + success + " " + data);
});

// 读改写：基于旧值算新值
DataStoreManager.UpdateData("backpack", "items", "count", cur =>
{
    double n = cur is double d ? d : 0;
    return n + 1;
}, (success, message, data) => Debug.Log("UpdateData: " + success));
```

## 第九步：封装"维度"层

管理层此时已可使用，但每次调用都需自行拼接 scope，容易出错。玩家数据与精灵数据的 scope 拼接规则是固定的，因此在管理层之上再封装一层，统一完成拼接：

| 维度 | scope 拼接方式 | 隔离对象 |
| --- | --- | --- |
| 用户维度 | 基于 `playerOpenID` 拼接，例如 `player_<openID>` | 各玩家自身的数据 |
| 精灵维度 | 基于 `petOpenID` 拼接，例如 `pet_<openID>` | 各精灵（小火人）的数据 |

该层不重复实现读写逻辑，仅在拼接好 scope 后转调下层管理层。完整实现见 [用户维度数据存储方式 - C#](数据存储方式/用户维度数据存储方式-CSharp.md) / [精灵维度数据存储方式 - C#](数据存储方式/精灵维度数据存储方式-CSharp.md)。

## 第十步：验证

至少覆盖以下场景，确认实现的行为符合预期：

| 场景 | 测试方式 | 预期结果 |
| --- | --- | --- |
| 新账号首次读取 | 对从未写入过的 key 调用 `GetData` | 读取成功，返回空数据，不报错 |
| 写入后读取 | 先 `SetData` 存入一个对象，再 `GetData` 读取 | 读回的结构与写入时一致 |
| 复用 store | 对同一 scope 连续读写多次 | 仅首次实际获取 store，其后命中缓存 |
| 自增 | 对数值 key 调用 `IncrementData` | 返回自增后的新值；对非数值 key 调用则失败 |
| 读改写 | 使用 `UpdateData` 基于旧值计算新值 | 写回的值基于最新值计算得出 |
| 超长数据 | 存入序列化后超长的数据 | 返回 `-10013`，不会被静默截断 |
| 删除 | `RemoveData` 后再次 `GetData` | 读取结果为"新账号/空数据" |

## 进阶扩展（选做）

完成以上步骤后即为一套完整可用的管理层。若项目规模更大，可在此基础上进一步扩展（相关原理与取舍见 Manual [数据库概述](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据库概述.md)）：

- **内存缓存**：将已读取的数据在内存中保留一份，后续优先读取内存，减少网络请求。
- **定期落库**：玩家在线期间改动先写入内存，进入时读取一次、离线时统一写回，避免高频写入触发频控（`-11001`）。
- **失败重试**：对网络类错误按 1s→2s→4s 的间隔退避重试若干次，仍失败则降级处理。
- **版本字段**：在数据中记录 `_ver` 字段，当字段结构变更时，读取旧数据可自动升级。

## 相关文档

- Lua 版：[自定义数据库管理系统 - Lua](自定义数据库管理系统-Lua.md)
- 上层维度封装：[用户维度数据存储方式 - C#](数据存储方式/用户维度数据存储方式-CSharp.md) / [精灵维度数据存储方式 - C#](数据存储方式/精灵维度数据存储方式-CSharp.md)
- 原生键值对存储实践：[数据存储DataStore - C#](数据存储DataStore-CSharp.md)
- Manual（概念、限制、错误码）：[数据库概述](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据库概述.md)、[数据存储DataStore](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据存储DataStore.md)
