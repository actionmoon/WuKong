# 平台工具（DouyinUtility）- C#

> 本文带你用 C# 从 0 到 1 用好平台工具类 `DouyinUtility`：Toast 轻量提示、Alert 确认弹窗、emoji 过滤、以及基于服务器时间的可信时间判断（签到 / 限时活动防作弊）。
>
> 能力概念、API 概览与边界请先阅读 Manual：[平台工具](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/平台工具.md)。Lua 版本见 [平台工具 - Lua](平台工具-Lua.md)。API 逐项签名见 API Reference：[DouyinUtility](../../API%20Reference/DouyinUtility.md)。

---

## 0. 真实 API 形态（先看这一节）

C# 侧 `DouyinUtility` 是**全局静态类**，5 个静态方法：

```csharp
DouyinUtility.Toast(string msg);                                                              // void
DouyinUtility.Alert(string title, string message, string confirm, Action confirmCallback,
                    string cancel, Action cancelCallback);                                    // void，回调式
string clean = DouyinUtility.FilteEmoji(string content);                                      // 同步返回过滤后字符串
DateTime dt = DouyinUtility.GetServerTime();                                                  // UTC 0 时区
long unix = DouyinUtility.GetServerUnixTime();                                                // Unix 时间戳
```

> ⚠️ `Alert` 是回调式、无同步返回值；`FilteEmoji` / `GetServerTime` / `GetServerUnixTime` 同步返回。没有 `async/await`、没有 `Instance` 单例。请勿引用不存在的符号。

---

## 1. Toast / Alert 封装

```csharp
using System;

public static class UiPrompt
{
    // Toast 只接受 string；上游值可能为 null / 空时先兜底，避免传入非法参数。
    // Toast 只是反馈，不是状态源，也不要在 Update 里每帧连续弹。
    public static void ShowToast(string message)
    {
        if (string.IsNullOrEmpty(message)) return;
        DouyinUtility.Toast(message);
    }

    // Alert 是回调式：用户的选择只通过 onConfirm / onCancel 表达，没有同步 boolean 返回值，
    // 所以“确认后的业务”必须写在回调里。六个参数顺序固定：
    // title, message, confirm 文案, confirmCallback, cancel 文案, cancelCallback —— 不要交换文案与回调的位置。
    public static void ShowConfirmAlert(string title, string message, string confirmText,
        string cancelText, Action onConfirm, Action onCancel)
    {
        DouyinUtility.Alert(
            title,
            message,
            confirmText,
            () => onConfirm?.Invoke(),
            cancelText,
            // 取消分支即使没有业务，也传一个空实现占位，保证参数顺序正确
            () => onCancel?.Invoke());
    }
}
```

### 使用场景

重置 / 消耗 / 购买 / 传送 / 放弃进度等**不可逆操作**要先 `Alert` 确认，不能只 `Toast` 一下就执行。

```csharp
// 1) 按钮点击后 Toast 反馈（Toast 是反馈，不是状态源）
public void OnOpenChestClick()
{
    OpenChest();
    UiPrompt.ShowToast("宝箱已打开");
}

// 2) 危险操作前 Alert 确认（业务写在确认回调内，不要因为多了一层弹窗就提前执行）
public void OnResetClick()
{
    UiPrompt.ShowConfirmAlert(
        "确认重置",
        "是否重置当前机关？",
        "确认",
        "取消",
        () =>
        {
            ResetMechanism();
            UiPrompt.ShowToast("机关已重置");
        },
        () => UiPrompt.ShowToast("已取消"));
}
```

---

## 2. emoji 过滤（FilteEmoji）

玩家昵称 / 输入框文本在 iOS 上 emoji 易乱码，入库或展示前过滤：

```csharp
public static string SafeText(string raw)
{
    if (string.IsNullOrEmpty(raw)) return string.Empty;
    return DouyinUtility.FilteEmoji(raw); // 同步返回
}

public void OnRenameConfirm(string inputText)
{
    string clean = SafeText(inputText);
    if (string.IsNullOrEmpty(clean))
    {
        UiPrompt.ShowToast("昵称不能为空");
        return;
    }
    SavePlayerName(clean);
}
```

---

## 3. 服务器时间与可信时间判断

`GetServerTime` 默认返回 **UTC 0 时区** `DateTime`，展示前用 `ToLocalTime()` 转本地；判逻辑用 `GetServerUnixTime` 更方便。**调用前必须判网络就绪**。

```csharp
using System;

// 读取服务器时间（带网络就绪判断）
public bool TryGetServerTime(out DateTime serverUtc)
{
    serverUtc = default;
    if (!DouyinNetService.isNetworkSettled)
    {
        CommonDebug.LogWarning("网络未准备好，稍后再取服务器时间");
        return false;
    }
    serverUtc = DouyinUtility.GetServerTime();            // UTC 0
    DateTime local = serverUtc.ToLocalTime();             // 转本地
    CommonDebug.Log($"ServerTime(local)={local:yyyy-MM-dd HH:mm:ss}");
    return true;
}

// 可信时间：判断每日签到是否可领（用服务器 Unix 时间，防本地改时间刷签到）
// lastClaimUnix 为上次领取的服务器时间戳（落库读出）
public bool CanClaimDaily(long lastClaimUnix)
{
    if (!DouyinNetService.isNetworkSettled) return false;
    long nowUnix = DouyinUtility.GetServerUnixTime();
    // 简化示例：距上次领取超过 24 小时（86400 秒）视为可领
    return (nowUnix - lastClaimUnix) >= 86400;
}
```

> 冷却 / 限时活动同理：一律以服务器时间为准，客户端本地时间不可信。平台没有 `GetServerTimeAsync` 之类的 async 接口，用同步的 `GetServerTime` / `GetServerUnixTime` 即可。

---

## 4. 相关文档

- [平台工具 - Lua](平台工具-Lua.md)
- API Reference：[DouyinUtility](../../API%20Reference/DouyinUtility.md) / [Alert](../../API%20Reference/DouyinUtility/DouyinUtility.Alert.md) / [Toast](../../API%20Reference/DouyinUtility/DouyinUtility.Toast.md) / [FilteEmoji](../../API%20Reference/DouyinUtility/DouyinUtility.FilteEmoji.md) / [GetServerTime](../../API%20Reference/DouyinUtility/DouyinUtility.GetServerTime.md) / [GetServerUnixTime](../../API%20Reference/DouyinUtility/DouyinUtility.GetServerUnixTime.md)
