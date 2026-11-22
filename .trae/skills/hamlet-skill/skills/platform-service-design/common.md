---
title: Platform Service Design - 通用入口
description: 本文档汇总了平台服务的核心概念与开发约束，并提供详细文档的索引。
---

## 适用场景

- 创作者信息、关注创作者、打开创作者主页
- 房间来源、邀请溯源、`enterFrom` 渠道识别
- 图片下载、头像 / 奖励缩略图展示、Texture2D / Sprite 生命周期
- 官方奖励、关注领奖、发奖幂等和错误码处理
- 托管排行榜上报、分数校验和成绩结算
- Toast、Alert、emoji 过滤、服务器时间
- 世界 / 图片分享、投稿进度和投稿结果监听
- 服务器日志、交易补单和数据读写失败定位

## 文档索引（以此表为准）

匹配到相关功能时，**必须先完整读取对应的参考文档**再开始编码。严禁凭记忆或拼凑现有 Demo 调用 API。

| 资料 | 路径 | 什么时候读 |
|---|---|---|
| 平台服务概述 | [平台服务概述.md](../../references/Manual/Ⅴ.%20平台服务(Cloud%20Services)/平台服务概述.md) | 了解平台服务的分类、核心职责、环境边界和通用调用原则；进入具体平台服务前先读。 |
| 创作者服务 | [创作者服务.md](../../references/Manual/%E2%85%A4.%20%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1(Cloud%20Services)/%E5%B9%B3%E5%8F%B0%E4%B8%9A%E5%8A%A1%E6%9C%8D%E5%8A%A1/%E5%88%9B%E4%BD%9C%E8%80%85%E6%9C%8D%E5%8A%A1.md) | `GetCreatorInfo`、`Follow`、打开主页；确认 `secUID`、身份隔离和回调语义。 |
| 房间服务 | [房间服务.md](../../references/Manual/%E2%85%A4.%20%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1(Cloud%20Services)/%E5%B9%B3%E5%8F%B0%E4%B8%9A%E5%8A%A1%E6%9C%8D%E5%8A%A1/%E6%88%BF%E9%97%B4%E6%9C%8D%E5%8A%A1.md) | 获取并缓存 `DouyinRoomInfo`；确认 `enterFrom` / `inviterOpenID` 和只读边界。 |
| 图片服务 | [图片服务.md](../../references/Manual/%E2%85%A4.%20%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1(Cloud%20Services)/%E5%B9%B3%E5%8F%B0%E4%B8%9A%E5%8A%A1%E6%9C%8D%E5%8A%A1/%E5%9B%BE%E7%89%87%E6%9C%8D%E5%8A%A1.md) | 下载图片、回调判空、URL 来源和 Texture2D 生命周期。 |
| 奖励服务 | [奖励服务.md](../../references/Manual/%E2%85%A4.%20%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1(Cloud%20Services)/%E5%B9%B3%E5%8F%B0%E4%B8%9A%E5%8A%A1%E6%9C%8D%E5%8A%A1/%E5%A5%96%E5%8A%B1%E6%9C%8D%E5%8A%A1.md) | `IssueReward`、响应结构、错误码和线上发奖边界。 |
| 排行榜服务 | [排行榜服务.md](../../references/Manual/%E2%85%A4.%20%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1(Cloud%20Services)/%E5%B9%B3%E5%8F%B0%E4%B8%9A%E5%8A%A1%E6%9C%8D%E5%8A%A1/%E6%8E%92%E8%A1%8C%E6%A6%9C%E6%9C%8D%E5%8A%A1.md) | `SetRankData`、`score` / `alias` 语义和托管榜只写边界。 |
| 平台工具 | [平台工具.md](../../references/Manual/%E2%85%A4.%20%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1%28Cloud%20Services%29/%E5%B9%B3%E5%8F%B0%E4%B8%9A%E5%8A%A1%E6%9C%8D%E5%8A%A1/%E5%B9%B3%E5%8F%B0%E5%B7%A5%E5%85%B7.md) | `Toast`、回调式 `Alert`、emoji 过滤和服务器时间。 |
| 社交服务 | [社交服务.md](../../references/Manual/%E2%85%A4.%20%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1(Cloud%20Services)/%E5%B9%B3%E5%8F%B0%E4%B8%9A%E5%8A%A1%E6%9C%8D%E5%8A%A1/%E7%A4%BE%E4%BA%A4%E6%9C%8D%E5%8A%A1.md) | 分享方法、投稿事件、线上限制和监听生命周期。 |
| 服务器日志 | [服务器日志.md](../../references/Manual/%E2%85%A4.%20%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1(Cloud%20Services)/%E5%B9%B3%E5%8F%B0%E4%B8%9A%E5%8A%A1%E6%9C%8D%E5%8A%A1/%E6%9C%8D%E5%8A%A1%E5%99%A8%E6%97%A5%E5%BF%97.md) | 分级日志、上下文、8KB 限制、频控和看板定位。 |
