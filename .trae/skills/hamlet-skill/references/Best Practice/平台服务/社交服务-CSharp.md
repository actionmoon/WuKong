# 社交服务 - C#

> 本文带你用 C# 从 0 到 1 用好 `DouyinSocialService`：世界 / 图片分享封装（含调试器拦截）、投稿事件监听生命周期、结合房间来源的裂变奖励。能力概念、接口语义与边界请先阅读 Manual：[社交服务](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/社交服务.md)。Lua 版本见 [社交服务 - Lua](社交服务-Lua.md)。API 逐项签名见 API Reference：[DouyinSocialService](../../API%20Reference/DouyinSocialService.md)。

---

## 0. 真实 API 形态（先看这一节）

C# 侧 `DouyinSocialService` 是**全局静态类**，2 方法（回调式）+ 2 事件：

```csharp
// 方法：callback 收到 bool 表示分享是否成功发起/完成
DouyinSocialService.ShareWorld(string templateId, Action<bool> callback);  // templateId 为 "" 时用官方默认模板
DouyinSocialService.ShareTexture(Texture t, Action<bool> callback);

// 事件：AddListener / RemoveListener
DouyinSocialService.onPublishProcessEvent; // (string publishId, int process 0-100)
DouyinSocialService.onPublishResultEvent;  // (string publishId, int success 1/0, string contentId)
```

- 分享仅**线上环境**生效；本地调试器 / 扫码测试不支持。
- 分享 `callback(false)` 含**用户取消**，不代表好友是否进房。

> ⚠️ 只有这 2 方法 + 2 事件，都是**回调式**，**没有** `async/await`、取消 / 重试、`Instance` 单例或查询分享详情的接口。请勿引用不存在的符号。

---

## 1. 世界分享封装

```csharp
using System;
using UnityEngine;

public class WorldShareSample
{
    // 已在创作后台审核通过的自定义分享模板 ID；没有就用 "" 走官方默认模板
    private const string CustomTemplateId = "tmpl_ab12cdefg345hijk";

    public void ShareCurrentWorld(Action<bool> onDone = null)
    {
        // 1) 调试器环境拦截：分享仅线上可用
        if (DouyinApplication.isSimulator)
        {
            DouyinUtility.Toast("分享功能请在线上环境体验");
            onDone?.Invoke(false);
            return;
        }

        // 2) 发起世界分享
        DouyinSocialService.ShareWorld(CustomTemplateId, success =>
        {
            if (success) CommonDebug.Log("[Social] 世界分享已发起");
            else CommonDebug.LogWarning("[Social] 世界分享失败或被用户取消");
            onDone?.Invoke(success);
        });
    }
}
```

> 若未配置自定义模板，把 `CustomTemplateId` 换成 `""` 即可使用官方默认世界分享模板。

---

## 2. 图片分享封装（结算战绩图场景）

`ShareTexture` 的图片建议尺寸 168×264（安卓）/ 168×224（iOS），过小分享预览会显示不全。

```csharp
using System;
using UnityEngine;
using UnityEngine.UI;

public class ImageShareSample
{
    [SerializeField] private RawImage resultImage; // 结算战绩图

    public void ShareImage(Texture texture, Action<bool> onDone = null)
    {
        if (DouyinApplication.isSimulator)
        {
            DouyinUtility.Toast("分享功能请在线上环境体验");
            onDone?.Invoke(false);
            return;
        }
        if (texture == null)
        {
            CommonDebug.LogWarning("[Social] 分享图片为空，跳过");
            onDone?.Invoke(false);
            return;
        }

        DouyinSocialService.ShareTexture(texture, success =>
        {
            if (success) CommonDebug.Log("[Social] 图片分享已发起");
            else CommonDebug.LogWarning("[Social] 图片分享失败或被用户取消");
            onDone?.Invoke(success);
        });
    }

    // 结算面板「分享战绩」按钮
    public void OnClickShareResult()
    {
        ShareImage(resultImage.texture);
    }
}
```

---

## 3. 投稿监听生命周期

```csharp
using UnityEngine;

public class PublishListenSample : MonoBehaviour
{
    private void Start()
    {
        DouyinSocialService.onPublishProcessEvent.AddListener(OnPublishProcess);
        DouyinSocialService.onPublishResultEvent.AddListener(OnPublishResult);
    }

    private void OnPublishProcess(string publishId, int process)
    {
        CommonDebug.Log($"[Social] 投稿进度 id={publishId} process={process}");
        // 可更新 UI 进度条
    }

    private void OnPublishResult(string publishId, int success, string contentId)
    {
        if (success == 1)
        {
            CommonDebug.Log($"[Social] 投稿成功 id={publishId} contentId={contentId}");
            // 投稿成功：给予奖励 / 提示（注意防重复，见奖励类实践）
        }
        else
        {
            CommonDebug.LogWarning($"[Social] 投稿失败 id={publishId}");
        }
    }

    // 必须成对移除，避免重复回调与泄漏
    private void OnDestroy()
    {
        DouyinSocialService.onPublishProcessEvent.RemoveListener(OnPublishProcess);
        DouyinSocialService.onPublishResultEvent.RemoveListener(OnPublishResult);
    }
}
```

---

## 4. 社交裂变（结合房间来源）

分享驱动裂变的关键是：**被邀请者进房时识别邀请人**，再给双方发奖。进入来源与邀请人 ID 取自房间信息（见 [房间服务 - C#](房间服务-CSharp.md)）。

```csharp
// 进房时判断是否由分享卡片进入（房间信息获取见房间服务）
private void OnRoomInfoReady(DouyinRoomInfo roomInfo)
{
    string inviterOpenID = roomInfo?.inviterOpenID;
    if (!string.IsNullOrEmpty(inviterOpenID))
    {
        // 当前玩家由分享进房：给被邀请者发奖，并记录邀请人待发奖
        CommonDebug.Log($"[Social] 分享进房，邀请人={inviterOpenID}");
        // GrantInviteeReward(); MarkInviterReward(inviterOpenID);
    }
}
```

---

## 5. 相关文档

- [社交服务 - Lua](社交服务-Lua.md)
- Manual：[社交服务](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/社交服务.md)
- 配合使用：[房间服务 - C#](房间服务-CSharp.md)（邀请来源）、[图片服务 - C#](图片服务-CSharp.md)（分享图获取）
- API Reference：[DouyinSocialService](../../API%20Reference/DouyinSocialService.md)
