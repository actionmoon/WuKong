# 飞行载具（Lua）最佳实践

> 💡 **前置阅读**：先读 [载具通用物理-Lua](./载具通用物理-Lua.md)（4 条载具补充硬约束、10 步 FixedUpdate 顺序、mass·drag 量级、4 类介质差异摘要）。飞行虽不套 5 大调校，但通用手感的 mass·drag 量级和 attributes 一致性仍适用。

> ⚠️ **飞行载具与地面 / 水面 / 悬浮硬约束方向相反**——不保留 y、脚本完整接管三轴姿态、不做 5 大调校、`useGravity` 在 `enterFlight` 里关闭。

> ⚠️ **适用范围**：本文的 `mass ≥ 500` 数值常量、12 条独有硬约束、`enterFlight` / `exitFlight` 契约跨 Lua / C# 都适用；`UIType.CustomMain / CustomSub` 与 `SetupActionButton` 属抖音 UGC runtime SDK 概念（Lua / C# 通用）；`meta.json.attributes` schema、`static-mod-agent` 前置、`assets/*.lua` 唯一事实源、`__FILL_*__` 占位符、`pi-*.lua` binding 规则、归档自检、`tunedMass / tunedDrag` 一致性约束仅在 ai-world-creator 的 AI-authoring 流程（`player-interaction-agent`）中生效。UGC SDK 手写场景可按项目约定自行维护。

---

## 一、介质定义与决策树

**飞行介质**：完全脱离重力自由三轴。覆盖飞碟 / 直升机 / 飞行摩托 / 战斗机 / 飞行扫帚 / 飞毯等**完全脱离重力、玩家能控制 Y 升降**的载具。

---

## 二、独有硬约束（12 条）

1. **前置守卫** `if not hasPassenger or rb == nil then return end`——无乘客时脚本不接管，走原生重力。
2. **完整覆盖 `rb.velocity` 三轴**（不保留 y）——脚本接管全部速度。
3. **每帧 `rb:MoveRotation(Quaternion.Euler(m_pitch, m_yaw, m_roll))` 重写完整 Quaternion**——姿态由脚本三个 euler 变量维护。
4. **`OnSeatEntered` 调用 `enterFlight()`**：关重力 / 矫正姿态 / 清角速度。
5. **`OnSeatExited` 调用 `exitFlight()`**：还原 `useGravity` / 允许自由落体。
6. **同时按上升 + 下降视为抵消**（`verticalIntent = 0`），全部松开由 `idleDamping` 自然收敛。
7. **升降必须同时挂两条通路**：右下角按钮（`UIType.CustomMain` / `CustomSub`） + 键盘 E / Q，`or` 合并（见 § 4.2）。
8. **摇杆 / 升降都不输入时用 `idleDamping` 自然减速**，不硬归零——保持悬浮飘感。
9. **禁用** `Rigidbody.constraints` 锁 X / Z 旋转——会盖掉 `MoveRotation`。
10. **禁写** `transform.rotation` / `transform.position` 直写——破坏刚体状态一致性。
11. **XLua 用 `*` 运算符**——`Quaternion.op_Multiply` 崩帧（继承通用硬约束）。
12. **姿态 pitch 唯一驱动源 = `verticalIntent`**：`targetPitch = -verticalIntent * maxPitchAngle`（上升抬头、下降低头）。摇杆 `moveVec.y` 只驱动水平位移和 roll，**不得**参与 pitch 计算。

### 2.1 飞行载具 Collider / Trigger 验收

飞行载具要把“是否需要实体碰撞”与“是否需要上机交互”分开决策：

- 上机/下机和靠近按钮需要 `isTrigger=true` 的 Interaction Trigger；Root-bound 脚本优先让它与 Root `DouyinScript` 同节点。
- 如果飞行器需要撞墙、停机坪接触或被玩家实体推动，配置至少一个 `isTrigger=false` 的实体 Collider。
- 如果飞行器设计为完全无实体接触的悬停物体，可以不配置实体接地 Collider，但必须明确该设计，并同步检查 `useGravity/isKinematic` 与 `enterFlight/exitFlight` 生命周期。
- 只有实体 Collider 不会产生 `OnActorTriggerEnter/Exit`；只有 Trigger 也不会提供地面支撑。两条职责不能互相替代。
- Play Mode 至少验证：静态停放状态不意外下坠；上机按钮能出现；上机后飞行控制正常；下机后的重力和实体接触符合设计。

---

## 三、数值常量

- `mass ≥ 500`、`drag ≥ 1.0`。
- 飞行载具姿态由脚本 `MoveRotation` 全接管，`mass` 拉高对驾驶姿态无副作用，仅影响停放态的抗推能力和 `exitFlight` 后自由落体的下落速度（drag=1.5 时下落时间与 drag=0.8 差别 <15%）。

