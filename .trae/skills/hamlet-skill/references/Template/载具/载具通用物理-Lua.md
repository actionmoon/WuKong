# 载具通用物理（Lua）最佳实践

> 💡 **前置阅读**：先读 [Rigidbody-驱动-Lua](../物理/Rigidbody-驱动-Lua.md)（通用范式：velocity 保留 y、MoveRotation、XLua `*`、Kinematic guard、W/S 双轴消费）。

> 基础概念、载具系统在物理领域中的位置见 [载具系统概述](../../Manual/Ⅰ.%20核心系统(Core)/载具/载具系统概述.md)；Rigidbody 通用规则见 [Rigidbody-规则](../../Manual/Ⅰ.%20核心系统(Core)/物理/Rigidbody-规则.md)。

> ⚠️ **适用范围**：本文中的 `applyRigidbodyTuning` 每帧覆写、10 步 FixedUpdate 顺序、mass·drag 抗推挤量级、4 类介质差异约束跨 Lua 与 C# 都适用。当前载具目录**仅提供 Lua 侧骨架**（无 C# 骨架）。若走 ai-world-creator 的 AI-authoring 流程（`player-interaction-agent`），`meta.json.attributes` 与 `tunedMass/tunedDrag` 的一致性约束尤为关键；直接用 UGC SDK 手写脚本时，可按项目约定维护静态刚体参数。

---

## 一、载具补充硬约束（4 条）

**载具**（玩家坐进 / 骑上去驾驶的物体）在通用主动驱动的基础上，还需要额外一套调校才能得到真实的驾驶手感；非载具的主动驱动物体（追踪 NPC / 遥控物）**不需要**这套调校。

1. **载具驾驶属于本地控制**，本模块的物理写入**不需要**主权门禁；只有多人扩展的按钮交互链路才在 `OnInteractorButtonClick` 里叠加 `ensureOwnership`。
2. **每帧显式重设刚体参数**：载具需要维护一个 `applyRigidbodyTuning(rb)` 函数，在 `FixedUpdate` **开头**调用一次，重新写入 `mass` / `drag` / `angularDrag` / `centerOfMass` / `maxAngularVelocity` —— 某些运行时版本会在刚体启用后重置这些字段，静态配置不足以保证运行时稳定。
3. **`FixedUpdate` 必须严格按 10 步顺序组织**——任何打乱都会出现物理失真（见 §三）。
4. **`mass` 与 `drag` 必须选对量级**：见 §二。

### 1.1 载具 Collider / Trigger 清单

生成或改造可交互载具时，先按职责检查资源拓扑：

| 需求 | 必查配置 |
| --- | --- |
| 上车、骑乘、上机、下车按钮 | `isTrigger=true` 的交互 Trigger；Root-bound 脚本优先让 Trigger 与 Root `DouyinScript` 同节点 |
| 车辆接地、撞墙、玩家实体接触 | 至少一个 `isTrigger=false` 的实体 Collider；复杂模型可把多个实体 Collider 放在子节点并共享 Root Rigidbody |
| 飞行载具无接地需求 | 可以省略实体接地 Collider，但必须明确这是“无实体接触”的玩法设计；不能因漏配 Collider 造成动态刚体意外下坠 |
| 复合模型 Hamlet 回调 | Unity 的 `attachedRigidbody` 复合关系与 Hamlet Actor 回调归属分开验证；脚本不会自动接收子 Collider 的 Actor 回调 |

两个项目反例：

- **Bicycle**：Root `BoxCollider(isTrigger=true)` 负责靠近交互，两个车轮 Pivot 的 `SphereCollider(isTrigger=false)` 负责接地；只有 Root Trigger 时 Play Mode 会掉到地下。
- **Helicopter**：Root `BoxCollider(isTrigger=true)` 负责 `OnActorTriggerEnter/Exit` 和上机按钮；只有实体 Collider 时物理可成立，但不会自动出现靠近交互入口。

载具最小 Play Mode 验收：落地/悬停状态符合设计、玩家靠近能触发交互、玩家远离能清理交互、上下车后 Rigidbody/Collider 状态符合介质规则。

### 1.2 介质参数决策矩阵

先按介质选择运动模型，再在推荐起步值附近调手感：

