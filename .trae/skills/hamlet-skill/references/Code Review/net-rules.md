---
title: NET / PERF 规则速查
scope: Hamlet 代码硬红线检查
applies-to: lua, csharp
language: any
project-usage: reference
last-synced: 2026-07-15
---

# NET / PERF 规则速查 — 网络同步与对象生命周期

严重等级：🔴 禁止 · 🟠 强烈不建议 · 🟡 警告

---

## NET-001 网络 API 高频调用（🟡）

**判据**：`Update` / 高频计时器中每帧调用 `SetValue` / `Rpc` / `NetSpawn` / `NetDespawn` 等网络写 API；`HasOwnership()` / 读操作除外。

**修复**：节流到 100~500ms，或改用事件驱动。

```lua
-- ❌ 每帧写同步变量
function Update()
    self.posVar:SetValue(self.transform.position)
end

-- ✅ 节流写入
local lastSync = 0
function Update()
    if os.clock() - lastSync > 0.1 then
        self.posVar:SetValue(self.transform.position)
        lastSync = os.clock()
    end
end
```

---

## NET-002 NetVar 写入必须持有主权（🔴）

**判据**：`xxxVar:SetValue(...)` 调用前未 `if self:HasOwnership() then`。无主权写入被 SDK 静默丢弃，导致同步失效。

```lua
-- ❌
self.scoreVar:SetValue(newScore)

-- ✅
if self:HasOwnership() then
    self.scoreVar:SetValue(newScore)
end
```

---

## NET-003 RPC 参数类型限制（🔴）

**判据**：`SendMessageToAll / SendMessageToServer / Rpc` 等参数只允许 SDK 白名单基础类型（Bool / Int / Float / String / Vector2/3/4 / Quaternion 以及同类型数组），禁止嵌套 table / function / userdata / DouyinActor。

**修复**：复杂结构走 `dkjson.encode` 转字符串再传，接收端 `dkjson.decode`。

```lua
-- ❌ 传嵌套 table
self:SendMessageToAll("Sync", { hp=100, pos={x=1,y=2} })

-- ✅ 序列化后传字符串
self:SendMessageToAll("Sync", dkjson.encode({ hp=100, pos={x=1,y=2} }))
```

---

## NET-004 业务逻辑必须在进房完成后执行（🔴）

**判据**：`Awake / Start` 中调用网络 API（`SetValue` / `NetSpawn` / `Rpc` / DataStore）。进房未完成时房间对象未 Ready，调用会失效或抛错。

**修复**：入口收敛到 `OnNetworkSettled`（DouyinScript）或 `DouyinNetService.isNetworkSettled == true` 后。`OnNetworkSettled` 为全局事件，只触发一次。

```lua
-- ❌
function Start()
    self.scoreVar:SetValue(0)
end

-- ✅
function OnNetworkSettled()
    if self:HasOwnership() then
        self.scoreVar:SetValue(0)
    end
end
```

---

## NET-005 生命周期回调必须配对（🟡）

**判据**：注册与释放需成对；否则跨房间残留导致重复触发或空引用。

| 注册端 | 释放端 |
|---|---|
| `Start` | `OnDestroy` |
| `OnNetSpawn` | `OnNetDespawn` |
| `OnActorSpawned` | `OnActorDespawned` |
| `Timer.SetInterval` | `Timer.Clear` |
| `xxx:AddListener` | `xxx:RemoveListener` |

```lua
function OnActorSpawned(actor)
    if not actor or not actor.isLocal then return end
    actor.onJump:AddListener(OnJumpCallBack)
end
function OnActorDespawned(actor)
    if not actor or not actor.isLocal then return end
    actor.onJump:RemoveListener(OnJumpCallBack)
end
```

---

## NET-006 三类对象判空规范（🔴）

**判据**：SDK/Unity 对象销毁后 Lua 侧 userdata 仍然存在，单靠 `xxx == nil` 无法判空，需按类型分档处理。

| 对象类型 | 正确判空 |
|---|---|
| 纯 Lua 对象 | `if xxx == nil then` |
| C# System.Object（`DouyinPlayer` / `DouyinPet` / `DouyinObject` / `DouyinActor`） | `if xxx == nil or CS.System.Object.ReferenceEquals(xxx, nil) then` |
| Unity Object / GameObject / Component | `if xxx == nil or xxx:IsNull() then`（或 `xxx:Equals(nil)`） |

**衍生**：
- **不要在 Lua 中缓存 DouyinActor/Player/Pet/Object**；缓存 `xxx.actorID/playerID/petID/objectID`，用时经服务 `GetXxxById(id)` 反查（返回值仍需判空）。
- `DouyinXxxService.GetXxx(...)` 类接口返回值必须判空。
- `setTimeout` / `Timer.SetTimeout` 回调内使用的所有外部对象，必须**重新判空**（回调触发时对象可能已销毁）。

```lua
-- ❌ 缓存 actor 对象本身
local cachedActor
function OnActorSpawned(actor) cachedActor = actor end

-- ✅ 缓存 id，用时反查+判空
local actorId
function OnActorSpawned(actor) actorId = actor.actorID end
function DoSomething()
    local actor = DouyinActorService.GetActorById(actorId)
    if actor == nil or CS.System.Object.ReferenceEquals(actor, nil) then return end
    -- 使用 actor
end
```

---

## NET-007 挂 DouyinScript 的网络对象禁用 Instantiate/Destroy（🔴）

