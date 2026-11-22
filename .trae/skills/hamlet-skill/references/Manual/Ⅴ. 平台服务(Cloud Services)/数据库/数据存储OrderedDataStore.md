# 数据存储 DouyinOrderedDataStore

`DouyinOrderedDataStore` 是抖音虚拟世界平台提供的**按数值排序的云端存储**核心类。它专门用于存储只包含数值类型的数据，支持按 value 对全体键做升序 / 降序排序并分页返回，常用于实现**排行榜（Leaderboard）**、TOP-N 榜单等场景。

它与通用键值对存储 [数据存储DataStore](数据存储DataStore.md) 共用同一套键结构、频控队列与错误码，本篇只讲解两者的**差异**与 OrderedDataStore **独有的排序分页能力**；键结构、容量/频控、DS 模式、错误码全表等通用内容请直接参见 DataStore。完整的可执行实践代码请见 Best Practice：

- Lua 实现：[数据存储OrderedDataStore-Lua](../../../Best%20Practice/数据库/数据存储OrderedDataStore-Lua.md)
- C# 实现：[数据存储OrderedDataStore-CSharp](../../../Best%20Practice/数据库/数据存储OrderedDataStore-CSharp.md)

> **🚨 注意（DedicatedServer 模式）**：与 DataStore 一致，DS 网络模式下所有云端数据库读写操作**仅允许在服务端执行**，客户端发起请求会收到 `-11002` 错误码。

## 1. 与 DataStore 的差异

OrderedDataStore 沿用 DataStore 的 `Name` + `Scope` + `key` 三段式键结构，语义一致；差异集中在值类型、排序能力与部分限制上：

| 维度 | DouyinDataStore | DouyinOrderedDataStore |
| --- | --- | --- |
| value 类型 | 数字 / 字符串 / 布尔 / 表（表需序列化） | **只能是数字**（number / double），写入非数字返回 `-10040` |
| 排序分页 | 不支持 | **支持按 value 升/降序排序 + 分页读取**（核心能力，见 §2） |
| Metadata / 历史版本 | 支持 | **不支持**，传入 `DataStoreSetOptions` 返回 `-10036` |
| Name 长度上限 | 20 字符 | **50 字符**（超限返回 `-10066`） |
| key 长度上限 | 128 字符 | **1000 字符**（超限返回 `-10012`） |
| 单 Scope 键数量上限 | 约 1000 个（`-11005`） | 约 **5000 个**（`-11007`） |

其余键结构含义（Name / Scope / key 的用途）、QPS 频控（与 DataStore **共享同一个 API 请求量队列**，默认 900 次/分钟、峰值 1800 次/分钟）、DS 模式限制均与 DataStore 相同，详见 [数据存储DataStore](数据存储DataStore.md)。

> 榜单场景下三段式键的典型用法：`Name` 标识一类榜单（如 `"Leaderboard"`），`Scope` 区分具体榜单实例（如 `"GoldRank"`、`"LevelRank_S1"`），`key` 为榜单条目（通常用 `playerOpenID` / `petOpenID`），对应 value 为该条目的分数。

## 2. 排序与分页（GetSortedData）

OrderedDataStore 的核心能力是“按 value 排序 + 分页读取”，通过 `GetSortedData` 实现，返回分页对象 `DouyinDataPages`。

**参数：**

- `ascending`（bool）：`true` 升序（从小到大），`false` 降序（从大到小，排行榜常用）。
- `pageSize`（int）：单页条目数量，不能超过 **1024**（超出范围返回 `-10024`）。
- `minValue` / `maxValue`（double，可选）：值范围过滤，包含两端；省略或传特殊值表示不限。

**分页遍历语义：**

- 分页对象 `DouyinDataPages` 逐页向后翻页读取，每页返回若干条 `DouyinOrderedDataInfo`，每项含 `key`（条目 key，如玩家 openID）与 `value`（分数）。
- 具体的翻页方法与结果字段随语言不同，见 API Reference 与 Best Practice。

> ⚠️ 业务层应设置“最大读取页数”上限，避免榜单异常膨胀时无限翻页耗尽 API 配额。完整分页遍历代码见 Best Practice。

## 3. 特有限制小结

