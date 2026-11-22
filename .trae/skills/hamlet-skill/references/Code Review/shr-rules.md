---
title: SHR 规则速查
scope: Hamlet 代码硬红线检查（仅 Shared 模式）
applies-to: lua, csharp
language: any
project-usage: reference
last-synced: 2026-07-15
---

# SHR 规则速查 — Shared 模式专属

严重等级：🔴 禁止 · 🟠 强烈不建议 · 🟡 警告

> Shared 模式下所有逻辑跑在玩家客户端，属于**不可信环境**：任何有经济价值的判定/发放必须迁至 DS。

---

## SHR-001 禁止发放虚拟资产（🔴）

**判据**：Shared 模式客户端里出现"写货币/道具/兑换券到 DataStore"或"客户端本地判定后触发发放"。

无经济价值的纯本地装扮/临时效果可豁免（且不写 DataStore）。凡涉及资产**必须**改造为 DS 服务端授权发放。

```lua
-- ❌ Shared 客户端直接发奖
store:SetData("coins", oldCoins + reward)

-- ✅ 上报请求，DS 侧发放
self:SendMessageToServer("RequestTaskReward", { taskID = taskID })
```

---

## SHR-002 主权依赖逻辑必须具备迁移/兜底（🔴）

**判据**：倒计时、状态机、物品刷新等关键循环仅在 `if self:HasOwnership() then` 中推进，且未在 `OnPlayerLeft` / 超时回调中处理主权方断线；主权方掉线后流程永久停滞。

```lua
-- ✅ 断线兜底
function OnPlayerLeft(player)
    if player.playerID == ownerPlayerID and not self:HasOwnership() then
        self:RequestOwnership()
    end
end

function Update()
    if os.clock() - lastTickTime > 5 and not self:HasOwnership() then
        self:RequestOwnership()  -- 超时接管
    end
end
```

需要长期稳定的全局状态优先迁移到 DS。

---

## SHR-003 SharedMode 禁用单个集合同步变量聚合所有玩家数据（🔴）

**判据**：SharedMode 下，在同一网络对象的同步 Dictionary/List 里聚合多个玩家的状态（分数、道具等），无论 key 是否使用 `player.playerID`。同步变量写入权限跟随所在对象的主权方；主权方杀端且服务器尚未感知下线时，其他玩家对这份集合的增删改查都会失败。

**不适用场景**：DS 场景中，这份集合所在网络对象的主权始终完全归 DS 所有，且代码里没有 `RequestOwnership`、`SetOwnership`、`SetOwner`、`NetworkObject.RequestOwnership()`、`OnOwnershipRequested` 等主权请求、审批或转移逻辑时，可以由 DS 维护集中集合。

**修复**：每个玩家的数据拆成各自独立的同步变量；每个玩家本地维护一份普通字典汇总所有玩家数据，并通过各玩家同步变量的变化回调更新本地字典。跨脚本缓存**只存 actorID**，用时再 `DouyinActorService.GetActorById` 反查。

```lua
-- ❌
self.playerScoreDict:SetValue(player.playerID, 0)

-- ✅
if actor.isLocal then
    DouyinObjectService.NetSpawn("PlayerScoreObj", actor.transform.position)
end
-- PlayerScoreObj 内部只放该玩家自己的 score 同步变量；
-- 其他玩家通过 OnValueChange 更新本地 allPlayerScores[playerID] 普通字典。
```

---

## SHR-004 禁止使用 DS 专属 RemoteEvent（🔴）

**判据**：Shared 模式代码中出现 `remoteEvent:FireServer` / `FireClient` / `FireAllClients` / `DouyinRemoteFunction.InvokeServer`。Shared 没有独立服务端，这些调用消息无处可达。

**修复**：改用 `DouyinScript.SendMessageToAll / SendMessageToOther / SendMessageToTarget`，或用同步变量。

```lua
-- ❌ Shared 侧
remoteEvent:FireServer({ action = "attack" })

-- ✅
self:SendMessageToAll("OnAttackBroadcast", {
    attackerID = localPlayer.playerID, targetID = targetID
})
```

---

## SHR-005 全局关键状态不应长期由单一玩家主权独占（🟠）

**判据**：房间状态机、全局计时器、全局积分板等**唯一实例**由"第一个进房玩家"/"房主"持有主权，且无 `OnPlayerLeft` 转移逻辑。房主断线即卡死。

**修复**：与 SHR-002 同——`OnPlayerLeft` 中检测主权方离开并 `RequestOwnership()`；或将全局态托管到 DS。

---

## 附：Shared 模式主权/控制权时序参考

写"断线兜底"逻辑时的行为参考（判断需不需要主动 `RequestOwnership`）：

| 场景 | 网络对象主权 | 控制权 |
|---|---|---|
| 应用切后台 | 转移至其他玩家 | 保留不转移 |
| 网络异常，服务器**未**感知断线 | 保留在原用户 | 不转移 |
| 网络异常，服务器**已**感知断线 | 转移至其他玩家 | 保留不转移 |
| 切回前台 / 重连成功，用户仍持有控制权 | **自动**恢复主权 | — |
| 切回前台 / 重连成功，用户无控制权 | 需主动 `RequestOwnership()` | — |
