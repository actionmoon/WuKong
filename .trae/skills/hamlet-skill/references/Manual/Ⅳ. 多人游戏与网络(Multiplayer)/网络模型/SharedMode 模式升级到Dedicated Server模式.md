# Shared Mode 升级到 Dedicated Server 模式

Shared Mode 与 Dedicated Server (DS) **不是一键切换**的关系，两者是不同场景下的架构选型。

在玩法初期验证阶段，可以使用 Shared Mode 快速上线；当验证用户反馈后，如果出现作弊问题、需要接入商业化流程，或者对数据安全有更高要求时，可将其迁移到 DS 模式来解决。
请注意，升级过程需要对业务逻辑进行解耦和重构，平均需要**原开发工作量的 30%–50%** 用于改造。

## 一、 主要改造点对比

在迁移过程中，核心是将分布在客户端的逻辑和数据收口到权威的 DS 服务器。以下是主要的改造点对比：

| 改造点 | Shared Mode 现状 | Dedicated Server (DS) 目标 |
| --- | --- | --- |
| **逻辑分层** | 核心逻辑（如数值计算、奖励发放、判定）散落在各客户端 | 核心逻辑迁移到 DS 侧执行，客户端只保留表现层（UI、特效、动画） |
| **权限校验** | 无校验或校验非常有限（客户端易篡改） | 所有客户端提交的核心操作必须在 DS 侧进行严格的合法性校验 |
| **全局逻辑** | 通常由房主或某对象的主权方托管，主权转移或断线时可能出现异常 | 由 DS 统一承载，网络状态始终稳定，不存在主权掉线阻塞问题 |
| **通信通道** | `SendMessageToXxx` (RPC) + 同步变量 | 客户端 ⇄ DS 走 `DouyinRemoteEvent` / `DouyinRemoteFunction`；客户端 ⇄ 客户端仍可用 `SendMessageToXxx` |
| **数据存储** | 客户端直接调用 DataStore API | 数据存储必须迁移到 DS；客户端需通过 Remote 通信请求 DS 代为读写 |
| **调试流程** | 单客户端视角调试 | 需同时调试客户端与服务器，必须在调试面板勾选“启动服务器端” |

## 二、 推荐迁移步骤

建议按照以下 6 个步骤平滑地将 Shared Mode 升级为 DS 模式：

### 第一步：逻辑分层与解耦
在原 Shared Mode 玩法中，提前做好逻辑分层，将**核心逻辑**与**表现逻辑**拆分。这一步在项目初期就应当保持良好的代码规范。

### 第二步：启用 DS 模式
在场景中添加 `DouyinServerRoot` 节点以正式启用 DS 模式，并在该节点下挂载至少一个服务器脚本。
> **⚠️ 注意**：必须挂载至少一个脚本，否则可能会报 `NetworkNetPacket_PlayerEnterSyncForOther Playerlnfos miss.` 错误。

### 第三步：核心逻辑迁移
逐步将核心逻辑脚本迁移到服务端专用的脚本载体中：
- **Lua**：将服务端代码放入 `DouyinServerScriptLoader`。
- **C#**：将服务端代码放入 `ServerScripts` 目录。
同时，客户端侧剥离这些逻辑，仅保留表现层代码。

### 第四步：通信通道改造
梳理原有的客户端 RPC 调用。将类似 `SendMessageToOwner` 这种“客户端委托主权方”执行的调用点，改造为标准的 Client-Server 通信：
- 单向通知：改用 `DouyinRemoteEvent.FireServer`。
- 双向请求响应：改用 `DouyinRemoteFunction.InvokeServer`。

### 第五步：数据存储 (DataStore) 迁移
梳理所有 DataStore / OrderedDataStore 的调用点。由于 DS 模式下禁止客户端直接调用存储 API（会返回 `-11002` 错误），必须将这些调用全部迁移到 DS 侧。客户端需要读写数据时，通过第四步的 Remote 通信向 DS 发起请求。

### 第六步：双端联调与验证
使用 DS 专属调试工具，勾选“启动服务器端”，在多端视角下验证逻辑一致性、权限拦截和数据同步是否正常。测试通过后即可完成上线。
