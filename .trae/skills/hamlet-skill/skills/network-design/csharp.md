---
title: Network Design — C# 版本
language: csharp
description: 本文档汇总使用 C# 实现网络同步的相关说明与代码示例索引。
---

## 适用场景（什么时候读这个文件）

用 C# 写网络同步代码时，遇到以下场景读本文件：

- 编写继承 `NetworkBehaviour` 的网络脚本，或给 Prefab 挂 `NetworkObject`
- 声明 / 读写同步变量（`NetworkVariable<T>` / `NetworkList` / `NetworkDictionary`）
- 使用 `[Rpc(SendTo.X)]` 或 `DouyinRemoteEvent` / `DouyinRemoteFunction` 做跨端通信
- 使用 `DouyinObjectService.NetSpawn/ServerSpawn/NetDestroy` 或 `DouyinActor.NetSpawn` 动态创建网络对象
- 判断主权归属，并接管主权转移与审批逻辑
- 处理 SharedMode 或 DS 下的 C# 网络对象生成、同步变量、RPC 和远程通信
- 调试 C# 同步不生效、消息丢包、对象重复生成等网络问题

---

## 文档索引（以此表为准）

匹配到相关功能时，**必须先完整读取对应的参考文档**再开始编码。严禁凭记忆或拼凑现有 Demo 调用 API。

「模式」列说明文档适用的网络架构：`SharedMode` 只在 SharedMode 项目读取，`DS` 只在 DedicatedServer 项目读取，`通用` 两种架构都要按需读取；当前项目架构在 hamlet-preferences.md 已固定，不要读另一架构的文档以免用错 API。

| 资料 | 模式 | 路径 | 什么时候读 |
|---|---|---|---|
| 主权实践-CSharp | 通用 | [主权/主权-CSharp.md](../../references/Best%20Practice/主权/主权-CSharp.md) | 需要在 C# 中判断主权、请求主权或接管主权转移逻辑时读。漏读易犯：使用同步回调获取异步请求结果、未在 `OnGainedOwnership` 接管权威逻辑。 |
| ShareMode 房间对象动态创建-CSharp | SharedMode | [网络通信/动态创建/ShareMode - 房间对象的动态创建 - CSharp.md](../../references/Best%20Practice/网络通信/动态创建/ShareMode%20-%20房间对象的动态创建%20-%20CSharp.md) | SharedMode 下 `DouyinObjectService.NetSpawn` 创建房间级对象的完整写法。写「动态生成敌人 / 道具 / 场景物件」时读。漏读易犯：把 `NetSpawn` 当回调式（实为同步返回 GameObject + `out int id`）、key 未注册返回 null、`autoRequest` 遗漏。 |
| DedicatedServer 房间对象动态创建-CSharp | DS | [网络通信/动态创建/DedicatedServer - 房间对象的动态创建 - CSharp.md](../../references/Best%20Practice/网络通信/动态创建/DedicatedServer%20-%20房间对象的动态创建%20-%20CSharp.md) | DS 模式服务端 `ServerSpawn / ServerDestroy` 创建对象、客户端经 `Rpc(SendTo.Server)` 请求生成的写法。DS 项目做服务端权威生成时读。漏读易犯：客户端直接调 `NetSpawn`（DS 下不行）、`ServerSpawn` 在客户端调用记 error。 |
| 用户绑定对象动态创建-CSharp | 通用 | [网络通信/动态创建/用户绑定对象的动态创建 - CSharp.md](../../references/Best%20Practice/网络通信/动态创建/用户绑定对象的动态创建%20-%20CSharp.md) | `DouyinActor.NetSpawn` / `DouyinPlayer.NetSpawn` 创建随玩家生命周期的绑定对象。写「玩家专属携带物」时读。漏读易犯：玩家离房后遗留对象未清理、`Actor` 与 `Player` 版本语义不同。 |
| 基础同步变量-CSharp | 通用 | [网络通信/同步变量/基础同步变量-CSharp.md](../../references/Best%20Practice/网络通信/同步变量/基础同步变量-CSharp.md) | `NetworkVariable<T>` 字段声明、`Value` 读写、`OnValueChanged` 回调的最小写法。做「跨端共享分数 / 状态」时读。漏读易犯：写成局部变量、`OnValueChanged` 参数顺序写反、非 `IsOwner` 端写 `Value` 静默无效、`OnNetworkSpawn` 前读到默认值。 |
| 集合同步变量-CSharp | 通用 | [网络通信/同步变量/集合同步变量-CSharp.md](../../references/Best%20Practice/网络通信/同步变量/集合同步变量-CSharp.md) | `NetworkList<T>` / `NetworkDictionary<K,V>` 声明与变更事件（`NetworkListEvent` / `NetworkDictionaryEvent`）。做「玩家列表 / 计分板 / 动态映射表」时读。 |
| 基础 RPC 通信-CSharp | 通用 | [网络通信/RPC/基础RPC通信-CSharp.md](../../references/Best%20Practice/网络通信/RPC/基础RPC通信-CSharp.md) | `[Rpc(SendTo.X)]` 特性、`SendTo` 各枚举与 `RpcTarget` 精确目标的写法。做「跨端事件 / 触发动作」时读。漏读易犯：方法名不以 `Rpc` 结尾、`SendTo.SpecifiedInParams` 漏传 `RpcTarget`、参数类型超范围丢包。 |
| DS 远程通信-CSharp | DS | [网络通信/RPC/DS远程通信-CSharp.md](../../references/Best%20Practice/网络通信/RPC/DS远程通信-CSharp.md) | DS 模式 `DouyinRemoteEvent` / `DouyinRemoteFunction` 客户端↔服务端通信。DS 项目做交互时读。 |
| DedicatedServer 综合实践-CSharp | DS | [DedicatedServer/DedicatedServer-CSharp.md](../../references/Best%20Practice/DedicatedServer/DedicatedServer-CSharp.md) | DS 模式 C# 双程序集、`enableCSharp`、`IsServer` 分支、服务端逻辑组织的综合实践。DS 项目起步时读。漏读易犯：`enableCSharp` 未开、`GameScripts` 误引用服务端类型导致裁剪失败。 |
