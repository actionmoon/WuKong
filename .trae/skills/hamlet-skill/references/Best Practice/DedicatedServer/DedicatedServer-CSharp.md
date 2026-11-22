# C# 版本 Dedicated Server 落地实操

> 本文提供 C# 侧 Dedicated Server 模式下服务端启动入口、ServerSpawn 以及通用请求套路的代码骨架。
> 相关的理论概念、避坑指南及 API 规则请参阅 Manual 目录下的《网络模型-Dedicated Server》。

## 一、 最小可用的 DS 服务脚本

将以下脚本文件放在 `ServerScripts/` 目录下，并挂载到场景中 `DouyinServerRoot` 节点下。

```csharp
// 放在 ServerScripts/ServerBoot.cs
using Douyin.Netcode;
using UnityEngine;

public class ServerBoot : DouyinMonoBehaviour
{
    private void Start()
    {
        if (!DouyinApplication.isServer) return;

        Debug.Log("DS ServerBoot: 服务器脚本启动");
    }

    public override void OnPlayerJoined(DouyinPlayer player, PlayerJoinEvent evt)
    {
        base.OnPlayerJoined(player, evt);
        
        // ⚠️ 过滤掉 DS 虚拟服务器 Player
        if (player.isServer) return;
        
        Debug.Log($"DS ServerBoot: 玩家加入 {player.playerOpenID}");
    }

    public override void OnPlayerLeft(DouyinPlayer player, PlayerLeftEvent evt)
    {
        base.OnPlayerLeft(player, evt);
        
        // ⚠️ 过滤掉 DS 虚拟服务器 Player
        if (player.isServer) return;
        
        Debug.Log($"DS ServerBoot: 玩家离开 {player.playerOpenID}");
    }
}
```

## 二、 ServerSpawn / ServerDestroy 完整流程

展示服务器端专属网络对象的生成（四种重载变体）与销毁。

```csharp
// 放在 ServerScripts/ServerSpawnDemo.cs
using System.Collections.Generic;
using UnityEngine;

public class ServerSpawnDemo : MonoBehaviour
{
    // 记录已生成的服务器专属对象，便于统一销毁
    private readonly List<GameObject> serverObjs = new();

    private void Start()
    {
        if (!DouyinApplication.isServer) return;

        ServerCreateNetObj_1();
        ServerCreateNetObj_2();
        ServerCreateNetObj_3();
        ServerCreateNetObj_4();
    }

    private void Update()
    {
        if (Input.GetKeyDown(KeyCode.Alpha1))
        {
            ServerDestroyNetObjs();
        }
    }

    // 变体一：默认位姿
    private void ServerCreateNetObj_1()
    {
        var go = DouyinObjectService.ServerSpawn("NetObj_1", out int id, (spawned, spawnedId) =>
        {
            Debug.Log($"ServerSpawn 变体1 回调, netObj:{spawned.name} id:{spawnedId}");
        });
        if (go != null)
        {
            serverObjs.Add(go);
            Debug.Log($"ServerSpawn 变体1 同步返回, id={id}");
        }
    }

    // 变体二：指定位置
    private void ServerCreateNetObj_2()
    {
        var go = DouyinObjectService.ServerSpawn(
            "NetObj_1", new Vector3(1, 0, 0), out int id, (spawned, spawnedId) =>
            {
                Debug.Log($"ServerSpawn 变体2 回调, netObj:{spawned.name} id:{spawnedId}");
            });
        if (go != null) serverObjs.Add(go);
    }

    // 变体三：位置 + 欧拉角
    private void ServerCreateNetObj_3()
    {
        var go = DouyinObjectService.ServerSpawn(
            "NetObj_1", new Vector3(2, 0, 0), new Vector3(45, 45, 45), out int id, (spawned, spawnedId) =>
            {
                Debug.Log($"ServerSpawn 变体3 回调, netObj:{spawned.name} id:{spawnedId}");
            });
        if (go != null) serverObjs.Add(go);
    }

    // 变体四：位置 + 四元数
    private void ServerCreateNetObj_4()
    {
        var go = DouyinObjectService.ServerSpawn(
            "NetObj_1", new Vector3(3, 0, 0), Quaternion.identity, out int id, (spawned, spawnedId) =>
            {
                Debug.Log($"ServerSpawn 变体4 回调, netObj:{spawned.name} id:{spawnedId}");
            });
        if (go != null) serverObjs.Add(go);
    }

    // 反向遍历删除，避免打乱下标
    private void ServerDestroyNetObjs()
    {
        for (int i = serverObjs.Count - 1; i >= 0; i--)
        {
            var netObj = serverObjs[i];
            DouyinObjectService.ServerDestroy(netObj);
            serverObjs.RemoveAt(i);
        }
        Debug.Log("ServerDestroy 全部销毁完成");
    }
}
```

## 三、 客户端请求服务器生成对象的通用套路

客户端没有权限直接生成对象，需通过 `DouyinRemoteEvent` 告知服务器代为生成。

**1. 客户端脚本（放 `GameScripts/`）**：
```csharp
// 放在 GameScripts/SpawnRequestSender.cs
using UnityEngine;

public class SpawnRequestSender : MonoBehaviour
{
    // ⚠️ 必须是类字段，不能是方法内局部变量（会被 GC 释放）
    private DouyinRemoteEvent spawnReqEvent = new("ReqServerSpawn");

    public void RequestSpawn(Vector3 pos)
    {
        if (DouyinApplication.isServer) return;
        spawnReqEvent.FireServer(pos.x, pos.y, pos.z);
    }

    private void OnDestroy()
    {
        spawnReqEvent?.Dispose();
        spawnReqEvent = null;
    }
}
```

**2. 服务器脚本（放 `ServerScripts/`）**：
```csharp
// 放在 ServerScripts/SpawnRequestReceiver.cs
using UnityEngine;

public class SpawnRequestReceiver : MonoBehaviour
{
    private DouyinRemoteEvent spawnReqEvent = new("ReqServerSpawn");

    private void Start()
    {
        if (DouyinApplication.isServer)
        {
            spawnReqEvent.onServerEvent.AddListener(OnClientRequestSpawn);
        }
    }

    private void OnClientRequestSpawn(DouyinPlayer player, params object[] args)
    {
        // ⚠️ 必须过滤服务器自身
        if (player == null || player.isServer) return;
        if (args.Length < 3) return;

        float x = System.Convert.ToSingle(args[0]);
        float y = System.Convert.ToSingle(args[1]);
        float z = System.Convert.ToSingle(args[2]);

        // 业务侧鉴权：例如冷却检查、位置合法性
        if (!CanPlayerSpawn(player)) return;

        var go = DouyinObjectService.ServerSpawn(
            "NetObj_1", new Vector3(x, y, z), out int id);
        if (go != null)
        {
            Debug.Log($"服务端为玩家 {player.playerOpenID} 生成对象 id={id}");
        }
    }

    private bool CanPlayerSpawn(DouyinPlayer player) => true;   // 业务规则

    private void OnDestroy()
    {
        if (DouyinApplication.isServer)
        {
            spawnReqEvent.onServerEvent.RemoveListener(OnClientRequestSpawn);
        }
        spawnReqEvent?.Dispose();
        spawnReqEvent = null;
    }
}
```
