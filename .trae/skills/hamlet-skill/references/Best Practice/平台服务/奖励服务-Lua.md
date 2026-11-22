# 奖励服务 - Lua

> 本篇带你从 0 到 1 用 Lua 跑通官方奖励下发：调试器拦截 → 发奖并按错误码分类处理 → 落库防重复领取 → 「关注创作者 → 领奖」组合链路。
>
> `DouyinOfficialRewardService` 是**全局注入对象**（Lua 侧直接调用，**不要**写成 `CS.DouyinOfficialRewardService`），只有 `IssueReward(rewardID, function(response) end)` 一个回调式方法——没有 `async`、没有「查询是否已领」接口（防重复要自己落库）、没有批量发放。`IssueRewardResponse` 返回结构、错误码全表、`rewardID` 来源与「仅线上 / 作者本人无法领取」等边界见 Manual：[奖励服务](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/奖励服务.md)。

---

## 一、发奖封装（错误码分类）

```lua
local DouyinOfficialRewardService = DouyinOfficialRewardService
local DouyinApplication = DouyinApplication

-- rewardID: long，由运营提供，不要硬编码猜测；onResult: function(ok:boolean, reason:string) 可选
function IssuePlatformReward(rewardID, onResult)
    -- 1) 调试器拦截：IssueReward 仅线上有效，模拟器直接返回
    if DouyinApplication.isSimulator then
        DouyinUtility.Toast("奖励领取请在线上环境体验")
        if onResult then onResult(false, "simulator") end
        return
    end

    DouyinOfficialRewardService.IssueReward(rewardID, function(response)
        local code = response and response.code
        if code == 0 then
            -- 成功：解析奖励信息（rewardType 2 形象 / 3 装扮）
            if response.rewardInfo ~= nil then
                for i = 0, response.rewardInfo.Count - 1 do
                    local info = response.rewardInfo[i]
                    print(string.format("[Reward] 发放成功 name=%s id=%s type=%d",
                        info.name, tostring(info.id), info.rewardType))
                end
            end
            DouyinUtility.Toast("奖励领取成功")
            if onResult then onResult(true, nil) end
        elseif code == 20801 then
            -- 已拥有：正常业务分支，不是错误，不重试
            DouyinUtility.Toast("你已拥有该奖励")
            if onResult then onResult(true, "owned") end
        elseif code == 20803 then
            -- 达领取上限：正常业务分支
            DouyinUtility.Toast("该奖励领取已达上限")
            if onResult then onResult(false, "limit") end
        else
            -- 10001/10002/20802 等：配置 / 鉴权问题，记日志提示联系运营，不做无脑重试
            print(string.format("[Reward] 发放失败 code=%s msg=%s", tostring(code), tostring(response and response.message)))
            DouyinUtility.Toast("奖励领取失败，请稍后再试")
            if onResult then onResult(false, "error") end
        end
    end)
end
```

---

## 二、落库防重复领取

`IssueReward` 没有「是否已领」查询接口，需业务侧用 [数据存储DataStore - Lua](../数据库/数据存储DataStore-Lua.md) 记录发放结果。领取资格与判重应放在**可信侧（DS 服务端）**，不要仅凭客户端点击就发奖。

```lua
-- 伪代码：发奖前查已领标记，发奖成功后落库
-- scope = "player_" .. playerOpenID，key = "reward_" .. rewardID
function ClaimRewardOnce(playerOpenID, rewardID, onResult)
    local scope = "player_" .. playerOpenID
    local key = "reward_" .. tostring(rewardID)

    -- 1) 查是否已领（DataStore 读，示意）
    ReadFlag(scope, key, function(claimed)
        if claimed then
            DouyinUtility.Toast("你已领取过该奖励")
            if onResult then onResult(true, "already") end
            return
        end
        -- 2) 未领：发奖
        IssuePlatformReward(rewardID, function(ok, reason)
            -- 成功或“已拥有”都写入标记，避免下次重复触发
            if ok or reason == "owned" then
                WriteFlag(scope, key, true, function() end)
            end
            if onResult then onResult(ok, reason) end
        end)
    end)
end
```

> `ReadFlag` / `WriteFlag` 为对 DataStore 读写的业务封装示意，具体实现见 [数据存储DataStore - Lua](../数据库/数据存储DataStore-Lua.md)。

---

## 三、关注领奖组合链路

「关注创作者 → 领奖」：先判断关注状态，未关注先关注，成功后发奖并落库。

```lua
local DouyinCreatorService = DouyinCreatorService

-- rewardID 由运营提供
function FollowAndClaim(playerOpenID, rewardID)
    DouyinCreatorService.GetCreatorInfo(function(creatorInfo)
        -- secUID 判空：调试器下可能取不到创作者信息
        if creatorInfo == nil or creatorInfo.secUID == nil or creatorInfo.secUID == "" then
            DouyinUtility.Toast("当前无法获取创作者信息")
            return
        end

        -- 已关注：直接发奖（用 isFollowing 判断，勿与 isFollowed 混淆）
        if creatorInfo.isFollowing == true then
            ClaimRewardOnce(playerOpenID, rewardID)
            return
        end

        -- 未关注：先关注，成功后发奖
        DouyinCreatorService.Follow(creatorInfo.secUID, function(success)
            if success then
                DouyinUtility.Toast("关注成功")
                ClaimRewardOnce(playerOpenID, rewardID)
            else
                DouyinUtility.Toast("关注失败，请重试")
            end
        end)
    end)
end
```

> 关注接口细节（`secUID` 大写 UID、`GetCreatorInfo` 调试器不可用等）见 [创作者服务 - Lua](创作者服务-Lua.md)。

---

## 四、相关文档

- C# 版：[奖励服务 - C#](奖励服务-CSharp.md)
- Manual（返回结构、错误码全表、rewardID 来源、边界）：[奖励服务](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/奖励服务.md)
- 配合使用：[创作者服务 - Lua](创作者服务-Lua.md)（关注）、[数据存储DataStore - Lua](../数据库/数据存储DataStore-Lua.md)（落库防重复）
- API Reference：[DouyinOfficialRewardService.IssueReward](../../API%20Reference/DouyinOfficialRewardService/DouyinOfficialRewardService.IssueReward.md)
