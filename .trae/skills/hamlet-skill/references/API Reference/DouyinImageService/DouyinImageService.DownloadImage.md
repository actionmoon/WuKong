public static void DownloadImage(string url, Action<Texture2D> callback)
# 参数
| 参数名称 | 参数描述 |
| --- | --- |
| url | 图片的下载链接 |
| callback | 回调函数，承载着获取到的 Texture2D 类型的图片数据 |
# 描述
通过url下载图片数据，并转换为Texture2D的格式
# 代码示例
```Lua
---@var rawImage:UnityEngine.UI.RawImage
---@end

local Input = UnityEngine.Input

function Update()
    if Input.GetKeyDown("0") then
        DownloadImageSample()
    end
end

function DownloadImageSample()
    --图片的下载链接
    local url = ""
    DouyinImageService.DownloadImage(url,function (downloadTex)
        if downloadTex then
            rawImage.texture = downloadTex
        end
    end)
end
```


