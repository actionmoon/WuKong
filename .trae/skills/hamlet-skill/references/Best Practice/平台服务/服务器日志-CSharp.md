# 服务器日志 - C#

> 本篇带你从 0 到 1 用 C# 在 DS 服务端打**带业务上下文的分级日志**并做**频控自保护**，让线上问题能在创作后台「服务器日志看板」按玩家 / 房间 / 模块快速定位。
>
> C# 侧 `DouyinLogService` 是**全局静态类**，只有 `Debug` / `Log` / `Info` / `Warning` / `Error` 五个方法，签名统一 `(string message)`——没有 tag 参数、格式化重载、`SetLevel`、`async` 版本、事件接口，也没有 `DouyinLogService.Instance` 单例，上下文与限流都要自己实现。级别语义、8KB / 频控限制、看板查询入口与常见问题见 Manual：[服务器日志](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/服务器日志.md)。

---

## 一、结构化日志封装（统一上下文 + 分级）

把以下工具类放在 **DS 服务端**脚本中（上报级日志只在 DS 生效，客户端调用无效）。业务用 `Info` / `Error` 等，自动拼模块标签与上下文。

```csharp
using System.Collections.Generic;
using System.Text;

public static class ServerLog
{
    // 把上下文拼成 " key=value" 串，让看板能按 openID / roomID 检索
    private static string FormatContext(IReadOnlyDictionary<string, object> ctx)
    {
        if (ctx == null || ctx.Count == 0) return string.Empty;
        var sb = new StringBuilder();
        foreach (var kv in ctx)
        {
            sb.Append(' ').Append(kv.Key).Append('=').Append(kv.Value);
        }
        return sb.ToString();
    }

    // 注意：单条 ≤ 8KB，只拼关键字段，不要把大对象整体序列化打印
    private static string Build(string module, string msg, IReadOnlyDictionary<string, object> ctx)
        => $"[{module}] {msg}{FormatContext(ctx)}";

    // 按语义分级，不要全用 Error：常规流程 Info、可疑 Warning、失败 Error
    public static void Info(string module, string msg, IReadOnlyDictionary<string, object> ctx = null)
        => DouyinLogService.Info(Build(module, msg, ctx));

    public static void Warning(string module, string msg, IReadOnlyDictionary<string, object> ctx = null)
        => DouyinLogService.Warning(Build(module, msg, ctx));

    public static void Error(string module, string msg, IReadOnlyDictionary<string, object> ctx = null)
        => DouyinLogService.Error(Build(module, msg, ctx));
}
```

用法：

```csharp
// 输出形如： [Trade] 发货成功 openID=xxx orderId=yyy
ServerLog.Info("Trade", "发货成功", new Dictionary<string, object>
{
    { "openID", playerOpenID },
    { "orderId", orderId },
});
```

---

## 二、频控自保护（限流 + 聚合）

平台限制每帧 20 条、每秒 200 条，且不要在 `Update` 中逐帧打印。对高频错误做**每秒计数聚合**：

```csharp
using System.Collections.Generic;
using UnityEngine;

public static class LogThrottle
{
    private const int MaxPerSecond = 5; // 同 key 每秒最多 5 条，其余聚合丢弃

    private struct Counter { public int Second; public int Count; }
    private static readonly Dictionary<string, Counter> _counters = new Dictionary<string, Counter>();

    // 返回 true 表示本次允许打印
    public static bool Allow(string key)
    {
        int now = (int)Time.realtimeSinceStartup;
        if (!_counters.TryGetValue(key, out var c) || c.Second != now)
        {
            _counters[key] = new Counter { Second = now, Count = 1 };
            return true;
        }
        c.Count++;
        _counters[key] = c;
        return c.Count <= MaxPerSecond;
    }
}

// 高频错误：同 key 限流
public static void LogErrorThrottled(string module, string key, string msg)
{
    if (LogThrottle.Allow($"{module}:{key}"))
    {
        ServerLog.Error(module, msg);
    }
}
```

---

## 三、问题定位场景

### 数据库读写失败

配合 [数据存储DataStore - C#](../数据库/数据存储DataStore-CSharp.md) 的错误码：

```csharp
// store.Get 回调里
if (res.Code != 0 && res.Code != -10001)
{
    ServerLog.Error("DataStore", "读取失败", new Dictionary<string, object>
    {
        { "openID", playerOpenID }, { "key", dataKey }, { "code", res.Code },
    });
}
```

### 交易发货 / 补单

配合 [交易与发货流程 - C#](../商业化/交易与发货流程-CSharp.md)：

```csharp
ServerLog.Info("Trade", "收到扣款事件", new Dictionary<string, object>
{
    { "openID", receiptInfo.playerOpenId }, { "orderId", receiptInfo.purchaseOrder },
});
// 幂等命中
ServerLog.Warning("Trade", "订单已发货，跳过重复发货", new Dictionary<string, object> { { "orderId", orderId } });
// 发货失败触发补单
ServerLog.Error("Trade", "发货落库失败，触发补单", new Dictionary<string, object> { { "orderId", orderId }, { "code", code } });
```

---

## 四、相关文档

- Lua 版：[服务器日志 - Lua](服务器日志-Lua.md)
- Manual（级别语义、限制、看板入口、常见问题 FAQ）：[服务器日志](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/服务器日志.md)
- 配合排查：[交易与发货流程 - C#](../商业化/交易与发货流程-CSharp.md)、[数据存储DataStore - C#](../数据库/数据存储DataStore-CSharp.md)
- API Reference：[DouyinLogService](../../API%20Reference/DouyinLogService.md)
