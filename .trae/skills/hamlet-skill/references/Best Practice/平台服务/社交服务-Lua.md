# 社交服务 - Lua

> 本文带你用 Lua 从 0 到 1 用好 `DouyinSocialService`：世界 / 图片分享封装（含调试器拦截）、投稿事件监听生命周期、结合房间来源的裂变奖励。
>
> 能力概念、接口语义与边界请先阅读 Manual：[社交服务](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/社交服务.md)。C# 版本见 [社交服务 - C#](社交服务-CSharp.md)。API 逐项签名见 API Reference：[DouyinSocialService](../../API%20Reference/DouyinSocialService.md)。

---

## 0. 真实 API 形态（先看这一节）

`DouyinSocialService` 是**全局注入对象**（Lua 侧直接调用），2 方法 + 2 事件：

```lua
-- 方法（回调式，callback 收到 bool 表示分享是否成功发起/完成）
DouyinSocialService.ShareWorld(templateId, function(value) end)   -- templateId 为 "" 时用官方默认模板
DouyinSocialService.ShareTexture(texture, function(value) end)    -- texture 为 UnityEngine.Texture

-- 事件（AddListener / RemoveListener）
DouyinSocialService.onPublishProcessEvent  -- 回调(publishId:string, process:int 0-100)
DouyinSocialService.onPublishResultEvent   -- 回调(publishId:string, success:int 1/0, contentId:string)
```

- 分享仅**线上环境**生效；本地调试器 / 扫码测试不支持。
- 分享 `callback(false)` 含**用户取消**，不代表好友是否进房。

> ⚠️ 只有这 2 方法 + 2 事件，**没有** `async/await`、取消 / 重试、或查询分享详情的接口。请勿引用不存在的符号。

---

## 一、何时使用

- 世界内「分享给好友」入口（世界卡片 / 战绩图），驱动传播裂变。
- 监听玩家投稿抖音视频的进度与结果，投稿完成后提示 / 奖励。

---

## 二、世界分享封装

```lua
local DouyinSocialService = DouyinSocialService
local DouyinApplication = DouyinApplication

-- 已在创作后台审核通过的自定义分享模板 ID；没有就用 "" 走官方默认模板
local CUSTOM_TEMPLATE_ID = "tmpl_ab12cdefg345hijk"

-- onDone: function(success:boolean) 可选
function ShareCurrentWorld(onDone)
    -- 1) 调试器环境拦截：分享仅线上可用
    if DouyinApplication.isSimulator then
        DouyinUtility.Toast("分享功能请在线上环境体验")
        if onDone then onDone(false) end
        return
    end

    -- 2) 发起世界分享
    DouyinSocialService.ShareWorld(CUSTOM_TEMPLATE_ID, function(value)
        if value then
            print("[Social] 世界分享已发起")
        else
            print("[Social] 世界分享失败或被用户取消")
        end
        if onDone then onDone(value) end
    end)
end
```

> 若未配置自定义模板，把 `CUSTOM_TEMPLATE_ID` 换成 `""` 即可使用官方默认世界分享模板。

---

## 三、图片分享封装（结算战绩图场景）

`ShareTexture` 的图片建议尺寸 168×264（安卓）/ 168×224（iOS），过小分享预览会显示不全。

```lua
---@var resultImage:UnityEngine.UI.RawImage
---@end

-- 分享一张图片（如结算战绩图 / 作品截图）
-- texture: UnityEngine.Texture；onDone: function(success) 可选
function ShareImage(texture, onDone)
    if DouyinApplication.isSimulator then
        DouyinUtility.Toast("分享功能请在线上环境体验")
        if onDone then onDone(false) end
        return
    end
    if texture == nil then
        print("[Social] 分享图片为空，跳过")
        if onDone then onDone(false) end
        return
    end

    DouyinSocialService.ShareTexture(texture, function(value)
        if value then
            print("[Social] 图片分享已发起")
        else
            print("[Social] 图片分享失败或被用户取消")
        end
        if onDone then onDone(value) end
    end)
end

-- 结算面板「分享战绩」按钮
function OnClickShareResult()
    -- resultImage.texture 为结算时生成/渲染的战绩图
    ShareImage(resultImage.texture)
end
```

---

## 四、投稿监听生命周期

```lua
local function OnPublishProcess(publishId, process)
    print(string.format("[Social] 投稿进度 id=%s process=%d", publishId, process))
    -- 可更新 UI 进度条
end

local function OnPublishResult(publishId, success, contentId)
    if success == 1 then
        print(string.format("[Social] 投稿成功 id=%s contentId=%s", publishId, contentId))
        -- 投稿成功：给予奖励 / 提示（注意防重复，见奖励类实践）
    else
        print(string.format("[Social] 投稿失败 id=%s", publishId))
    end
end

function Start()
    DouyinSocialService.onPublishProcessEvent:AddListener(OnPublishProcess)
    DouyinSocialService.onPublishResultEvent:AddListener(OnPublishResult)
end

-- 必须成对移除，避免重复回调与泄漏
function OnDestroy()
    DouyinSocialService.onPublishProcessEvent:RemoveListener(OnPublishProcess)
    DouyinSocialService.onPublishResultEvent:RemoveListener(OnPublishResult)
end
```

---

## 五、社交裂变（结合房间来源）

分享驱动裂变的关键是：**被邀请者进房时识别邀请人**，再给双方发奖。进入来源与邀请人 ID 取自房间信息（见 [房间服务 - Lua](房间服务-Lua.md)）。

```lua
-- 进房时判断是否由分享卡片进入（伪代码，房间信息获取见房间服务）
local function OnRoomInfoReady(roomInfo)
    local inviterOpenID = roomInfo and roomInfo.inviterOpenID
    if inviterOpenID ~= nil and inviterOpenID ~= "" then
        -- 当前玩家由分享进房：给被邀请者发奖，并记录邀请人待发奖
        print("[Social] 分享进房，邀请人=" .. inviterOpenID)
        -- GrantInviteeReward(); MarkInviterReward(inviterOpenID)
    end
end
```

---

## 六、相关文档

- [社交服务 - C#](社交服务-CSharp.md)
- Manual：[社交服务](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/社交服务.md)
- 配合使用：[房间服务 - Lua](房间服务-Lua.md)（邀请来源）、[图片服务 - Lua](图片服务-Lua.md)（分享图获取）
- API Reference：[DouyinSocialService](../../API%20Reference/DouyinSocialService.md)
