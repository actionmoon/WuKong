---
title: Singleplayer Design — Lua 版本
language: lua
description: 本文档汇总使用 Lua 实现单机模式的相关说明与代码示例索引。
---

# Singleplayer Design — Lua 路由

Lua 单机模式的**允许清单 + 禁用清单**。示例代码请查 Unity 官方文档（PlayerPrefs / JsonUtility / Object.Instantiate）。

> 领域铁律见 [SKILL.md](../../SKILL.md)。本 skill 范围内的 UGC 业务脚本（Lua/C# 通用，无需自判是否热更）在 Lua ↔ Unity 类型桥接前，须同级并列查沙箱清单：[../../references/raw/sandbox/SDK API白名单.md](../../references/API%E7%99%BD%E5%90%8D%E5%8D%95.md) + [../../references/raw/sandbox/SDK API黑名单.md](../../references/API%E9%BB%91%E5%90%8D%E5%8D%95.md)。

---

## Lua 侧允许 API 速查

### 生命周期（普通 Lua 脚本，不是 DouyinScript）

| 函数 | 说明 |
|------|------|
| `Awake()` | 对象创建时 |
| `Start()` | 第一帧前 |
| `Update()` | 每帧 |
| `FixedUpdate()` | 物理帧 |
| `LateUpdate()` | Update 后 |
| `OnDestroy()` | 销毁前 |
| `OnEnable()` / `OnDisable()` | 启用/禁用 |

### 本地存储

| API | 说明 |
|------|------|
| `CS.UnityEngine.PlayerPrefs.SetInt/Float/String` | 键值写 |
| `CS.UnityEngine.PlayerPrefs.GetInt/Float/String` | 键值读 |
| `CS.UnityEngine.PlayerPrefs.Save` | 强制落盘 |
| `CS.System.IO.File.WriteAllText / ReadAllText` | JSON/文本文件 |
| `CS.UnityEngine.Application.persistentDataPath` | 存档目录 |

### 对象与组件

| API | 说明 |
|------|------|
| `CS.UnityEngine.Object.Instantiate(prefab, pos?, rot?)` | 创建实例 |
| `CS.UnityEngine.Object.Destroy(go, delay?)` | 销毁 |
| `go:GetComponent(typeof(CS.UnityEngine.UI.Button))` | 获取组件（走白名单） |

> **JSON 序列化建议**：Lua 项目遵循 [../../references/Manual/Ⅲ.%20逻辑与脚本%28Logic%26Scripting%29/编码约束与开发规范.md](../../references/Manual/Ⅲ.%20逻辑与脚本%28Logic%26Scripting%29/编码约束与开发规范.md)，使用 `dkjson`；不要直接 `require("cjson")`。

---

## Lua 侧禁用 API（黑名单）

| 分类 | 禁用 |
|------|------|
| 同步变量 | `---@varSync` / `SetValue` / `GetValue` / `OnValueChange` |
| 消息 | `self:SendMessageToOwner/All/Target/Others` |
| 主权/控制权 | `self:HasOwnership` / `self:RequestOwnership` / `self:HasControllership` |
| 网络生命周期 | `OnNetSpawned` / `OnNetDestroy` |
| 网络对象 | `DouyinObjectService.NetSpawn` / `DouyinObjectService.NetDestroy` / `DouyinActor.NetSpawn` |
| 网络服务 | `DouyinNetService` / `DouyinActorService.*` / `isNetworkSettled` |
| 数据存储 | `DATASTORE()` / `DouyinDataService.GetDataStore` / `DouyinDataStore:*` |

---

## Layer 2 路由表

### 迁移到联网时的参考（Lua 实操）

| 主题 | 本地路径 | WebSearch 关键字 |
|------|---------|-----------------|
| 基础同步变量-Lua | [best-practice/网络通信/同步变量/基础同步变量-Lua.md](../../references/Best%20Practice/%E7%BD%91%E7%BB%9C%E9%80%9A%E4%BF%A1/%E5%90%8C%E6%AD%A5%E5%8F%98%E9%87%8F/%E5%9F%BA%E7%A1%80%E5%90%8C%E6%AD%A5%E5%8F%98%E9%87%8F-Lua.md) | `Hamlet 基础同步变量 Lua varSync` |
| 数据存储 DataStore-Lua | [best-practice/数据库/数据存储DataStore-Lua.md](../../references/Best%20Practice/%E6%95%B0%E6%8D%AE%E5%BA%93/%E6%95%B0%E6%8D%AE%E5%AD%98%E5%82%A8DataStore-Lua.md) | `Hamlet 数据存储 DataStore Lua` |
| 主权-Lua | [best-practice/主权/主权-Lua.md](../../references/Best%20Practice/%E4%B8%BB%E6%9D%83/%E4%B8%BB%E6%9D%83-Lua.md) | `Hamlet 主权 Lua HasOwnership` |
| SharedMode 房间对象动态创建-Lua | [best-practice/网络通信/动态创建/SharedMode - 房间对象的动态创建 - Lua.md](../../references/Best%20Practice/%E7%BD%91%E7%BB%9C%E9%80%9A%E4%BF%A1/%E5%8A%A8%E6%80%81%E5%88%9B%E5%BB%BA/SharedMode%20-%20%E6%88%BF%E9%97%B4%E5%AF%B9%E8%B1%A1%E7%9A%84%E5%8A%A8%E6%80%81%E5%88%9B%E5%BB%BA%20-%20Lua.md) | `Hamlet SharedMode 房间对象 动态创建 Lua` |

### Lua 项目横切约定

| 主题 | 本地路径 |
|------|---------|
| dkjson / self: / 跨脚本调用 / 日志前缀 | [../../references/Manual/Ⅲ.%20逻辑与脚本%28Logic%26Scripting%29/编码约束与开发规范.md](../../references/Manual/Ⅲ.%20逻辑与脚本%28Logic%26Scripting%29/编码约束与开发规范.md) |
| SDK API 白名单（UGC 业务脚本允许清单，Lua/C# 同守） | [../../references/raw/sandbox/SDK API白名单.md](../../references/API%E7%99%BD%E5%90%8D%E5%8D%95.md) |
| SDK API 黑名单（UGC 业务脚本禁止清单，Lua/C# 同守） | [../../references/raw/sandbox/SDK API黑名单.md](../../references/API%E9%BB%91%E5%90%8D%E5%8D%95.md) |
