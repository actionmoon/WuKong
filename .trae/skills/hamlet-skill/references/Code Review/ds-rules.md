---
title: DS 规则速查
scope: Hamlet 代码硬红线检查（仅 DS / Dedicated Server 模式）
applies-to: lua, csharp
language: any
project-usage: reference
last-synced: 2026-07-15
---

# DS 规则速查 — Dedicated Server 专属

严重等级：🔴 禁止 · 🟠 强烈不建议 · 🟡 警告

---

## DS-001 禁用危险标准库（🔴）

**判据**：Lua 沙盒禁用以下标准库/API：
`io.*` / `package.*` / `os.execute` / `os.exit` / `os.getenv` / `os.remove` / `dofile` / `loadfile` / `debug.*` / `string.dump` / `load(bytecode)` / `module`。

出现即拒绝合入；替代方案：文件 I/O → DataStore；时间 → `os.time` / `os.date`（保留）；序列化 → `dkjson`。

---

## DS-002 C/S 端专属 API 边界（🔴）

**判据**：以下 API 只能在对应端调用，混用会运行时报错或消息无处可达。

| 服务端 (`DouyinServerScript`) | 客户端 (`DouyinScript`) |
|---|---|
| `DouyinDedicatedServer.NetServerSpawn` | `DouyinObjectService.NetSpawn` |
| `DouyinDedicatedServer.NetServerDespawn` | `DouyinObjectService.NetDespawn` |
| `DouyinDedicatedServer.SendEventToAllClients` | `remoteEvent:FireServer` |
| `DouyinDedicatedServer.SendEventToClient` | — |
| `DouyinDedicatedServer.DSLog` | `print` |

---

## DS-003 客户端不建议直连 DataStore（🟠）

**判据**：客户端脚本中直接 `DouyinDataService.GetDataStore` 读写玩家档案。DS 模式下应走 `remoteEvent:FireServer(...)` 让服务端读写，避免客户端伪造。

只读非敏感数据（如公共配置）可豁免，但需评估。

---

## DS-004 敏感数据禁下发客户端（🔴）

**判据**：以下参数不得通过 RemoteEvent / 同步变量 / 配置表下发到客户端：
- 掉落率 / 概率表
- 伤害/暴击/减伤系数
- 反作弊阈值（如 MAX_DAMAGE、位移速度上限）
- 结算/奖励参数

均由服务端持有并计算，客户端只收结果。

---

## DS-005 服务端资源使用限制（🟡）

**CPU**：避免 O(n²) 遍历（大玩家列表用 hashmap）；限制递归深度；字符串拼接用 `table.concat` 不用循环 `..`。

**内存**：所有缓存必须有上界；避免大闭包捕获整个玩家对象；`AddListener` 与 `RemoveListener` 配对，防止 map/表泄漏。

**带宽**：同步只传差量；玩家/对象数量大时使用 AOI 或缩小 NetVar 广播范围。

---

## DS-006 公共网络对象建议在服务端创建（🟠）

**判据**：DS 模式下 `DouyinObjectService.NetSpawn`（公共对象/掉落物/BOSS）建议由服务端使用 `DouyinDedicatedServer.NetServerSpawn`；客户端 spawn 会导致主权归发起客户端，权威性丢失。

例外：`DouyinActor.NetSpawn`（玩家 Avatar/Pet）由客户端发起是合规的。

---

## DS-007 服务端必须校验客户端输入（🔴/🟡）

**判据**：服务端处理 `remoteEvent:FireServer` 事件时，必须做：
- **身份**：`player` 是否为当前房间合法玩家；
- **状态**：玩家/对象状态允许此操作（如"死亡状态不可攻击"）；
- **范围**：数值在服务端阈值内（伤害 ≤ `MAX_DAMAGE`、坐标在合理范围）；
- **幂等**：同一 seqId / actionId 二次上报直接忽略。

```lua
-- ✅ 服务端事件校验
remoteEvent.OnServerEvent:Connect(function(player, damage, targetId)
    if not IsValidPlayer(player) then return end
    if IsDead(player) then return end
    if damage < 0 or damage > MAX_DAMAGE then return end
    ApplyDamage(targetId, damage, player)
end)
```

---

## DS-008 GM / 调试指令必须包裹 isSimulator（🔴）

**判据**：任何"改数据 / 加金币 / 强制状态"等调试用途代码，必须被 `if DouyinApplication.isSimulator then ... end` 包裹。DS 服务端尤其严格——未包裹的 GM 逻辑会随发布流入正式环境。

```lua
-- ❌
function OnCommandAddCoins(player, amount)
    AddCoins(player, amount)
end

-- ✅
function OnCommandAddCoins(player, amount)
    if not DouyinApplication.isSimulator then return end
    AddCoins(player, amount)
end
```
