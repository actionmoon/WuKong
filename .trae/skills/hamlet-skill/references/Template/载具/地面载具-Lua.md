# 地面载具（Lua）最佳实践

> 💡 **前置阅读**：先读 [载具通用物理-Lua](./载具通用物理-Lua.md)（4 条载具补充硬约束、10 步 FixedUpdate 顺序、mass·drag 量级、4 类介质差异摘要、5 大调校完整代码）。

> ⚠️ **适用范围**：本文的 `mass ≥ 1000` 数值常量、6 条独有硬约束、Motion API 8 挂载接口契约跨 Lua / C# 都适用；`meta.json.attributes` schema、`static-mod-agent` 前置、`assets/*.lua` 唯一事实源、`__FILL_*__` 占位符、`pi-*.lua` binding 规则、归档自检等内容以及 `ms-root.lua` 挂载接口的具体命名（`SetMountedMoveIntent` 等）仅在 ai-world-creator 的 AI-authoring 流程（`player-interaction-agent`）中生效。UGC SDK 手写场景可根据项目脚手架自行维护 rig 结构与静态配置。

---

## 一、介质定义与决策树

**地面介质**：贴地行驶，靠重力接地。覆盖四轮车（汽车 / 卡丁车 / 越野车 / rally / 皮卡 / 摩托）与骑行生物（马 / 龙 / 鱼 / 兽骑）两大子模板。

**判断标准**（"玩家在哪里？"）：需要脚下有地面 / 会翻车 / 有重力接地 → **地面**介质。

**特例**：飞行生物骑行（龙 / 飞鹰 / 翼兽）**仍归为地面介质下的骑行生物子模板**，通过 `controlProfile = "flying"` + `allowVerticalControl = true` 实现空中飞行，与飞行介质（飞碟 / 直升机）的骨架**互斥不叠加**。

---

## 二、独有硬约束（6 条）

1. **`rb.velocity` 保留 y 轴**：`rb.velocity = Vector3(newX, rb.velocity.y, newZ)`——地面载具靠重力贴地；覆盖 y 会让车"飘"。
2. **静态 `useGravity = true` + `isKinematic = false`**：车辆必须受物理驱动。
3. **5 大调校全部启用**：刚体调校 / 高速转向衰减 / 侧向摩擦 / 侧翻保护 / 角速度稳定，缺一不可（防翻车 + 手感）。
4. **`grip` 推荐 0.9 – 1.0**：地面咬合最强。
5. **Layer 处理**：走载具专用层（`meta.layer.id = 9`），或整棵子树 `SetLayer(0)` 让玩家能站上去。参考 [Collider-规则](../../Manual/Ⅰ.%20核心系统(Core)/物理/Collider-规则.md)。
6. **座位对齐**：走 `seat-alignment` 的 Hips 校正（详见 [座位系统-规则](../基础交互/座位系统-规则.md)）。

### 2.1 地面载具 Collider / Trigger 验收

地面载具依靠重力接地，必须同时区分物理支撑与靠近交互：

- `Rigidbody` 为动态刚体时，至少有一个 `isTrigger=false` 的实体 Collider 与地面接触；车轮、底盘或车身可使用复合实体 Collider。
- 上车/骑乘按钮另需 `isTrigger=true` 的 Interaction Trigger；它只负责 `OnActorTriggerEnter/Exit`，不能替代车轮/底盘实体 Collider。
- Root-bound Lua 脚本若实现 `OnActorTriggerEnter/Exit`，交互 Trigger 优先放 Root；子节点实体 Collider 共享 Root Rigidbody 只解决 Unity 物理，不会让 Hamlet Actor 回调自动冒泡。
- Play Mode 至少验证：车辆不穿地、玩家靠近出现“上车/骑乘”、离开清理按钮、实体 Collider 与子节点 Layer 均正确。

---

## 三、数值常量

