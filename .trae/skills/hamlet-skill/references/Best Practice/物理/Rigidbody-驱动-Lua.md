# Rigidbody 驱动（Lua）最佳实践

> 💡 **理论与机制指引**：关于主动驱动 vs 被动接受力两种运动模型的选择、12 条通用硬约束、W/S 双轴消费、水平限速的剥离 y 技巧、载具专属手感，请参考手册规则文档：[刚体运动控制约束](../../Manual/%E2%85%A2.%20%E9%80%BB%E8%BE%91%E4%B8%8E%E8%84%9A%E6%9C%AC(Logic%26Scripting)/%E7%BC%96%E7%A0%81%E7%BA%A6%E6%9D%9F%E4%B8%8E%E5%BC%80%E5%8F%91%E8%A7%84%E8%8C%83/%E5%88%9A%E4%BD%93%E8%BF%90%E5%8A%A8%E6%8E%A7%E5%88%B6%E7%BA%A6%E6%9D%9F.md) 与 [刚体与运动模型](../../Manual/%E2%85%A0.%20%E6%A0%B8%E5%BF%83%E7%B3%BB%E7%BB%9F(Core)/%E7%89%A9%E7%90%86/%E5%88%9A%E4%BD%93%E4%B8%8E%E8%BF%90%E5%8A%A8%E6%A8%A1%E5%9E%8B.md)。
> 本文仅提供**主动驱动**（`FixedUpdate` 里持续写 `rb.velocity` / `rb:MoveRotation`）在 Lua 侧的通用范式代码骨架。

---

## 0. 前置选型

本骨架只适用于“脚本主动驱动”的动态对象。接入前先确认：

- 对象确实需要移动或被脚本驱动；纯视觉、静态环境和静态 Trigger 不要为了使用脚本而添加 Rigidbody。
- 使用 `rb.velocity` 的动态主动驱动必须配置 `isKinematic=false`，并至少有一个实体 Collider。
- 使用 `rb:MovePosition` / `rb:MoveRotation` 的运动学对象应配置 `isKinematic=true`，不要在同一脚本继续写 velocity 或 AddForce。
- `mass`、`drag`、`angularDrag`、初始 `useGravity` 和 `centerOfMass` 由资源配置维护。
- 需要靠近交互时，额外配置 `isTrigger=true` 的 Interaction Trigger；Trigger 不能替代实体 Collider。

---

## 1. 状态变量（脚本顶部）

```lua
local rb = nil
local moveVec = CS.UnityEngine.Vector2.zero  -- 若由玩家输入驱动
```

---

## 2. Start 缓存 Rigidbody

```lua
function Start()
  rb = self.gameObject:GetComponent(typeof(CS.UnityEngine.Rigidbody))
  -- 静态刚体参数（重心 / mass / drag 等）优先在资源配置文件里维护，Lua 不覆写
end
```

---

## 3. FixedUpdate 主结构

```lua
function FixedUpdate()
  -- 前置守卫：kinematic 时直接返回
  if rb == nil then return end
  if moveVec == nil then return end            -- 若由玩家输入驱动
  if rb.isKinematic then return end            -- Kinematic 不允许直接写 velocity

  local dt = CS.UnityEngine.Time.fixedDeltaTime
  local DEAD_ZONE = 0.1

  -- 输入双轴消费：同时读 moveVec.x 与 moveVec.y（非输入驱动的场景跳过）
  local accelInput = 0
  if math.abs(moveVec.y) > DEAD_ZONE then accelInput = moveVec.y end
  local turnInput = 0
  if math.abs(moveVec.x) > DEAD_ZONE then turnInput = moveVec.x end

  -- 计算水平 forward（只取水平分量，避免物体抬起时推力产生向上分量）
  local fwd = self.transform.forward
  local horizontalForward = CS.UnityEngine.Vector3(fwd.x, 0, fwd.z)
  if horizontalForward.sqrMagnitude > 0.0001 then
    horizontalForward:Normalize()
  else
    return
  end

  -- 转向走 MoveRotation，避免直写 transform.rotation
  local turnSpeed = 100                        -- 具体值由业务定义
  if math.abs(turnInput) > DEAD_ZONE then
    local turnAngle = CS.UnityEngine.Quaternion.Euler(0, turnInput * turnSpeed * dt, 0)
    -- XLua 环境用 * 运算符，禁止 op_Multiply
    rb:MoveRotation(self.transform.rotation * turnAngle)
  end

  -- 业务计算目标水平速度（具体公式由业务定义）
  local moveSpeed = 5
  local targetHorizontalVel = horizontalForward * (accelInput * moveSpeed)

  -- 水平限速：剥离 y 后对 XZ 分量限速
  if targetHorizontalVel.magnitude > moveSpeed then
    targetHorizontalVel = CS.UnityEngine.Vector3.ClampMagnitude(targetHorizontalVel, moveSpeed)
  end

  -- 写回速度时保留 rb.velocity.y，避免覆盖重力/跳跃
  rb.velocity = CS.UnityEngine.Vector3(
    targetHorizontalVel.x,
    rb.velocity.y,                             -- 保留重力 y 分量
    targetHorizontalVel.z
  )
end
```