---

## 四、专属机制

### 4.1 `enterFlight` / `exitFlight` 钩子契约

**`enterFlight()`**（`OnSeatEntered` 触发）：

- 设置 `rb.useGravity = false`
- 读取当前 `transform.eulerAngles` 初始化 `m_pitch / m_yaw / m_roll`
- 设置 `rb.angularVelocity = Vector3.zero`
- 首帧**不写** `rb.velocity`（避免瞬间加速）

**`exitFlight()`**（`OnSeatExited` 触发）：

- 设置 `rb.useGravity = true`
- 保留当前 velocity 让载具自由落体 / 惯性飞行
- 姿态由 `angularDrag` 自然稳定

### 4.2 双通路升降（键盘 E/Q + `UIType.CustomMain`/`CustomSub`）

飞行载具的升降**必须同时挂两条输入通路**，缺一不可：

1. **右下角按钮通路**（移动端主通道）：`UIType.CustomMain` = 上升、`UIType.CustomSub` = 下降；`EventTrigger.PointerDown/Up` 驱动 `btnAscend`/`btnDescend`。右下角操作按钮的 API 与生命周期（`SetupActionButton` / `HideButton` / `ClearTrigger`）见 [交互按钮体系 § 四 右下角操作按钮](../../Manual/Ⅱ.%20界面与交互(UI)/交互按钮体系.md)。
2. **键盘 E/Q 通路**（PC 兼容）：E = 上升、Q = 下降。

**合并**：`computeVerticalIntent()` 里 `or` 合并——`up = btnAscend or Input.GetKey(KeyCode.E)`、`down = btnDescend or Input.GetKey(KeyCode.Q)`。同时按上升 + 下降返回 `0`；全部松开由 `idleDamping` 自然收敛。

**移动端 vs PC 端**：移动端交付无键盘、缺按钮 = 玩家无法升降；PC 端调试无按钮、缺键盘 = 开发不便。两条并存互不干扰。

### 4.3 5 大调校启用状态对照（飞行是特例）

| 调校 | 飞行是否启用 |
| --- | --- |
| 刚体调校 `applyRigidbodyTuning` | ⚠️ **只保留** `maxAngularVelocity` 限速，其它不套 |
| 高速转向衰减 | ❌ 不适用（三轴自由，不做地面式 turn scale） |
| 侧向摩擦力 | ❌ 不适用 |
| 侧翻保护 | ❌ 不适用（飞行需要 pitch / roll 自由） |
| 角速度稳定 | ⚠️ 仅在 `idleDamping` 场景下做温和阻尼 |

### 4.4 姿态动画开关

| 开关 | 说明 | 典型变体 |
| --- | --- | --- |
| `enablePitch` | 前进 / 上升时前倾 / 后仰 | 直升机 / 战斗机 = `true` |
| `enableRoll` | 转向时侧倾 | 战斗机 / 飞行摩托 = `true` |
| 两者都 `false` | 悬停飞碟——仅 yaw 旋转 | 飞碟 / UFO |
| 只 `enablePitch = true` | 轿车型飞行——保持水平 | 飞行客车 |

---

## 五、`meta.json.attributes` 要求

```json
{
  "": {
    "trigger": {
      "shape": "box",
      "size": [2.0, 1.4, 3.6],
      "center": [0, 0.5, 0]
    },
    "rigidBody": {
      "mass": 700,
      "drag": 1.5,
      "angularDrag": 4.0,
      "useGravity": true,
      "isKinematic": false,
      "centerOfMass": [0, 0, 0]
    },
    "collider": {
      "enable": true,
      "includeChildren": true
    },
    "layer": {
      "id": 9,
      "includeChildren": true
    }
  },
  "<seatAnchorPath>": {
    "interaction": {
      "kind": "Seat"
    }
  }
}
```

**关键**：

