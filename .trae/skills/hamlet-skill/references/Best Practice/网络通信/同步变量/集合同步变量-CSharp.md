# 集合同步变量（C#）最佳实践

> 💡 **理论与机制指引**：关于集合同步变量的类型限制（如 C# 专属的不支持 bool 等限制）、与基础同步变量的回调差异，以及相关避坑指南，请参考手册：[同步变量.md](../../../Manual/Ⅳ.%20多人游戏与网络%28Multiplayer%29/数据与通信/同步变量.md)。
> 本文仅提供集合同步变量在 C# 侧开发时的标准代码骨架。

---

## 1. 最小可用集合同步变量骨架

```csharp
using Douyin.Netcode;
using UnityEngine;

public class Board : NetworkBehaviour
{
    // 1. 声明集合同步变量
    private NetworkList<int> listSync = new();
    private NetworkDictionary<int, string> dictionarySync = new();

    public override void OnNetworkSpawn()
    {
        base.OnNetworkSpawn();

        // 2. 集合的 handler 带 event 参数
        listSync.OnValueChanged += evt =>
        {
            Debug.Log($"listSync changed: action={evt.Action}, count={listSync.Count}");
            for (int i = 0; i < listSync.Count; i++)
            {
                Debug.Log($"  index={i} value={listSync[i]}");
            }
        };

        dictionarySync.OnValueChanged += evt =>
        {
            Debug.Log($"dictionarySync changed: action={evt.Action}, count={dictionarySync.Count}");
            foreach (var kv in dictionarySync)
            {
                Debug.Log($"  key={kv.Key} value={kv.Value}");
            }
        };
    }

    // 3. 业务触发入口：处理主权方与非主权方的写入逻辑
    public void TryAppendListItem(int v)
    {
        if (!IsOwner)
        {
            // 非主权方：通过 Rpc 转发
            TryAppendListItemRpc(v);
            return;
        }
        // 主权方追加，触发全端 OnValueChanged
        listSync.Add(v);
    }

    [Rpc(SendTo.Owner)]
    private void TryAppendListItemRpc(int v)
    {
        if (!IsOwner) return;
        listSync.Add(v);
    }

    public void TrySetDictItem(int key, string val)
    {
        if (!IsOwner)
        {
            TrySetDictItemRpc(key, val);
            return;
        }
        // 主权方新增或覆盖
        dictionarySync[key] = val;
    }

    [Rpc(SendTo.Owner)]
    private void TrySetDictItemRpc(int key, string val)
    {
        if (!IsOwner) return;
        dictionarySync[key] = val;
    }
}
```

---

## 2. 使用完整变化事件精细响应

C# 侧不需要业务缓存快照，直接读 `evt.Action / evt.Index / evt.Value / evt.PreviousValue` 即可精准感知。

```csharp
using Douyin.Netcode;
using UnityEngine;

public class DiffRenderer : NetworkBehaviour
{
    private NetworkList<int> listSync = new();

    public override void OnNetworkSpawn()
    {
        base.OnNetworkSpawn();

        listSync.OnValueChanged += evt =>
        {
            switch (evt.Action)
            {
                case NetworkListEventAction.Add:
                    // Insert 也会触发 Add；evt.Index 指示落地位置
                    OnItemAdded(evt.Index, evt.Value);
                    break;

                case NetworkListEventAction.Remove:
                    // RemoveAt 也会触发 Remove
                    OnItemRemoved(evt.Index, evt.PreviousValue);
                    break;

                case NetworkListEventAction.ValueChange:
                    // listSync[i] = v
                    OnItemChanged(evt.Index, evt.PreviousValue, evt.Value);
                    break;

                case NetworkListEventAction.Clear:
                    // Clear 只触发一次
                    OnCleared();
                    break;
            }
        };
    }

    private void OnItemAdded(int index, int value) => Debug.Log($"added @ {index}: {value}");
    private void OnItemRemoved(int index, int previous) => Debug.Log($"removed @ {index}: {previous}");
    private void OnItemChanged(int index, int oldV, int newV) => Debug.Log($"changed @ {index}: {oldV} -> {newV}");
    private void OnCleared() => Debug.Log("cleared");
}
```

---

## 3. 排行榜/状态表（Dictionary 典型业务）

以玩家 openId（string）作为 key，同步玩家在房间内的分数。

```csharp
using Douyin.Netcode;
using UnityEngine;

// 需要继承 DouyinMonoBehaviour 才能覆写 OnPlayerLeft
public class ScoreBoard : DouyinMonoBehaviour
{
    private NetworkDictionary<string, int> scoreBoard = new();

    public override void OnNetworkSpawn()
    {
        base.OnNetworkSpawn();

        scoreBoard.OnValueChanged += evt =>
        {
            RefreshScoreboardUi();   // 表现层：所有端刷新 UI
        };

        RefreshScoreboardUi();       // 首次进入也主动刷新一次
    }

    // 任意端触发分数变化
    public void OnPlayerScoreChanged(string openId, int newScore)
    {
        if (!IsOwner)
        {
            OnPlayerScoreChangedRpc(openId, newScore);
            return;
        }
        scoreBoard[openId] = newScore;
    }

    [Rpc(SendTo.Owner)]
    private void OnPlayerScoreChangedRpc(string openId, int newScore)
    {
        if (!IsOwner) return;
        scoreBoard[openId] = newScore;
    }

    // 主权方负责清理离房玩家的残留数据
    public override void OnPlayerLeft(DouyinPlayer player, PlayerLeftEvent evt)
    {
        base.OnPlayerLeft(player, evt);
        if (!IsOwner) return;
        if (scoreBoard.ContainsKey(player.openId))
        {
            scoreBoard.Remove(player.openId);
        }
    }

    private void RefreshScoreboardUi()
    {
        // ...表现层逻辑
    }
}
```
