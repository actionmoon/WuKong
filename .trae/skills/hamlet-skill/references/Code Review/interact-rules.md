---
title: INT 规则速查
scope: Hamlet 代码硬红线检查
applies-to: lua, csharp
language: any
project-usage: reference
last-synced: 2026-07-15
---

# INT 规则速查 — 交互与合养控制权

严重等级：🔴 禁止 · 🟠 强烈不建议 · 🟡 警告

---

## INT-001 拾取/座位 API 自动带控制权，不要重复请求（🟡）

**判据**：`DouyinActor.PickUp` / `DouyinActor.SitDown` 会**自动获取**目标网络对象控制权（并因此获得主权）；`DouyinActor.Drop` / `DouyinActor.StandUp` 会**自动释放**。业务代码里在这些 API 前后再调用 `RequestOwnership` / `ReleaseOwnership` 会引发多余的主权抖动。

网络对象控制权规则要点：
- 默认无归属，需主动 `RequestOwnership` 获取；已被其他玩家持有则请求失败。
- 请求成功即自动获得主权。
- 玩家退房时，其持有的所有网络对象控制权自动释放。

---

## INT-002 精灵合养控制权转移必须两端对偶处理（🔴）

**判据**：合养场景（A 操控者、B 观察者）下，`DouyinPet` 控制权在 A/B 间切换时，与该 Pet 关联的 UI / 状态 / 隐藏按钮 / 特殊状态（钓鱼、瞄准等）必须在两端**成对**处理：
- **拿到控制权端**：进入相应 UI / 状态；
- **失去控制权端**：关闭 UI / 重置状态。

**衍生**：精灵控制权转移时，该玩家名下所有网络对象的主权/控制权会**跟随转移**——不要假设 Pet 与网络对象的持权可以分离。

```lua
-- ✅ Pet 控制权变化的对偶处理
function OnPetControllershipChanged(hasControl)
    if hasControl then
        OpenFishingUI()
        EnterFishingState()
    else
        CloseFishingUI()
        ResetFishingState()
    end
end
```

**触发时机**：
1. 操控者主动移交
2. 观察者请求并被同意
3. 操控者退房 → 自动转给观察者

---

## INT-003 网络对象父子级慎用；使用需妥善销毁（🟠）

**判据**：`NetSpawn` 出的网络对象挂到另一个网络对象（尤其 `DouyinActor`）下面，形成父子级。父对象销毁会连带销毁子对象，但**不会**走子对象的 `NetDespawn`——导致服务端仍认为该网络对象存在。

**修复**：
- 优先扁平化，不建立父子级。
- 必须父子级时，`OnActorDespawn` / 父对象销毁前：**先解除父子级** → 再对子对象自行 `DouyinObjectService.NetDespawn`。

```lua
-- ✅
function OnActorDespawn(actor)
    if childNetObjId ~= nil then
        childGO.transform:SetParent(nil)
        DouyinObjectService.NetDespawn(childNetObjId)
        childNetObjId = nil
    end
end
```
