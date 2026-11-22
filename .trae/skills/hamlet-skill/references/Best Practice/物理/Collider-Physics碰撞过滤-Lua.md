# Physics 碰撞过滤（Lua）最佳实践

> 💡 **理论与机制指引**：关于碰撞过滤优先级（pair-wise 首选、Layer-based 兜底、IgnoreRaycast 常见误区）、有限重试与阻塞判断、保留 trigger 触发信号，请参考手册规则文档：[碰撞与触发器规范](../../Manual/%E2%85%A2.%20%E9%80%BB%E8%BE%91%E4%B8%8E%E8%84%9A%E6%9C%AC(Logic%26Scripting)/%E7%BC%96%E7%A0%81%E7%BA%A6%E6%9D%9F%E4%B8%8E%E5%BC%80%E5%8F%91%E8%A7%84%E8%8C%83/%E7%A2%B0%E6%92%9E%E4%B8%8E%E8%A7%A6%E5%8F%91%E5%99%A8%E8%A7%84%E8%8C%83.md) 与 [碰撞体与触发器](../../Manual/%E2%85%A0.%20%E6%A0%B8%E5%BF%83%E7%B3%BB%E7%BB%9F(Core)/%E7%89%A9%E7%90%86/%E7%A2%B0%E6%92%9E%E4%BD%93%E4%B8%8E%E8%A7%A6%E5%8F%91%E5%99%A8.md)。
> 本文仅提供碰撞过滤在 Lua 侧的标准代码骨架 + 场景变体。

---

## 1. 状态变量

```lua
local RETRY_INTERVAL = 0.5  -- 重试间隔（秒）
local MAX_RETRY_COUNT = 6   -- 最大重试次数（3 秒后阻塞）

local targetObjectName = "TargetObject"  -- 目标场景对象名称
local ignorePairsDone = false
local retryCount = 0
```

---

## 2. pair-wise IgnoreCollision helper

```lua
-- 获取一个 GameObject 子树内的所有实体 Collider（排除 trigger）
local function collectSolidColliders(root)
  local result = {}
  if root == nil then return result end
  local cols = root:GetComponentsInChildren(typeof(CS.UnityEngine.Collider))
  if cols ~= nil then
    for i = 0, cols.Length - 1 do
      local col = cols[i]
      if col ~= nil and not col.isTrigger then
        result[#result + 1] = col
      end
    end
  end
  return result
end

-- 逐对忽略两个物体的实体碰撞；保留双方的 trigger 触发信号
local function ignoreCollisionBetween(rootA, rootB)
  local colsA = collectSolidColliders(rootA)
  local colsB = collectSolidColliders(rootB)
  if #colsA == 0 or #colsB == 0 then return false end

  for _, a in ipairs(colsA) do
    for _, b in ipairs(colsB) do
      CS.UnityEngine.Physics.IgnoreCollision(a, b, true)
    end
  end
  return true
end
```

---

## 3. 有限重试发现对方资源

```lua
-- 尝试按已配置的名称找到目标场景对象
local function tryFindTarget()
  local target = CS.UnityEngine.GameObject.Find(targetObjectName)
  if target == nil then return nil end
  return target.transform
end

local function tryApplyIgnorePairs()
  if ignorePairsDone then return end
  local target = tryFindTarget()
  if target == nil then
    retryCount = retryCount + 1
    if retryCount >= MAX_RETRY_COUNT then
      -- 无法稳定发现另一方 → 阻塞并在完成说明里标未完成，不降级
      print("[collision-filtering] target not found: '" .. targetObjectName .. "', retries=" .. retryCount)
      return
    end
    -- 有限重试（下一个间隔再试）
    return
  end

  if ignoreCollisionBetween(self.transform, target) then
    ignorePairsDone = true
    print("[collision-filtering] pairs applied to " .. targetObjectName)
  end
end

function Start()
  tryApplyIgnorePairs()
end

-- 有限重试：Update 里按间隔重试，达到 MAX_RETRY_COUNT 或成功后停止
local elapsed = 0
function Update()
  if ignorePairsDone or retryCount >= MAX_RETRY_COUNT then return end
  elapsed = elapsed + CS.UnityEngine.Time.deltaTime
  if elapsed >= RETRY_INTERVAL then
    elapsed = 0
    tryApplyIgnorePairs()
  end
end
```

