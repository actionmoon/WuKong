---
title: Singleplayer Design — C# 版本
language: csharp
description: 本文档汇总使用 C# 实现单机模式的相关说明与代码示例索引。
---

# Singleplayer Design — C# 路由

C# 单机模式的**允许清单 + 禁用清单**。示例代码请查 Unity 官方文档（PlayerPrefs / JsonUtility / ScriptableObject / Object.Instantiate）。

> 领域铁律见 [SKILL.md](../../SKILL.md)。判定"是否属于单机代码"：脚本继承 `MonoBehaviour`（**不是** `NetworkBehaviour`）、Prefab **未挂** `NetworkObject`、且不 `using Douyin.Netcode`。

---

## C# 侧允许 API 速查

### 基类与命名空间

| 项 | 用法 |
|----|------|
| 脚本基类 | `MonoBehaviour`（**不用** `NetworkBehaviour` / `DouyinMonoBehaviour`） |
| 命名空间 | `using UnityEngine;`（**不 import** `Douyin.Netcode` / `Douyin.DataStore`） |
| Prefab 组件 | ✅ Unity 原生组件；❌ **不挂** `NetworkObject` |

### 生命周期（Unity 原生）

| 方法 | 说明 |
|------|------|
| `Awake()` | 对象创建时 |
| `Start()` | 第一帧前 |
| `OnEnable()` / `OnDisable()` | 启用 / 禁用 |
| `Update()` | 每帧 |
| `FixedUpdate()` | 物理帧 |
| `LateUpdate()` | Update 后 |
| `OnDestroy()` | 销毁前 |

### 本地存储

| API | 说明 |
|-----|------|
| `PlayerPrefs.SetInt / SetFloat / SetString` | 键值写 |
| `PlayerPrefs.GetInt / GetFloat / GetString` | 键值读 |
| `PlayerPrefs.Save()` | 强制落盘 |
| `JsonUtility.ToJson(obj)` / `FromJson<T>(json)` | 结构化存档（对应 Lua 侧 `dkjson`） |
| `System.IO.File.WriteAllText` / `ReadAllText` | 文本 / JSON 文件 |
| `Application.persistentDataPath` | 存档目录 |
| `[CreateAssetMenu]` + `ScriptableObject` | 静态配置资产 |

> **JSON 序列化建议**：C# 内建 `JsonUtility` 已覆盖大部分场景；复杂嵌套 / 字典建议使用 `Newtonsoft.Json`（工程内可用）。

### 对象与组件

| API | 说明 |
|-----|------|
| `Object.Instantiate(prefab, pos?, rot?)` | 创建实例 |
| `Object.Destroy(go, delay?)` | 销毁 |
| `GetComponent<T>()` / `GetComponentInChildren<T>()` / `GetComponentInParent<T>()` | 组件访问 |
| `FindObjectOfType<T>()` / `FindObjectsOfType<T>()` | 全局查找（谨慎使用，性能敏感） |

---

## C# 侧禁用 API（黑名单）

| 分类 | 禁用 API |
|------|---------|
| 脚本基类 | `NetworkBehaviour` / `DouyinMonoBehaviour` |
| 网络组件 | `NetworkObject`（Prefab 上禁挂载） |
| 同步变量 | `NetworkVariable<T>` / `NetworkList<T>` / `NetworkDictionary<K,V>` / `OnValueChanged` |
| RPC | `[Rpc]` / `SendTo.*` / `RpcTarget` / `RpcParams` |
| 主权 / 控制权 | `IsOwner` / `RequestOwnership()` / `OnGainedOwnership` / `OnLostOwnership` / `OnOwnershipChanged` / `OnControllershipTransferred` |
| 网络生命周期 | `OnNetworkSpawn` / `OnNetworkDespawn` / `NetworkObjectId` / `IsSpawned` / `isNetworkSettled` |
| 动态生成 | `DouyinObjectService.NetSpawn / NetDestroy / ServerSpawn / ServerDestroy` / `DouyinActor.NetSpawn` / `DouyinPlayer.NetSpawn` |
| 网络服务 | `DouyinNetService.*` / `DouyinPlayerService.*` / `DouyinActorService.*` |
| 数据存储 | `Douyin.DataStore.*` / `DataStoreService.Instance.*` / `IKeyValueStore` / `IOrderedStore` |
| DS 远程通信 | `DouyinRemoteEvent` / `DouyinRemoteFunction` |
| 命名空间 | `using Douyin.Netcode` / `using Douyin.DataStore` / `using Douyin` 下的网络类型 |

---

## Layer 2 路由表

### C# 单机 → 联网迁移参考（C# 实操）

