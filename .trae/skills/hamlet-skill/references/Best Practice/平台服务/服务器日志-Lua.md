# 服务器日志 - Lua

> 本篇带你从 0 到 1 用 Lua 在 DS 服务端打**带业务上下文的分级日志**并做**频控自保护**，让线上问题能在创作后台「服务器日志看板」按玩家 / 房间 / 模块快速定位。
>
> `DouyinLogService` 是**全局注入对象**（Lua 侧直接调用），只有 `Debug` / `Log` / `Info` / `Warning` / `Error` 五个方法，签名统一 `(string message)`——没有 tag 参数、格式化重载、`SetLevel`、异步或事件接口，上下文与限流都要自己在 message 里实现。级别语义、8KB / 频控限制、看板查询入口与常见问题见 Manual：[服务器日志](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/服务器日志.md)。

---

## 一、结构化日志 helper（统一上下文 + 分级）

把以下 helper 放在 **DS 服务端**脚本公共区（上报级日志只在 DS 生效，客户端调用无效）。业务用 `LogInfo` / `LogError` 等，自动拼模块标签与上下文，避免只打一句“失败了”。

```lua
local DouyinLogService = DouyinLogService

-- 把上下文表拼成 " key=value" 串，让看板能按 openID / roomID 检索
local function formatContext(ctx)
    if ctx == nil then return "" end
    local parts = {}
    for k, v in pairs(ctx) do
        parts[#parts + 1] = string.format("%s=%s", tostring(k), tostring(v))
    end
    return " " .. table.concat(parts, " ")
end

-- module: 模块标签；msg: 描述；ctx: 上下文表（可选，如 { openID=..., roomID=... }）
-- 注意：单条 ≤ 8KB，只拼关键字段，不要把大对象 / 长 JSON 整体打印
local function buildMessage(module, msg, ctx)
    return string.format("[%s] %s%s", module, msg, formatContext(ctx))
end

-- 按语义分级，不要全用 Error：常规流程 Info、可疑 Warning、失败 Error
local function LogInfo(module, msg, ctx)
    DouyinLogService.Info(buildMessage(module, msg, ctx))
end

local function LogWarning(module, msg, ctx)
    DouyinLogService.Warning(buildMessage(module, msg, ctx))
end

local function LogError(module, msg, ctx)
    DouyinLogService.Error(buildMessage(module, msg, ctx))
end
```

用法：

```lua
-- 输出形如： [Trade] 发货成功 openID=xxx orderId=yyy
LogInfo("Trade", "发货成功", { openID = playerOpenID, orderId = orderId })
```

---

## 二、频控自保护（限流 + 聚合）

平台限制每帧 20 条、每秒 200 条，且不要在 `Update` 中逐帧打印。对高频错误做**每秒计数聚合**，避免刷屏截断。

```lua
local UnityEngine = UnityEngine

local logCounters = {}      -- key -> { second = 秒, count = 次数 }
local MAX_PER_SECOND = 5    -- 同 key 每秒最多打 5 条，其余聚合丢弃

-- 返回 true 表示本次允许打印
local function allowLog(key)
    local now = math.floor(UnityEngine.Time.realtimeSinceStartup)
    local c = logCounters[key]
    if c == nil or c.second ~= now then
        logCounters[key] = { second = now, count = 1 }
        return true
    end
    c.count = c.count + 1
    return c.count <= MAX_PER_SECOND
end

-- 高频错误：同 key 限流，超出的丢弃（可在下个周期补一条聚合汇总）
local function LogErrorThrottled(module, key, msg, ctx)
    if allowLog(module .. ":" .. key) then
        LogError(module, msg, ctx)
    end
end
```

---

## 三、问题定位场景

### 数据库读写失败

配合 [数据存储DataStore - Lua](../数据库/数据存储DataStore-Lua.md) 的错误码：

```lua
-- store.Get 回调里
if code ~= 0 and code ~= -10001 then
    LogError("DataStore", "读取失败", { openID = playerOpenID, key = dataKey, code = code })
end
```

### 交易发货 / 补单

配合 [交易与发货流程 - Lua](../商业化/交易与发货流程-Lua.md)：

```lua
LogInfo("Trade", "收到扣款事件", { openID = receiptInfo.playerOpenId, orderId = receiptInfo.purchaseOrder })
-- 幂等命中
LogWarning("Trade", "订单已发货，跳过重复发货", { orderId = orderId })
-- 发货失败触发补单
LogError("Trade", "发货落库失败，触发补单", { orderId = orderId, code = code })
```

---

## 四、相关文档

- C# 版：[服务器日志 - C#](服务器日志-CSharp.md)
- Manual（级别语义、限制、看板入口、常见问题 FAQ）：[服务器日志](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/服务器日志.md)
- 配合排查：[交易与发货流程 - Lua](../商业化/交易与发货流程-Lua.md)、[数据存储DataStore - Lua](../数据库/数据存储DataStore-Lua.md)
- API Reference：[DouyinLogService](../../API%20Reference/DouyinLogService.md)
