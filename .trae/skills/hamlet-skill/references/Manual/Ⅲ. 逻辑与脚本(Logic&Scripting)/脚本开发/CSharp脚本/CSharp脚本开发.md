# C# 脚本开发

除了 Lua，抖音虚拟世界 SDK 也支持使用 C# 作为脚本开发语言，极大地提升了服务端逻辑的严谨性和复杂工程的维护性，尤其在 **Dedicated Server (DS)** 模式下具有显著的优势。

## 一、 环境准备与开启 C# 支持

当前版本中，C# 脚本特性默认是关闭的。
1. 在项目目录中找到 `Packages/com.douyin.world/Config/simulator.json` 文件。
2. 将其中的 `enableCSharp` 字段修改为 `true`。
3. 重启 Unity Editor 使配置生效。

## 二、 工程目录架构：GameScripts 与 ServerScripts

导入 SDK 后，工程内会自动创建两个 C# 特殊目录。**你编写的 C# 脚本必须放置在这两个目录之一，否则打包时不会被识别。**

1. **`GameScripts` (客户端/共享代码)**
   - 放置客户端脚本以及与服务器共享的 C# 代码。
   - **严格限制**：该程序集中的代码**不能**访问 `ServerScripts` 程序集中的任何类型。因为在打包客户端包体会时，`ServerScripts` 会被物理裁剪掉，强行访问将导致编译报错。
2. **`ServerScripts` (Dedicated Server 专属代码)**
   - 专门用于放置 DS 服务端的校验与落库等后端逻辑。
   - 放置在此目录的代码对客户端完全隐藏，极大地提升了游戏核心资产的安全性。

## 三、 C# 脚本基础用法

### 1. 替代 Douyin Script 的 DouyinMonoBehaviour
在 C# 开发中，使用 `DouyinMonoBehaviour` 作为基类，它等同于 Lua 中的 `Douyin Script`，并补充了虚拟世界的专属生命周期：

```csharp
using UnityEngine;
namespace GameScripts
{
    public class GameMgr : DouyinMonoBehaviour
    {
        public override void OnActorSpawned(DouyinActor actor)
        {
            DouyinPlayer localPlayer = DouyinPlayerService.GetLocalPlayer();
            Debug.Log($"角色生成: {actor.actorID}");
        }

        public override void OnPlayerJoined(DouyinPlayer player, PlayerJoinEvent evt)
        {
            Debug.Log($"玩家加入: {player.playerID}");
        }
    }
}
```

### 2. Dedicated Server 的测试与组件隔离
- 场景中不仅需要添加 `DouyinWorldRoot`，还需要为服务端专属逻辑添加 **`DouyinServerRoot`** 组件。
- 挂载在 `DouyinServerRoot` 节点及其子节点下的对象和组件，**在客户端 AssetBundle 中会被自动剔除**，仅在 DS 服务器上保留运行。
- 在代码中可以通过判断 `DouyinApplication.isServer` 来验证当前是否运行在 DS 服务端。

## 四、 网络通信与数据同步 (Netcode)

C# 环境下的网络通信高度还原了 Unity Netcode 的体验，需引入 `Douyin.Netcode` 命名空间。

### 1. 同步变量 (NetworkVariable)
通过继承 `NetworkBehaviour` 并声明 `NetworkVariable`，可以轻松实现多端数据自动同步：
```csharp
using Douyin.Netcode;
namespace GameScripts
{
    public class UICountdown : NetworkBehaviour
    {
        // 声明一个网络同步变量
        private NetworkVariable<float> syncCountdown = new(120.0f);
        // 支持集合类型
        private NetworkList<string> syncListTest = new();  

        private void Start()
        {
            // 绑定变量变化时的回调
            syncCountdown.OnValueChanged = (oldVal, newVal) => {
                Debug.Log($"倒计时更新: {newVal}");
            };
        }

        public void Update()
        {
            // 只有拥有主权 (IsOwner) 的端才有权限修改值
            if (IsOwner && syncCountdown.Value > 0)
            {
                syncCountdown.Value -= Time.deltaTime;
            }
        }
    }
}
```
> **强制规则**：所有的 `NetworkBehaviour` 组件都必须处于某个 `NetworkObject` 对象的节点或子节点下。

### 2. RPC 通信
在 C# 中，可以直接使用 `[Rpc(SendTo.xxx)]` 特性来标记 RPC 函数，取代传统的 `DouyinRemoteEvent`：

