# 水面载具（Lua）最佳实践

> 💡 **前置阅读**：先读 [载具通用物理-Lua](./载具通用物理-Lua.md)（4 条载具补充硬约束、10 步 FixedUpdate 顺序、mass·drag 量级、4 类介质差异摘要、5 大调校完整代码）。

> ⚠️ **适用范围**：本文的 `mass ≥ 1000` 数值常量、7 条独有硬约束、y 阻尼收敛跨 Lua / C# 都适用；`meta.json.attributes` schema、`static-mod-agent` 前置、`assets/*.lua` 唯一事实源、`__FILL_*__` 占位符、`pi-*.lua` binding 规则、归档自检、`tunedMass / tunedDrag` 一致性约束仅在 ai-world-creator 的 AI-authoring 流程（`player-interaction-agent`）中生效。UGC SDK 手写场景可按项目约定自行维护。

---

## 一、介质定义与决策树

**水面介质**：贴水面行驶，y 分量由 y 阻尼收敛或浮力维持。覆盖船 / 快艇 / 冲浪板 / 划艇等**长期停留在水面上、有浮力**的载具。

---

## 二、独有硬约束（7 条）

1. **`rb.velocity` 保留 y 轴**：水面浮力靠 y 分量维持；覆盖 y 会让船"陷"下去。
2. **`useGravity = false` 或 y 阻尼系数拉高**：让 y 方向自然稳定在水面高度，避免持续下沉或反弹。
3. **`grip` 弱化到 0.6 – 0.8**：水面咬合弱，保留漂移感。
4. **`sidewaysFriction` 加强（推荐 10 – 14）**：水阻力大，侧向摩擦拉高避免打滑失控。
5. **高速转向衰减更明显**：船头惯性大，`minHighSpeedSteerScale` 建议压到 **0.3** 左右。
6. **不启用侧翻保护**（`applyTiltSafetyBrake`）：船翻是玩法内容，不自动扶正；把 `tiltSafetyStart` 设成 999 或跳过。
7. **加入 y 阻尼收敛代替重力**：例如 `rb.velocity.y *= (1 - Time.fixedDeltaTime * 2.0)`，避免 y 分量堆积导致"漂离水面"。

---

## 三、数值常量

- `mass ≥ 1000`、`drag ≥ 3.5`——船只 `mass` 与玩家同量级会被日常碰撞持续推离水面停靠位。
- `applyRigidbodyTuning` 每帧会用统一的 `tunedMass / tunedDrag` 覆盖 `meta.json.attributes` 里的值；若船只想更沉（`mass = 1500` / `drag = 4`），需要在**当前脚本的 CONFIG 段**里同时改 `tunedMass` / `tunedDrag`，否则运行时会在两个值之间跳变。

---

## 四、专属机制

### 4.1 y 阻尼收敛代替重力

- 静态 `useGravity = false`，脚本在 `FixedUpdate` 内每帧衰减 y 分量：`rb.velocity.y *= (1 - Time.fixedDeltaTime * yDampCoef)`（推荐 `yDampCoef = 2.0`）。
- 避免 y 分量堆积导致船只逐渐漂离水面；同时不使用重力后天然抑制"陷下水面"。

### 4.2 相机 Yaw 跟随

与地面载具相同（yaw-only + 手动 look 暂停 + `Mathf.DeltaAngle` 回绕）。若无需相机跟随，把 `cameraFollowEnabled = false`。

详细相机 yaw 跟随行为见 [地面载具-Lua § 4.4](./地面载具-Lua.md)。

---

## 五、`meta.json.attributes` 要求

