# RPC 概述

在 Douyin World 的联网世界里，存在两种解决不同场景的网络通信机制：
- **RPC 通信（Remote Procedure Call）**：基于**事件驱动，让网络中客户端调用服务器/另外客户端的函数**。
- **同步变量**：**状态驱动**，值变化时框架自动同步；适合"必须最终一致"的持续状态（如生命值、位置）。

## RPC 与 同步变量 的对比

| 对比项 | RPC (消息互通) | 同步变量 |
| --- | --- | --- |
| **适用场景** | 对消息的可靠性要求不高的场景，客户端表现相关（特效、声音播放） | 持续存在的状态（生命值、得分、位置） |
| **通信机制** | 事件驱动，发送方主动调用发送 | 状态驱动，变量值变化时框架自动同步 |
| **多参数支持** | 支持传递多个参数 | 只能针对单个变量进行独立同步 |
| **后加入玩家 / 断线重连** | 无法收到已经发送过的 RPC 消息 | 加房/重连后能拉取到最新值 |
| **可靠性** | 不保证 100% 送达（网络断开不补发） | 保证送达，平台确保数据的最终一致性 |

> **黄金选型原则**：
> - **需要确保可靠同步**：用**同步变量**，配合 `OnValueChange`。
> - **只需一次性通知副作用**（播放特效、弹窗、请求某端触发某个动作）：用 **RPC 通信**。
> - **必须拿到对端计算结果（高可靠性要求）**：强烈建议把结果**写进同步变量**，让所有端通过 `OnValueChange` 收到，而不是依赖 RPC（如 `OwnerCall` / `DouyinRemoteFunction`）的返回值，因为所有 RPC 回调都存在静默丢失的风险。

## 调用时机

所有 RPC 通信都属于网络 API。**在 `Awake / Start / Update` 等生命周期回调中调用前，必须通过`DouyinNetService.isNetworkSettled`先判断网络环境是否就绪**，否则会出现“消息发出去了但传输通道尚未建立”的静默失败。

## 参数类型限制

RPC 通信的参数只支持**基础数据类型**，跨语言、跨模式一致：

- **支持类型**：`bool, byte, short, int, long, float, double, string`。
  - C# 侧额外支持 `Vector2/3/4, Quaternion`（这与 NetworkVariable 层已支持的类型约束相同）。
- **不支持类型**：Lua 的 `table`、C# 的自定义 `class`、`List`（在 RPC 参数层面不支持）、`Dictionary<K, V>` 等复杂容器。

**传递复杂结构的替代方案**：
如果确实需要跨端传递复杂数据，请遵循以下优先级：
1. **拆分参数**：用多个基础类型参数分开传（推荐）。
2. **序列化**：序列化成 `string`（如 JSON）再传（次选，需业务侧自行处理版本兼容）。
3. **改用同步变量**：将数据存到同步变量中，并通过 `OnValueChange` 触发（最推荐，兼顾了数据的可靠性与最终一致性）。

## 通信方式分类

根据网络开发模式的不同，Douyin World 提供了以下两大类 RPC 消息互通方式：

### 1. SendMessageTo*(name, ...)（SharedMode / DS 通用）

- 用于在玩家与玩家、玩家与主权方之间的点对点发送消息，同时支持广播给所有人、房间内其他玩家（不含自己）。
- Lua侧：网络对象需要挂载`DouyinScript`组件
- CSharp侧：网络对象需要挂载`NetworkBehaviour`组件
 
相关的接口主要包括：
| 场景 | Lua（`DouyinScript`） | C#（`NetworkBehaviour`） |
| --- | --- | --- |
| 通知主权方 | `SendMessageToOwner(method, args...)` | `[Rpc(SendTo.Owner)] void Foo(...)` |
| 广播给所有人 | `SendMessageToAll(method, args...)` | `[Rpc(SendTo.Everyone)] void Foo(...)` |
| 广播给他人（不含自己） | `SendMessageToOthers(method, args...)` | `[Rpc(SendTo.NotMe)] void Foo(...)` |
| 发给指定玩家 | `SendMessageToTarget(method, target, args...)` | `[Rpc(SendTo.SpecifiedInParams)] void Foo(..., RpcTarget rpcTarget, ...)` |
| 通知主权方并回调 | `OwnerCall(method, onFinish, args...)` | 无原生等价；用 NetworkVariable 记结果 |
| 通知指定玩家并回调 | `TargetCall(method, target, onFinish, args...)` | 无原生等价；用 NetworkVariable 记结果 |

**Lua 与 C# 语言特性差异**：
- **Lua 侧**：无需提前注册方法签名，直接通过字符串 `name` 发送和监听。
- **C# 侧**：
  1. RPC 方法名必须以 `Rpc` 结尾（例如 `DoSomethingRpc`）。
  2. 使用 `SendTo.SpecifiedInParams` 发给指定玩家时，参数列表最后必须携带 `RpcTarget` 对象，否则运行时会报错。

**详细说明见**：[SendMessage](./SendMessage.md)

### 2. DS 模式下的 C/S 通信 (RemoteEvent / RemoteFunction)

在 Dedicated Server (DS) 开发模式下，引入了独立的服务器节点。为了实现客户端与服务端（C/S）之间的通信，平台提供了专属的异步通信对象。
- **DouyinRemoteEvent**：用于异步单向通信，调用方无需等待响应。
  **详细说明见**：[RemoteEvent](./RemoteEvent.md)
- **DouyinRemoteFunction**：用于双向通信，调用方可以等待并处理另一方的返回结果。
  **详细说明见**：[RemoteFunction](./RemoteFunction.md)

相关的接口主要包括：
| 场景 | Lua（`DouyinScript`） | C#（`NetworkBehaviour` 独立组件） |
| --- | --- | --- |
| 客户端 → 服务器（单向） | `DouyinRemoteEvent("id"):FireServer(...)` | `new DouyinRemoteEvent("id").FireServer(...)` |
| 服务器 → 指定客户端（单向） | `DouyinRemoteEvent("id"):FireClient(player, ...)` | `new DouyinRemoteEvent("id").FireClient(player, ...)` |
| 服务器 → 所有客户端（单向） | `DouyinRemoteEvent("id"):FireAllClients(...)` | `new DouyinRemoteEvent("id").FireAllClients(...)` |
| 客户端 → 服务器（带响应） | `DouyinRemoteFunction("id"):InvokeServer(cb, ...)` | 待补 C# 官方封装（可用 RemoteEvent 双向拼接） |
| 服务器 → 客户端（带响应） | `DouyinRemoteFunction("id"):InvokeClient(player, cb, ...)` | 待补 |

**DS 模式开发差异（脚本位置约束）**：

> **适用范围**：当 [hamlet-preferences.md](../../../../../hamlet-preferences.md) 中 `DevTool=UnityEditor` 时阅读。
> `DevTool` 的详细说明请参考[开发工具概述](../../../VI.%20开发工具/开发工具概述.md)。

- **Lua 侧**：使用 `DouyinServerRoot` + `DouyinServerScriptLoader`，服务器脚本与客户端脚本互斥（同一个脚本不能同时挂在两端）。
- **C# 侧**：使用 `DouyinServerRoot` + `ServerScripts` 目录；服务器脚本必须放在 `DouyinServerScripts` 程序集内，客户端脚本放在 `GameScripts` 程序集内。C# DS 支持需要在 `Packages/com.douyin.world/Config/simulator.json` 中将 `enableCSharp` 开启。
