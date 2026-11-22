# 相机回正（Lua）最佳实践

> 💡 **理论与机制指引**：关于 yaw 渐进回正的四条硬约束、Look 输入监听时序、扩展点契约、通用硬约束、常见坑，请参考手册：[相机视角控制.md](../../Manual/%E2%85%A0.%20%E6%A0%B8%E5%BF%83%E7%B3%BB%E7%BB%9F(Core)/%E7%8E%A9%E5%AE%B6%E7%BD%91%E7%BB%9C%E5%AF%B9%E8%B1%A1/%E7%9B%B8%E6%9C%BA%E6%8E%A7%E5%88%B6/%E7%9B%B8%E6%9C%BA%E8%A7%86%E8%A7%92%E6%8E%A7%E5%88%B6.md)。
> 本文仅提供相机回正在 Lua 侧的标准代码骨架 + 三个业务变体。

---

## 1. 最小可用骨架（完整闭环）

由 6 段代码组成：状态变量、Look 输入注册 / 解绑、`Start` / `OnDestroy` 集成、`LateUpdate` 渐进对齐、宿主扩展点默认实现。业务变体只覆写扩展点，**不要**改动本骨架结构。

### 1.1 状态变量（脚本顶部）

```lua
local DouyinCameraService = CS.DouyinCameraService
local DouyinInputService = CS.DouyinInputService

local cameraAlignSpeed = 90       -- 回正最大角速度（度/秒）
local cameraAlignGrace = 0.5      -- 玩家最近一次操作视角后的冷却时间（秒）
local isLookingActive = false     -- 通用硬约束 #6：顶层声明
local lastLookTime = -math.huge   -- 通用硬约束 #6：顶层声明

-- 保存 handler 引用（通用硬约束 #5：精准解绑）
local onLookStartHandler = nil
local onLookPerformHandler = nil
local onLookCancelHandler = nil
```

### 1.2 Look 输入注册

```lua
local function registerCameraAlignInputListeners()
  onLookStartHandler = function()
    isLookingActive = true
    lastLookTime = CS.UnityEngine.Time.time
  end
  onLookPerformHandler = function()
    isLookingActive = true
    lastLookTime = CS.UnityEngine.Time.time
  end
  onLookCancelHandler = function()
    isLookingActive = false
    lastLookTime = CS.UnityEngine.Time.time
  end

  DouyinInputService.onLookInputStart:AddListener(onLookStartHandler)
  DouyinInputService.onLookInputPerform:AddListener(onLookPerformHandler)
  DouyinInputService.onLookInputCancel:AddListener(onLookCancelHandler)
end
```

### 1.3 Look 输入解绑

```lua
local function removeCameraAlignInputListeners()
  if onLookStartHandler ~= nil then
    DouyinInputService.onLookInputStart:RemoveListener(onLookStartHandler)
  end
  if onLookPerformHandler ~= nil then
    DouyinInputService.onLookInputPerform:RemoveListener(onLookPerformHandler)
  end
  if onLookCancelHandler ~= nil then
    DouyinInputService.onLookInputCancel:RemoveListener(onLookCancelHandler)
  end
end
```

### 1.4 `Start` / `OnDestroy` 集成

```lua
function Start()
  -- ...宿主自身的输入 / 业务初始化...
  registerCameraAlignInputListeners()  -- Manual §4.3：宿主输入之后再注册
end

function OnDestroy()
  -- ...宿主自身的输入 / 业务销毁...
  removeCameraAlignInputListeners()    -- Manual §4.3：宿主输入解绑之后再清理
end
```

### 1.5 `LateUpdate` 渐进对齐

```lua
function LateUpdate()
  -- Manual §4.2：逐项 guard
  if isLookingActive then return end
  if CS.UnityEngine.Time.time - lastLookTime < cameraAlignGrace then return end

  local targetYaw = getCameraAlignTargetYaw()
  if targetYaw == nil then return end

  local speedScale = getCameraAlignSpeedScale()
  if speedScale == nil or speedScale <= 0 then return end

  local currentYaw = DouyinCameraService.GetYaw()
  if currentYaw == nil then return end                                   -- 通用硬约束 #1

  -- 回正硬约束 #3：Mathf.DeltaAngle 取最短角差
  local delta = CS.UnityEngine.Mathf.DeltaAngle(currentYaw, targetYaw)

  -- 回正硬约束 #4：按最大步长渐进
  local maxStep = cameraAlignSpeed * speedScale * CS.UnityEngine.Time.deltaTime
  local step = 0
  if math.abs(delta) <= maxStep then
    step = delta
  elseif delta >= 0 then
    step = maxStep
  else
    step = -maxStep
  end

  DouyinCameraService.SetYaw(currentYaw + step)
end
```

### 1.6 宿主扩展点（默认空实现）

```lua
-- 返回当前希望对齐到的 yaw（度），不需要对齐时返回 nil
function getCameraAlignTargetYaw()
  return nil
end

-- 返回 [0, 1] 范围的速度缩放；返回 0 等价于不对齐
function getCameraAlignSpeedScale()
  return 1
end
```

宿主脚本**必须覆写**这两个函数以提供业务语义；不覆写则默认完全不对齐。

---

## 2. 业务变体 A：驾驶载具时回正到车头方向

依赖 `seat-alignment` 提供的 `hasPassenger` 和 `input-listener` 提供的 `moveVec` / `DEAD_ZONE`。只在前进油门时回正，油门越深回正越积极。

```lua
function getCameraAlignTargetYaw()
  if not hasPassenger then return nil end
  if moveVec == nil or moveVec.y < DEAD_ZONE then return nil end  -- 只在前进油门时对齐
  return self.transform.rotation.eulerAngles.y
end

function getCameraAlignSpeedScale()
  if not hasPassenger or moveVec == nil then return 0 end
  return math.min(1, math.max(0, moveVec.y))  -- 油门越深回正越积极
end
```

---

## 3. 业务变体 B：进入触发区强制回正到固定朝向

进入触发区时锁定当前触发器的朝向为目标 yaw，离开时清空。适合剧情引导 / 传送落点。

```lua
local forcedYaw = nil

function OnActorTriggerEnter(actor)
  if actor == nil or not actor.isLocal then return end
  forcedYaw = self.transform.rotation.eulerAngles.y
end

function OnActorTriggerExit(actor)
  if actor == nil or not actor.isLocal then return end
  forcedYaw = nil
end

function getCameraAlignTargetYaw()
  return forcedYaw
end

function getCameraAlignSpeedScale()
  return forcedYaw == nil and 0 or 1
end
```

---

## 4. 业务变体 C：朝动态目标对齐（锁定 NPC / UI 焦点）

由外部设置 `cameraTarget`（`Transform` 或含 `position` 的对象）；模块朝目标的水平方向渐进回正。

```lua
local cameraTarget = nil

function getCameraAlignTargetYaw()
  if cameraTarget == nil then return nil end
  local camera = DouyinCameraService.GetCamera()
  if camera == nil then return nil end
  local dir = cameraTarget.position - camera.transform.position
  if dir.sqrMagnitude < 0.0001 then return nil end
  -- 以世界 Y 轴为旋转轴，根据水平方向计算 yaw
  return CS.UnityEngine.Mathf.Atan2(dir.x, dir.z) * CS.UnityEngine.Mathf.Rad2Deg
end

function getCameraAlignSpeedScale()
  return cameraTarget == nil and 0 or 0.6
end
```

> ⚠️ **注意**：这里读 `camera.transform.position` 仅用于**计算方向**，没有写入相机姿态，符合"不直接写 `Camera.main.transform`"的通用硬约束 #2。