| 介质 | `isKinematic` | `useGravity` | y 速度 | `mass/drag` 起步值 | 备注 |
| --- | ---: | ---: | --- | --- | --- |
| 地面 | `false` | `true` | 保留 y | `1200 / 3.0` | 实体 Collider 接地，启用 5 大调校 |
| 水面 | `false` | 通常 `false` | 脚本 y 阻尼 | `1500 / 4.0` | 浮力/水面高度由脚本负责 |
| 悬浮 | `false` | `false` | 脚本完整控制 | `800 / 2.0` | Raycast + PD |
| 飞行 | `false` | 进入飞行时 `false` | 脚本接管三轴 | `700 / 1.5` | `enterFlight`/`exitFlight` 成对切换 |
| 运动学移动平台 | `true` | 通常不依赖重力 | `MovePosition` | 质量不是主要调参项 | 站立玩家需要 Default 可踩层 |
| 骑行生物 Motion API | 由框架管理 | 由框架管理 | 不由载具 Rigidbody 接管 | 不套实体载具量级 | 不误用四轮/实体载具骨架 |

注意：

- `mass` 和 `drag` 是成组调参，不是“越大越稳定”。
- `useGravity` 只描述重力来源，不等于是否需要实体 Collider。
- `isKinematic` 只描述刚体是否接受物理驱动，不等于是否需要 Trigger。
- 每种载具都要同时验收 Rigidbody 状态、实体 Collider、Interaction Trigger、座位生命周期、Layer 和控制权。

---

## 二、mass·drag 抗推挤量级

玩家角色（碰撞体 + 自身质量）大约在 60 kg 量级。若载具 `mass` 与玩家同量级（如 80 kg）且 `drag` 偏低（0.5 左右），停放载具会被玩家步行时的持续碰撞不断顶开，一整局下来偏离原位几米。载具 `mass` 应比玩家高一个量级，`drag` 也要成比例提高：

| 介质 | `mass` 推荐 | `drag` 推荐 | `angularDrag` 推荐 |
| --- | --- | --- | --- |
| **地面**（越野车 / 卡丁车 / 皮卡） | 1200 | 3.0 | 6.0 |
| **水面**（船 / 快艇） | 1500 | 4.0 | 7.0 |
| **悬浮**（滑板 / 气垫船） | 800 | 2.0 | 6.0 |
| **飞行**（直升机 / 飞碟） | 700 | 1.5 | 4.0 |

**验证方法（三项）**：

1. 玩家站在载具旁持续按 W 顶车 10 秒，位移应 <0.3 米。
2. 从静止踩油门到 `topSpeed` 应在 2–3 秒内。
3. 两辆同型号载具正面相撞（一辆静止一辆开到 `topSpeed`），静止那辆应被撞开 1–3 米。

**成组调整**：不要单参数走极端。`mass` 提一个量级时 `drag` 也要成比例提；`mass = 5000` + `drag = 0.5` 或 `mass = 100` + `drag = 10` 都会破坏驾驶手感。

**authoring 一致性**（AI-authoring 流程专属）：`applyRigidbodyTuning` 每帧会用 `tunedMass / tunedDrag` 覆盖 `meta.json.attributes` 里的值；若走 authoring 流程，attributes 里的值必须与模板 CONFIG 的 `tunedMass / tunedDrag` 保持一致，否则运行时刚体状态会在两个值之间跳变。

---

## 三、FixedUpdate 10 步顺序

载具 `FixedUpdate` 严格按以下顺序组织（任何打乱都会出现物理失真——例如侧向摩擦放在 Grip 之前会消掉转向修正、限速放写回之后会漂移）：

