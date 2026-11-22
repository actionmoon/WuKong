# 视野角 FOV（Lua）最佳实践

> 💡 **理论与机制指引**：关于 FOV 的平滑过渡要求、数值建议、常见误区（用 FOV 模拟拉远相机 / 瞬切眩晕 / 调窄模拟加速）、平台跟随不回拨 fieldOfView 的行为，请参考手册：[相机视角控制.md](../../Manual/%E2%85%A0.%20%E6%A0%B8%E5%BF%83%E7%B3%BB%E7%BB%9F(Core)/%E7%8E%A9%E5%AE%B6%E7%BD%91%E7%BB%9C%E5%AF%B9%E8%B1%A1/%E7%9B%B8%E6%9C%BA%E6%8E%A7%E5%88%B6/%E7%9B%B8%E6%9C%BA%E8%A7%86%E8%A7%92%E6%8E%A7%E5%88%B6.md) §六。
> 本文仅提供 FOV 视野增强在 Lua 侧的标准代码骨架。

---

## 1. 加速 FOV 视野增强

加速 / boost 期间临时把视野角调大以增强速度感。当前世界相机位置不变，只写 `fieldOfView`。

```lua
local DouyinCameraService = CS.DouyinCameraService

local baseFov = 60
local boostFov = 68
local currentFov = baseFov
local fovLerpSpeed = 6

local function getTargetFov()
  if not hasPassenger then return baseFov end
  if boostHeld then return boostFov end
  return baseFov
end

function Update()
  local camera = DouyinCameraService.GetCamera()
  if camera == nil then return end  -- 通用硬约束 #1：nil-guard

  local targetFov = getTargetFov()
  currentFov = CS.UnityEngine.Mathf.Lerp(
    currentFov,
    targetFov,
    CS.UnityEngine.Time.deltaTime * fovLerpSpeed
  )

  camera.fieldOfView = currentFov  -- 通用硬约束 #2 的例外：允许写 fieldOfView
end
```