```csharp
using Douyin.Netcode;
namespace GameScripts
{
    public class RPCTest : NetworkBehaviour
    {
        private void Update()
        {
            if (Input.GetKeyDown(KeyCode.Space))
            {
                // 调用 RPC 发送消息给对应目标
                SendMessageToEveryoneRpc("Hello World");
            }
        }

        // 发送给所有端（包括服务端和所有客户端）
        [Rpc(SendTo.Everyone)]
        void SendMessageToEveryoneRpc(string msg, RpcParams rpcParams = default)
        {
            Debug.Log($"收到RPC: {msg}, 发送者 ID: {rpcParams.SenderClientId}");
        }
        
        // 发送给指定的客户端 (单播)
        [Rpc(SendTo.SpecifiedInParams)]
        private void SendToSelectedRpc(string msg, RpcTarget rpcTarget, RpcParams rpcParams = default)
        {
            Debug.Log($"收到定向单播 RPC: {msg}");
        }
    }
}
```

#### 常用的 SendTo 枚举
- `Everyone`: 服务器和所有客户端。
- `Owner`: 仅发送到该 NetworkObject 的所有者端。
- `Server`: 仅发送给服务器。
- `SpecifiedInParams`: 指定接收者，需配合 `RpcTarget.Single(playerId)` 等参数使用。

## 五、 数据存储 API (DataStoreService)

在 C# (特别是 ServerScripts 中)，操作持久化数据存储需要使用异步任务 `Task` 结构，并且**建议包裹在 try-catch 块中防止异常崩溃**。

### 1. 通用键值对存储 (KVStore)
支持复杂的元数据和对象存储，适合用于玩家背包、装备等数据。
```csharp
using System.Threading.Tasks;

private async Task KVStoreTest()
{
    var client = DataStoreService.Instance;
    // 获取指定存储空间下的特定玩家数据存储
    var store = await client.GetKeyValueStoreAsync("PlayerInventory", "player001");
    
    // 写入数据
    await store.SetAsync("gold", 100);
    // 带有 metadata 的写入
    var options = new StoreWriteOptionsBuilder().AddMetadata("source", "task").Build();
    await store.SetAsync("reward_id", "seed_001", options);
    
    // 读取数据
    var gold = await store.GetAsync<long>("gold");
    // 安全读取
    var (found, missingGold) = await store.TryGetAsync<long>("gold_backup");
    
    // 原子增量操作
    var newGold = await store.IncrementAsync("gold", 5);
    // 移除数据
    await store.RemoveAsync<long>("gold");
}
```

### 2. 有序数据存储 (OrderedStore)
专为排行榜设计，仅支持数值型存储。
```csharp
private async Task OrderedStoreTest()
{
    var client = DataStoreService.Instance;
    var orderedStore = await client.GetOrderedStoreAsync("leaderboard", "season_1");
    
    await orderedStore.SetAsync("player_1001", 10);
    await orderedStore.SetAsync("player_1002", 20);
    
    var rankValue = await orderedStore.GetAsync("player_1001");
    
    // 按顺序分页遍历排行榜
    var rangeStore = (IOrderedRangeStore)orderedStore;
    var cursor = await rangeStore.ListSortedAsync(
        ascending: false, // 降序
        pageSize: 50,
        minValue: 0,
        maxValue: double.PositiveInfinity);

    for (var pageIndex = 0; pageIndex < cursor.PageCount; pageIndex++)
    {
        var page = await cursor.GetPageAsync(pageIndex);
        foreach (var item in page)
        {
            Debug.Log($"排行榜数据: key={item.Key}, value={item.Value}");
        }
    }
}
```

## 六、 主权管理机制 (Ownership)

针对挂载了 `NetworkObject` 的网络对象，C# 提供了完备的主权判定与交接 API。

### 1. 判断与请求主权
```csharp
public void Update()
{
    if (Input.GetKeyDown(KeyCode.F))
    {
        // 判断当前端是否拥有主权
        if (!IsOwner)
        {
            // 向服务器请求主权
            OwnershipRequestStatus status = NetworkObject.RequestOwnership();
            if (status == OwnershipRequestStatus.RequestSent) {
                Debug.Log("请求已发送");
            }
        }
    }
}
```

### 2. 监听主权事件
可以在继承 `NetworkBehaviour` 的组件中重写或监听主权变更事件：
```csharp
public override void OnGainedOwnership()
{
    base.OnGainedOwnership();
    Debug.Log("当前端已获得主权");
}

public override void OnLostOwnership()
{
    base.OnLostOwnership();
    Debug.Log("当前端已丢失主权");
}

public void Start()
{
    // 监听其他端发来的主权请求（若返回 false 则直接拒绝转移主权）
    NetworkObject.OnOwnershipRequested += (sequenceId) => { return true; };
    
    // 监听己方发起的主权请求结果
    NetworkObject.OnOwnershipRequestResponse += (succeed, msg) => {
        Debug.Log($"请求主权结果: {succeed}");
    };
}
```