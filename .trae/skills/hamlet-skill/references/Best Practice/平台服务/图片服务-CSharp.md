# 图片服务 - C#

> 本文带你用 C# 从 0 到 1 用好 `DouyinImageService.DownloadImage`：下载远程图片、赋值 UI、缓存复用、生命周期释放与失败降级。能力概念与边界请先阅读 Manual：[图片服务](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/图片服务.md)。Lua 版本见 [图片服务 - Lua](图片服务-Lua.md)。API 逐项签名见 API Reference：[DouyinImageService.DownloadImage](../../API%20Reference/DouyinImageService/DouyinImageService.DownloadImage.md)。

---

## 0. 真实 API 形态（先看这一节）

C# 侧 `DouyinImageService` 是**全局静态类**，只有一个方法，回调式（不是 `async/await`，没有返回 `Task`）：

```csharp
DouyinImageService.DownloadImage(string url, Action<Texture2D> callback);
```

- 入参 `url`：图片下载链接。
- 回调 `Action<Texture2D>`：下载完成时触发，参数为 `Texture2D`，**失败时可能为 `null`**。
- **没有**取消、进度、批量或缓存接口，缓存与释放都由业务侧实现。

> ⚠️ 平台**未提供** `async/await` 版本，也**没有** `DownloadImageAsync`、`Cancel`、`LoadSprite`、进度回调或 `DouyinImageService.Instance` 单例。请勿引用这些不存在的符号——一切以 `DownloadImage(url, callback)` + 判空为准。

---

## 1. 最小下载封装（缓存 + 并发合并 + 降级）

把以下 helper 放在业务脚本中。调用方用 `LoadImageTo(rawImage, url)` 即可，无需关心缓存与时序。

```csharp
using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class ImageLoader
{
    // url -> Texture2D 缓存
    private readonly Dictionary<string, Texture2D> _cache = new Dictionary<string, Texture2D>();
    // url -> 进行中的回调队列，用于合并同 URL 并发
    private readonly Dictionary<string, List<Action<Texture2D>>> _pending =
        new Dictionary<string, List<Action<Texture2D>>>();

    // 下载（带缓存与并发合并）。onDone(tex) 中 tex 可能为 null
    public void DownloadImageCached(string url, Action<Texture2D> onDone)
    {
        if (string.IsNullOrEmpty(url))
        {
            onDone?.Invoke(null);
            return;
        }

        // 命中缓存
        if (_cache.TryGetValue(url, out var cached))
        {
            onDone?.Invoke(cached);
            return;
        }

        // 已有同 URL 请求在途，挂到回调队列
        if (_pending.TryGetValue(url, out var list))
        {
            list.Add(onDone);
            return;
        }

        _pending[url] = new List<Action<Texture2D>> { onDone };
        DouyinImageService.DownloadImage(url, tex =>
        {
            if (tex != null)
            {
                _cache[url] = tex;
            }
            else
            {
                Debug.LogWarning($"[Image] 下载失败 url={url}");
            }

            if (_pending.TryGetValue(url, out var callbacks))
            {
                _pending.Remove(url);
                foreach (var cb in callbacks)
                {
                    cb?.Invoke(tex);
                }
            }
        });
    }

    // 赋值到 RawImage：记录目标期望 url，回调时校验防错图
    private readonly Dictionary<RawImage, string> _expectUrl = new Dictionary<RawImage, string>();

    public void LoadImageTo(RawImage rawImage, string url, Texture placeholder = null)
    {
        if (rawImage == null) return;
        _expectUrl[rawImage] = url;

        DownloadImageCached(url, tex =>
        {
            // 目标已销毁或期望 URL 已变（列表复用），丢弃结果
            if (rawImage == null) return;
            if (!_expectUrl.TryGetValue(rawImage, out var expect) || expect != url) return;

            if (tex != null)
            {
                rawImage.texture = tex;
            }
            else if (placeholder != null)
            {
                rawImage.texture = placeholder; // 降级占位图
            }
        });
    }

    // 释放全部缓存纹理（界面销毁时调用）
    public void Clear()
    {
        foreach (var tex in _cache.Values)
        {
            if (tex != null)
            {
                UnityEngine.Object.Destroy(tex);
            }
        }
        _cache.Clear();
        _pending.Clear();
        _expectUrl.Clear();
    }
}
```

---

## 2. 赋值给 Image（转 Sprite）

`RawImage` 可直接用 `Texture2D`；`Image` 组件需要 `Sprite`：

```csharp
public static Sprite TextureToSprite(Texture2D tex)
{
    if (tex == null) return null;
    var rect = new Rect(0, 0, tex.width, tex.height);
    var pivot = new Vector2(0.5f, 0.5f);
    return Sprite.Create(tex, rect, pivot);
}

public void LoadSpriteTo(ImageLoader loader, Image image, string url)
{
    if (image == null) return;
    loader.DownloadImageCached(url, tex =>
    {
        if (image == null || tex == null) return;
        image.sprite = TextureToSprite(tex);
    });
}
```

---

## 3. 业务接入示例

### 展示创作者头像

配合 `DouyinCreatorService.GetCreatorInfo`（见 [创作者服务 - C#](创作者服务-CSharp.md)）：

```csharp
private readonly ImageLoader _imageLoader = new ImageLoader();
public RawImage avatarImage;

public void ShowCreatorAvatar()
{
    DouyinCreatorService.GetCreatorInfo(info =>
    {
        if (info == null || string.IsNullOrEmpty(info.portrait))
        {
            return;
        }
        _imageLoader.LoadImageTo(avatarImage, info.portrait);
    });
}

private void OnDestroy()
{
    _imageLoader.Clear();
}
```

---

## 4. 相关文档

- [图片服务 - Lua](图片服务-Lua.md)
- URL 来源：[创作者服务 - C#](创作者服务-CSharp.md)（`portrait`）
- Manual：[图片服务](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台业务服务/图片服务.md)
- API Reference：[DouyinImageService.DownloadImage](../../API%20Reference/DouyinImageService/DouyinImageService.DownloadImage.md)
