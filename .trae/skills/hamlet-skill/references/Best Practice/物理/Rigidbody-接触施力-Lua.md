# Rigidbody 接触施力（Lua）最佳实践

> 💡 **理论与机制指引**：关于被动接受力（球 / 推箱 / 弹球）的实体碰撞单一入口、冷却语义、实体 Collider 与可选交互 Trigger 的分工、本地物理不套主权门禁，请参考手册规则文档：[刚体运动控制约束](../../Manual/%E2%85%A2.%20%E9%80%BB%E8%BE%91%E4%B8%8E%E8%84%9A%E6%9C%AC(Logic%26Scripting)/%E7%BC%96%E7%A0%81%E7%BA%A6%E6%9D%9F%E4%B8%8E%E5%BC%80%E5%8F%91%E8%A7%84%E8%8C%83/%E5%88%9A%E4%BD%93%E8%BF%90%E5%8A%A8%E6%8E%A7%E5%88%B6%E7%BA%A6%E6%9D%9F.md)、[碰撞与触发器规范](../../Manual/%E2%85%A2.%20%E9%80%BB%E8%BE%91%E4%B8%8E%E8%84%9A%E6%9C%AC(Logic%26Scripting)/%E7%BC%96%E7%A0%81%E7%BA%A6%E6%9D%9F%E4%B8%8E%E5%BC%80%E5%8F%91%E8%A7%84%E8%8C%83/%E7%A2%B0%E6%92%9E%E4%B8%8E%E8%A7%A6%E5%8F%91%E5%99%A8%E8%A7%84%E8%8C%83.md) 与 [刚体与运动模型](../../Manual/%E2%85%A0.%20%E6%A0%B8%E5%BF%83%E7%B3%BB%E7%BB%9F(Core)/%E7%89%A9%E7%90%86/%E5%88%9A%E4%BD%93%E4%B8%8E%E8%BF%90%E5%8A%A8%E6%A8%A1%E5%9E%8B.md)。
> 本文仅提供接触施力在 Lua 侧的标准代码骨架 + 场景变体。

> **硬边界**：门 / 柜门 / 衣柜 / 钟摆 / 拉杆 / 机关 / 宝箱等普通可操作物，即使需求写成"玩家靠近后打开 / 关闭 / 启动"，也不属于本文；它们必须走通用交互按钮闭环。

---

## 0. 前置选型

本骨架只适用于“动态刚体被动接受力”的对象。接入前先确认：

- 对象确实需要被碰撞或外力推动；纯视觉、静态环境和静态 Trigger 不要添加 Rigidbody。
- Rigidbody 必须配置 `isKinematic=false`，并至少有一个 `isTrigger=false` 的实体 Collider。
- `useGravity` 按对象是否需要自然下落决定；关闭重力时必须由其它明确运动模型接管高度。
- `mass`、`drag`、`angularDrag` 和初始重力状态由资源配置维护，脚本只在接触入口调用 AddForce/AddTorque。
- 需要靠近拾取或操作时另配 Interaction Trigger；Trigger 只负责交互生命周期，不参与同一接触的施力。

---

## 1. 状态变量（脚本顶部）

```lua
local KICK_COOLDOWN = 0.1  -- 秒；只用于防"同一物理瞬间多次回调"，不做长期状态锁
local KICK_FORCE = 8.0     -- 冲量大小（配合静态配置里的 mass）
local KICK_UP_BOOST = 0.3  -- 略微向上的分量，让球飞起来（可选）

local rb = nil
local lastKickTime = -999
```

---

## 2. Start 缓存 Rigidbody

```lua
function Start()
  -- 优先 root，找不到再递归子级
  rb = self.gameObject:GetComponent(typeof(CS.UnityEngine.Rigidbody))
  if rb == nil then
    rb = self.gameObject:GetComponentInChildren(typeof(CS.UnityEngine.Rigidbody))
  end
  if rb == nil then
    print("[contact-force] Rigidbody not found on " .. self.gameObject.name)
    -- warning 但不静默 return；允许其它模块继续
  end

  -- 如需限制最大自旋，Start 一次性配置；不要在 FixedUpdate 每帧写
  -- if rb ~= nil then rb.maxAngularVelocity = 20 end
end
```

---

## 前置硬约束：Hamlet 回调组件归属

在进入下面的施力代码前，先确认承载 Lua 的 `DouyinScript` 与触发该回调的 Trigger/实体 `Collider` 位于同一个 `GameObject`。当前 Hamlet runtime 不会把子节点 Collider 产生的 `OnActorTriggerEnter` / `OnActorCollisionEnter` 自动转发给父节点脚本；“脚本在 root、Trigger 在 child”会表现为 Unity 物理可能存在，但 Hamlet Actor 回调没有日志、业务不进入。

这条是 Hamlet 回调绑定约束，不是 Unity 原生复合碰撞约束：Rigidbody 仍可放在根节点，Lua 也可以沿层级查找 Rigidbody；但回调脚本不能依赖父子节点自动冒泡。推荐将回调所需的 `DouyinScript` 和对应 Collider 放在同一节点，视觉 Mesh 可放在子节点。

## 3. 单一入口施力（`OnActorCollisionEnter`）

