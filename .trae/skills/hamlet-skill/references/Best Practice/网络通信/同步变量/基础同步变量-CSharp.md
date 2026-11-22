# 基础同步变量（C#）最佳实践

> 💡 **理论与机制指引**：关于同步变量的支持类型、生命周期窗口、完整触发链路以及 C# 专属坑点（如参数顺序、事件订阅方式等），请参考手册：[同步变量.md](../../../Manual/Ⅳ.%20多人游戏与网络%28Multiplayer%29/数据与通信/同步变量.md)。
> 本文仅提供基础同步变量在 C# 侧开发时的标准代码骨架。

---

## 1. 最小可用基础同步变量骨架

```csharp
using Douyin.Netcode;
using UnityEngine;

public class ScoreSync : NetworkBehaviour
{
    // 1. 类字段声明；IL 编织会自动注册
    private NetworkVariable<int> intValue = new(0);
    private NetworkVariable<Vector3> vectorValue = new(Vector3.zero);

    // 2. 统一在 OnNetworkSpawn 窗口中订阅监听
    public override void OnNetworkSpawn()
    {
        base.OnNetworkSpawn();

        // 基础值 handler 参数顺序：(oldVal, newVal)
        intValue.OnValueChanged += (oldVal, newVal) =>
        {
            Debug.Log($"intValue changed: {oldVal} -> {newVal}");
        };

        vectorValue.OnValueChanged += (oldVal, newVal) =>
        {
            Debug.Log($"vectorValue changed: {oldVal} -> {newVal}");
        };
    }

    // 3. 业务触发入口：处理主权方与非主权方的写入逻辑
    public void OnScoreChanged(int newScore)
    {
        if (!IsOwner)
        {
            // 非主权方：通过 Rpc 转发到主权方执行
            OnScoreChangedRpc(newScore);
            return;
        }
        
        // 主权方：直接写入，触发全端（含本端）的 OnValueChanged
        intValue.Value = newScore;
        vectorValue.Value = new Vector3(1, 2, 0);
    }

    [Rpc(SendTo.Owner)]
    private void OnScoreChangedRpc(int newScore)
    {
        // 二次校验：RPC 到达期间，主权可能已经迁移
        if (!IsOwner) return;
        
        intValue.Value = newScore;
        vectorValue.Value = new Vector3(1, 2, 0);
    }
}
```

---

## 2. 动态对象设置初始值（NetSpawn 窗口）

```csharp
// ================= 被创建的动态对象脚本 =================
using Douyin.Netcode;
using UnityEngine;

public class DynamicNetObj : NetworkBehaviour
{
    private NetworkVariable<string> ownerId = new("");
    private NetworkVariable<int> initScore = new(0);

    // 由创建端在 Spawn 前经由 gameObject 上的其它组件写入初值
    public string PendingOwnerId;   
    public int PendingInitScore;

    public override void OnNetworkSpawn()
    {
        base.OnNetworkSpawn();

        ownerId.OnValueChanged += (oldVal, newVal) => { /* 略 */ };
        initScore.OnValueChanged += (oldVal, newVal) => { /* 略 */ };

        // 由主权方（通常是创建者）在 OnNetworkSpawn 内根据 IsOwner 写入初值
        if (IsOwner)
        {
            ownerId.Value = PendingOwnerId;   // 会可靠地同步到所有客户端
            initScore.Value = PendingInitScore;
        }
    }
}

// ================= 创建端（主权方）业务逻辑 =================
// 创建端本地调用
DouyinObjectService.NetSpawn(key, position, rotation, go =>
{
    var script = go.GetComponent<DynamicNetObj>();
    script.PendingOwnerId = myOpenId;
    script.PendingInitScore = score;
    // 主权方进入 OnNetworkSpawn 时会把 Pending 字段写入同步变量
});
```
