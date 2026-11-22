# 图片服务 - Lua

> 本文带你用 Lua 从 0 到 1 用好 `DouyinImageService.DownloadImage`：下载远程图片、赋值 UI、缓存复用、生命周期释放与失败降级。
>
> 能力概念与边界请先阅读 Manual：[图片服务](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/图片服务.md)。C# 版本见 [图片服务 - C#](图片服务-CSharp.md)。API 逐项签名见 API Reference：[DouyinImageService.DownloadImage](../../API%20Reference/DouyinImageService/DouyinImageService.DownloadImage.md)。

---

## 0. 真实 API 形态（先看这一节）

`DouyinImageService` 是**全局静态类**，只有一个方法，回调式：

```lua
DouyinImageService.DownloadImage(url, function(tex)
    -- tex: UnityEngine.Texture2D，下载失败可能为 nil
end)
```

- 入参 `url`：图片下载链接（string）。
- 回调 `function(tex)`：下载完成时触发，`tex` 为 `Texture2D`，**失败时可能为 nil**。
- **没有**取消、进度、批量或缓存接口，缓存与释放都由业务侧实现。

> ⚠️ 请勿引用不存在的符号（如 `DouyinImageService.Cancel`、`LoadImage`、`GetTexture`、进度回调等）。一切以 `DownloadImage(url, callback)` 为准。

---

## 一、何时使用

- 展示创作者头像（`creatorInfo.portrait`）、奖励缩略图（`rewardInfo.imageUrl`）等远程图片。
- 把网络图片赋给 `RawImage`，或转成 `Sprite` 赋给 `Image`。
- 需要“下载一次、多处复用、离开释放”的图片加载。

---

## 二、最小下载 helper（缓存 + 并发合并 + 降级）

把以下 helper 放在脚本顶部公共区。调用方用 `LoadImageTo(rawImage, url)` 即可。约束都写在注释里，跟着代码看即可。

```lua
local UnityEngine = UnityEngine
local DouyinImageService = DouyinImageService

-- url -> Texture2D 缓存
local textureCache = {}
-- url -> { callbacks... } 进行中的请求，用于合并同 URL 并发
local pendingCallbacks = {}

-- 下载（带缓存与并发合并）。onDone(tex) 中 tex 可能为 nil
local function DownloadImageCached(url, onDone)
    if url == nil or url == "" then
        if onDone then onDone(nil) end
        return
    end

    -- 命中缓存
    local cached = textureCache[url]
    if cached ~= nil then
        if onDone then onDone(cached) end
        return
    end

    -- 已有同 URL 请求在途，挂到回调队列
    if pendingCallbacks[url] ~= nil then
        table.insert(pendingCallbacks[url], onDone)
        return
    end

    pendingCallbacks[url] = { onDone }
    DouyinImageService.DownloadImage(url, function(tex)
        if tex ~= nil then
            textureCache[url] = tex
        else
            UnityEngine.Debug.LogWarning("[Image] 下载失败 url=" .. url)
        end

        local callbacks = pendingCallbacks[url]
        pendingCallbacks[url] = nil
        if callbacks ~= nil then
            for i = 1, #callbacks do
                local cb = callbacks[i]
                if cb ~= nil then cb(tex) end
            end
        end
    end)
end

-- 赋值到 RawImage：记录目标当前期望的 url，回调时校验防错图
local function LoadImageTo(rawImage, url, placeholder)
    if rawImage == nil then return end
    rawImage._expectUrl = url

    DownloadImageCached(url, function(tex)
        -- 目标已被销毁或期望 URL 已变（列表复用），丢弃本次结果
        if rawImage == nil or rawImage._expectUrl ~= url then
            return
        end
        if tex ~= nil then
            rawImage.texture = tex
        elseif placeholder ~= nil then
            rawImage.texture = placeholder -- 降级占位图
        end
    end)
end
```

---

## 三、赋值给 Image（转 Sprite）

`RawImage` 可直接用 `Texture2D`；`Image` 组件需要 `Sprite`：

```lua
local function TextureToSprite(tex)
    if tex == nil then return nil end
    local rect = UnityEngine.Rect(0, 0, tex.width, tex.height)
    local pivot = UnityEngine.Vector2(0.5, 0.5)
    return UnityEngine.Sprite.Create(tex, rect, pivot)
end

-- 用法：把远程图下载后赋给 Image 组件
local function LoadSpriteTo(image, url)
    if image == nil then return end
    DownloadImageCached(url, function(tex)
        if image == nil or tex == nil then return end
        image.sprite = TextureToSprite(tex)
    end)
end
```

---

## 四、入口组合示例

### 展示创作者头像

配合 `DouyinCreatorService.GetCreatorInfo`（见 [创作者服务 - Lua](创作者服务-Lua.md)）：

```lua
---@var avatarImage:UnityEngine.UI.RawImage
---@end

function ShowCreatorAvatar()
    DouyinCreatorService.GetCreatorInfo(function(info)
        if info == nil or info.portrait == nil or info.portrait == "" then
            return
        end
        LoadImageTo(avatarImage, info.portrait)
    end)
end
```

---

## 五、释放与清理

界面销毁或缓存不再需要时释放纹理（不要在 `Update` / `FixedUpdate` 中反复下载同一张图）：

```lua
local function ClearImageCache()
    for _, tex in pairs(textureCache) do
        if tex ~= nil then
            UnityEngine.Object.Destroy(tex)
        end
    end
    textureCache = {}
    pendingCallbacks = {}
end

function OnDestroy()
    ClearImageCache()
end
```

---

## 六、相关文档

- [图片服务 - C#](图片服务-CSharp.md)
- URL 来源：[创作者服务 - Lua](创作者服务-Lua.md)（`portrait`）
- Manual：[图片服务](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/图片服务.md)
- API Reference：[DouyinImageService.DownloadImage](../../API%20Reference/DouyinImageService/DouyinImageService.DownloadImage.md)