---

## 4. 场景变体

### 4.1 只过滤“挡板与球门门框”，保留“足球与挡板”

目标碰撞关系：

```
挡板 ↔ 球门门框: ignore
足球 ↔ 挡板: collide (保留)
足球 ↔ 球门门框: collide (保留)
```

只对第一 pair 调 `ignoreCollisionBetween(挡板root, 球门门框root)`；其它 pair 不动。

### 4.2 抑制"玩家 ↔ 足球"硬挤反作用，保留实体接触施力与交互 Trigger 信号

- 球的实体 collider 走 [Collider-Layer与碰撞矩阵-Lua](./Collider-Layer%E4%B8%8E%E7%A2%B0%E6%92%9E%E7%9F%A9%E9%98%B5-Lua.md) 设 `Props(6)` → 玩家踩地检测穿过，实体碰撞仍在但不会顶飞；`OnActorCollisionEnter` 仍可作为接触施力入口。
- 如果对象还需要拾取或靠近交互，独立的大 sphere Trigger 保留 `OnActorTriggerEnter/Exit` 入口；它只负责交互生命周期，不重复施加接触冲量。
- **不用** `Physics.IgnoreCollision(球, 玩家胶囊)` —— `IgnoreCollision` 会同时屏蔽 trigger 与实体碰撞。

### 4.3 未明确目标碰撞关系但当前交互依赖 Trigger

只保留本对象的必要配置：

- 在 属性面板 中配置 Trigger 和实体 Collider。
- 不调用跨对象 `IgnoreCollision`。
- 明确记录尚未确定需要忽略碰撞的对象组合。

### 4.4 双 Collider 与过滤边界

碰撞过滤只处理“哪些实体 Collider pair 不参与求解”，不负责创建缺失的物理或交互入口：

- `isTrigger=false` 实体 Collider 仍是撞地、撞墙和 `OnActorCollisionEnter` 的来源。
- `isTrigger=true` Interaction Trigger 仍是 `OnActorTriggerEnter/Exit` 的来源。
- `Physics.IgnoreCollision` 的实体 Collider 遍历不能被误解为“添加 Trigger”；过滤完成后仍要独立检查交互 Trigger 是否存在。
- 不要通过关闭所有实体 Collider 来解决玩家无法交互，也不要通过只保留 Trigger 来解决物体穿地。

---

## 5. 验证

- 目标对象存在时，确认指定的实体 Collider pair 已忽略碰撞。
- 目标对象缺失时，确认有限重试结束后不再轮询。
- 双方的 Trigger 仍能触发进入和退出回调。
- 未指定的对象组合仍保持原有碰撞关系。

---

## 6. 常见坑 FAQ

| 现象 | 违反约束 | 修复 |
| --- | --- | --- |
| 用 `IgnoreLayerCollision(6, 8)` 关球 vs 玩家 | 全局层过滤会误伤同层其他对象，粒度过粗 | pair-wise `Physics.IgnoreCollision(球 col, 玩家 col)` |
| 关掉玩家 vs 球后踢球触发也失效 | 未区分实体 Collider 与 Trigger，`IgnoreCollision` 把 Trigger 也一并关掉 | trigger 走 `isTrigger = true` 的 Collider，不参与 `IgnoreCollision` 逐对遍历 |
| 找不到对方 collider 时降级为"只过滤事件不实际过滤碰撞" | 事件过滤只掩盖回调，物理接触仍生效，等于没过滤 | 阻塞标记，不降级 |
| 无限轮询 target 直到发现 | 缺少上限，遇到目标不存在会永久轮询 | 有限重试（如 6 次）后阻塞 |
| 用 `SetLayer(2)`（IgnoreRaycast）代替 `IgnoreCollision` | `IgnoreRaycast` 只影响射线，不影响求解器接触，无法实现 pair-wise 过滤 | `IgnoreRaycast` 不能替代实体过滤 |
| 过滤后 Play 仍掉到地下 | 资源没有实体 `isTrigger=false` Collider | 补实体 Collider，并确认地面 Layer 与碰撞矩阵 |
| 过滤后无法靠近交互 | 资源没有独立 Interaction Trigger，或脚本不在 Trigger 同节点 | 补 `isTrigger=true` Trigger，并校验 Hamlet 回调组件归属 |
