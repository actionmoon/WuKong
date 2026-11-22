# 悬浮载具（Lua）最佳实践

> 💡 **前置阅读**：先读 [载具通用物理-Lua](./载具通用物理-Lua.md)（4 条载具补充硬约束、10 步 FixedUpdate 顺序、mass·drag 量级、4 类介质差异摘要、5 大调校完整代码）。

> ⚠️ **适用范围**：本文的 `mass ≥ 500` 数值常量、8 条独有硬约束、PD 控制器与 Raycast fallback 跨 Lua / C# 都适用；`meta.json.attributes` schema、`static-mod-agent` 前置、`assets/*.lua` 唯一事实源、`__FILL_*__` 占位符、`pi-*.lua` binding 规则、归档自检、`tunedMass / tunedDrag` 一致性约束仅在 ai-world-creator 的 AI-authoring 流程（`player-interaction-agent`）中生效。UGC SDK 手写场景可按项目约定自行维护。

---

## 一、介质定义与决策树

**悬浮介质**：离地固定高度飘行，y 分量由脚本每帧 Raycast + PD 控制。覆盖悬浮滑板 / 悬浮摩托 / 气垫船 / 悬浮车等**离地固定高度、不落地、不飞高**的载具。

---

## 二、独有硬约束（8 条）

1. **`rb.velocity` 完整覆盖 y 分量**：y 由脚本每帧 Raycast 目标离地高度决定，**不保留原 velocity.y**（与地面 / 水面相反）。
2. **静态 `useGravity = false`**：脚本接管重力 / 悬浮高度。
3. **每帧 Raycast 计算目标 Y** = `groundHitPoint.y + hoverHeight`，`hoverHeight` 常量推荐 **0.6 – 1.2**。
4. **Y 走 PD 控制器**（弹簧 + 阻尼）避免震荡，两个常量 `verticalSpringK` / `verticalDampingC`。
5. **`grip` 弱化到 0.5 – 0.7**：悬浮咬合最弱，明显漂移。
6. **启用侧向压翼**（`enableRoll = true`）：转向时车身侧倾，增强手感。
7. **不启用侧翻保护**（`applyTiltSafetyBrake`）：悬浮姿态完全由脚本控制。
8. **Raycast 无命中时进入 fallback**（悬浮 → 缓降 or 保留最后一次 Y），避免掉出地图。

---

## 三、数值常量

- `mass ≥ 500`、`drag ≥ 1.5`。
- 悬浮姿态由脚本每帧 Raycast + PD 控制器接管，`mass` 拉高后姿态响应基本不受影响；驾驶手感受 `mass` 影响主要体现在加速度上（`acceleration` 参考值针对 `mass ≈ 800` 已 balance）。

---

## 四、专属机制

### 4.1 悬浮高度 PD 控制思路

- **弹簧项**：`error = targetY - currentY`；`springForce = error * verticalSpringK`。
- **阻尼项**：`dampForce = -velocityY * verticalDampingC`。
- 合成后写入 `rb.velocity.y`。

**参数建议**：`verticalSpringK` 60 – 120、`verticalDampingC` 8 – 16。

### 4.2 走水面的额外要求

若悬浮载具需要在水面上飞：

- 水面 collider **必须存在且不是 trigger**——`Physics.Raycast` 能击中。
- 水面 collider 的 Layer **未被 `hoverRaycastLayerMask` 过滤**。
- `hoverRaycastMaxDistance` 需覆盖水面到载具的最大预期距离（默认 5m）。

---

## 五、`meta.json.attributes` 要求

