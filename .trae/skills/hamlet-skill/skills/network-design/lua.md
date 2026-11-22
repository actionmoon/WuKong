---
title: Network Design — Lua 版本
language: lua
description: 本文档汇总使用 Lua 实现网络同步的相关说明与代码示例索引。
---

## 适用场景（什么时候读这个文件）

用 Lua 写网络同步代码时，遇到以下场景读本文件：

- 编写 `DouyinScript` 网络脚本，或让某个 GameObject 成为网络对象
- 声明 / 读写同步变量（`---@varSync`、`SetValue` / `GetValue` / `OnValueChange`）
- 使用 `SendMessageToOwner/All/Target/Others/Server` 或 `DouyinRemoteEvent` 做跨端通信
- 使用 `DouyinObjectService.NetSpawn/NetDestroy` 或 `DouyinActor.NetSpawn` 动态创建网络对象
- 判断主权或控制权归属，并接管转移逻辑
- 处理 SharedMode 或 DS 下的 Lua 网络对象生成、同步变量、RPC 和远程通信
- 调试 Lua 同步不生效、消息丢包、对象重复生成等网络问题

---

## 文档索引（以此表为准）

匹配到相关功能时，**必须先完整读取对应的参考文档**再开始编码。严禁凭记忆或拼凑现有 Demo 调用 API。

「模式」列说明文档适用的网络架构：`SharedMode` 只在 SharedMode 项目读取，`DS` 只在 DedicatedServer 项目读取，`通用` 两种架构都要按需读取；当前项目架构在 hamlet-preferences.md 已固定，不要读另一架构的文档以免用错 API。

| 资料 | 模式 | 路径 | 什么时候读 |
|---|---|---|---|
| 主权实践-Lua | 通用 | [主权/主权-Lua.md](../../references/Best%20Practice/主权/主权-Lua.md) | 需要在 Lua 中判断主权、请求主权或接管主权转移逻辑时读。漏读易犯：忘记判空、在回调内错误执行副作用。 |
| 控制权实践-Lua | 通用 | [主权/控制权-Lua.md](../../references/Best%20Practice/主权/控制权-Lua.md) | 需要在 Lua 中获取控制权以绑定输入、或处理对象控制者转移时读。漏读易犯：在 `OnNetSpawned` 中未延迟请求控制权导致失败。 |
| SharedMode 房间对象动态创建-Lua | SharedMode | [网络通信/动态创建/SharedMode - 房间对象的动态创建 - Lua.md](../../references/Best%20Practice/网络通信/动态创建/SharedMode%20-%20房间对象的动态创建%20-%20Lua.md) | SharedMode 下用 `DouyinObjectService.NetSpawn` 创建房间级网络对象的完整闭环（注册 key、回调 `(go, id)`、主权与 `NetDestroy`）。写「动态生成敌人 / 道具 / 场景物件」时读。漏读易犯：key 未注册到 `NetSpawnObjectAsset`、回调参数顺序搞错、`autoRequest` 遗漏导致非主权方销毁失败。 |
| DedicatedServer 房间对象动态创建-Lua | DS | [网络通信/动态创建/DedicatedServer-房间对象的动态创建 - Lua.md](../../references/Best%20Practice/网络通信/动态创建/DedicatedServer-房间对象的动态创建%20-%20Lua.md) | DS 模式下服务端用 `ServerSpawn` 创建对象、客户端经消息请求生成的写法。DS 项目做服务端权威生成时读。漏读易犯：以为客户端能直接 `NetSpawn`（DS 下不行，必须请求服务端）。 |
| 用户绑定对象动态创建-Lua | 通用 | [网络通信/动态创建/用户绑定对象的动态创建 - Lua.md](../../references/Best%20Practice/网络通信/动态创建/用户绑定对象的动态创建%20-%20Lua.md) | 用 `DouyinActor.NetSpawn` 创建随玩家生命周期的绑定对象（玩家离房自动销毁）。写「玩家专属携带物 / 拖尾 / 头顶物件」时读。漏读易犯：玩家离房后遗留对象未清理。 |
| 基础同步变量-Lua | 通用 | [网络通信/同步变量/基础同步变量-Lua.md](../../references/Best%20Practice/网络通信/同步变量/基础同步变量-Lua.md) | `---@varSync` 声明标量同步变量、`SetValue/GetValue/OnValueChange` 读写与回调的最小写法。做「跨端共享分数 / 状态 / 开关」时读。漏读易犯：主权检查漏做、非主权方 `SetValue` 静默失败、`---@var` 与 `---@varSync` 拆块导致声明丢失。 |
| 集合同步变量-Lua | 通用 | [网络通信/同步变量/集合同步变量-Lua.md](../../references/Best%20Practice/网络通信/同步变量/集合同步变量-Lua.md) | `Dictionary` 类型同步变量的声明与增删改同步。做「玩家列表 / 计分板 / 动态映射表」时读。 |
| 基础 RPC 通信-Lua | 通用 | [网络通信/RPC/基础RPC通信-Lua.md](../../references/Best%20Practice/网络通信/RPC/基础RPC通信-Lua.md) | `SendMessageToOwner/All/Target/Others` 脚本消息的收发写法。做「一次性事件通知 / 触发跨端动作」时读。漏读易犯：消息参数类型超出 SDK 支持导致静默丢包。 |
| DS 远程通信-Lua | DS | [网络通信/RPC/DS远程通信-Lua.md](../../references/Best%20Practice/网络通信/RPC/DS远程通信-Lua.md) | DS 模式下客户端与服务端用 `DouyinRemoteEvent` 通信的写法。DS 项目做客户端↔服务端交互时读。 |
| DedicatedServer 综合实践-Lua | DS | [DedicatedServer/DedicatedServer-Lua.md](../../references/Best%20Practice/DedicatedServer/DedicatedServer-Lua.md) | DS 模式 Lua 侧服务端 / 客户端脚本分层、服务端逻辑组织的综合实践。DS 项目起步时读。 |
