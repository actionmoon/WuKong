---
title: Platform Service Design — Lua 版本
language: lua
description: 本文档汇总使用 Lua 实现平台服务的相关说明与代码示例索引。
---

## 适用场景

用 Lua 写平台服务代码时，遇到以下场景读本文件：

- 获取创作者、房间、奖励或图片信息
- 分享世界 / 图片、监听投稿进度和结果
- 上报托管排行榜、读取服务器时间、过滤 emoji
- 记录服务器日志、处理交易 / 数据失败定位
- 排查异步回调、空值、重复请求、监听泄漏或 Lua/C# 入口差异

---

## 文档索引（以此表为准）

匹配到相关功能时，**必须先完整读取对应的参考文档**再开始编码。严禁凭记忆或拼凑现有 Demo 调用 API。

| 资料 | 路径 | 什么时候读 |
|---|---|---|
| 创作者服务 | [Lua](../../references/Best%20Practice/%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1/%E5%88%9B%E4%BD%9C%E8%80%85%E6%9C%8D%E5%8A%A1-Lua.md) | `GetCreatorInfo`、`Follow`、打开主页。重点是 `secUID` 动态获取、判空、异步回调和 `openID` 身份隔离。 |
| 房间服务 | [Lua](../../references/Best%20Practice/%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1/%E6%88%BF%E9%97%B4%E6%9C%8D%E5%8A%A1-Lua.md) | 获取并缓存 `DouyinRoomInfo`、按 `enterFrom` / `inviterOpenID` 做来源归因。只有只读回调，没有创建或切换房间 API。 |
| 图片服务 | [Lua](../../references/Best%20Practice/%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1/%E5%9B%BE%E7%89%87%E6%9C%8D%E5%8A%A1-Lua.md) | `DownloadImage`、Texture2D / Sprite、缓存、并发合并、UI 复用防错图和销毁释放。 |
| 奖励服务 | [Lua](../../references/Best%20Practice/%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1/%E5%A5%96%E5%8A%B1%E6%9C%8D%E5%8A%A1-Lua.md) | `IssueReward`、错误码、关注领奖和可信侧防重复。`rewardID` 由运营提供，不能猜测或硬编码业务规则。 |
| 排行榜服务 | [Lua](../../references/Best%20Practice/%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1/%E6%8E%92%E8%A1%8C%E6%A6%9C%E6%9C%8D%E5%8A%A1-Lua.md) | `SetRankData(score, alias, callback)`，只升不降、并发拦截和有限重试。托管榜没有读回 / 分页接口。 |
| 平台工具 | [Lua](../../references/Best%20Practice/%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1/%E5%B9%B3%E5%8F%B0%E5%B7%A5%E5%85%B7-Lua.md) | `Toast`、回调式 `Alert`、`FilteEmoji`、服务器时间。确认逻辑必须写在回调，网络时间先确认网络就绪。 |
| 社交服务 | [Lua](../../references/Best%20Practice/%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1/%E7%A4%BE%E4%BA%A4%E6%9C%8D%E5%8A%A1-Lua.md) | 世界 / 图片分享、投稿进度与结果事件。监听必须成对移除；分享回调不代表好友进房。 |
| 服务器日志 | [Lua](../../references/Best%20Practice/%E5%B9%B3%E5%8F%B0%E6%9C%8D%E5%8A%A1/%E6%9C%8D%E5%8A%A1%E5%99%A8%E6%97%A5%E5%BF%97-Lua.md) | 分级日志、统一上下文、频控聚合，以及数据读写 / 交易补单定位。单次消息遵守 8KB 限制。 |
