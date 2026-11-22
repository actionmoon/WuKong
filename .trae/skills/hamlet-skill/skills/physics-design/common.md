---
title: Physics Design - 通用入口
description: 本文档汇总了场景物理的核心概念与开发约束，并提供详细文档的索引
---

## 适用场景

- Rigidbody、Collider、Trigger、Physic Material、Layer 和碰撞矩阵
- 球、冰球、推箱、滚筒等接触施力玩法
- 载具、遥控物、升降台、移动 NPC 等主动刚体驱动
- 进球、命中、收集、伤害、checkpoint 等物理事件结算
- 指定 Collider 碰撞过滤、载人平台、防顶飞和复合模型去重

## 文档索引（以此表为准）

匹配到相关功能时，**必须先完整读取对应的参考文档**再开始编码。严禁凭记忆或拼凑现有 Demo 调用 API。

| 资料 | 路径 | 什么时候读 |
|---|---|---|
| 物理系统概述 | [物理系统概述.md](../../references/Manual/%E2%85%A0.%20%E6%A0%B8%E5%BF%83%E7%B3%BB%E7%BB%9F(Core)/%E7%89%A9%E7%90%86/%E7%89%A9%E7%90%86%E7%B3%BB%E7%BB%9F%E6%A6%82%E8%BF%B0.md) | 所有场景物理任务的第一份资料；确认支持 API、Layer ID、IgnoreCollision 和静态/运行期分工。 |
| 刚体与运动模型 | [刚体与运动模型.md](../../references/Manual/%E2%85%A0.%20%E6%A0%B8%E5%BF%83%E7%B3%BB%E7%BB%9F(Core)/%E7%89%A9%E7%90%86/%E5%88%9A%E4%BD%93%E4%B8%8E%E8%BF%90%E5%8A%A8%E6%A8%A1%E5%9E%8B.md) | 选择被动受力(AddForce) 或主动驱动(velocity/MoveRotation)、排查物理异常现象时阅读。 |
| 碰撞体与触发器 | [碰撞体与触发器.md](../../references/Manual/%E2%85%A0.%20%E6%A0%B8%E5%BF%83%E7%B3%BB%E7%BB%9F(Core)/%E7%89%A9%E7%90%86/%E7%A2%B0%E6%92%9E%E4%BD%93%E4%B8%8E%E8%A7%A6%E5%8F%91%E5%99%A8.md) | 区分实体 Collider 与 Trigger 的职责、决定是否使用双Collider模式、Layer踩地检测时阅读。 |
