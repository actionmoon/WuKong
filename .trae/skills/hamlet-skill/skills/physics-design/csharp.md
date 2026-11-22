---
title: Physics Design - C# 版本
language: csharp
description: 本文档汇总使用 C# 实现场景物理的相关说明与代码示例索引。
---

## 适用场景

- 球、冰球、可推箱、滚筒等 `AddForce` 接触施力
- 载具、遥控物、升降台、移动 NPC 等 `velocity` / `MoveRotation` 驱动
- Layer 分类、递归 `SetLayer`、碰撞矩阵和指定 Collider 过滤
- 进球、命中、收集、伤害、checkpoint 的实体级去重和集中幂等结算

## 文档索引（以此表为准）

匹配到相关功能时，**必须先完整读取对应的参考文档**再开始编码。严禁凭记忆或拼凑现有 Demo 调用 API。

| 资料 | 路径 | 什么时候读 |
|---|---|---|
| Rigidbody-接触施力-CSharp | [物理/Rigidbody-接触施力-CSharp.md](../../references/Best%20Practice/%E7%89%A9%E7%90%86/Rigidbody-%E6%8E%A5%E8%A7%A6%E6%96%BD%E5%8A%9B-CSharp.md) | 球、冰球、推箱等一次性冲量；重点检查单一 `OnActorTriggerEnter`、短冷却、方向计算和不加主权门禁。 |
| Rigidbody-驱动-CSharp | [物理/Rigidbody-驱动-CSharp.md](../../references/Best%20Practice/%E7%89%A9%E7%90%86/Rigidbody-%E9%A9%B1%E5%8A%A8-CSharp.md) | 每帧主动控制物体；重点检查 `FixedUpdate`、Kinematic guard、保留 `velocity.y`、`MoveRotation` 和 W/S 双轴。 |
| 输送带-CSharp | [物理/输送带-CSharp.md](../../references/Best%20Practice/%E7%89%A9%E7%90%86/%E8%BE%93%E9%80%81%E5%B8%A6-CSharp.md) | 实现输送带、跑步机、输送玩家、加速带、DriveZone 或带面速度驱动时读。 |
| Collider-Layer与碰撞矩阵-CSharp | [物理/Collider-Layer与碰撞矩阵-CSharp.md](../../references/Best%20Practice/%E7%89%A9%E7%90%86/Collider-Layer%E4%B8%8E%E7%A2%B0%E6%92%9E%E7%9F%A9%E9%98%B5-CSharp.md) | 载人平台、防顶飞、球/道具层分类、递归 `SetLayer` 和选择性车顶可踩节点。 |
| Collider-Physics碰撞过滤-CSharp | [物理/Collider-Physics碰撞过滤-CSharp.md](../../references/Best%20Practice/%E7%89%A9%E7%90%86/Collider-Physics%E7%A2%B0%E6%92%9E%E8%BF%87%E6%BB%A4-CSharp.md) | 只忽略指定物体的实体碰撞、保留 Trigger，并对目标引用缺失进行有限重试。 |
| Trigger-结算去重-CSharp | [物理/Trigger-结算去重-CSharp.md](../../references/Best%20Practice/%E7%89%A9%E7%90%86/Trigger-%E7%BB%93%E7%AE%97%E5%8E%BB%E9%87%8D-CSharp.md) | 进球、命中、拾取、伤害等 outcome；重点检查 attachedRigidbody 归一化、幂等 key 和 reset 跨帧。 |
