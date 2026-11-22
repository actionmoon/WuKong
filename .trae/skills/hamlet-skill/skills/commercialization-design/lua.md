---
title: Commercialization Design — Lua 版本
language: lua
description: 本文档汇总使用 Lua 实现商品管理、星光币和交易发货的相关说明与代码示例索引。
---

## 适用场景

- Lua 客户端获取商品、分页展示、过滤上架商品
- 监听星光币变化、处理余额不足和跳转充值
- Lua DS 服务端监听 `onOrderPayment` 并完成幂等发货
- 处理 `ConfirmOrder`、自动补单和手动 `BackOrder`

## 文档索引（以此表为准）

匹配到相关功能时，**必须先完整读取对应的参考文档**再开始编码。严禁凭记忆或拼凑现有 Demo 调用 API。

| 资料 | 路径 | 什么时候读 |
|---|---|---|
| 商品与星光币管理-Lua | [商品与星光币管理-Lua.md](../../references/Best%20Practice/商业化/商品与星光币管理-Lua.md) | 编写商品全量 / 分页获取、商品状态过滤、星光币监听和充值跳转时读。 |
| 交易与发货流程-Lua | [交易与发货流程-Lua.md](../../references/Best%20Practice/商业化/交易与发货流程-Lua.md) | 编写客户端购买或 DS 服务端发货时读；严格遵守服务端落库、订单幂等和回执时限。 |