- `mass ≥ 1000`、`drag ≥ 2.5` 是硬性数值常量。`applyRigidbodyTuning` 每帧会用统一的 `tunedMass / tunedDrag` 覆盖 `meta.json.attributes` 里的值；attributes 里的 `mass` / `drag` 必须与模板 CONFIG 的 `tunedMass` / `tunedDrag` 保持一致，否则运行时刚体状态会在两个值之间跳变。
- **骑行生物例外**：由于没有实体 Rigidbody 驱动（走 Motion API handoff），本条不适用；若仍想避免"骑行生物停在原地被玩家推走"，请把 rig 的 `isKinematic` 保持默认（由 `ms-root.lua` 生命周期管理）。

---

## 四、专属机制

### 4.1 子模板：四轮车 vs 骑行生物

| 子模板 | 判断依据 |
| --- | --- |
| **四轮车** | 有 wheel 骨骼 / 4 个 wheel pivot 需要 spin+steer 动画 |
| **骑行生物** | 有 mounted motion API（`ms-root.lua` 暴露 8 个挂载接口） |

**注**：骑行生物子模板**没有实体 Rigidbody 驱动**（走 Motion API handoff），因此 § 二 #1 / #2 里的 rb.velocity 直写与 useGravity 约束**不适用**；改由 `ms-root.lua` 生命周期管理。

### 4.2 骑行生物 Motion API 契约（8 挂载接口）

骑行生物模板**不自己写物理驱动**，而是通过 Motion API 与 `ms-root.lua` 握手，让 motion-state 侧接管移动、朝向、跳跃、垂直控制。`ms-root.lua` 必须暴露 8 个挂载接口：

| 方法 | 参数 | 说明 |
| --- | --- | --- |
| `SetMountedRider(actor)` | `actor: DouyinActor` | 传入当前 rider；motion-state 侧接管其骨骼动画 |
| `ClearMountedRider()` | 无 | 卸下 rider；motion-state 侧还原独立漫游状态 |
| `SetMountedMoveIntent(forward, strafe)` | `forward, strafe: number` | 前后 / 侧向意图（本模板只传 `forward`，`strafe` 恒 0） |
| `SetMountedMoveMode(mode)` | `mode: "idle" \| "walk" \| "run" \| "back"` | 动作状态机切换 |
| `SetMountedTurnIntent(x)` | `x: number` | 转向意图（`moveVec.x` 直传） |
| `SetMountedJumpIntent(shouldJump)` | `shouldJump: bool` | 仅 `land` profile 消费 |
| `SetMountedVerticalIntent(vertical)` | `vertical: -1 / 0 / +1` | 仅 `allowVerticalControl = true` 时消费（`flying` / `fish`） |
| `RefreshMountedGrounding(force)` / `ClearMountedGroundingState()` | `force: bool` | `land` profile 上马后必须调一次 refresh 让地面检测归零 |

### 4.3 骑行生物 Profile 差异（陆 / 海 / 空三档）

| Profile | `controlProfile` | `allowVerticalControl` | 跳跃（Space） | 垂直控制（E/Q） | 典型生物 |
| --- | --- | --- | --- | --- | --- |
| **陆** | `"land"` | `false` | ✅ 通过 `SetMountedJumpIntent` | ❌ | 马 / 兽骑 / 步行 NPC |
| **海** | `"fish"` | `true` | ❌ | ✅ 通过 `SetMountedVerticalIntent` | 鱼 / 海豚 / 鲸 |
| **空** | `"flying"` | `true` | ❌ | ✅ 通过 `SetMountedVerticalIntent` | 龙 / 飞鹰 / 翼兽 |

**关键差异**：

- 只有 `land` profile 上马后调 `RefreshMountedGrounding(true)`——水中 / 空中生物不需要地面检测。
- 海 / 空 profile 的 seat fallback 用**背面**（`directionScale = -1`），`land` 用**前面**。
- 座位对齐（`seat-alignment`）会自动跑 pelvis 探测；若模型没有 `pelvis` / `Pelvis` 骨骼会有 warn。

### 4.4 相机 Yaw 跟随内置行为

地面载具默认启用 yaw-only 相机跟随：

