---
title: Platform Service Design — C# 版本
language: csharp
description: 本文档汇总使用 C# 实现平台服务的相关说明与代码示例索引。
---

# 平台服务（C#）

本文件是 C# 平台服务的二级入口。先阅读[通用入口](./common.md)，再按任务命中本表。

## 文档索引（以此表为准）

匹配到相关功能时，**必须先完整读取对应的参考文档**再开始编码。严禁凭记忆或拼凑现有 Demo 调用 API。

| 服务 | C# 最佳实践 | 重点 |
|---|---|---|---|
| 创作者 | [创作者服务-CSharp.md](../../references/Best%20Practice/平台服务/创作者服务-CSharp.md) | `CreatorInfo.secUID` 动态获取；`Follow` 是异步回调；不要传玩家 `openID`。 |
| 房间 | [房间服务-CSharp.md](../../references/Best%20Practice/平台服务/房间服务-CSharp.md) | 只读 `GetCurrentRoomInfo` 回调；缓存并判空；无 `async/await`、创建或切换房间。 |
| 图片 | [图片服务-CSharp.md](../../references/Best%20Practice/平台服务/图片服务-CSharp.md) | `Action<Texture2D>` 可返回 `null`；自行实现缓存、并发合并、UI 复用校验和释放。 |
| 奖励 | [奖励服务-CSharp.md](../../references/Best%20Practice/平台服务/奖励服务-CSharp.md) | `IssueReward(long, Action<IssueRewardResponse>)`；防重必须可信侧落库。 |
| 排行榜 | [排行榜服务-CSharp.md](../../references/Best%20Practice/平台服务/排行榜服务-CSharp.md) | `SetRankData(float, string, Action<bool>)`；只升不降；无读回 / 分页。 |
| 平台工具 | [平台工具-CSharp.md](../../references/Best%20Practice/平台服务/平台工具-CSharp.md) | `Alert` 无返回值且回调式；服务器时间同步返回；无 `Instance`。 |
| 社交 | [社交服务-CSharp.md](../../references/Best%20Practice/平台服务/社交服务-CSharp.md) | 2 方法 + 2 事件；监听成对移除；分享回调不等于好友进房。 |
| 服务器日志 | [服务器日志-CSharp.md](../../references/Best%20Practice/平台服务/服务器日志-CSharp.md) | 仅 5 个单参静态方法；上下文自拼；限流聚合；单条消息不超过 8KB。 |
