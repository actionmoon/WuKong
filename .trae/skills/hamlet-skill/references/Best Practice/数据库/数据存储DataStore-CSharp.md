# 数据存储 DataStore — C# 实践

原生键值对存储 `DouyinDataStore` 的 C# 写法。C# 侧是**回调式**：没有 `async/await`，也不抛异常，一律通过回调结果 `DouyinDataRes` 的整数错误码 `res.Code` 判断成败（`0` 成功，`-10001` 表示数据不存在）。

> 概念（Name/Scope/Key 三段式、容量与频控限制、错误码全表）见 Manual：[数据存储DataStore](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据存储DataStore.md)。Lua 版见 [数据存储DataStore - Lua](数据存储DataStore-Lua.md)。需要统一封装的读写管理层，见 [自定义数据库管理系统 - C#](自定义数据库管理系统-CSharp.md)。
>
> **DS 模式**：DedicatedServer 网络模式下云端读写**仅允许服务端执行**，客户端发起报 `-11002`。

## 真实 API 形态

- **入口**：全局静态方法 `DouyinDataStoreService.GetDataStore(name, scope, Action<DouyinDataRes> callback)`，回调里从 `storeRes.Store` 拿到 `DouyinDataStore` 实例。`name` ≤ 20 字符、`scope` ≤ 50 字符（如 `"player_" + playerOpenID`）。
- **实例方法**（均为回调式）：`store.Get(key, cb)`、`store.Set(key, value, options, cb)`（有 `string`/`double`/`bool` 重载）、`store.Increment(key, delta, options, cb)`、`store.Remove(key, cb)`。不需要 metadata 时 `options` 传 `null`。
- **读取结果**：字符串取 `res.ValueDataInfo?.value` 或 `res.ValueString`；数值取 `res.ValueDouble` / `res.ValueLong`；`Increment` 结果在 `res.ValueDouble`。
- **序列化**：平台内置 **LitJson**（`JsonMapper.ToJson(obj)` / `JsonMapper.ToObject<T>(str)`）。DataStore 存字符串，表结构需业务自行序列化，无泛型自动编解码。
- **日志**：示例统一用平台封装的 `CommonDebug.Log / LogWarning / LogError`（直接用 `UnityEngine.Debug` 亦可）。

## 读 / 写 / 自增 / 删除

```csharp
using UnityEngine;

public class DataStoreSample
{
    public void Run(string playerOpenID)
    {
        string scope = "player_" + playerOpenID;

        // 获取 store：storeRes.Code == 0 才成功；同一 name+scope 复用同一实例
        DouyinDataStoreService.GetDataStore("sim_game", scope, storeRes =>
        {
            // 一律显式判 Code：回调式不抛异常，不判就会“静默失败”。日志带上 Code + Msg
            if (storeRes.Code != 0)
            {
                CommonDebug.LogError($"[DataStore] GetDataStore 失败 code={storeRes.Code} msg={storeRes.Msg}");
                return;
            }
            var store = storeRes.Store;

            // 读：-10001 是“新号/数据不存在”，属正常业务分支，不是错误
            store.Get("coin", res =>
            {
                if (res.Code == -10001)
                {
                    store.Set("coin", 0.0, null, _ => { });   // 新号初始化：数值直接存 double
                }
                else if (res.Code == 0)
                {
                    CommonDebug.Log($"[DataStore] coin = {res.ValueLong}");
                }
                else
                {
                    CommonDebug.LogError($"[DataStore] 读取失败 code={res.Code} msg={res.Msg}");
                }
            });

            // 写：序列化后别超过约 6000 字符，超了返回 -10013
            store.Set("coin", "100", null, res => { if (res.Code != 0) CommonDebug.LogError($"写入失败 {res.Code}"); });

            // 自增：delta 必须是 double；被自增的 key 必须全程以数值类型存储，否则计数会被误判为“新号”而清零
            store.Increment("coin", 10.0, null, res => { if (res.Code == 0) CommonDebug.Log($"coin = {res.ValueDouble}"); });

            // 删除
            store.Remove("coin", _ => { });
        });
    }
}
```

## 表数据的 JSON 编解码（LitJson）

DataStore 存字符串，表结构需业务自行序列化。POCO 字段仅用基础类型 / `string` / 数值 / `List<>` / `Dictionary<string, ...>`，复杂字段会读回默认值。

```csharp
using System.Collections.Generic;
using LitJson;

[System.Serializable]
public class PlayerData
{
    public long coin;
    public int level;
    public List<int> items = new();
}

// 保存：先序列化再校验长度
void Save(DouyinDataStore store, PlayerData data)
{
    string json = JsonMapper.ToJson(data);
    if (json.Length > 6000)   // 超限写入会失败（-10013）
    {
        CommonDebug.LogError($"[DataStore] value 超长 {json.Length}，需拆分或压缩");
        return;
    }
    store.Set("player_data", json, null, res => { if (res.Code != 0) CommonDebug.LogError($"写入失败 {res.Code}"); });
}

// 读取：新号返回空对象，否则反序列化
void Load(DouyinDataStore store)
{
    store.Get("player_data", res =>
    {
        if (res.Code != 0 && res.Code != -10001) { CommonDebug.LogError($"读取失败 {res.Code}"); return; }
        string raw = res.ValueDataInfo?.value;
        var obj = string.IsNullOrEmpty(raw) ? new PlayerData() : JsonMapper.ToObject<PlayerData>(raw);
        CommonDebug.Log($"coin={obj.coin} level={obj.level}");
    });
}
```

## 失败重试（网络类错误退避）

只对网络类错误（如 `-10050`）重试；`name`/`scope`/value 超长等校验错误重试再多次也不会成功，应直接失败并修数据。回调式没有 `Task.Delay`，延时用 Unity 协程 `WaitForSeconds`，因此重试逻辑挂在 `MonoBehaviour` 上。

```csharp
using System;
using System.Collections;
using UnityEngine;

// 挂在任意 MonoBehaviour 上（协程需要 MonoBehaviour 宿主）
public class DataStoreWriter : MonoBehaviour
{
    private const int MaxRetries = 3;

    public void SaveWithRetry(string name, string scope, string key, string value, Action<bool> onDone)
        => StartCoroutine(SaveCoroutine(name, scope, key, value, 0, onDone));

    private IEnumerator SaveCoroutine(string name, string scope, string key, string value, int attempt, Action<bool> onDone)
    {
        bool finished = false, succeeded = false, retryable = false;

        DouyinDataStoreService.GetDataStore(name, scope, storeRes =>
        {
            if (storeRes.Code != 0)
            {
                retryable = storeRes.Code == -10050;   // 仅网络类错误可重试
                CommonDebug.LogWarning($"[Save] GetDataStore code={storeRes.Code} msg={storeRes.Msg}");
                finished = true;
                return;
            }
            storeRes.Store.Set(key, value, null, res =>
            {
                succeeded = res.Code == 0;
                retryable = res.Code == -10050;
                if (!succeeded) CommonDebug.LogWarning($"[Save] Set code={res.Code} msg={res.Msg}");
                finished = true;
            });
        });

        while (!finished) yield return null;   // 等回调返回

        if (succeeded) { onDone?.Invoke(true); yield break; }

        if (retryable && attempt < MaxRetries)
        {
            yield return new WaitForSeconds(1 << attempt);   // 指数退避：1s, 2s, 4s
            yield return SaveCoroutine(name, scope, key, value, attempt + 1, onDone);
        }
        else
        {
            onDone?.Invoke(false);   // 失败：业务侧可降级到本地缓存，待网络恢复再同步
        }
    }
}
```

## 相关文档

- Lua 版：[数据存储DataStore - Lua](数据存储DataStore-Lua.md)
- 统一封装：[自定义数据库管理系统 - C#](自定义数据库管理系统-CSharp.md)
- 有序/排行榜存储：[数据存储OrderedDataStore - C#](数据存储OrderedDataStore-CSharp.md)
- Manual（概念、限制、错误码全表）：[数据存储DataStore](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据存储DataStore.md)、[数据库概述](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/数据库/数据库概述.md)
- API Reference：[DouyinDataService.GetDataStore](../../API%20Reference/数据存储/DouyinDataService/DouyinDataService.GetDataStore.md)、[DouyinDataStore](../../API%20Reference/数据存储/DouyinDataStore.md)
