---
title: Commercialization Design — 通用入口
description: 本文档汇总了商业模块的核心概念与开发约束，并提供详细文档的索引
---

## 适用场景（什么时候读这个文件）

- 获取商品、过滤商品状态、展示价格和商品图标
- 查询 / 监听星光币余额、跳转充值
- 设计客户端购买、DS 服务端发货和订单确认链路
- 处理补单、幂等发货、订单状态和数据落库
- 阅读 `DouyinProductInfo`、`DouyinProductPage`、`DouyinReceiptInfo` 等数据结构
- 判断客户端与 Dedicated Server 的职责边界

## 文档索引（以此表为准）

匹配到相关功能时，**必须先完整读取对应的参考文档**再开始编码。严禁凭记忆或拼凑现有 Demo 调用 API。

| 资料 | 路径 | 什么时候读 |
|---|---|---|
| 商业化概述 | [商业化概述.md](../../references/Manual/%E2%85%A4.%20%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1%28Cloud%20Services%29/商业化/商业化概述.md) | 开始接入商业化功能时读，确认商品管理、购买流程、DS 前置条件和测试边界。 |
| 商品与星光币管理 | [商品与星光币管理.md](../../references/Manual/%E2%85%A4.%20%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1%28Cloud%20Services%29/商业化/商品与星光币管理.md) | 实现商品列表、分页、限购、星光币监听和充值时读。 |
| 交易与发货流程 | [交易与发货流程.md](../../references/Manual/%E2%85%A4.%20%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1%28Cloud%20Services%29/商业化/交易与发货流程.md) | 实现购买回调、DS 发货、ConfirmOrder、补单和幂等时读。 |
| 数据结构参考 | [数据结构参考.md](../../references/Manual/%E2%85%A4.%20%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1%28Cloud%20Services%29/商业化/数据结构参考.md) | 需要确认商品、订单、票据、限购枚举或字段类型时读。 |