以下为 OrderedDataStore 相较 DataStore 需额外注意的限制（其余容量 / 频控 / DS 模式限制见 DataStore）：

- **value 只能是数字**：写入非数字返回 `-10040`。
- **不支持 Metadata / 历史版本**：`SetData` / `IncrementData` 不要传 options，`UpdateData` 回调也不要返回 options，否则返回 `-10036`。
- **pageSize 上限 1024**：`GetSortedData` 超出返回 `-10024`。
- **单个 OrderedDataStore 的 key 数量约 5000 个**（`-11007`）：达到上限后“新增 key”写入失败，“已存在 key 的 value 更新”不受影响。超过时需按业务维度分片（按赛季 / 分段位 / hash 分桶）。
  > 该 5000 键上限与 `-11007` 依据平台 API Reference；客户端源码未对其做本地校验，判断为服务端侧限制。

## 4. 错误码参考

OrderedDataStore 与 DataStore 共用同一套整数错误码，完整全表见 [数据存储DataStore](数据存储DataStore.md#4-错误码参考)。下表列出 OrderedDataStore 场景常见、或与 DataStore 取值不同的错误码：

| 错误代码 | 含义 |
| --- | --- |
| -10001 | 数据不存在（key 未上榜 / 新号场景）。 |
| -10012 | key 名称超出长度限制（OrderedDataStore 上限 1000 字符）。 |
| -10024 | pageSize 超出预定义范围（不能超过 1024）。 |
| -10036 | OrderedDataStore 不支持 `DataStoreSetOptions`（不能带 Metadata）。 |
| -10040 | value 无效，OrderedDataStore 的 value 必须是数字。 |
| -10066 | Name 参数超长（最大 50 字符）。 |
| -11007 | 单个 OrderedDataStore 键数量达上限（服务端限制约 5000）。 |

## 5. 使用中必须处理的问题（约束）

DataStore 的通用约束（新号场景、网络重试、数据一致性、实例复用、ID 设计等）在 OrderedDataStore 同样适用，详见 [数据存储DataStore §5](数据存储DataStore.md#5-使用中必须处理的问题约束)。以下是 OrderedDataStore 特有的注意点：

- **首次上榜等同新号**：读取未上榜的 key 会返回 `-10001`，业务需作为“未上榜”分支处理，而非报错。
- **value 全程必须是数字**：若榜单需要携带昵称、头像等信息，应在另一个普通 DataStore 关联存储，或以 openID 为 key 时用户信息接口拉取（注意模拟器下用户信息接口不可用）。
- **不要带 Metadata / options**：避免触发 `-10036`。
- **上榜策略**：“取最大值”上榜用事务式更新（读出当前值比较后写回），累加场景用自增；相同 key 的写入需串行以保证顺序。
- **榜单设计与分片**：账号级榜单用 `playerOpenID`，小火人级榜单用 `petOpenID`；赛季 / 分段位榜单通过 Scope 区分；超过 5000 键时按 hash / 分段位拆分为多个 OrderedDataStore，读取时聚合。

> 编写数据库存取逻辑时（安全读取、异步/回调包裹、增量类型、频控等），请同时遵守全局统一的 **[编码约束与开发规范](../../Ⅲ.%20逻辑与脚本%28Logic%26Scripting%29/编码约束与开发规范/数据库开发约束.md)**。

## 6. 相关 API Reference

- [DouyinDataService.GetOrderedDataStore](../../../API%20Reference/数据存储/DouyinDataService/DouyinDataService.GetOrderedDataStore.md)
- [DouyinOrderedDataStore](../../../API%20Reference/数据存储/DouyinOrderedDataStore.md)（`GetData` / `SetData` / `IncrementData` / `RemoveData` / `GetSortedData`；`UpdateData` 仅 Lua 侧提供）
- [DouyinDataPages](../../../API%20Reference/数据存储/DouyinDataPages.md)（排序分页对象）

## 7. 关联文档

- [数据库概述](数据库概述.md)
- [数据存储DataStore](数据存储DataStore.md)（通用键值对存储，键结构 / 容量频控 / DS 模式 / 错误码全表 / 通用约束）
- [用户维度数据存储方式](数据存储方式/用户维度数据存储方式.md) / [精灵维度数据存储方式](数据存储方式/精灵维度数据存储方式.md)
