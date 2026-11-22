# 奖励服务 - C#

> 本篇带你从 0 到 1 用 C# 跑通官方奖励下发：调试器拦截 → 发奖并按错误码分类处理 → 落库防重复领取 → 「关注创作者 → 领奖」组合链路。
>
> C# 侧 `DouyinOfficialRewardService` 是**全局静态类**，只有 `IssueReward(long rewardID, Action<IssueRewardResponse>)` 一个回调式方法——没有 `async/await`、没有「查询是否已领」接口（防重复要自己落库）、没有批量发放，也没有 `Instance` 单例。`IssueRewardResponse` 返回结构、错误码全表、`rewardID` 来源与「仅线上 / 作者本人无法领取」等边界见 Manual：[奖励服务](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/奖励服务.md)。

---

## 一、发奖封装（错误码分类）

```csharp
using System;
using UnityEngine;

public class RewardSample
{
    // rewardID: 由运营提供，不要硬编码猜测；onResult: (ok, reason) 可选
    public void IssuePlatformReward(long rewardID, Action<bool, string> onResult = null)
    {
        // 1) 调试器拦截：IssueReward 仅线上有效，模拟器直接返回
        if (DouyinApplication.isSimulator)
        {
            DouyinUtility.Toast("奖励领取请在线上环境体验");
            onResult?.Invoke(false, "simulator");
            return;
        }

        DouyinOfficialRewardService.IssueReward(rewardID, response =>
        {
            int code = response.code;
            if (code == 0)
            {
                // 成功：解析奖励信息（rewardType 2 形象 / 3 装扮）
                if (response.rewardInfo != null)
                {
                    foreach (var info in response.rewardInfo)
                    {
                        CommonDebug.Log($"[Reward] 发放成功 name={info.name} id={info.id} type={info.rewardType}");
                    }
                }
                DouyinUtility.Toast("奖励领取成功");
                onResult?.Invoke(true, null);
            }
            else if (code == 20801)
            {
                // 已拥有：正常业务分支，不是错误，不重试
                DouyinUtility.Toast("你已拥有该奖励");
                onResult?.Invoke(true, "owned");
            }
            else if (code == 20803)
            {
                // 达领取上限：正常业务分支
                DouyinUtility.Toast("该奖励领取已达上限");
                onResult?.Invoke(false, "limit");
            }
            else
            {
                // 10001/10002/20802 等：配置 / 鉴权问题，记日志提示联系运营，不做无脑重试
                CommonDebug.LogError($"[Reward] 发放失败 code={code} msg={response.message}");
                DouyinUtility.Toast("奖励领取失败，请稍后再试");
                onResult?.Invoke(false, "error");
            }
        });
    }
}
```

---

## 二、落库防重复领取

`IssueReward` 没有「是否已领」查询接口，需业务侧用 [数据存储DataStore - C#](../数据库/数据存储DataStore-CSharp.md) 记录发放结果。领取资格与判重应放在**可信侧（DS 服务端）**，不要仅凭客户端点击就发奖。

```csharp
// 伪代码：发奖前查已领标记，发奖成功后落库
// scope = "player_" + playerOpenID，key = "reward_" + rewardID
public void ClaimRewardOnce(string playerOpenID, long rewardID, Action<bool, string> onResult = null)
{
    string scope = "player_" + playerOpenID;
    string key = "reward_" + rewardID;

    // 1) 查是否已领（DataStore 读，示意）
    ReadFlag(scope, key, claimed =>
    {
        if (claimed)
        {
            DouyinUtility.Toast("你已领取过该奖励");
            onResult?.Invoke(true, "already");
            return;
        }
        // 2) 未领：发奖
        IssuePlatformReward(rewardID, (ok, reason) =>
        {
            // 成功或“已拥有”都写入标记，避免下次重复触发
            if (ok || reason == "owned")
            {
                WriteFlag(scope, key, true, () => { });
            }
            onResult?.Invoke(ok, reason);
        });
    });
}
```

> `ReadFlag` / `WriteFlag` 为对 DataStore 读写的业务封装示意，具体实现见 [数据存储DataStore - C#](../数据库/数据存储DataStore-CSharp.md)。

---

## 三、关注领奖组合链路

「关注创作者 → 领奖」：先判断关注状态，未关注先关注，成功后发奖并落库。

```csharp
public void FollowAndClaim(string playerOpenID, long rewardID)
{
    DouyinCreatorService.GetCreatorInfo(creatorInfo =>
    {
        // secUID 判空：调试器下可能取不到创作者信息
        if (creatorInfo == null || string.IsNullOrEmpty(creatorInfo.secUID))
        {
            DouyinUtility.Toast("当前无法获取创作者信息");
            return;
        }

        // 已关注：直接发奖（用 isFollowing 判断，勿与 isFollowed 混淆）
        if (creatorInfo.isFollowing)
        {
            ClaimRewardOnce(playerOpenID, rewardID);
            return;
        }

        // 未关注：先关注，成功后发奖
        DouyinCreatorService.Follow(creatorInfo.secUID, success =>
        {
            if (success)
            {
                DouyinUtility.Toast("关注成功");
                ClaimRewardOnce(playerOpenID, rewardID);
            }
            else
            {
                DouyinUtility.Toast("关注失败，请重试");
            }
        });
    });
}
```

> 关注接口细节（`secUID` 大写 UID、`GetCreatorInfo` 调试器不可用等）见 [创作者服务 - C#](创作者服务-CSharp.md)。

---

## 四、相关文档

- Lua 版：[奖励服务 - Lua](奖励服务-Lua.md)
- Manual（返回结构、错误码全表、rewardID 来源、边界）：[奖励服务](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/奖励服务.md)
- 配合使用：[创作者服务 - C#](创作者服务-CSharp.md)（关注）、[数据存储DataStore - C#](../数据库/数据存储DataStore-CSharp.md)（落库防重复）
- API Reference：[DouyinOfficialRewardService.IssueReward](../../API%20Reference/DouyinOfficialRewardService/DouyinOfficialRewardService.IssueReward.md)