---

## 4. 常见应用参考

以下场景只需要本骨架：

| 场景 | 说明 |
| --- | --- |
| 追踪玩家的敌人 NPC | `FixedUpdate` 里根据玩家位置计算 direction，写 velocity 让敌人朝玩家移动 |
| 剧情驱动的机关升降台 | `FixedUpdate` 里根据剧情状态在两点间用 `rb:MoveRotation` + `velocity` 驱动 |
| 玩家遥控的无人机 / 遥控模型 | 本骨架 + 输入监听消费 `moveVec` |
| 追踪导弹 | `FixedUpdate` 里根据目标位置更新 velocity 方向 |

**判定规则**：物体是**主动移动**（每帧写 velocity）还是**被动接受力**（一次性 AddForce）？前者走本骨架，后者走 [Rigidbody-接触施力-Lua](./Rigidbody-%E6%8E%A5%E8%A7%A6%E6%96%BD%E5%8A%9B-Lua.md)。

---

## 5. 常见坑 FAQ

| 现象 | 违反约束 | 修复 |
| --- | --- | --- |
| 物体在空中漂浮 / 下坡卡顿 / 无重力 | 写回 velocity 时覆盖了 y 轴，或限速用了含 y 的向量 | 写回时保留 `rb.velocity.y`；限速用剥离 y 的水平向量 |
| 一打方向盘就失去动力卡死 | XLua 环境用了 `op_Multiply` 而不是 `*` 运算符 | 用 `*` 运算符 |
| 物理引擎报错 / velocity 写入无效 | 没有判 `isKinematic`，对 Kinematic 刚体写 velocity | 加 `if rb.isKinematic then return end` |
| 物体运动失控 / 参数失效 | `velocity` 与 `AddForce` 混写，主动驱动模型不唯一 | 选一种模型；主动驱动用 velocity |
| 转向抖动 / 穿墙 | 直写 `transform.rotation` 绕过物理，导致渗透 | 用 `rb:MoveRotation(quaternion)` |
| W/S 前进 / 倒车不生效但 A/D 转向可以 | 只消费 `moveVec.x`，没有消费 `moveVec.y` | 同时消费 `moveVec.y` |
| WASD 有采样但实体不动 / 转向抖一下就复原 | 同帧内既直写 `transform.position/rotation` 又写 velocity，双方互相覆盖 | 删除所有 `self.transform.position/rotation =` 直写，只走 `rb.velocity` + `rb:MoveRotation` |
| 编辑器改 `mass` 无效 | Lua 里运行期覆写了 rigidbody 参数，覆盖资源配置 | 通过资源配置文件维护，Lua 不 override |
| 动态对象 Play 后掉到地下 | 缺少实体 `isTrigger=false` Collider，或地面 Layer/矩阵不匹配 | 补实体 Collider，检查 `useGravity`、Layer 和初始位置；不要只调 mass |
| 物理正常但靠近没有交互 | 缺少 `isTrigger=true` Interaction Trigger，或脚本不在 Trigger 同节点 | 补 Trigger 并校验 Hamlet 回调组件归属 |
| 关闭重力后对象悬浮失控 | `useGravity=false` 但没有脚本高度控制 | 恢复重力，或补齐 Raycast/PD/三轴运动模型 |