- 玩家坐上车后，`LateUpdate` 逐步把相机 yaw 移向 `self.transform.eulerAngles.y`。
- 通过 `DouyinCameraService.GetYaw()` + `SetYaw(currentYaw + step)` + `Mathf.DeltaAngle` 处理 0/360 度回绕。
- 玩家手动 look（`onLookInput*`）时暂停跟随，`cameraAlignGrace` 秒后恢复。
- **只改 yaw**，不改相机 position / pitch / distance / offset / FOV。

需要 FOV / pitch / distance 等其他相机属性时，见 [相机视角控制](../../Manual/Ⅰ.%20核心系统(Core)/玩家网络对象/相机控制/相机视角控制.md)。

---

## 五、`meta.json.attributes` 要求

```json
{
  "": {
    "trigger": {
      "shape": "box",
      "size": [2.4, 1.9, 5.2],
      "center": [0, 0.75, 0]
    },
    "rigidBody": {
      "mass": 1200,
      "drag": 3.0,
      "angularDrag": 6.0,
      "useGravity": true,
      "isKinematic": false,
      "centerOfMass": [0, -0.45, 0]
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

- `size` 必须**按当前载具实际包围盒**填写（`get_preview_module_bounding_box` / `get_glb_nodes`），不要照抄默认。
- 骑行生物的 `size` 视骨架体型调整（马 ≈ `[1.4, 1.9, 3.0]`）。
- `centerOfMass` 下移防翻车；骑行生物略微上移到 `[0, 0.0, 0]`。
- `mass` / `drag` 硬性数值常量见 [§ 三 数值常量](#三数值常量)。

---

## 六、子模板路由

| 子模板 | 判断依据 | 完整 Lua 引用 |
|---|---|---|
| **四轮车** | 有 wheel 骨骼 / 4 个 wheel pivot 需要 spin+steer 动画 | Read [assets/四轮车.lua](./assets/四轮车.lua) → Write 到 `pi-vehicle.lua` |
| **骑行生物** | 有 mounted motion API（`ms-root.lua` 暴露 8 个挂载接口） | Read [assets/骑行生物.lua](./assets/骑行生物.lua) → Write 到 `pi-mount.lua` |

> **assets/*.lua 是唯一事实源**——本 md 只描述硬约束与 meta 要求，代码实现在外部 lua 文件中，由 IDE / Lua Language Server 校验。

---

## 七、虚拟锚点要求

### 7.1 四轮车专属（static-mod-agent 前置）

生成 `pi-vehicle.lua` 前，`static-mod-agent` 必须为车辆模型确认或新增以下 anchor 虚拟节点：

| Anchor | 作用 | targetPath 示例 |
|---|---|---|
| `SeatAnchor` | 玩家上车后 SetParent 挂载点 | `Body/SeatAnchor` |
| `StandUpAnchor`（可选） | 玩家下车时的安全落点 | `Body/StandUpAnchor` |
| 4 个 `WheelPivot` | 车轮 spin + steer 视觉节点 | `Body/Wheels/FrontLeft` 等 |

**规则**：

- anchor 必须是**独立虚拟节点**(不含 MeshRenderer)，不能直接挂到车轮 mesh 节点。
- `StandUpAnchor` 缺省时脚本使用车辆右侧偏移作为下车点；模型带安全下车节点时改成对应 targetPath。

### 7.2 骑行生物专属

| Anchor | 作用 | 备注 |
|---|---|---|
| `RideInteractRoot`（可选） | 座位 / 上车按钮挂载父节点 | 缺省时挂到 root |
| `SeatAnchor/Seat`（推荐） | 座位精确位置 | 缺省时脚本从 pelvis + bounds 推断 fallback |
| `StandUpAnchor`（可选） | 下车安全落点 | 缺省时保留原世界位置 |

**说明**：座位对齐（`seat-alignment`）会自动跑 pelvis 探测；若模型没有 `pelvis` / `Pelvis` 骨骼会有 warn，需要 `static-mod-agent` 补节点。

---

## 八、使用步骤

1. **判断子模板**：看嵌套模型是否有 4 个 wheel pivot / mounted motion API → 决定走"四轮车"或"骑行生物"。
2. **Read 子模板 lua**：完整读取 `assets/{子模板}.lua`。
3. **Write 到目标脚本**：`assets/module/<resource-id>/scripts/pi-*.lua`。
4. **替换占位符**：见 § 九。
5. **落 `meta.json.attributes`**：按 § 五 填写实际包围盒 + rigidBody 参数。
6. **归档前自检**：见 § 十。

---

## 九、占位符清单

**四轮车专属**：

| 占位符 | 说明 | 来源 |
|---|---|---|
| `__FILL_SEAT_ANCHOR_PATH__` | 座位锚点 targetPath | `get_glb_nodes` |
| `__FILL_FRONT_LEFT_WHEEL_PATH__` | 左前轮 pivot | 同上 |
| `__FILL_FRONT_RIGHT_WHEEL_PATH__` | 右前轮 pivot | 同上 |
| `__FILL_REAR_LEFT_WHEEL_PATH__` | 左后轮 pivot | 同上 |
| `__FILL_REAR_RIGHT_WHEEL_PATH__` | 右后轮 pivot | 同上 |

**骑行生物专属**：

| 占位符 | 说明 | 来源 |
|---|---|---|
| `__FILL_SEAT_ANCHOR_PATH__` | 骑乘锚点 targetPath | `get_glb_nodes` |
| `__FILL_MOTION_ROOT_SCRIPT_PATH__` | `ms-root.lua` 的相对路径 | 项目脚本目录 |

---

## 十、禁止改动清单 & 归档前自检

**禁止改动**：

- `-- BEGIN TEMPLATE CONFIG` / `-- END TEMPLATE CONFIG` 之外的物理调校常量（`accelerationCurve` / `emergencyStabilityBrake` / `yawStability` / `pitchRollDamping` / `uprightAssist` / `maxAngularVelocity`）
- 5 大调校函数的实现细节（`applyRigidbodyTuning` / `dampSidewaysSlip` / `applyTiltSafetyBrake` / `stabilizeAngularMotion`）
- `FixedUpdate` 内的 10 步调用顺序
- **四轮车专属**：禁止把车辆拆成 `ms-*.lua` + `pi-*.lua` 双脚本协作。车轮 spin / steer、排气特效、装饰旋转等"自运动 / 程序动画"必须合入本模板 `pi-vehicle.lua`（放在 `Update` 或 `LateUpdate` 里）。`OnActorTriggerEnter → EnableInteraction → OnFocus → AddInteractorButton → SitDown` 的交互握手闭环由 `pi-vehicle.lua` 独占，禁止拆到 `pi-driver.lua` / `pi-proximity.lua` / `pi-root-trigger.lua` / `ms-*.lua` 等副脚本
- **四轮车专属**：`pi-vehicle.lua` 的 binding targetPath 必须为 `""`（root binding）。禁止改绑到 `SeatAnchor` / `DriverSeatAnchor` 等子节点；模板 `Start()` 内 `self.gameObject:GetComponent(typeof(UnityEngine.Rigidbody))` 假设 `self` 就是车体 root，一旦改绑后 rb 取不到，agent 会私自加 `findVehicleRigidbody()` 沿 parent 向上找，属于违规修补
- **四轮车专属**：`attributes[""]` 是车辆 `trigger` 的唯一挂点；`SeatAnchor` 只允许写 `interaction: { kind: "Seat" }`，禁止再叠 `trigger` 的 `shape` / `size` / `center`
- **骑行生物专属例外**：本子模板通过 Motion API 与 `ms-root.lua` 握手是**框架规定**，`ms-root.lua` 只允许暴露 [§ 4.2 骑行生物 Motion API 契约](#42-骑行生物-motion-api-契约8-挂载接口) 列出的 8 个挂载接口；交互握手闭环仍必须整体落在 `pi-mount.lua`，不得再新增第三份 pi 脚本
- **骑行生物专属例外**：`pi-mount.lua` 的 binding targetPath 允许为 `""` 或 `RideInteractRoot` anchor 之一（骑行生物模板本身不消费 root Rigidbody，可自由选择），但**同一资源内只允许挂一处**

**归档前自检**：

- [ ] `pi-*.lua` 顶部有 `-- BEGIN TEMPLATE CONFIG` 边界注释
- [ ] `meta.json.attributes` 的 `size` 已按实际包围盒填写（未沿用默认）
- [ ] 座位 anchor 的 `interaction.kind = "Seat"` 已在正确路径挂载
- [ ] 所有 `__FILL_*__` 占位符已替换（`grep __FILL_` 无输出）
- [ ] 无 `transform.rotation` / `transform.position` 直写（与 `rb.velocity` 并存即违规，见 [Rigidbody-驱动-Lua](../物理/Rigidbody-驱动-Lua.md)）
- [ ] 无 `Quaternion.op_Multiply`（XLua 用 `*`）
- [ ] 车辆能上车 / 下车 / 前进 / 后退 / 转向 / 相机跟随
- [ ] 四轮车 `scripts/**` 下**只有一份 `pi-vehicle.lua`**；车轮旋转、排气特效等自运动都在 `pi-vehicle.lua` 内部实现
- [ ] 四轮车 `pi-vehicle.lua` 位于 `scripts/pi-vehicle.lua`（root binding）
- [ ] 四轮车 `meta.json.attributes` 里 `""` 有 `trigger`，`SeatAnchor` 只有 `interaction: { kind: "Seat" }`
- [ ] 四轮车 `mass ≥ 1000` 且 `drag ≥ 2.5`；attributes 与模板 CONFIG `tunedMass/tunedDrag` 一致
- [ ] 停放抗推验证：玩家静止在四轮车侧面持续 10 秒按 W 顶车，车辆位移应 <0.3 米；两辆同型号车头对撞（一静一动到 topSpeed），静止那辆被撞开 1-3 米（骑行生物不适用本条）
- [ ] 骑行生物 `scripts/**` 下只有 `ms-root.lua` + `pi-mount.lua` 两份脚本
- [ ] 骑行生物 `SeatAnchor` 只有 `interaction: { kind: "Seat" }`，不叠 `trigger`
- [ ] `OnSeatEntered` 的 `if actor.isLocal` 分支走的是 `removeInteractionButton() → self:EnableInteraction() → ensureInteractionButton()`，**没有** `self:DisableInteraction()`；否则上车后下车按钮永远不弹（见 [基础交互/座位系统-Lua.md § 十一 硬约束 #14](../基础交互/座位系统-Lua.md)）

---

## 十一、常见坑 FAQ

| 现象 | 违反约束 | 修复 |
| --- | --- | --- |
| 车在空中漂浮 / 下坡卡顿 | § 二 #1（Y 轴被覆盖） | 写回时保留 `rb.velocity.y` |
| 骑行生物"跳跃无效" | § 4.2（`SetMountedJumpIntent` 只对 `land` profile 消费） | 检查 `controlProfile = "land"` |
| 骑行生物首帧地面检测异常 | § 4.3（`land` profile 上马后未调 `RefreshMountedGrounding(true)`） | `OnSeatEntered` 调用 refresh |

通用载具坑（甩尾 / 侧翻 / 车头抖动 / 停放被推走 / mass 起步慢 / 相撞纹丝不动）见 [载具通用物理-Lua § 七](./载具通用物理-Lua.md)。

---

### 跨语言适用性

- 本文硬约束跨 Lua / C# 都适用
- **本手册目前仅提供 Lua 侧代码骨架**（无 C# 骨架）

---

## 实现参考

- Lua 实现：assets 骨架
  - [assets/四轮车.lua](./assets/四轮车.lua)：四轮车 assets 引用、`meta.json.attributes`、anchor 前置、`__FILL_*__` 占位符替换、归档自检
  - [assets/骑行生物.lua](./assets/骑行生物.lua)：骑行生物 assets 引用、Motion API 握手、`ms-root.lua` 挂载接口
- 相关规则：
  - [载具通用物理-Lua](./载具通用物理-Lua.md)（5 大调校 + 10 步顺序）
  - [座位系统-规则](../基础交互/座位系统-规则.md)（`OnSeatEntered` / `OnSeatExited` / seat-alignment）
