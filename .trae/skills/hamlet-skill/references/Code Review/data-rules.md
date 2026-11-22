---
title: DATA 规则速查
scope: Hamlet 代码硬红线检查
applies-to: lua, csharp
language: any
project-usage: reference
last-synced: 2026-07-15
---

# DATA 规则速查 — 数据存储

严重等级：🔴 禁止 · 🟠 强烈不建议 · 🟡 警告

---

## DATA-001 合理评估存储用量与访问频率（🟡）

**判据**：
- 单 scope 上限 **1000 key**（DataStore）/ **5000 key**（OrderedDataStore），超限写入失败。
- 按玩家的档案，`openId` 必须拼进 **scope** 而非 key（否则 1000 玩家即撑满）。
- 写入频率上限约 6 次/秒/key，高频写需合并/节流。

```lua
-- ❌ 所有玩家档案挤在同一 scope
local ok, store = DouyinDataService.GetDataStore("Common", "playerData")
store:SetData(openId, jsonStr)  -- key 数量 = 玩家数

-- ✅ openId 拼到 scope
local ok, store = DouyinDataService.GetDataStore("Common", "playerData_" .. openId)
store:SetData("profile", jsonStr)
```

---

## DATA-002 SetData / GetData 必须做失败处理（🔴/🟡）

**判据**：`SetData / GetData` 返回 `ok, data`；未 `pcall` 或未判 `ok`，遇到超限、频控、序列化失败会静默丢数据。

```lua
-- ❌
local _, data = store:GetData("profile")
DoSomething(data)

-- ✅
local ok, data = store:GetData("profile")
if not ok then
    -- 失败降级或重试
    return
end
if type(data) ~= "table" then data = {} end
```

写入后建议根据业务重要性决定是否重试；金钱/资产类失败必须回滚业务态。

---

## DATA-003 DS 服务端不得直接持久化客户端上报值（🔴）

**判据**：DS 模式下服务端收到客户端上报（分数、货币、道具数）后未做校验/裁剪，直接 `store:SetData` 持久化。客户端可篡改上报，导致资产伪造。

```lua
-- ❌（DS 服务端）
remoteEvent.OnServerEvent:Connect(function(player, score)
    store:SetData(player.openId, tostring(score))
end)

-- ✅ 服务端权威计算
remoteEvent.OnServerEvent:Connect(function(player, action)
    local score = ScoreLogicOnServer(player, action)
    if score < 0 or score > MAX_SCORE then return end
    store:SetData(player.openId, tostring(score))
end)
```