```json
{
  "": {
    "trigger": {
      "shape": "box",
      "size": [1.6, 0.9, 2.4],
      "center": [0, 0.3, 0]
    },
    "rigidBody": {
      "mass": 800,
      "drag": 2.0,
      "angularDrag": 6.0,
      "useGravity": false,
      "isKinematic": false,
      "centerOfMass": [0, -0.2, 0]
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

- `useGravity = false` 强制。
- `angularDrag` 拉高（6.0）—— 悬浮姿态自阻尼。
- 悬浮滑板 `size` 更小（约 `[1.0, 0.3, 1.6]`），气垫船更大。
- `mass ≥ 500`、`drag ≥ 1.5` 硬性数值常量见 [§ 三 数值常量](#三数值常量)。本模板 `acceleration` 参考值针对 `mass ≈ 800` 已 balance。

---

## 六、子模板路由

| 子模板 | 覆盖 | 完整 Lua 引用 |
|---|---|---|
| **悬浮滑板** | 滑板 / 悬浮摩托 / 气垫船 / 悬浮车 | Read [assets/悬浮滑板.lua](./assets/悬浮滑板.lua) → Write 到 `pi-hover.lua` |

---

## 七、虚拟锚点要求（static-mod-agent 前置）

生成 `pi-hover.lua` 前，`static-mod-agent` 必须为悬浮载具模型确认或新增以下 anchor 虚拟节点：

| Anchor | 作用 | targetPath 示例 |
|---|---|---|
| `SeatAnchor` | 玩家上车后 SetParent 挂载点 | `Board/SeatAnchor` |
| `StandUpAnchor`（可选） | 玩家下车的安全落点 | `Board/StandUpAnchor` |

**规则**：

- anchor 必须是**独立虚拟节点**（不含 MeshRenderer）。
- 悬浮载具的 `Rigidbody` 在 root 上，脚本会写 `useGravity = false`；模型层不需要预设该参数（`meta.json.attributes` 已在 § 五 覆盖）。

**走水面的额外要求（可选）**：见 [§ 4.2 走水面的额外要求](#42-走水面的额外要求)。

---

## 八、使用步骤

1. Read [assets/悬浮滑板.lua](./assets/悬浮滑板.lua) 全文。
2. Write 到 `assets/module/<resource-id>/scripts/pi-hover.lua`。
3. 替换 `__FILL_SEAT_ANCHOR_PATH__` / `__FILL_HOVER_HEIGHT__` 等占位符（见 § 九）。
4. 落 `meta.json.attributes`（按 § 五）。
5. 归档前自检（见 § 十）。

---

## 九、占位符清单

| 占位符 | 说明 | 推荐值 |
|---|---|---|
| `__FILL_SEAT_ANCHOR_PATH__` | 座位锚点 targetPath | `get_glb_nodes` |
| `__FILL_HOVER_HEIGHT__` | 离地悬浮高度（米） | 0.6-1.2 |
| `__FILL_VERTICAL_SPRING_K__` | Y 弹簧系数 | 60-120 |
| `__FILL_VERTICAL_DAMPING_C__` | Y 阻尼系数 | 8-16 |

---

## 十、禁止改动清单 & 归档前自检

**禁止改动**：

- Raycast 目标 Y 计算逻辑
- Y 方向 PD 控制器实现
- 通用物理 5 大调校中启用的部分（刚体调校 + 侧向摩擦 + 角速度稳定）
- **禁止把悬浮载具拆成 `ms-*.lua` + `pi-*.lua` 双脚本协作**。喷射尾焰、浮空震动、灯光闪烁、装饰旋转等"自运动 / 程序动画"必须合入本模板 `pi-hover.lua`（放在 `Update` 或 `LateUpdate` 里）。`OnActorTriggerEnter → EnableInteraction → OnFocus → AddInteractorButton → SitDown` 的交互握手闭环由 `pi-hover.lua` 独占
- **`pi-hover.lua` 的 binding targetPath 必须为 `""`（root binding）**。禁止改绑到 `SeatAnchor` 等子节点；模板 `Start()` 内 `self.gameObject:GetComponent(typeof(UnityEngine.Rigidbody))` 假设 `self` 就是载具 root
- **`attributes[""]` 是悬浮载具 `trigger` 的唯一挂点**；`SeatAnchor` 只允许写 `interaction: { kind: "Seat" }`

**归档前自检**：

- [ ] `useGravity = false` 已在 attributes 落地
- [ ] 悬浮高度稳定（无持续下沉 / 上浮 / 震荡）
- [ ] Raycast miss 时有 fallback（不会掉出地图）
- [ ] 侧翻保护未启用（悬浮姿态由脚本控制）
- [ ] `enableRoll = true` —— 转向压翼
- [ ] 所有占位符已替换
- [ ] `scripts/**` 下**只有一份 `pi-hover.lua`**，没有额外的 `ms-*.lua` / `pi-driver.lua` / `pi-proximity.lua` / `pi-root.lua` / `pi-seat.lua` 分身；尾焰、装饰旋转等自运动都在 `pi-hover.lua` 内部实现
- [ ] `pi-hover.lua` 位于 `scripts/pi-hover.lua`（root binding，父目录为空）；不在 `scripts/**/SeatAnchor/` 等子目录下
- [ ] `meta.json.attributes` 里 `""` 有 `trigger`，`SeatAnchor` 只有 `interaction: { kind: "Seat" }` —— 没有第二份 `trigger`
- [ ] `mass ≥ 500` 且 `drag ≥ 1.5`
- [ ] 全脚本 `grep -n "self.transform.position\s*=\|self.transform.rotation\s*="` 结果为空 —— 不允许直写 transform 与 `rb.velocity` 并存（见 [Rigidbody-驱动-Lua](../物理/Rigidbody-驱动-Lua.md)）
- [ ] 停放抗推验证：玩家步行到悬浮载具旁持续 10 秒推挤，载具位移应 <0.3 米；两台同型号载具冲撞时静止一方能被撞开 1-3 米
- [ ] "WASD 无效"回归时禁止再新增键盘采样脚本；先在**唯一**的 `pi-hover.lua` 里 `Debug.Log` 一次 `SetDriveInput(x, y)` 的入参，确认输入通路后再改运动求解
- [ ] `OnSeatEntered` 的 `if actor.isLocal` 分支走的是 `removeInteractionButton() → self:EnableInteraction() → ensureInteractionButton()`，**没有** `self:DisableInteraction()`；否则上车后下车按钮永远不弹（见 [基础交互/座位系统-Lua.md § 十一 硬约束 #14](../基础交互/座位系统-Lua.md)）

---

## 十一、常见坑 FAQ

| 现象 | 违反约束 | 修复 |
| --- | --- | --- |
| 悬浮载具持续下沉 / 上浮 / 震荡 | § 二 #4（未走 PD 控制器） | 用 `verticalSpringK` + `verticalDampingC` PD 求解 |
| 悬浮载具掉出地图 | § 二 #8（Raycast miss 没兜底） | fallback 到"保留最后一次 Y"或缓降 |
| 悬浮载具在水面上失稳 | § 4.2（水面 collider 是 trigger 或被 layerMask 过滤） | 保证水面 collider 不是 trigger + Layer 未被过滤 |

通用载具坑（甩尾 / 车头抖动 / 停放被推走 / mass 起步慢）见 [载具通用物理-Lua § 七](./载具通用物理-Lua.md)。

---

### 跨语言适用性

- 本文硬约束跨 Lua / C# 都适用
- **本手册目前仅提供 Lua 侧代码骨架**（无 C# 骨架）

---

## 实现参考

- Lua 实现：[assets/悬浮滑板.lua](./assets/悬浮滑板.lua)（悬浮滑板 assets 引用、`meta.json.attributes`、Raycast + PD 控制骨架、`__FILL_*__` 占位符）
- 相关规则：[载具通用物理-Lua](./载具通用物理-Lua.md)（5 大调校 + 10 步顺序）
