# Layer 与碰撞矩阵（Lua）最佳实践

> 💡 **理论与机制指引**：关于 Layer 与碰撞矩阵、踩地检测显性二选一（Default `0` vs Props `6`）、递归 SetLayer 硬约束、IgnoreRaycast 常见误区，请参考手册规则文档：[物理对象层级约束](../../Manual/%E2%85%A2.%20%E9%80%BB%E8%BE%91%E4%B8%8E%E8%84%9A%E6%9C%AC(Logic%26Scripting)/%E7%BC%96%E7%A0%81%E7%BA%A6%E6%9D%9F%E4%B8%8E%E5%BC%80%E5%8F%91%E8%A7%84%E8%8C%83/%E7%89%A9%E7%90%86%E5%AF%B9%E8%B1%A1%E5%B1%82%E7%BA%A7%E7%BA%A6%E6%9D%9F.md) 与 [碰撞体与触发器](../../Manual/%E2%85%A0.%20%E6%A0%B8%E5%BF%83%E7%B3%BB%E7%BB%9F(Core)/%E7%89%A9%E7%90%86/%E7%A2%B0%E6%92%9E%E4%BD%93%E4%B8%8E%E8%A7%A6%E5%8F%91%E5%99%A8.md)。
> 本文仅提供 Layer 与碰撞矩阵在 Lua 侧的标准代码骨架 + 场景变体。

---

## 1. 状态变量（脚本顶部）

```lua
local DEFAULT_LAYER = 0  -- 可踩层：踩地检测命中 → 玩家能站上去、被带走
local PROPS_LAYER = 6    -- 物理道具层：踩地检测穿过 → 玩家站不上去、不被顶飞；但仍可踢 / 推
```

---

## 2. 递归设层 helper（两个方向共用）

```lua
-- 把整棵子树设到指定 layer
-- 自由刚体常由多个子碰撞体组成，必须递归；引擎通常只改 root
local function setLayerRecursive(trans, layer)
  if trans == nil then return end
  trans.gameObject:SetLayer(layer)
  for i = 0, trans.childCount - 1 do
    setLayerRecursive(trans:GetChild(i), layer)
  end
end
```

---

## 3. 方向 A：载人移动平台（让玩家被带走）

```lua
function Start()
  -- ...其它初始化（motion、rb、trigger）...

  -- Start 里显性递归 SetLayer 到 Default(0)，避免子碰撞体沿用旧 layer
  setLayerRecursive(self.transform, DEFAULT_LAYER)
end
```

---

## 4. 方向 B：防带飞（球 / 可踢可推道具，禁止玩家站上去）

```lua
function Start()
  -- ...其它初始化（rb 缓存、施力入口注册）...

  -- Start 里显性递归 SetLayer 到 Props(6)，防止踩地检测命中
  setLayerRecursive(self.transform, PROPS_LAYER)
end
```

---

## 5. 场景变体

### 5.1 载人平台 + 升降（Kinematic + MovePosition）

载人平台的位移方式应使用 `isKinematic = true` + `rb:MovePosition`，让 3C 平滑接住站立的胶囊；直接改 `transform.position` 会让玩家被"传送"，站不稳。

```lua
function Start()
  setLayerRecursive(self.transform, DEFAULT_LAYER)

  rb = self.gameObject:GetComponent(typeof(CS.UnityEngine.Rigidbody))
  if rb ~= nil then rb.isKinematic = true end
end

function FixedUpdate()
  if rb == nil then return end
  -- 沿正弦曲线上下移动
  local y = math.sin(CS.UnityEngine.Time.time * 2) * 2
  local pos = self.transform.position
  rb:MovePosition(CS.UnityEngine.Vector3(pos.x, baseY + y, pos.z))
end
```

### 5.2 防带飞的球（配合接触施力）

球既要防顶飞（`Props(6)`）又要接受踢球（见 [Rigidbody-接触施力-Lua](./Rigidbody-%E6%8E%A5%E8%A7%A6%E6%96%BD%E5%8A%9B-Lua.md)）：

