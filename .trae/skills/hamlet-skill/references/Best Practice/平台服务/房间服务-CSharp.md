# 房间服务 - C#

> 本篇带你从 0 到 1 用 C# 跑通房间信息读取：进入时获取一次并缓存 → 按 `enterFrom` 做渠道差异化奖励 / 埋点 → 用 `inviterOpenID` 做邀请溯源。
>
> C# 侧 `DouyinRoomService` 是**全局静态类**，只有 `GetCurrentRoomInfo` 一个只读**回调式**方法（非 `async/await`）——没有创建 / 切换房间，也没有房间事件。字段语义与 `enterFrom` 对照表见 Manual：[房间服务](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/房间服务.md)。

---

## 一、进入时获取并缓存

把以下 helper 放在业务脚本中。玩家加入时调用 `FetchRoomInfo`，其余逻辑读缓存，切勿在 `Update` / `FixedUpdate` 中轮询。

```csharp
using System;
using UnityEngine;

public class RoomInfoHelper
{
    // enterFrom 渠道常量：用常量替代散落的魔法数字
    public const int EnterFromOther = -1;   // 其他渠道
    public const int EnterFromExplore = 0;  // 逛一逛
    public const int EnterFromSidebar = 1;  // 侧边栏

    private DouyinRoomInfo _current;
    private bool _requesting;

    // 获取一次并缓存；onReady(roomInfo) 中 roomInfo 可能为 null
    public void FetchRoomInfo(Action<DouyinRoomInfo> onReady)
    {
        // 命中缓存直接返回，避免重复请求
        if (_current != null)
        {
            onReady?.Invoke(_current);
            return;
        }
        // _requesting 拦截并发，防止请求风暴
        if (_requesting)
        {
            return;
        }

        _requesting = true;
        DouyinRoomService.GetCurrentRoomInfo(roomInfo =>
        {
            _requesting = false;
            // 回调可能返回 null（如失败），读字段前必须判空
            if (roomInfo == null)
            {
                Debug.LogWarning("[Room] GetCurrentRoomInfo 返回空");
                onReady?.Invoke(null);
                return;
            }
            _current = roomInfo;
            onReady?.Invoke(roomInfo);
        });
    }
}
```

---

## 二、业务接入示例

### enterFrom 渠道差异化奖励 / 埋点

```csharp
private readonly RoomInfoHelper _room = new RoomInfoHelper();

public void OnPlayerJoined(DouyinPlayer player)
{
    _room.FetchRoomInfo(roomInfo =>
    {
        if (roomInfo == null) return;

        Debug.Log($"[Room] roomID={roomInfo.roomID} worldID={roomInfo.worldID}");

        switch (roomInfo.enterFrom)
        {
            case RoomInfoHelper.EnterFromExplore:
                GrantExploreReward(player); // 逛一逛专属奖励 + 埋点
                break;
            case RoomInfoHelper.EnterFromSidebar:
                ReportEnter(player, "sidebar");
                break;
            default: // EnterFromOther 或未知值：default 兜底
                ReportEnter(player, "other");
                break;
        }
    });
}
```

### inviterOpenID 邀请溯源

```csharp
public void TryBindInviter(DouyinPlayer player)
{
    _room.FetchRoomInfo(roomInfo =>
    {
        if (roomInfo == null) return;

        // inviterOpenID 非邀请进入时为空，使用前必须判空
        var inviter = roomInfo.inviterOpenID;
        if (string.IsNullOrEmpty(inviter))
        {
            return; // 非邀请进入，跳过
        }

        // inviter 是邀请者身份，不要与玩家自身 OpenID 混淆
        BindInviteRelation(player.playerOpenID, inviter);
    });
}
```

---

## 三、相关文档

- Lua 版：[房间服务 - Lua](房间服务-Lua.md)
- Manual（概念、字段、`enterFrom` 表、边界、FAQ）：[房间服务](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/房间服务.md)
- API Reference：[DouyinRoomService.GetCurrentRoomInfo](../../API%20Reference/DouyinRoomService/DouyinRoomService.GetCurrentRoomInfo.md)、[DouyinRoomInfo](../../API%20Reference/DouyinRoomService/DouyinRoomInfo.md)
