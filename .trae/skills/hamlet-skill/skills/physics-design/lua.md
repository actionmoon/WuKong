---
title: Physics Design — Lua 版本
language: lua
description: 本文档汇总使用 Lua 实现场景物理的相关说明与代码示例索引。
---

## 适用场景（什么时候读这个文件）

遇到以下场景时读本文件：

- 足球、冰球、可推箱、滚筒等接触施力玩法
- 载具、遥控物、升降台、移动 NPC 等 Rigidbody 主动驱动
- 指定对象之间的碰撞过滤、忽略指定 Collider 碰撞
- 进球、命中、得分、收集、通关等一次性结算去重
- 载人平台、防顶飞、Layer 分类和递归 `SetLayer`

---

## 文档索引（以此表为准）

匹配到相关功能时，**必须先完整读取对应的参考文档**再开始编码。严禁凭记忆或拼凑现有 Demo 调用 API。

| 资料 | 路径 | 什么时候读 |
|---|---|---|
| Rigidbody-接触施力-Lua | [物理/Rigidbody-接触施力-Lua.md](../../references/Best%20Practice/%E7%89%A9%E7%90%86/Rigidbody-%E6%8E%A5%E8%A7%A6%E6%96%BD%E5%8A%9B-Lua.md) | 球、冰球、可推箱、滚筒的一次性冲量骨架、冷却、刚体缓存和 Inspector 配置。写踢球 / 推箱时读。漏读易犯：一次接触多次施力、Lua 覆盖静态 Rigidbody 参数、持续 clamp 导致踢不动。 |
| Rigidbody-驱动-Lua | [物理/Rigidbody-驱动-Lua.md](../../references/Best%20Practice/%E7%89%A9%E7%90%86/Rigidbody-%E9%A9%B1%E5%8A%A8-Lua.md) | 主动移动物体的通用范式：载具、遥控物、升降台、移动 NPC，重点看 `velocity` 保留 y、`MoveRotation`、Kinematic guard、双轴输入消费。漏读易犯：覆盖 y 轴重力、直写 transform 旋转、只消费横轴。 |
| 输送带-Lua | [物理/输送带-Lua.md](../../references/Best%20Practice/%E7%89%A9%E7%90%86/%E8%BE%93%E9%80%81%E5%B8%A6-Lua.md) | 实现输送带、跑步机、输送玩家、加速带、DriveZone 或带面速度驱动时读。 |
| Collider-Physics碰撞过滤-Lua | [物理/Collider-Physics碰撞过滤-Lua.md](../../references/Best%20Practice/%E7%89%A9%E7%90%86/Collider-Physics%E7%A2%B0%E6%92%9E%E8%BF%87%E6%BB%A4-Lua.md) | 处理“两个物体不要互相顶开 / 阻挡，但仍要保留触发器事件”的情况。写玩家不被球、车、道具硬挤，或指定两个对象互不阻挡时读。漏读易犯：用全局 Layer 过滤误伤其它对象，或为了防碰撞把按钮区、踢球区、检测区的 trigger 也一起关掉。 |
| Trigger-结算去重-Lua | [物理/Trigger-结算去重-Lua.md](../../references/Best%20Practice/%E7%89%A9%E7%90%86/Trigger-%E7%BB%93%E7%AE%97%E5%8E%BB%E9%87%8D-Lua.md) | 把 trigger / collision / raycast / overlap 命中转换成一次玩法结果，并按“玩法实体”而不是单个 Collider 去重。写进球、命中、得分、收集、checkpoint、伤害或失败区时读。漏读易犯：复杂 GLB 多个子碰撞体导致一次事件结算多次，或 reset 后同一帧又重新开闸。 |
| Collider-Layer与碰撞矩阵-Lua | [物理/Collider-Layer与碰撞矩阵-Lua.md](../../references/Best%20Practice/%E7%89%A9%E7%90%86/Collider-Layer%E4%B8%8E%E7%A2%B0%E6%92%9E%E7%9F%A9%E9%98%B5-Lua.md) | 决定带 Rigidbody 的自由刚体能不能被玩家“踩住”：载人平台 / 升降台设可踩层 `Default(0)`，球 / 冰球 / 可推物设 `Props(6)` 防止玩家被顶飞。写移动踏板、输送带、足球、可推箱时读。漏读易犯：只改 root 没递归到子碰撞体，或误用 `IgnoreCollision` / 关碰撞体来解决踩地问题。 |
