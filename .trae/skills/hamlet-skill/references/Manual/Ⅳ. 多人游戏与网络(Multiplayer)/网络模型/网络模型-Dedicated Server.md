# 网络模型 - Dedicated Server (DS) 模式

**Dedicated Server（DS）** 是 Douyin World 提供的**独立服务器联网模式**。在 DS 模式下，房间里除了每个玩家的客户端之外，还多了一个**由官方托管的独立服务器进程**。
核心业务判定、防作弊逻辑与数据存储都在这个服务器上执行，客户端只负责表现与操作提交。

## 一、 核心概念与数据校验

- **逻辑分离**：强烈建议将所有关键玩法和关键逻辑在服务端执行，客户端不参与任何涉及安全风险的核心判定。
- **不可见性与防作弊**：服务端脚本和服务器专属网络对象（`DouyinServerRoot` 节点下的对象）对客户端**完全不可见**（打客户端 AssetBundle 时会被物理剔除）。因此，诸如掉落概率、伤害系数、反作弊阈值等核心参数无法被客户端读取或篡改，天然具备极强的防作弊能力。
- **服务器虚拟玩家**：DS 启动时框架会插入一个"服务器 Player"以方便走统一的 `PlayerService` 调度通道。在 `OnPlayerJoined/Left` 等回调中，**必须**使用 `player.isServer` 过滤掉这个虚拟玩家，避免把它当成真实玩家去执行业务判定（如计入排行榜、发奖励等）。

## 二、 脚本组织与特定端执行

DS 模式的核心约束是“**服务器专属代码不能被客户端看到/加载**”。

> **适用范围**：当 [hamlet-preferences.md](../../../../hamlet-preferences.md) 中 `DevTool=UnityEditor` 时阅读。
> `DevTool` 的详细说明请参考[开发工具概述](../../VI.%20开发工具/开发工具概述.md)。

- **Lua 脚本**：`DouyinServerScriptLoader` 目录下的脚本**只有服务器可用**。`DouyinScriptLoader` 下的脚本为双端共享。**关键约束：同一个 `.lua` 文件不能同时放到两个 Loader 里，二者互斥。**
- **C# 脚本**：C# 侧使用**双程序集架构**。`ServerScripts` 目录下的代码编译到服务器专属程序集 `DouyinServerScripts`。`GameScripts` 目录下的代码为共享程序集。**关键约束：`GameScripts` 中的代码不允许访问 `DouyinServerScripts` 程序集中的类型，否则会引发编译报错或客户端裁剪失败。**
- **C# 独有配置 `enableCSharp`**：默认关闭。需要打开 `Packages/com.douyin.world/Config/simulator.json`，将 `enableCSharp` 改为 `true` 并重启 Unity Editor，否则 C# 服务器脚本不会被加载。

如果希望某段代码“仅在服务器执行”，有以下三种做法：
1. 脚本挂到 `DouyinServerRoot` 节点下。
2. 用 `DouyinObjectService.ServerSpawn` 创建服务器专属网络对象。
3. 在双端共享脚本中使用 `if DouyinApplication.isServer` 做运行时分派。
> **⚠️ 注意**：不存在“只在客户端执行、服务器端不执行”的代码机制。客户端可见的代码路径，服务器也一定会执行到；如果需要屏蔽服务器执行，同样只能用 `if not DouyinApplication.isServer` 做拦截。

## 三、 主权分配规则

- **默认归属**：服务端拥有所有网络对象的默认主权（除了玩家控制的 Actor 角色）。
- **客户端请求**：由 DS 端调用 `NetSpawn` 创建的房间对象，初始主权归 DS，客户端可以请求主权（默认放行），业务侧需自行决定是否 `return false` 拒绝。
- **主权转移阻塞免除**：与 Shared Mode 不同，因为 DS 端网络始终稳定，DS 持有的主权**不存在**“主权方掉线导致对象暂时不可修改”的阻塞问题。

## 四、 服务器专属对象与生成销毁

- `DouyinObjectService.ServerSpawn`：生成的对象自动挂在 `DouyinServerRoot` 下，**仅服务端可见**，客户端无对应实例。常用于服务器后台任务或隐形状态机。
  - **语言差异**：
    - **C#**：同步返回 `GameObject`，方法重载必须带 `out int id` 参数，`onSpawn` 回调为可选。
    - **Lua**：无返回值（`void`），必须通过回调 `onFinish(netObj, netObjId)` 获取生成的对象引用。
  - **调用限制**：只能在服务器端调用，客户端调用无效（C# 中会返回 `null` 并打印错误日志）。若需客户端触发生成，需通过 Remote 通信请求服务器代为生成。
  > **⚠️ 物理约束**：生成的对象**必须不带 Rigidbody** 等物理组件。否则服务端发生碰撞改变了位置，而客户端因无此对象未发生碰撞，会导致严重的跨端位置不同步。
- `DouyinObjectService.ServerDestroy`：销毁上述专属对象，**只能在服务器端调用**。

## 五、 网络通信机制

DS 模式下，客户端与服务器之间**绝对不能**用 `SendMessageToXxx`（那是玩家间的消息通道），必须使用专用的 RPC 对象：
- **DouyinRemoteEvent**：异步单向通信。用于客户端提交操作或服务器广播状态变更。
  - `FireServer` (C→S)
  - `FireClient` (S→C，发给单人)
  - `FireAllClients` (S→C，发给所有人)
- **DouyinRemoteFunction**：异步双向通信。用于客户端请求服务器并等待结果回调（如：“我能不能买这个道具？”）。
  - `InvokeServer` (C→S)
  - `InvokeClient` (S→C)