```json
{
  "": {
    "trigger": {
      "shape": "box",
      "size": [1.8, 1.2, 3.2],
      "center": [0, 0.4, 0]
    },
    "rigidBody": {
      "mass": 1500,
      "drag": 4.0,
      "angularDrag": 7.0,
      "useGravity": false,
      "isKinematic": false,
      "centerOfMass": [0, -0.3, 0]
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

- `drag` 更大（4.0 vs 地面 3.0）—— 水阻力。
- `useGravity = false` —— 由脚本 y 阻尼收敛代替重力。
- `size` 必须按实际船体包围盒填写。
- `mass ≥ 1000`、`drag ≥ 3.5` 硬性数值常量见 [§ 三 数值常量](#三数值常量)。

---

## 六、子模板路由

| 子模板 | 覆盖 | 完整 Lua 引用 |
|---|---|---|
| **船** | 小船 / 快艇 / 帆船 / 冲浪板 / 划艇 | Read [assets/船.lua](./assets/船.lua) → Write 到 `pi-boat.lua` |

---

## 七、虚拟锚点要求（static-mod-agent 前置）

生成 `pi-boat.lua` 前，`static-mod-agent` 必须为船体模型确认或新增以下 anchor 虚拟节点：

| Anchor | 作用 | targetPath 示例 |
|---|---|---|
| `SeatAnchor` | 玩家上船后 SetParent 挂载点 | `Hull/SeatAnchor` |
| `StandUpAnchor`（可选） | 玩家下船的安全落点（岸边 / 甲板边缘） | `Hull/StandUpAnchor` |

**规则**：

- anchor 必须是**独立虚拟节点**（不含 MeshRenderer），船头 / 船中 / 船尾都可选，视玩法而定。
- `StandUpAnchor` 缺省时脚本使用船右侧 + Y+0.5m 偏移作为下船点；若可能有玩家掉入水中的风险，务必补节点。

---

## 八、使用步骤

1. Read [assets/船.lua](./assets/船.lua) 全文。
2. Write 到 `assets/module/<resource-id>/scripts/pi-boat.lua`。
3. 替换 `__FILL_*__` 占位符（见 § 九）。
4. 落 `meta.json.attributes`（按 § 五）。
5. 归档前自检（见 § 十）。

---

## 九、占位符清单

| 占位符 | 说明 | 来源 |
|---|---|---|
| `__FILL_SEAT_ANCHOR_PATH__` | 座位锚点 targetPath | `get_glb_nodes` |
| `__FILL_TOP_SPEED__` | 前进最高速度 | 12-20 |
| `__FILL_STEER_SCALE__` | 高速转向压制 | 0.3 左右 |

---

## 十、禁止改动清单 & 归档前自检

**禁止改动**：

- 5 大调校中启用的部分（刚体调校 / 高速转向衰减 / 侧向摩擦 / 角速度稳定）
- y 阻尼收敛的实现（`rb.velocity.y *= (1 - Time.fixedDeltaTime * yDampCoef)`）
- **禁止把水面载具拆成 `ms-*.lua` + `pi-*.lua` 双脚本协作**。桨叶自转、船身摇摆、水花特效、灯光闪烁等"自运动 / 程序动画"必须合入本模板 `pi-boat.lua`（放在 `Update` 或 `LateUpdate` 里）。`OnActorTriggerEnter → EnableInteraction → OnFocus → AddInteractorButton → SitDown` 的交互握手闭环由 `pi-boat.lua` 独占
- **`pi-boat.lua` 的 binding targetPath 必须为 `""`（root binding）**。禁止改绑到 `SeatAnchor` 等子节点
- **`attributes[""]` 是船只 `trigger` 的唯一挂点**；`SeatAnchor` 只允许写 `interaction: { kind: "Seat" }`

**归档前自检**：

- [ ] `useGravity = false` 已在 attributes 落地
- [ ] y 方向不持续下沉 / 不反弹漂离水面
- [ ] `grip` 弱化（0.6-0.8）；`sidewaysFriction` 拉高（10-14）
- [ ] 侧翻保护未启用（船翻是玩法内容）
- [ ] 所有 `__FILL_*__` 占位符已替换
- [ ] `scripts/**` 下**只有一份 `pi-boat.lua`**，没有额外的 `ms-*.lua` / `pi-driver.lua` / `pi-proximity.lua` 分身；船身摇摆等自运动都在 `pi-boat.lua` 内部实现
- [ ] `pi-boat.lua` 位于 `scripts/pi-boat.lua`（root binding，父目录为空）
- [ ] `meta.json.attributes` 里 `""` 有 `trigger`，`SeatAnchor` 只有 `interaction: { kind: "Seat" }` —— 没有第二份 `trigger`
- [ ] `mass ≥ 1000` 且 `drag ≥ 3.5`
- [ ] 全脚本 `grep -n "self.transform.position\s*=\|self.transform.rotation\s*="` 结果为空 —— 不允许直写 transform 与 `rb.velocity` 并存（见 [Rigidbody-驱动-Lua](../物理/Rigidbody-驱动-Lua.md)）
- [ ] 停放抗推验证：玩家游到船只侧面持续 10 秒推挤，船只位移应 <0.3 米；两艘同型号船只水上碰撞时静止一方能被撞开 1-3 米
- [ ] `OnSeatEntered` 的 `if actor.isLocal` 分支走的是 `removeInteractionButton() → self:EnableInteraction() → ensureInteractionButton()`，**没有** `self:DisableInteraction()`；否则上船后下船按钮永远不弹（见 [基础交互/座位系统-Lua.md § 十一 硬约束 #14](../基础交互/座位系统-Lua.md)）

---

## 十一、常见坑 FAQ

| 现象 | 违反约束 | 修复 |
| --- | --- | --- |
| 船在空中漂浮 / 下坡卡顿 | § 二 #1（Y 轴被覆盖） | 写回时保留 `rb.velocity.y` |
| 船只"漂离水面" | § 二 #7（未做 y 阻尼收敛） | 加入 `rb.velocity.y *= (1 - dt * 2.0)` |
| 船翻船不起 | 强启用了侧翻保护 | § 二 #6：`tiltSafetyStart` 设成 999 或跳过 `applyTiltSafetyBrake` |

通用载具坑（甩尾 / 车头抖动 / 停放被推走 / mass 起步慢 / 相撞纹丝不动）见 [载具通用物理-Lua § 七](./载具通用物理-Lua.md)。

---

### 跨语言适用性

- 本文硬约束跨 Lua / C# 都适用
- **本手册目前仅提供 Lua 侧代码骨架**（无 C# 骨架）

---

## 实现参考

- Lua 实现：[assets/船.lua](./assets/船.lua)（船 assets 引用、`meta.json.attributes`、y 阻尼收敛骨架、`__FILL_*__` 占位符）
- 相关规则：[载具通用物理-Lua](./载具通用物理-Lua.md)（5 大调校 + 10 步顺序）