| 主题 | 本地路径 | WebSearch 关键字 |
|------|---------|-----------------|
| 基础同步变量-CSharp | [best-practice/网络通信/同步变量/基础同步变量-CSharp.md](../../references/Best%20Practice/%E7%BD%91%E7%BB%9C%E9%80%9A%E4%BF%A1/%E5%90%8C%E6%AD%A5%E5%8F%98%E9%87%8F/%E5%9F%BA%E7%A1%80%E5%90%8C%E6%AD%A5%E5%8F%98%E9%87%8F-CSharp.md) | `Hamlet NetworkVariable CSharp OnValueChanged` |
| 数据存储 DataStore-CSharp | [best-practice/数据库/数据存储DataStore-CSharp.md](../../references/Best%20Practice/%E6%95%B0%E6%8D%AE%E5%BA%93/%E6%95%B0%E6%8D%AE%E5%AD%98%E5%82%A8DataStore-CSharp.md) | `Hamlet 数据存储 DataStore CSharp` |
| 主权-CSharp | [best-practice/主权/主权-CSharp.md](../../references/Best%20Practice/%E4%B8%BB%E6%9D%83/%E4%B8%BB%E6%9D%83-CSharp.md) | `Hamlet 主权 CSharp IsOwner RequestOwnership` |
| ShareMode 房间对象动态创建-CSharp | [best-practice/网络通信/动态创建/ShareMode - 房间对象的动态创建 - CSharp.md](../../references/Best%20Practice/%E7%BD%91%E7%BB%9C%E9%80%9A%E4%BF%A1/%E5%8A%A8%E6%80%81%E5%88%9B%E5%BB%BA/ShareMode%20-%20%E6%88%BF%E9%97%B4%E5%AF%B9%E8%B1%A1%E7%9A%84%E5%8A%A8%E6%80%81%E5%88%9B%E5%BB%BA%20-%20CSharp.md) | `Hamlet ShareMode NetSpawn CSharp` |
| 基础 RPC 通信-CSharp | [best-practice/网络通信/RPC/基础RPC通信-CSharp.md](../../references/Best%20Practice/%E7%BD%91%E7%BB%9C%E9%80%9A%E4%BF%A1/RPC/%E5%9F%BA%E7%A1%80RPC%E9%80%9A%E4%BF%A1-CSharp.md) | `Hamlet Rpc SendTo CSharp` |

### 概念参考（迁移时使用，Lua/C# 共用）

| 主题 | 本地路径 | WebSearch 关键字 |
|------|---------|-----------------|
| 网络对象生命周期 | [best-practice/网络通信/动态创建/网络对象.md](../../references/Manual/%E2%85%A3.%20%E5%A4%9A%E4%BA%BA%E6%B8%B8%E6%88%8F%E4%B8%8E%E7%BD%91%E7%BB%9C%28Multiplayer%29/%E7%BD%91%E7%BB%9C%E5%9F%BA%E7%A1%80/%E7%BD%91%E7%BB%9C%E5%AF%B9%E8%B1%A1%E7%9A%84%E5%8A%A8%E6%80%81%E5%88%9B%E5%BB%BA.md) | `Hamlet 网络对象 NetworkObject` |
| 主权和控制权 | [best-practice/主权/主权和控制权.md](../../references/Manual/%E2%85%A3.%20%E5%A4%9A%E4%BA%BA%E6%B8%B8%E6%88%8F%E4%B8%8E%E7%BD%91%E7%BB%9C%28Multiplayer%29/%E7%BD%91%E7%BB%9C%E5%9F%BA%E7%A1%80/%E4%B8%BB%E6%9D%83%E4%B8%8E%E6%8E%A7%E5%88%B6%E6%9D%83.md) | `Hamlet 主权 控制权 Ownership` |
| 同步变量总览 | [best-practice/网络通信/同步变量/同步变量.md](../../references/Manual/%E2%85%A3.%20%E5%A4%9A%E4%BA%BA%E6%B8%B8%E6%88%8F%E4%B8%8E%E7%BD%91%E7%BB%9C%28Multiplayer%29/%E6%95%B0%E6%8D%AE%E4%B8%8E%E9%80%9A%E4%BF%A1/%E5%90%8C%E6%AD%A5%E5%8F%98%E9%87%8F.md) | `Hamlet 同步变量 varSync NetworkVariable` |
| RPC 通信总览 | [best-practice/网络通信/RPC/RPC通信.md](../../references/Manual/%E2%85%A3.%20%E5%A4%9A%E4%BA%BA%E6%B8%B8%E6%88%8F%E4%B8%8E%E7%BD%91%E7%BB%9C%28Multiplayer%29/%E6%95%B0%E6%8D%AE%E4%B8%8E%E9%80%9A%E4%BF%A1/RPC/RPC%20%E6%A6%82%E8%BF%B0.md) | `Hamlet RPC 通信` |
| DedicatedServer 架构 | [best-practice/DedicatedServer/DedicatedServer.md](../../references/Manual/%E2%85%A3.%20%E5%A4%9A%E4%BA%BA%E6%B8%B8%E6%88%8F%E4%B8%8E%E7%BD%91%E7%BB%9C%28Multiplayer%29/%E7%BD%91%E7%BB%9C%E6%A8%A1%E5%9E%8B/%E7%BD%91%E7%BB%9C%E6%A8%A1%E5%9E%8B-Dedicated%20Server.md) | `Hamlet DedicatedServer 中心化` |

### 相关兄弟 skill（迁移到联网时的领域入口）

| 主题 | 本地路径 |
|------|---------|
| 网络设计（同步变量 / RPC / 动态创建 C# 索引） | [network-design/csharp.md](../network-design/csharp.md) |
| 主权设计 | [ownership-design/csharp.md](../ownership-design/csharp.md) |
| 生命周期设计 | [lifecycle-design/common.md](../lifecycle-design/common.md) |
| 数据存储设计 | [database-design/csharp.md](../database-design/csharp.md) |