> **⚠️ 通信约束**：
> 1. 参数**只支持基础类型**（如 bool、int、float、string），不支持 table、List、自定义 class 等复杂对象。
> 2. `RemoteEvent/Function` **不能定义为方法内的局部变量**，否则会随 GC 释放导致监听失效。

## 六、 数据存储 (DataStore) 强约束

在 DS 模式下，数据存储（DataStore / OrderedDataStore）有**唯一位置约束**：
- **所有的** DataStore API 必须**只在 DS 服务器脚本**上调用。
- 如果在客户端脚本中调用数据存储 API，会上报 `-11002` 错误码。
- **业务模式**：客户端需要读写数据存储时，必须通过 `DouyinRemoteEvent / DouyinRemoteFunction` 请求 DS，由 DS 代为读写并回传结果。

## 七、 适合的玩法场景

只要涉及以下任何一条，就**必须**选择 DS 模式：
- 强竞技类玩法，需要严格公平性保障。
- 抽奖/扭蛋玩法，随机结果必须由可信方生成。
- 排行榜奖励玩法，积分来源需经服务端校验防刷。
- 虚拟资产交易、道具付费购买等商业化核心流程。
- 任何“玩家获益行为”均需经服务端授权的玩法。
- 对数据存储/数据安全有高要求。

## 八、 常见问题 (FAQ)

**Q1：有没有只在客户端执行、服务器端不执行的代码？**
没有。客户端可见的代码在服务器上也会执行；只能用 `if not DouyinApplication.isServer` 做运行时拦截。

**Q2：`DouyinRemoteEvent / DouyinRemoteFunction` 的参数支持 table 或类吗？**
不支持。只支持基础数据类型。如果需要传复杂结构，请拆成多个基础参数或序列化为 JSON 字符串。

**Q3：服务器脚本的生命周期和房间生命周期一致吗？**
完全一致。房间创建时 DS 启动（触发 `Awake / Start`），房间销毁时 DS 退出。DS 也会收到 `OnPlayerLeft`（包括最后一个真实玩家离开），业务侧可以在此做房间结算。

**Q4：挂在 `DouyinServerRoot` 下的同步变量会同步到客户端吗？**
不会。因为该对象对客户端物理不存在。需要同步给客户端的状态请挂在 `DouyinWorldRoot` 下的网络对象上，或走 Remote 通信推送。

**Q5：为什么 DS 启动就报 `NetworkNetPacket_PlayerEnterSyncForOther Playerlnfos miss.`？**
因为 `DouyinServerRoot` 节点下没有挂载任何服务脚本。确保该节点下至少挂载了一个服务脚本即可解决。

**Q6：Remote 通信一定能到达接收方吗？**
不一定。网络抖动或接收方崩溃会导致消息丢失。`RemoteEvent` 完全不等待响应，`RemoteFunction` 虽然是双向但也依赖网络可靠性。**关键的核心结果**请务必通过同步变量进行传递。

## 九、 避坑指南 (Pitfalls)

### 1. 通用避坑
- **客户端调用 ServerSpawn / DataStore**：在客户端调用 `ServerSpawn` 无效（C# 返回 null）；调用 DataStore 会抛出 `-11002` 错误。必须通过 RPC 提交给服务器代为执行。
- **NetSpawn 的资产表挂错位置**：`NetSpawnObjectAsset` 如果挂在 `DouyinServerRoot` 上会导致 `NetSpawn` 找不到 Key。`NetSpawn` 的资产表必须挂在 `DouyinWorldRoot`，而 `ServerSpawn` 才使用 `DouyinServerRoot` 上的资产表。
- **Mac 下载的模拟器无法运行**：双击模拟器弹“损坏”或“移到废纸篓”时，需在终端执行 `sudo xattr -rd com.apple.quarantine 调试器路径.app`。

### 2. C# 特有避坑
- **ServerSpawn 忘写 out int id**：C# 侧 `ServerSpawn` 所有重载都要求传入 `out int id`（若不用可写 `out _`），否则会报编译错误。
- **服务端脚本基类选错**：
  - 如果只需要生命周期 `Start/Update`，请继承普通 `MonoBehaviour`。
  - 如果需要 SDK 事件（如 `OnPlayerJoined`），必须继承 `DouyinMonoBehaviour`，且对象**必须带 `NetworkObject` 组件**。
- **DouyinMonoBehaviour.Awake 的 NRE 异常**：该基类在 `Awake` 阶段依赖内部单例。若在“进房完成前”被执行（如单场景 Play），会报 `NullReferenceException`。若无需 SDK 回调，建议改继承 `NetworkBehaviour`。
- **DS 独占节点严禁挂 NetworkObject**：DS 独占对象若仅挂 `NetworkObject` 没挂 `DouyinNetworkGuid`，SDK 会将其错误当作客户端场景对象广播，导致客户端报 `GameObjectInfo miss` 错误。DS 专属节点如需稳定 GUID，请只挂 `DouyinNetworkGuid`。
- **房间共享布尔态推荐用 int 替代 bool**：由于 SDK 当前对 `NetworkVariable<bool>` 存在间歇性丢包 Bug，强烈建议 DS 侧布尔状态一律使用 `NetworkVariable<int>`，0 代表 false，1 代表 true。
- **DS 侧的 Actor 主控判定**：在 DS 上遍历 `DouyinActorService.GetActors()` 得到的对象，其 `isMasterMode` / `isLocal` 永远为 `false`（因为 DS 不是客户端）。DS 端仅做业务逻辑和状态校验，不要用上述字段判断主控。
