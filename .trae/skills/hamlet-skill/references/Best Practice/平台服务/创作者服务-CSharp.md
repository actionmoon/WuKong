# 创作者服务 - C#

> 本篇带你从 0 到 1 用 C# 实现创作者关注链路：获取当前创作者信息 → 关注 → 打开主页，并封装缓存 / 并发 / 容错。C# 侧接口为静态类回调形态（非 `async/await`）。

---

## 一、最小封装（缓存 + 并发拦截 + 容错）

把以下 helper 放在业务脚本中。调用方按自身流程调用 `FollowCurrentCreator` / `OpenCurrentCreatorInformation`，无需关心信息获取时序。

```csharp
using System;
using UnityEngine;

public class CreatorServiceHelper
{
    private CreatorInfo _creatorInfo;
    private bool _requesting;
    private bool _isFollowing;
    private bool _followPending;
    private Action<CreatorInfo, string> _pendingAction;

    // 字段名是 secUID（UID 大写），且必须非空；不要把玩家 openID 当作 secUID
    private static string GetSecUID(CreatorInfo info)
    {
        if (info == null || string.IsNullOrEmpty(info.secUID))
        {
            return null;
        }
        return info.secUID;
    }

    // 命中缓存则直接执行，否则发起一次 GetCreatorInfo，并用 _requesting 拦截并发
    private void RunWithCreatorInfo(Action<CreatorInfo, string> action)
    {
        if (action == null)
        {
            return;
        }

        var cachedSecUID = GetSecUID(_creatorInfo);
        if (cachedSecUID != null)
        {
            action(_creatorInfo, cachedSecUID);
            return;
        }

        _pendingAction = action;
        if (_requesting)
        {
            return;
        }

        _requesting = true;
        DouyinCreatorService.GetCreatorInfo(info =>
        {
            _requesting = false;
            _creatorInfo = info;
            _isFollowing = info != null && info.isFollowing;

            var readyAction = _pendingAction;
            _pendingAction = null;

            // 调试器模式下可能返回空：判空并提示，不继续后续调用
            var secUID = GetSecUID(info);
            if (secUID == null)
            {
                Debug.LogWarning("[Creator] GetCreatorInfo 返回空信息");
                DouyinUtility.Toast("当前无法获取创作者信息");
                return;
            }

            readyAction?.Invoke(info, secUID);
        });
    }

    // 关注当前创作者：已关注则直接视为成功，_followPending 拦截重复点击
    public void FollowCurrentCreator(Action<bool> onFinished = null)
    {
        RunWithCreatorInfo((info, secUID) =>
        {
            if (_isFollowing || info.isFollowing)
            {
                onFinished?.Invoke(true);
                return;
            }

            if (_followPending)
            {
                return;
            }
            _followPending = true;

            // Follow 是异步回调，只有 success == true 才代表关注成功
            DouyinCreatorService.Follow(secUID, success =>
            {
                _followPending = false;
                if (success)
                {
                    _isFollowing = true;
                }
                onFinished?.Invoke(success);
            });
        });
    }

    // 打开当前创作者主页：纯动作，无回调，不要写等待逻辑
    public void OpenCurrentCreatorInformation()
    {
        RunWithCreatorInfo((_, secUID) => DouyinCreatorService.OpenCreatorInformation(secUID));
    }
}
```

---

## 二、业务接入示例

### 按钮点击关注并提示

```csharp
private readonly CreatorServiceHelper _creatorHelper = new CreatorServiceHelper();

public void OnFollowButtonClick()
{
    _creatorHelper.FollowCurrentCreator(success =>
    {
        DouyinUtility.Toast(success ? "关注成功" : "关注失败");
    });
}
```

### 关注成功后打开主页

```csharp
public void OnFollowThenOpen()
{
    _creatorHelper.FollowCurrentCreator(success =>
    {
        if (success)
        {
            _creatorHelper.OpenCurrentCreatorInformation();
        }
    });
}
```

---

## 三、相关文档

- Lua 版：[创作者服务 - Lua](创作者服务-Lua.md)
- Manual（概念、字段、边界、FAQ）：[创作者服务](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/创作者服务.md)
- API Reference：[GetCreatorInfo](../../API%20Reference/DouyinCreatorService/DouyinCreatorService.GetCreatorInfo.md)、[Follow](../../API%20Reference/DouyinCreatorService/DouyinCreatorService.Follow.md)、[OpenCreatorInformation](../../API%20Reference/DouyinCreatorService/DouyinCreatorService.OpenCreatorInformation.md)、[CreatorInfo](../../API%20Reference/DouyinCreatorService/CreatorInfo.md)