- **`useGravity = true` 静态设置** —— 脚本在 `enterFlight` 里改成 `false`；`exitFlight` 还原为 `true` 让载具在无人时自然下落。
- `centerOfMass` 保持 `[0, 0, 0]`（飞行姿态由脚本控制，无需重心偏移）。
- `drag` 拉高（1.5）—— 无人时空气阻力 + 停放态抗玩家推挤。
- `mass ≥ 500`、`drag ≥ 1.0` 硬性数值常量见 [§ 三 数值常量](#三数值常量)。

---

## 六、子模板路由

| 子模板 | 覆盖 | 完整 Lua 引用 |
|---|---|---|
| **飞行器** | 飞碟 / 直升机 / 飞行扫帚 / 飞毯 / 战斗机 | Read [assets/飞行器.lua](./assets/飞行器.lua) → Write 到 `pi-flight.lua` |

---

## 七、虚拟锚点要求（static-mod-agent 前置）

生成 `pi-flight.lua` 前，`static-mod-agent` 必须为飞行载具模型确认或新增以下 anchor 虚拟节点：

| Anchor | 作用 | targetPath 示例 |
|---|---|---|
| `SeatAnchor` | 玩家上机后 SetParent 挂载点 | `Body/Cockpit/SeatAnchor` |
| `StandUpAnchor`（可选） | 玩家下机的安全落点 | `Body/Cockpit/StandUpAnchor` |

**规则**：

- anchor 必须是**独立虚拟节点**（不含 MeshRenderer）。
- `StandUpAnchor` 缺省时脚本使用载具右侧偏移作为下机点；**注意**空中下机后玩家会自由落体（这是玩法一部分，不做安全兜底）；若需着陆才允许下机，请在 `OnInteractorButtonClick` 加高度判定。
- 飞行载具的 `Rigidbody.useGravity` 静态设为 `true`；脚本会在 `enterFlight` / `exitFlight` 里切换。

**双通路升降 authoring 要求**（机制说明见 [§ 4.2 双通路升降](#42-双通路升降键盘-eq--uitypecustommaincustomsub)）：

1. **右下角按钮通路**（移动端主通道）：`OnSeatEntered → showFlightActionButtons()` 调用 `SetupActionButton(UIType.CustomMain, "上升", onDown, onUp)` 与 `UIType.CustomSub`。`onDown` 只设 `btnAscend`/`btnDescend = true`，`onUp` 清零；工具函数完整实现见 [基础交互/右下角操作按钮-Lua.md](../基础交互/右下角操作按钮-Lua.md)。
2. **键盘 E/Q 通路**（PC 兼容）：`E` = 上升、`Q` = 下降。

**生命周期**：`OnSeatEntered → showFlightActionButtons()`；`OnSeatExited / OnDestroy / OnDisable → hideFlightActionButtons()`。`hideFlightActionButtons` 必须清 EventTrigger 并重置 `btnAscend / btnDescend = false`，避免下一个玩家上机时按住前次玩家绑定的旧 handler。完整参考：[assets/飞行器.lua](./assets/飞行器.lua) 的 `showFlightActionButtons` / `hideFlightActionButtons` / `computeVerticalIntent` 段。

**禁止调用 `self:AddBottomRightButton` / `self:RemoveBottomRightButton`**：这两个 SDK 方法在当前抖音 UGC runtime 下实测不存在（`attempt to call a nil value (method 'AddBottomRightButton')`），且抛错会发生在 `OnSeatEntered → enterDriving` 内部，导致 `alignActorHipsToSeat` 与 `seatedActors[actor] = ...` 全部被跳过，玩家原地坐姿、载具单独飞走。**正确通道** = `SetupActionButton(UIType.CustomMain / CustomSub, ...)`。

---

## 八、使用步骤

1. Read [assets/飞行器.lua](./assets/飞行器.lua) 全文。
2. Write 到 `assets/module/<resource-id>/scripts/pi-flight.lua`。
3. 替换 `__FILL_*__` 占位符（见 § 九）。
4. 根据变体设置 `enablePitch` / `enableRoll` 开关（4 种变体见 [§ 4.4 姿态动画开关](#44-姿态动画开关)）。
5. 落 `meta.json.attributes`（按 § 五）。
6. 归档前自检（见 § 十）。

---

## 九、占位符清单

| 占位符 | 说明 | 推荐值 |
|---|---|---|
| `__FILL_SEAT_ANCHOR_PATH__` | 座位锚点 targetPath | `get_glb_nodes` |
| `__FILL_TOP_SPEED__` | 水平最高速度 | 20-40 |
| `__FILL_ASCEND_SPEED__` | 升降速度 | 6-15 |
| `__FILL_PITCH_ENABLE__` | 是否启用前倾 | `true` / `false` |
| `__FILL_ROLL_ENABLE__` | 是否启用侧倾 | `true` / `false` |

---

## 十、禁止改动清单 & 归档前自检

**禁止改动**：

- `enterFlight` / `exitFlight` 钩子实现
- `m_pitch` / `m_yaw` / `m_roll` 三轴维护逻辑
- E/Q 键盘接管升降
- `useGravity` 的开关时机
- **禁止把飞行载具拆成 `ms-*.lua` + `pi-*.lua` 双脚本协作**。主旋翼 / 尾桨旋转、机身震动、灯光闪烁、螺旋桨自转等"自运动 / 程序动画"必须合入本模板 `pi-flight.lua`。`OnActorTriggerEnter → EnableInteraction → OnFocus → AddInteractorButton → SitDown` 的交互握手闭环由 `pi-flight.lua` 独占
- **`pi-flight.lua` 的 binding targetPath 必须为 `""`（root binding）**。禁止改绑到 `SeatAnchor` / `DriverSeatAnchor` / `Cockpit` 等子节点
- **`attributes[""]` 是飞行载具 `trigger` 的唯一挂点**；`SeatAnchor` 只允许写 `interaction: { kind: "Seat" }`

**归档前自检**：

- [ ] `enterFlight` 在 `OnSeatEntered` 里调用（关重力 + 清角速度）
- [ ] `exitFlight` 在 `OnSeatExited` 里调用（还原 `useGravity`）
- [ ] E / Q 键盘升降双路径都能工作
- [ ] 升降**同时**挂 `UIType.CustomMain` / `UIType.CustomSub` 按钮 **和** 键盘 E / Q 两条通路；`OnSeatEntered → showFlightActionButtons`、`OnSeatExited / OnDestroy / OnDisable → hideFlightActionButtons` 均已调用；`hideFlightActionButtons` 内 `clearTrigger` 并把 `btnAscend / btnDescend` 归零
- [ ] 姿态 pitch 唯一驱动源 = `verticalIntent`：`targetPitch = -verticalIntent * maxPitchAngle`。全脚本 `grep -n "forwardInput.*pitch\|moveVec\.y.*pitch\|forwardInput.*maxPitchAngle"` 结果为空
- [ ] 松开摇杆时载具**自然减速悬停**，不会硬归零
- [ ] 无 `transform.rotation` / `transform.position` 直写（与 `rb.velocity` 并存即违规，见 [Rigidbody-驱动-Lua](../物理/Rigidbody-驱动-Lua.md)）
- [ ] 无 `Rigidbody.constraints` 锁旋转
- [ ] `Quaternion.op_Multiply` 全部替换为 `*`
- [ ] 所有占位符已替换
- [ ] `scripts/**` 下**只有一份 `pi-flight.lua`**，没有额外的 `ms-*.lua` / `pi-driver.lua` / `pi-proximity.lua` 分身；旋翼旋转、机身震动都在 `pi-flight.lua` 内部实现
- [ ] `pi-flight.lua` 位于 `scripts/pi-flight.lua`（root binding，父目录为空）；不在 `scripts/**/SeatAnchor/` 等子目录下
- [ ] `meta.json.attributes` 里 `""` 有 `trigger`，`SeatAnchor` 只有 `interaction: { kind: "Seat" }` —— 没有第二份 `trigger`
- [ ] `mass ≥ 500` 且 `drag ≥ 1.0`
- [ ] 停放抗推验证：飞行载具停在地面 / 停机坪，玩家步行推挤 10 秒位移应 <0.3 米；两架同型号飞行载具低空对撞时静止一方能被撞开 1-3 米
- [ ] `grep -n "AddBottomRightButton\|RemoveBottomRightButton" pi-flight.lua` 无结果（该 SDK 方法实测不存在）
- [ ] `OnSeatEntered` 的 `if actor.isLocal` 分支走的是 `removeInteractionButton() → self:EnableInteraction() → ensureInteractionButton()`，**没有** `self:DisableInteraction()`；否则上机后下机按钮永远不弹（见 [基础交互/座位系统-Lua.md § 十一 硬约束 #14](../基础交互/座位系统-Lua.md)）

---

## 十一、常见坑 FAQ

| 现象 | 违反约束 | 修复 |
| --- | --- | --- |
| 飞行载具"摇杆前进就抬头" | § 二 #12（`forwardInput` 误参与 pitch 计算） | pitch 唯一驱动源 = `verticalIntent` |
| 飞行载具移动端无法升降 | § 二 #7（缺右下角按钮通路） | 挂 `UIType.CustomMain` / `CustomSub`，回调只设标志位 |
| 飞行载具下机后原地翻滚 | § 二 #9（用 `Rigidbody.constraints` 锁旋转） | 删 constraints，姿态由 `MoveRotation` 管 |
| 飞行载具停机坪被玩家推走 | § 三（`mass` 与玩家同量级） | 拉到 `mass ≥ 500` |

通用载具坑（甩尾 / 车头抖动 / 停放被推走 / mass 起步慢）见 [载具通用物理-Lua § 七](./载具通用物理-Lua.md)。

---

### 跨语言适用性

- 本文硬约束跨 Lua / C# 都适用
- **本手册目前仅提供 Lua 侧代码骨架**（无 C# 骨架）

---

## 实现参考

- Lua 实现：[assets/飞行器.lua](./assets/飞行器.lua)（飞行器 assets 引用、`meta.json.attributes`、`enterFlight` / `exitFlight` 钩子、双通路升降、`__FILL_*__` 占位符）
- 相关规则：[载具通用物理-Lua](./载具通用物理-Lua.md)（虽然飞行不套 5 大调校，但 mass / drag 量级和 attributes 一致性仍适用）
