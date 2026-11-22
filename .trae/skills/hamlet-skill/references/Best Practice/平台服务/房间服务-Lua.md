# 房间服务 - Lua

> 本篇带你从 0 到 1 用 Lua 跑通房间信息读取：进入时获取一次并缓存 → 按 `enterFrom` 做渠道差异化奖励 / 埋点 → 用 `inviterOpenID` 做邀请溯源。
>
> `DouyinRoomService` 是**全局注入对象**（Lua 侧直接用，**无 `CS.` 前缀**），只有 `GetCurrentRoomInfo` 一个只读回调方法——没有创建 / 切换房间，也没有房间事件。字段语义与 `enterFrom` 对照表见 Manual：[房间服务](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/房间服务.md)。

---

## 一、何时使用

- 玩家加入 / 初始化时识别进入渠道（逛一逛 / 侧边栏 / 其他），做差异化奖励或埋点。
- 记录 `roomID` / `worldID` 作为日志上下文或分区键。
- 通过 `inviterOpenID` 做邀请激励、组队绑定。

---

## 二、进入时获取并缓存

把以下 helper 放在脚本顶部公共区。玩家加入时调用 `FetchRoomInfo`，其余逻辑读缓存 `currentRoomInfo`，切勿在 `Update` / `FixedUpdate` 中轮询。

```lua
-- 直接用全局 DouyinRoomService，不要写成 CS.DouyinRoomService
local DouyinRoomService = DouyinRoomService

-- enterFrom 渠道常量：用映射表替代散落的魔法数字
local ENTER_FROM = {
    OTHER = -1,   -- 其他渠道
    EXPLORE = 0,  -- 逛一逛
    SIDEBAR = 1,  -- 侧边栏
}

local currentRoomInfo = nil
local roomInfoRequesting = false

-- 获取一次房间信息并缓存；onReady(roomInfo) 中 roomInfo 可能为 nil
local function FetchRoomInfo(onReady)
    -- 命中缓存直接返回，避免重复请求
    if currentRoomInfo ~= nil then
        if onReady ~= nil then onReady(currentRoomInfo) end
        return
    end
    -- requesting 拦截并发，防止请求风暴
    if roomInfoRequesting then return end

    roomInfoRequesting = true
    DouyinRoomService.GetCurrentRoomInfo(function(roomInfo)
        roomInfoRequesting = false
        -- 回调可能返回 nil（如失败），读字段前必须判空
        if roomInfo == nil then
            print("[Room] GetCurrentRoomInfo 返回空")
            if onReady ~= nil then onReady(nil) end
            return
        end
        currentRoomInfo = roomInfo
        if onReady ~= nil then onReady(roomInfo) end
    end)
end
```

---

## 三、入口组合示例

### enterFrom 渠道差异化奖励 / 埋点

```lua
function OnPlayerJoined(player)
    FetchRoomInfo(function(roomInfo)
        if roomInfo == nil then return end

        print(string.format("[Room] roomID=%s worldID=%s", roomInfo.roomID, roomInfo.worldID))

        if roomInfo.enterFrom == ENTER_FROM.EXPLORE then
            -- 逛一逛进入：发放推荐位专属奖励 + 埋点
            GrantExploreReward(player)
        elseif roomInfo.enterFrom == ENTER_FROM.SIDEBAR then
            -- 侧边栏进入
            ReportEnter(player, "sidebar")
        else
            -- ENTER_FROM.OTHER 或未知值：默认分支兜底
            ReportEnter(player, "other")
        end
    end)
end
```

### inviterOpenID 邀请溯源

```lua
function TryBindInviter(player)
    FetchRoomInfo(function(roomInfo)
        if roomInfo == nil then return end

        -- inviterOpenID 非邀请进入时为空，使用前必须判空
        local inviter = roomInfo.inviterOpenID
        if inviter == nil or inviter == "" then
            return -- 非邀请进入，跳过
        end

        -- inviter 是邀请者身份，不要与玩家自身 OpenID 混淆
        BindInviteRelation(player.playerOpenID, inviter)
    end)
end
```

---

## 四、相关文档

- C# 版：[房间服务 - C#](房间服务-CSharp.md)
- Manual（概念、字段、`enterFrom` 表、边界、FAQ）：[房间服务](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/房间服务.md)
- API Reference：[DouyinRoomService.GetCurrentRoomInfo](../../API%20Reference/DouyinRoomService/DouyinRoomService.GetCurrentRoomInfo.md)、[DouyinRoomInfo](../../API%20Reference/DouyinRoomService/DouyinRoomInfo.md)
