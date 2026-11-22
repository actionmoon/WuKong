---
title: Database Design — 通用入口
description: 本文档汇总了数据库模块的核心概念与开发约束，并提供详细文档的索引
---

## 适用场景（什么时候读这个文件）

- 实现玩家存档 / 读档、背包、进度、货币、道具数量等持久化数据
- 设计 DataStore 的 `Name / Scope / Key`，或控制 key / value 规模
- 实现排行榜、TopN、积分排名、排序分页
- 处理新号默认值、错误语义、并发更新、存储大小限制
- 判断 SharedMode / DedicatedServer 下数据存储应该在哪一端调用
- 存储表值、对象或复杂结构，需要先序列化再落库

---

## 文档索引（以此表为准）

匹配到相关功能时，**必须先完整读取对应的参考文档**再开始编码。严禁凭记忆或拼凑现有 Demo 调用 API。

| 资料 | 路径 | 什么时候读 |
|---|---|---|
| 数据库概述 | [数据库概述.md](../../references/Manual/%E2%85%A4.%20%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1%28Cloud%20Services%29/%E6%95%B0%E6%8D%AE%E5%BA%93/%E6%95%B0%E6%8D%AE%E5%BA%93%E6%A6%82%E8%BF%B0.md) | 设计任何数据存储前读，确认数据库能力边界、适用场景和整体读取顺序。 |
| 用户维度数据存储 | [用户维度数据存储方式.md](../../references/Manual/%E2%85%A4.%20%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1%28Cloud%20Services%29/%E6%95%B0%E6%8D%AE%E5%BA%93/%E6%95%B0%E6%8D%AE%E5%AD%98%E5%82%A8%E6%96%B9%E5%BC%8F/%E7%94%A8%E6%88%B7%E7%BB%B4%E5%BA%A6%E6%95%B0%E6%8D%AE%E5%AD%98%E5%82%A8%E6%96%B9%E5%BC%8F.md) | 保存玩家长期数据前读，确认用户标识、数据归属、生命周期和读写边界。 |
| 精灵维度数据存储 | [精灵维度数据存储方式.md](../../references/Manual/%E2%85%A4.%20%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1%28Cloud%20Services%29/%E6%95%B0%E6%8D%AE%E5%BA%93/%E6%95%B0%E6%8D%AE%E5%AD%98%E5%82%A8%E6%96%B9%E5%BC%8F/%E7%B2%BE%E7%81%B5%E7%BB%B4%E5%BA%A6%E6%95%B0%E6%8D%AE%E5%AD%98%E5%82%A8%E6%96%B9%E5%BC%8F.md) | 保存精灵或 Pet 维度数据前读，确认对象归属、切换和序列化边界。 |
| DataStore 概念说明 | [数据库/数据存储DataStore.md](../../references/Manual/%E2%85%A4.%20%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1%28Cloud%20Services%29/%E6%95%B0%E6%8D%AE%E5%BA%93/%E6%95%B0%E6%8D%AE%E5%AD%98%E5%82%A8DataStore.md) | 写玩家存档、进度、背包、货币、道具数量等键值数据前读。它解释 `Name / Scope / Key`、SharedMode / DS 调用位置、错误码语义、默认数据、序列化、容量限制、QPS 和缓存策略。漏读易犯：key / value 设计超限、新号未初始化、DS 客户端误调存储 API、读写频率过高。 |
| OrderedDataStore 概念说明 | [数据库/数据存储OrderedDataStore.md](../../references/Manual/%E2%85%A4.%20%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1%28Cloud%20Services%29/%E6%95%B0%E6%8D%AE%E5%BA%93/%E6%95%B0%E6%8D%AE%E5%AD%98%E5%82%A8OrderedDataStore.md) | 写排行榜、TopN、积分排名、排序分页前读。它解释 OrderedDataStore 与普通 DataStore 的差异、分数类型、容量限制、分页语义、QPS 和榜单拆分策略。漏读易犯：score 不是 number、分页 index / cursor 语义错、把实时刷新当成强一致。 |
