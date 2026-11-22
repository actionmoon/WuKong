---
title: Database Design — C# 版本
language: csharp
description: 本文档汇总使用 C# 实现数据存储的相关说明与代码示例索引。
---

## 适用场景（什么时候读这个文件）

用 C# 写数据存储代码时，遇到以下场景读本文件：

- 实现玩家存档 / 读档、背包、进度、货币、道具数量等持久化数据
- 设计 DataStore 的 `Name / Scope / Key`，或控制 key / value 规模
- 实现排行榜、TopN、积分排名、排序分页
- 处理新号默认值、错误语义、并发更新、存储大小限制
- 判断 SharedMode / DedicatedServer 下数据存储应该在哪一端调用
- 存储对象或复杂结构，需要先序列化再落库

---

## 文档索引（以此表为准）

匹配到相关功能时，**必须先完整读取对应的参考文档**再开始编码。严禁凭记忆或拼凑现有 Demo 调用 API。

### 代码示例（确定功能后按 C# 读具体写法）

| 资料 | 路径 | 什么时候读 |
|---|---|---|
| 数据存储 DataStore-CSharp | [数据库/数据存储DataStore-CSharp.md](../../references/Best%20Practice/%E6%95%B0%E6%8D%AE%E5%BA%93/%E6%95%B0%E6%8D%AE%E5%AD%98%E5%82%A8DataStore-CSharp.md) | C# 键值存储的完整写法：`GetKeyValueStoreAsync`、`TryGetAsync`、`SetAsync`、`IncrementAsync`、异常处理、重试、复杂对象序列化、前缀分页和缓存。写键值存档 / 读档 / 计数器时读。漏读易犯：找不到 key 时用 `GetAsync` 走异常、`IncrementAsync` delta 写错类型、捕获到旧 `DataStoreException`、复杂对象未按文档序列化。 |
| 数据存储 OrderedDataStore-CSharp | [数据库/数据存储OrderedDataStore-CSharp.md](../../references/Best%20Practice/%E6%95%B0%E6%8D%AE%E5%BA%93/%E6%95%B0%E6%8D%AE%E5%AD%98%E5%82%A8OrderedDataStore-CSharp.md) | C# 排序存储的完整写法：`GetOrderedStoreAsync`、`SetAsync`、`IncrementAsync`、`ListSortedAsync`、分页游标、榜单附加信息关联存储和并发冲突重试。写排行榜 / TopN / 积分排名时读。漏读易犯：照搬 Lua `UpdateData`、OrderedDataStore value 写非数字、把 `OrderedEntry` 当成有 metadata / version。 |
| 用户维度数据存储-CSharp | [数据库/数据存储方式/用户维度数据存储方式-CSharp.md](../../references/Best%20Practice/数据库/数据存储方式/用户维度数据存储方式-CSharp.md) | 按用户维度保存玩家长期数据时读，确认用户标识、生命周期和异步读写边界。 |
| 精灵维度数据存储-CSharp | [数据库/数据存储方式/精灵维度数据存储方式-CSharp.md](../../references/Best%20Practice/数据库/数据存储方式/精灵维度数据存储方式-CSharp.md) | 按精灵或 Pet 维度保存数据时读，确认数据归属和对象序列化边界。 |
| 自定义数据库管理系统-CSharp | [自定义数据库管理系统-CSharp.md](../../references/Best%20Practice/数据库/自定义数据库管理系统-CSharp.md) | 需要封装统一数据访问、缓存、重试和异常处理层时读。 |
