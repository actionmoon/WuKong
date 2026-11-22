---
title: 代码检查规则总入口
scope: Hamlet AI 代码验收唯一权威
applies-to: lua, csharp
language: any
project-usage: primary
last-synced: 2026-07-15
---

# 代码检查规则 — AI 编码 / 审查唯一入口

> **本目录是 AI 生成或审查 Hamlet SDK 代码时唯一的规则来源**。所有硬红线判据都收敛在这里。

## 使用方式

- **写代码前**：按当前任务领域读取对应文件（如涉及 DataStore 就读 `data-rules.md`）。
- **写代码后**：对照相应文件里的编号规则做自检，逐条判断是否命中。
- **审查代码**：直接逐条对照，命中即按严重等级和话术输出反馈。

严重等级：🔴 禁止 · 🟠 强烈不建议 · 🟡 警告

## 文件与规则清单

| 文件 | 覆盖 | 规则数 |
|---|---|---|
| [net-rules.md](./net-rules.md) | 网络同步、生命周期、对象判空、参数类型、性能 | NET-001~010 · PERF-001~004 |
| [data-rules.md](./data-rules.md) | DataStore / OrderedDataStore 容量、失败处理、可信数据源 | DATA-001~003 |
| [mall-rules.md](./mall-rules.md) | 商业化：进房时机、发货一致性、幂等、状态码校验 | MALL-001~005 |
| [ds-rules.md](./ds-rules.md) | DS 模式：沙盒、C/S 边界、敏感数据、校验、GM 门禁 | DS-001~008 |
| [shr-rules.md](./shr-rules.md) | Shared 模式：虚拟资产、主权兜底、跨玩家聚合、DS 专属 API 禁用 | SHR-001~005 |
| [interact-rules.md](./interact-rules.md) | 拾取/座位、合养控制权、父子级 | INT-001~003 |

## 领域路由

| 需求关键词 | 优先加载 |
|---|---|
| 同步变量 / NetVar / RPC / SendMessage / 网络对象 | net-rules |
| DataStore / 存档 / 排行榜 | data-rules |
| 商品 / 订单 / 发货 / 支付 / ConfirmOrder | mall-rules |
| DS / 服务端 / Dedicated Server / RemoteEvent | ds-rules |
| Shared / 房主 / 主权兜底 / 断线接管 | shr-rules |
| 拾取 / 座位 / PickUp / SitDown / 合养 / 精灵控制权 | interact-rules |

## 编号约定

- **NET-xxx** 网络同步与对象通用（Shared & DS 都适用）
- **PERF-xxx** 性能（并入 net-rules 文件，但独立编号）
- **DATA-xxx** 数据存储
- **MALL-xxx** 商业化
- **DS-xxx** DS 模式专属
- **SHR-xxx** Shared 模式专属
- **INT-xxx** 交互与合养

## 严格性说明

- 🔴 **禁止**：命中即拒绝合入或提交，必须修复。
- 🟠 **强烈不建议**：命中需修复，如有正当理由须在 PR 里明说豁免依据。
- 🟡 **警告**：命中原则上要改；如工期紧张可延后，但需记入 tech-debt。
