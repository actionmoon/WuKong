# 拍照模式（Lua）最佳实践

> 💡 **理论与机制指引**：关于拍照模式核心 API、与业务相机参数（yaw / pitch / distance / offset）的冲突处理、模式切换事件精准解绑，请参考手册：[相机视角控制.md](../../Manual/%E2%85%A0.%20%E6%A0%B8%E5%BF%83%E7%B3%BB%E7%BB%9F(Core)/%E7%8E%A9%E5%AE%B6%E7%BD%91%E7%BB%9C%E5%AF%B9%E8%B1%A1/%E7%9B%B8%E6%9C%BA%E6%8E%A7%E5%88%B6/%E7%9B%B8%E6%9C%BA%E8%A7%86%E8%A7%92%E6%8E%A7%E5%88%B6.md) §七。
> 本文仅提供拍照模式在 Lua 侧的标准代码骨架。

---

## 1. 监听模式切换（onCameraModeChanged）

监听平台相机模式切换，在进入拍照时暂停业务干预、退出时重新施加当前状态的相机参数。

```lua
local DouyinCameraService = CS.DouyinCameraService

local onCameraModeChangedHandler = nil

function Start()
  onCameraModeChangedHandler = function(mode)
    if mode == CS.DouyinCameraMode.GamePlay then
      -- 扩展点：切回游戏模式后恢复业务相机参数
      -- 例：if hasPassenger then applyDriveCameraView() end
    else
      -- 扩展点：进入拍照模式，暂停业务相机干预
    end
  end
  DouyinCameraService.onCameraModeChanged:AddListener(onCameraModeChangedHandler)
end

function OnDestroy()
  if onCameraModeChangedHandler ~= nil then
    -- 通用硬约束 #5：保存 handler 引用，用 RemoveListener 精准解绑
    DouyinCameraService.onCameraModeChanged:RemoveListener(onCameraModeChangedHandler)
  end
end
```

---

## 2. 主动进入 / 退出拍照模式（Start / Stop / IsPhotographMode）

按当前拍照状态在两种模式间切换。

```lua
local DouyinCameraService = CS.DouyinCameraService

-- 主动进入 / 退出拍照模式
local function togglePhotograph()
  if DouyinCameraService.IsPhotographMode() then
    DouyinCameraService.StopPhotograph()
  else
    DouyinCameraService.StartPhotograph()
  end
end
```