```lua
function Start()
  -- 防顶飞
  setLayerRecursive(self.transform, PROPS_LAYER)

  -- 缓存 Rigidbody（接触施力用）
  rb = self.gameObject:GetComponent(typeof(CS.UnityEngine.Rigidbody))
end

function OnActorCollisionEnter(actor)
  -- 接触施力（见 Rigidbody 接触施力-Lua.md 完整骨架）
  -- ...
end
```

**关键**：`Props(6)` 只影响踩地检测，不会移除实体碰撞或 `OnActorCollisionEnter`；实体碰撞仍保留（可以被踢/推）。如果对象还需要拾取或靠近交互，独立 Trigger 仍可保留 `OnActorTriggerEnter/Exit` 入口。

### 5.3 大型载人载具（车顶可站人）

如果载人平台本身是载具（车顶可站客人）：

- 车身 root：走载具模板 layer 配置（通常项目自定义 `9`）。
- 车顶可踩 collider：**单独** `SetLayer(DEFAULT_LAYER)`（不用整棵子树都设 `0`）。

此时需要更精细的选择性 SetLayer——只对 collider 命名匹配的子节点设 `Default(0)`。

### 5.4 双 Collider 的 Layer 验收

对象同时存在实体 Collider 和交互 Trigger 时，必须分别确认：

- 实体 Collider 使用能满足撞地/撞墙/玩家接触的 Layer；`isTrigger=false` 不能被误改成 Trigger。
- Interaction Trigger 保持 `isTrigger=true`，范围只比交互所需略大，不能用 Layer 配置替代 Trigger。
- 子 Collider 即使共享 Root Rigidbody，也必须递归检查 Layer；Unity 复合物理成立不代表 Hamlet Actor 回调会向 Root 脚本冒泡。
- 载人载具的实体 Collider 不能只依赖 Trigger 维持站立；交互入口也不能只依赖实体 Collider。

---

## 6. 常见坑 FAQ

| 现象 | 违反约束 | 修复 |
| --- | --- | --- |
| 载人平台站不住 / 陷下去 | 给载人平台设了 `Props(6)` 或 `IgnoreRaycast(2)`，踩地检测穿过 | 载人平台设 `Default(0)` |
| 载人平台移动不带走玩家 | 只设 root 未递归到子碰撞体，或用 `transform.position` 直接传送而不是 `MovePosition` | 递归 `SetLayer(0)` + Kinematic 刚体 + `MovePosition` |
| 球会顶飞玩家 | 用了可踩层（`Default(0)`）或没有显性设 layer，被踩地检测命中 | `Start` 递归 `SetLayer(6)` |
| 只设 root layer，子碰撞体仍被踩 / 未防带飞 | `SetLayer` 只作用于 root，子节点仍保留旧 layer | 用 `setLayerRecursive(self.transform, ...)` |
| 依赖静态配置里的 `Props(6)` 生效 | 资源配置里的静态 `layer` 字段只支持 `0` 和 `9`，写 `6` 不生效 | 在 `Start` 运行时递归 `SetLayer(6)` |
| 用 `Physics.IgnoreCollision(球, 玩家)` 防顶飞 | `IgnoreCollision` 只屏蔽求解器接触，对踩地射线查询无效 | 改 `SetLayer(6)`；`IgnoreCollision` 只屏蔽求解器接触，对踩地查询无效 |
| 临时改层 / 卡时间窗口切换 | 治标不治本，容易出现窗口期漂移 | 在 `Start` 一次性按目标层设定 |
| 编辑器改 `PhysicMaterial` 无效 | Lua 脚本里运行期 `new PhysicMaterial` 覆写了 `sharedMaterial`，覆盖资源配置 | 走资源配置文件；Lua 不 `new PhysicMaterial` |
| Play 后动态物体掉到地下 | 只有 Trigger，缺少实体 Collider | 添加 `isTrigger=false` 的实体 Collider，并确认其 Layer 能与地面接触 |
| 物理碰撞正常但无法交互 | 只有实体 Collider，缺少 Interaction Trigger | 添加 `isTrigger=true` Trigger，并确认 `DouyinScript` 与 Trigger 同节点 |
