# 平台工具（DouyinUtility）- Lua

> 本文带你用 Lua 从 0 到 1 用好平台工具类 `DouyinUtility`：Toast 轻量提示、Alert 确认弹窗、emoji 过滤、以及基于服务器时间的可信时间判断（签到 / 限时活动防作弊）。
>
> 能力概念、API 概览与边界请先阅读 Manual：[平台工具](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/平台工具.md)。C# 版本见 [平台工具 - C#](平台工具-CSharp.md)。API 逐项签名见 API Reference：[DouyinUtility](../../API%20Reference/DouyinUtility.md)。

---

## 一、真实 API 形态

`DouyinUtility` 是**全局注入对象**（Lua 侧直接调用，不要写成 `CS.DouyinUtility`），共 5 个静态方法：

```lua
DouyinUtility.Toast(msg)                                                      -- void，轻量提示，非阻塞
DouyinUtility.Alert(title, message, confirm, confirmCb, cancel, cancelCb)     -- void，回调式确认弹窗，无同步返回值
DouyinUtility.FilteEmoji(content)                                             -- 同步返回过滤 emoji 后的 string
DouyinUtility.GetServerTime()                                                 -- 同步返回 DateTime（UTC 0 时区）
DouyinUtility.GetServerUnixTime()                                             -- 同步返回 long（Unix 时间戳）
```

---

## 二、Toast / Alert 封装

把下面的 helper 放在脚本公共区，业务侧直接调用。约束都写在注释里，跟着代码看即可。

```lua
local DouyinUtility = DouyinUtility

-- Toast 只接受 string；上游值可能为 nil / 空时先兜底，避免传入非法参数
local function ShowToast(message)
  if message == nil or message == "" then
    return
  end
  DouyinUtility.Toast(tostring(message))
end

-- Alert 是回调式：用户的选择只通过 confirmCb / cancelCb 表达，没有同步 boolean 返回值，
-- 所以“确认后的业务”必须写在回调里。六个参数顺序固定：
-- title, message, confirm 文案, confirmCb, cancel 文案, cancelCb —— 不要交换文案与回调的位置。
local function ShowConfirmAlert(title, message, confirmText, cancelText, onConfirm, onCancel)
  DouyinUtility.Alert(
    title,
    message,
    confirmText,
    function()
      if onConfirm ~= nil then onConfirm() end
    end,
    cancelText,
    -- 取消分支即使没有业务，也传一个空函数占位，保证参数顺序正确
    function()
      if onCancel ~= nil then onCancel() end
    end
  )
end
```

### 使用场景

重置 / 消耗 / 购买 / 传送 / 放弃进度等**不可逆操作**要先 `Alert` 确认，不能只 `Toast` 一下就执行。

```lua
-- 1) 按钮点击后 Toast 反馈（Toast 是反馈，不是状态源）
function OnInteractorButtonClick(index)
  if index ~= 1 or localActor == nil then
    return
  end
  OpenChest()
  -- Toast 只是反馈，业务是否成功仍由 OpenChest() / 状态变量决定
  ShowToast("宝箱已打开")
end

-- 2) 危险操作前 Alert 确认（业务写在确认回调内，不要因为多了一层弹窗就提前执行）
function OnResetButtonClick(index)
  if index ~= 1 or localActor == nil then
    return
  end
  ShowConfirmAlert(
    "确认重置",
    "是否重置当前机关？",
    "确认",
    "取消",
    function()
      ResetMechanism()
      ShowToast("机关已重置")
    end,
    function()
      ShowToast("已取消")
    end
  )
end
```

> 提示应由点击或一次性状态变化触发，不要在 `Update` / `FixedUpdate` 中连续弹 Toast / Alert。

---

## 三、emoji 过滤（FilteEmoji）

玩家昵称 / 输入框文本在 iOS 上 emoji 易显示成乱码，入库或展示前过滤：

```lua
local DouyinUtility = DouyinUtility

-- FilteEmoji 同步返回过滤后的字符串
local function SafeText(raw)
  if raw == nil then return "" end
  return DouyinUtility.FilteEmoji(tostring(raw))
end

-- 示例：玩家改名前过滤
function OnRenameConfirm(inputText)
  local clean = SafeText(inputText)
  if clean == "" then
    ShowToast("昵称不能为空")
    return
  end
  SavePlayerName(clean)
end
```

---

## 四、服务器时间与可信时间判断

签到、限时活动、冷却等判断**必须用服务器时间**，不要用客户端本地时间（`os.time()` 可被玩家改系统时间刷奖励）。`GetServerTime` 默认返回 UTC 0 时区，展示前用 `ToLocalTime()` 转本地；比较逻辑用 `GetServerUnixTime` 的时间戳更方便。

```lua
local DouyinUtility = DouyinUtility

-- 读取服务器时间。GetServerTime / GetServerUnixTime 属网络相关 API，
-- 调用前必须先判 DouyinNetService.isNetworkSettled，否则可能异常或拿到无效值
local function TryGetServerTime()
  if not DouyinNetService.isNetworkSettled then
    print("---网络未准备好，稍后再取服务器时间")
    return nil
  end
  local dt = DouyinUtility.GetServerTime()          -- UTC 0
  local localDt = dt:ToLocalTime()                  -- 转本地时区后再展示
  print("---ServerTime(local)=" .. localDt:ToString("yyyy-MM-dd HH:mm:ss"))
  return dt
end

-- 可信时间：判断每日签到是否可领（用服务器 Unix 时间，防本地改时间刷签到）
-- lastClaimUnix 为上次领取的服务器时间戳（落库读出）
local function CanClaimDaily(lastClaimUnix)
  if not DouyinNetService.isNetworkSettled then
    return false
  end
  local nowUnix = DouyinUtility.GetServerUnixTime()
  -- 简化示例：距上次领取超过 24 小时（86400 秒）视为可领；冷却 / 限时活动同理
  return (nowUnix - lastClaimUnix) >= 86400
end
```

---

## 五、相关文档

- [平台工具 - C#](平台工具-CSharp.md)
- API Reference：[DouyinUtility](../../API%20Reference/DouyinUtility.md) / [Alert](../../API%20Reference/DouyinUtility/DouyinUtility.Alert.md) / [Toast](../../API%20Reference/DouyinUtility/DouyinUtility.Toast.md) / [FilteEmoji](../../API%20Reference/DouyinUtility/DouyinUtility.FilteEmoji.md) / [GetServerTime](../../API%20Reference/DouyinUtility/DouyinUtility.GetServerTime.md) / [GetServerUnixTime](../../API%20Reference/DouyinUtility/DouyinUtility.GetServerUnixTime.md)