```lua
function OnActorCollisionEnter(actor)
  -- 接触施力不套 isLocal / isNetworkSettled / HasOwnership 门禁；只做 nil guard
  if actor == nil or rb == nil then return end

  -- 冷却只防同一物理瞬间连发
  local now = CS.UnityEngine.Time.time
  if now - lastKickTime < KICK_COOLDOWN then return end
  lastKickTime = now

  -- 方向：从玩家指向球，让球远离玩家；y 加一点向上分量
  local playerPos = actor.gameObject.transform.position
  local ballPos = self.transform.position
  local dir = ballPos - playerPos
  dir.y = 0                                            -- 先取水平方向
  dir = dir.normalized + CS.UnityEngine.Vector3.up * KICK_UP_BOOST

  -- 一次性 Impulse，方向让球远离玩家
  rb:AddForce(dir * KICK_FORCE, CS.UnityEngine.ForceMode.Impulse)

  -- 可选：加一点自旋
  -- rb:AddTorque(CS.UnityEngine.Vector3(0, KICK_FORCE * 0.3, 0), CS.UnityEngine.ForceMode.Impulse)
end
```

---

## 4. 物理属性静态配置

在目标对象 的 属性面板 中配置动态 Rigidbody 属性，建议初始值为 `mass=0.4`、`drag=0.05`、`angularDrag=0.15`、`Use Gravity=true`、`Is Kinematic=false`。根据物体重量和玩法手感调整这些值，不要在 Lua 启动后重复覆盖已经确定的静态配置。

为对象保留至少一个 `isTrigger=false` 的实体 Collider。如果还需要靠近拾取或交互入口，再额外添加一个 `isTrigger=true` 的 Trigger Collider。实体 Collider 负责 `OnActorCollisionEnter` 接触施力，Trigger 只负责 `OnActorTriggerEnter/Exit` 交互生命周期。

防顶飞需要使用 `Props(6)` 时，按 [Collider-Layer 与碰撞矩阵](./Collider-Layer%E4%B8%8E%E7%A2%B0%E6%92%9E%E7%9F%A9%E9%98%B5-Lua.md) 在 `Start` 中递归设置 Layer。交互 Trigger 的范围只比实体包围盒略大即可；范围过大会导致 Enter/Exit 抖动，并使交互位置与物体脱节。

---

## 4.1 双 Collider 配置验收

接入接触施力前，先确认资源拓扑：

| 检查项 | 预期 |
| --- | --- |
| `Rigidbody` | 存在，且按被动接受力模型配置为动态刚体 |
| 实体 Collider | 至少一个 `isTrigger=false`，负责撞地、撞墙和 `OnActorCollisionEnter` |
| 交互 Trigger | 只有需要靠近拾取/操作时才配置 `isTrigger=true`，负责 `OnActorTriggerEnter/Exit` |
| Hamlet 回调归属 | `DouyinScript` 与产生目标 Actor 回调的 Collider 同节点 |
| 入口去重 | 同一冲量不同时接入 Collision 和 Trigger，也不把 Enter 与 Stay 叠加 |

两个典型反例：

- Play Mode 后掉到地下：通常是只有 Trigger，缺少 `isTrigger=false` 实体 Collider，或实体 Collider 未命中地面 Layer。
- 物理正常但无法交互：通常是缺少 `isTrigger=true` Interaction Trigger，Trigger 未覆盖靠近范围，或脚本与 Trigger 不在同一 `GameObject`。

---

## 5. 场景变体

### 5.1 冰球 / 低摩擦滑动

调整静态参数：`drag = 0.02`（更低阻尼），`angularDrag = 0.05`；`Vector3.up * 0` 关掉上跳分量，让球贴地滑。

### 5.2 可推箱 / 重物

调整静态参数：`mass = 5.0`（提高质量），`drag = 0.5`（大阻尼），`useGravity = true`。`KICK_FORCE` 也相应提高（比如 20）。

### 5.3 一击必打飞的道具

`KICK_FORCE = 30`；不需要冷却（或 `KICK_COOLDOWN = 0.5` 防单帧多回调）。

### 5.4 需要"精准踢"的场景（点击按钮踢）

**改变入口，不叠加**。放弃 `OnActorCollisionEnter` 自动施力，改用按钮闭环 + `OnInteractorButtonClick` 里施力。**不要**在同一个脚本里同时保留两种施力入口；若对象还需要拾取范围，Trigger 仍可独立用于交互。

---

## 6. 常见坑 FAQ

| 现象 | 违反约束 | 修复 |
| --- | --- | --- |
| 玩家碰球被弹飞 / 顶飞 | 未做单一碰撞入口，且没有把球设 `Props(6)` 防带飞 | 单一 `OnActorCollisionEnter` + 走 Layer 分类设 `Props(6)` |
| 球踢不动 | 在 `FixedUpdate` 每帧压速度或参数极端叠加 | 删掉 `FixedUpdate` 里的 clamp；静态参数成组调整 |
| 一次接触触发 3–5 次冲量 | Collision 与 Trigger 双入口，或 Enter + Stay 重复接入 | 只保留 `OnActorCollisionEnter` 作为接触施力入口 |
| 单机或网络未 settled 时球不动 | 接触施力被 `HasOwnership` 之类门禁挡住 | 接触施力不走主权 |
| 物体运动失控 / 参数失效 | `velocity` 与 `AddForce` 混写，两种驱动模型相互覆盖 | 选一种模型；接触施力用 AddForce |
| 动态物体 Play 后掉到地下 | 缺少实体 `isTrigger=false` Collider，或地面 Layer/矩阵不匹配 | 补实体 Collider，检查 `useGravity` 和 Layer；不要只调 mass |
| 物理正常但靠近没有交互 | 缺少 `isTrigger=true` Interaction Trigger，或脚本不在 Trigger 同节点 | 补 Trigger 并校验 Hamlet 回调组件归属 |
| 关闭重力后球不落地 | `useGravity=false` 但没有其它高度/运动模型 | 恢复重力，或明确由脚本接管垂直运动 |