**判据**：任意挂载 `DouyinScript` 的 Prefab 通过 `UnityEngine.GameObject.Instantiate` 实例化，或通过 `UnityEngine.GameObject.Destroy` 销毁。将导致同步变量、`OnActorSpawned` / `OnActorTrigger` 等 SDK 生命周期不触发。

**修复**：
- 创建：`DouyinObjectService.NetSpawn` 或 `DouyinActor.NetSpawn`
- 销毁：与创建 API 同族的 `NetDespawn` / `NetDestroy`（见 PERF-002）
- 静态网络对象不建议销毁

```lua
-- ❌
local go = UnityEngine.GameObject.Instantiate(prefab)

-- ✅
local go, id = DouyinObjectService.NetSpawn("BulletPrefab", pos)
```

---

## NET-008 跨对象回调时序不固定（🟡）

**判据**：`OnPlayerJoined` 与 `OnActorSpawned` 的相对触发顺序不保证，跨查另一域对象可能拿到 nil。

**修复**：跨查必判空；必要时把配对逻辑收敛到两个回调都到齐后再执行。

```lua
-- ❌
function OnPlayerJoined(player)
    local actor = DouyinActorService.GetActorByPlayerId(player.playerID)
    actor:DoSomething()  -- 此刻 actor 可能尚未 spawn
end

-- ✅
function OnPlayerJoined(player)
    local actor = DouyinActorService.GetActorByPlayerId(player.playerID)
    if actor == nil then return end   -- 等 OnActorSpawned 再处理
    actor:DoSomething()
end
```

同理：`OnNetSpawned` 中 `DouyinActorService.GetLocalActor()` 可能为 nil；`OnActorSpawned` 中 `DouyinObjectService.GetDouyinObject(id)` 可能为 nil。

---

## NET-009 断线重连回调需去重（🔴）

**判据**：断线**不会**触发 `OnActorDespawned` / `OnPlayerLeft`；但重连**会**再次触发 `OnActorSpawned` / `OnPlayerJoined`。若在这两个回调里做"动态创建网络对象/注册资源"等副作用，重连会重复执行，导致对象/监听器无限增长。

```lua
-- ❌ 重连后每次都会再 spawn 一个
function OnActorSpawned(actor)
    if actor.isLocal then
        DouyinObjectService.NetSpawn("MyGadget", pos)
    end
end

-- ✅ 用 actorID/openId 记录已处理过
local spawned = {}
function OnActorSpawned(actor)
    if actor.isLocal and not spawned[actor.actorID] then
        spawned[actor.actorID] = true
        DouyinObjectService.NetSpawn("MyGadget", pos)
    end
end
```

---

## NET-010 业务关键状态禁用 SendMessage 传递（🟠）

**判据**：`SendMessageToAll / SendMessageToOther / SendMessageToTarget` 不保证送达（丢包/断线丢消息不会重发）。凡"接收方必须收到才能保持状态一致"的数据（分数、状态机、库存、血量），必须走**同步变量**。

- ✅ 可用 SendMessage：一次性通知/特效触发/临时提示，丢失可接受。
- ❌ 不可用 SendMessage：分数变化、状态机推进、库存变更、位置权威。

---

## PERF-001 禁止高频创建/销毁对象（🟡）

**判据**：`Update` / 高频计时器中调用 `Instantiate` / `Destroy` / `NetSpawn` / `NetDespawn`。手机端 GC 压力大、易掉帧。

**修复**：使用对象池（预生成一批后 `SetActive(true/false)` 复用）。

---

## PERF-002 对象创建/销毁 API 必须配对（🔴）

**判据**：创建/销毁必须使用同族 API，否则破坏网络同步或残留对象。

| 创建 | 销毁 |
|---|---|
| `DouyinObjectService.NetSpawn` | `DouyinObjectService.NetDespawn` |
| `DouyinActor.NetSpawn` | `DouyinActor.NetDestroy`（Actor 销毁时自动清理；如需手动，用同族 API） |
| `UnityEngine.GameObject.Instantiate`（**仅非网络对象**） | `UnityEngine.GameObject.Destroy` |

**衍生**：`DouyinObjectService.NetSpawn` 出的子对象若挂到 Actor 下，必须在 `OnActorDespawn` 中**先取消父子级关系**再自行 `NetDespawn`，否则 Actor 销毁时会连带销毁但不走 `NetDespawn`。

```lua
-- ❌ 混用
local go, id = DouyinObjectService.NetSpawn("Bullet", pos)
UnityEngine.GameObject.Destroy(go)

-- ✅
DouyinObjectService.NetDespawn(id)
```

---

## PERF-003 高频 C# 对象/方法需 local 缓存（🟡）

**判据**：`Update` / 高频回调里反复访问 `self.transform` / `self.gameObject` / `DouyinXxxService.GetXxx(...)` 等 C# 侧成员。跨语言桥消耗大。

```lua
-- ❌
function Update()
    self.transform.position = self.transform.position + dir
end

-- ✅
local myTransform
function Start() myTransform = self.transform end
function Update()
    myTransform.position = myTransform.position + dir
end
```

---

## PERF-004 用 GetDouyinScript(name) 代替 GetComponents（🟡）

**判据**：`self.transform:GetComponents(typeof(DouyinScript))` 会拿到该对象上**全部** DouyinScript，多脚本挂载时容易命中错误的实例。

**修复**：使用 `self:GetDouyinScript("ScriptName")` / `self:GetDouyinScripts("ScriptName")` 按脚本类名精确获取。