1. `applyRigidbodyTuning(rb)`（每帧重设刚体参数）
2. 解析输入（`accelInput` / `turnInput`）
3. **高速转向衰减**（车速越高转向灵敏度越低，防止高速失控）
4. 加速曲线 / 刹车 / 滑行（业务侧速度公式）
5. **Grip 方向修正**（让已有速度方向跟着车头一起偏转）
6. **`dampSidewaysSlip`**（侧向摩擦力，抑制车身横向滑动）
7. **`applyTiltSafetyBrake`**（侧翻保护：车身倾斜超过阈值时自动减速）
8. 二次限速（`ClampMagnitude`，剥离 y）
9. 写回 `rb.velocity`（保留 y 分量；见 [Rigidbody-规则 § 四 #3](../../Manual/Ⅰ.%20核心系统(Core)/物理/Rigidbody-规则.md)）
10. **`stabilizeAngularMotion`**（角速度稳定与扶正辅助）

---

## 四、4 类介质差异摘要

| 介质 | y 轴写回 | `useGravity` | Grip 参考值 | 是否用第 3/6/7/10 步调校 |
| --- | --- | --- | --- | --- |
| **地面** | 保留 y（重力） | `true` | 0.9–1.0 | ✅ 全部使用 |
| **水面** | 保留 y（浮力 + y 阻尼） | `true` 或 `false` | 0.6–0.8（漂移感） | ✅ 全部使用，`sidewaysFriction` 更强 |
| **悬浮** | **完整覆盖 y**（Raycast 离地高度） | `false`（脚本接管） | 0.5–0.7 | ✅ 全部使用，无侧翻保护（姿态脚本控制） |
| **飞行** | **完整覆盖 y**（脚本接管三轴） | `false`（`enterFlight` 关，`exitFlight` 还原） | 不适用 | ❌ **不使用**（姿态走 `MoveRotation` + `m_pitch/yaw/roll`） |

介质专属规则（各介质独有硬约束逐条、Motion API 契约、`enterFlight` / `exitFlight` 钩子、悬浮 PD 控制、飞行 12 条硬约束、专属 FAQ）见：

- [地面载具-Lua](./地面载具-Lua.md)
- [水面载具-Lua](./水面载具-Lua.md)
- [悬浮载具-Lua](./悬浮载具-Lua.md)
- [飞行载具-Lua](./飞行载具-Lua.md)

---

## 五、参数参考值

以下是**贴地 / 贴水面 / 悬浮**载具的推荐**高速响应型**参数（飞行载具见 [飞行载具-Lua](./飞行载具-Lua.md)）。可根据具体手感微调，**不要单参数走极端**。

```lua
-- ============ 载具物理参数参考值 ============
local topSpeed = 20.0             -- 前进最高速度（推荐 15-25）
local reverseSpeed = 8.0          -- 倒车最高速度（推荐 5-10）
local acceleration = 15.0         -- 前进加速度（推荐 10-20）
local reverseAcceleration = 10.0  -- 倒车加速度（推荐 8-15）
local accelerationCurve = 4.0     -- 加速曲线（起步猛 / 极速平缓；推荐 2-5）
local braking = 25.0              -- 刹车减速度（推荐 20-35）
local coastingDrag = 5.0          -- 松油门滑行阻力（越大滑行距离越短；推荐 3-8）
local turnSpeed = 120.0           -- 转向速度（度/秒；推荐 90-150）
local grip = 0.95                 -- 转向咬合度（0-1；地面 0.9-1.0，水面 0.6-0.8，悬浮 0.5-0.7）
local DEAD_ZONE = 0.1             -- 摇杆死区

-- ============ 5 大调校系统参数 ============
local tunedMass = 1200.0
local tunedDrag = 3.0
local tunedAngularDrag = 6.0
local tunedCenterOfMass = CS.UnityEngine.Vector3(0, -0.45, 0)  -- 重心下移防翻车
local maxAngularVelocity = 4.5

local minHighSpeedSteerScale = 0.42   -- 高速转向衰减最小比例
local sidewaysFriction = 8.0          -- 侧向摩擦力
local tiltSafetyStart = 12.0          -- 侧翻保护起始角度
local maxTiltAssistAngle = 25.0
local emergencyStabilityBrake = 14.0

local yawStability = 2.4
local pitchRollDamping = 7.5
local uprightAssist = 4.2
local tiltAssistStart = 4.0
```

**成组调整提示**：`mass = 100` + `drag = 10`、`mass = 5000` + `drag = 0.5` 都会破坏驾驶手感（前者一开就"卡住"油门无效，后者一撞就飞、刹不住）。

---

## 六、5 大调校完整代码

以下 5 个系统在通用 Rigidbody 驱动范式之上，为载具提供更真实的驾驶手感。**用于贴地 / 贴水面 / 悬浮载具；飞行载具不使用**（详见 [飞行载具-Lua](./飞行载具-Lua.md)）。

### 6.1 刚体参数调校（`applyRigidbodyTuning`）

在 `Start()` 中获取 Rigidbody 后 + `FixedUpdate()` 每帧开头，都要调用一次。重心下移是防翻车的关键。

```lua
local function applyRigidbodyTuning(body)
  if body == nil then return end
  body.mass = tunedMass
  body.drag = tunedDrag
  body.angularDrag = tunedAngularDrag
  body.centerOfMass = tunedCenterOfMass
  body.maxAngularVelocity = maxAngularVelocity
end
```

### 6.2 高速转向衰减

车速越高，转向灵敏度越低，防止高速时轻轻一推摇杆就失控。

```lua
local horizontalSpeed = CS.UnityEngine.Vector3(body.velocity.x, 0, body.velocity.z).magnitude
local speedRatio = 0
if topSpeed > 0.0001 then
  speedRatio = CS.UnityEngine.Mathf.Clamp01(horizontalSpeed / topSpeed)
end
local steerScale = CS.UnityEngine.Mathf.Lerp(1.0, minHighSpeedSteerScale, speedRatio * speedRatio)
local turningPower = turnInput * turnSpeed * dt * steerScale
```

### 6.3 侧向摩擦力（`dampSidewaysSlip`）

抑制车身横向滑动，让载具更贴地。高速时阻尼更强。

```lua
local function dampSidewaysSlip(horizontalVelocity, speedRatio, dt)
  local right = self.transform.right
  local lateralSpeed = CS.UnityEngine.Vector3.Dot(horizontalVelocity, right)
  local dampingStrength = CS.UnityEngine.Mathf.Lerp(
    sidewaysFriction, sidewaysFriction * 1.35, speedRatio)
  local correction = lateralSpeed * CS.UnityEngine.Mathf.Clamp01(dampingStrength * dt)
  return CS.UnityEngine.Vector3(
    horizontalVelocity.x - right.x * correction,
    0,
    horizontalVelocity.z - right.z * correction
  )
end
```

### 6.4 侧翻保护（`applyTiltSafetyBrake`）

当车身倾斜超过安全角度时自动减速，模拟真实物理中即将侧翻时的速度衰减。

```lua
local DEG_TO_RAD = math.pi / 180

local function getTiltAngles()
  local euler = self.transform.eulerAngles
  return CS.UnityEngine.Mathf.DeltaAngle(0, euler.x), CS.UnityEngine.Mathf.DeltaAngle(0, euler.z)
end

local function applyTiltSafetyBrake(horizontalVelocity, dt)
  local pitch, roll = getTiltAngles()
  local tiltMagnitude = CS.UnityEngine.Mathf.Max(
    CS.UnityEngine.Mathf.Abs(pitch), CS.UnityEngine.Mathf.Abs(roll))
  if tiltMagnitude <= tiltSafetyStart then
    return horizontalVelocity
  end
  local brakeRatio = CS.UnityEngine.Mathf.Clamp01(
    (tiltMagnitude - tiltSafetyStart) / CS.UnityEngine.Mathf.Max(1.0, maxTiltAssistAngle - tiltSafetyStart))
  return CS.UnityEngine.Vector3.MoveTowards(
    horizontalVelocity,
    CS.UnityEngine.Vector3.zero,
    emergencyStabilityBrake * brakeRatio * dt
  )
end
```

### 6.5 角速度稳定与扶正辅助（`stabilizeAngularMotion`）

对刚体的角速度做分轴处理：pitch/roll 方向强阻尼防止晃动，yaw 方向根据是否在转向动态调整阻尼。车身倾斜超过扶正介入角度时施加反向角速度扶正。

```lua
local function stabilizeAngularMotion(body, turnInput, speedRatio, dt)
  if body == nil then return end
  local localAngular = self.transform:InverseTransformDirection(body.angularVelocity)
  local pitch, roll = getTiltAngles()

  local pitchRollDampingT = CS.UnityEngine.Mathf.Clamp01(pitchRollDamping * dt)
  local yawDampingT = CS.UnityEngine.Mathf.Clamp01(yawStability * dt * (0.6 + speedRatio * 0.8))
  if math.abs(turnInput) > DEAD_ZONE then
    yawDampingT = yawDampingT * 0.35   -- 转向时降低 yaw 阻尼
  end

  local correctedX = CS.UnityEngine.Mathf.Lerp(localAngular.x, 0, pitchRollDampingT)
  local correctedY = CS.UnityEngine.Mathf.Lerp(localAngular.y, 0, yawDampingT)
  local correctedZ = CS.UnityEngine.Mathf.Lerp(localAngular.z, 0, pitchRollDampingT)

  -- 扶正辅助：倾斜越大回正力越强
  local tiltMagnitude = CS.UnityEngine.Mathf.Max(
    CS.UnityEngine.Mathf.Abs(pitch), CS.UnityEngine.Mathf.Abs(roll))
  if tiltMagnitude > tiltAssistStart then
    local tiltRatio = CS.UnityEngine.Mathf.Clamp01(
      (tiltMagnitude - tiltAssistStart) / CS.UnityEngine.Mathf.Max(1.0, maxTiltAssistAngle - tiltAssistStart))
    local assistT = CS.UnityEngine.Mathf.Clamp01(tiltRatio * dt * 4.0)
    correctedX = CS.UnityEngine.Mathf.Lerp(correctedX, -pitch * DEG_TO_RAD * uprightAssist, assistT)
    correctedZ = CS.UnityEngine.Mathf.Lerp(correctedZ, -roll * DEG_TO_RAD * uprightAssist, assistT)
  end

  local correctedWorld = self.transform:TransformDirection(
    CS.UnityEngine.Vector3(correctedX, correctedY, correctedZ))
  body.angularVelocity = CS.UnityEngine.Vector3.ClampMagnitude(correctedWorld, maxAngularVelocity)
end
```

---

## 七、常见坑 FAQ

| 现象 | 违反约束 | 修复 |
| --- | --- | --- |
| 载具高速一打方向盘就甩尾失控 | 漏 §三 第 3 步 高速转向衰减 | 加 `steerScale` 计算 |
| 侧翻后车倒地不起 | 漏 §三 第 7 / 10 步 侧翻保护与扶正辅助 | 两者都加 |
| 车头总是抖动 / 不稳 | 漏 §三 第 10 步 `stabilizeAngularMotion` | 加分轴角速度阻尼 |
| 停放载具被玩家走路推开 / 长时间偏离原位 | §一 #4（`mass` 与玩家同量级或 `drag` 过低） | 按 §二 表格量级把 `mass` 拉到 700–1500、`drag` 拉到 1.5–4；静态配置与 `applyRigidbodyTuning` **两处一致** |
| 提了 mass 后载具起步慢得开不动 | 单参数走极端；未同步调 `drag` 或加速度 | 参考 §二 量级，成组调整 |
| 载具间相撞时被撞的车纹丝不动 | `drag` 过高（>5）或 `angularDrag` 过高（>10） | 压回 §二 推荐值 |

通用刚体运动的坑（Y 轴被覆盖、Kinematic 未判、W/S 双轴等）见 [Rigidbody-驱动-Lua](../物理/Rigidbody-驱动-Lua.md) 与 [Rigidbody-接触施力-Lua](../物理/Rigidbody-接触施力-Lua.md) 骨架末尾的常见坑 FAQ。

**介质专属坑**：车 / 船在空中漂浮 / 下坡卡顿、船只漂离水面、悬浮载具 PD 震荡、飞行载具摇杆前进就抬头等——分别见 [地面载具-Lua](./地面载具-Lua.md) / [水面载具-Lua](./水面载具-Lua.md) / [悬浮载具-Lua](./悬浮载具-Lua.md) / [飞行载具-Lua](./飞行载具-Lua.md) 的 § 常见坑 FAQ。

---

### 跨语言适用性

- Lua / C# 通用：4 条硬约束（§一）、10 步顺序（§三）、mass·drag 量级（§二）、4 类介质差异（§四）
- Lua 专属细节：矩阵 / 四元数用 `*` 运算符（不能 `op_Multiply`）；调用形如 `CS.UnityEngine.Rigidbody`
- C# 直接暴露同名 API，无 XLua 限制
- **本手册目前仅提供 Lua 侧代码骨架**（无 C# 骨架）

---

## 相关模板

- [地面载具-Lua](./地面载具-Lua.md) —— 四轮车 / 卡丁车 / 越野车 / 骑行生物完整闭环
- [水面载具-Lua](./水面载具-Lua.md) —— 船 / 水上摩托 / 浮筏完整闭环
- [悬浮载具-Lua](./悬浮载具-Lua.md) —— 悬浮滑板 / 悬浮摩托 / 气垫船完整闭环
- [飞行载具-Lua](./飞行载具-Lua.md) —— 飞碟 / 直升机 / 飞行扫帚完整闭环（**不使用本模块 5 大调校**）
