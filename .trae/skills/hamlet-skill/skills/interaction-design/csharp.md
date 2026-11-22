---
title: Interaction Design — C# 版本
language: csharp
description: 本文档汇总使用 C# 实现基础交互的相关说明与代码示例索引。
---

## 文档索引（以此表为准）

### 按具体业务场景查阅（最佳实践闭环）

> **规则说明**：根据需求描述，无法推断是“自动触发”还是“主动触发”时，**默认采用主动触发**（即必须通过按钮交互）。

- **[业务场景] 开发需要玩家主动点击按钮来触发通用状态变更或操作时（如：开关门、开宝箱、操作机关、与NPC对话等非拾取/非乘坐行为）**
  - **资料**：[自定义交互-CSharp.md](../../references/Best%20Practice/基础交互/自定义交互-CSharp.md)

- **[业务场景] 开发需要将物体挂载到玩家手部并随玩家移动的拾取交互时（如：手持道具、武器、工具、可拿起/放下的物件）**
  - **资料**：[自定义拾取-CSharp.md](../../references/Best%20Practice/基础交互/自定义拾取-CSharp.md)

- **[业务场景] 开发玩家乘坐交互时（如：椅子、沙发、长凳、秋千等非载具类的座位）**
  - **资料**：[自定义座位-CSharp.md](../../references/Best%20Practice/基础交互/自定义座位-CSharp.md)

> **边界提示**：
> - 「球 / 冰球 / 可推箱 / 滚筒 / 可踢可推动态刚体」属于接触施力类，转到 [physics-design/csharp.md](../physics-design/csharp.md)，身体接触即一次性施力，不走按钮闭环；
> - 「键盘 / 摇杆 / UI event / 按住 / 抬起 / 连续输入」属于多输入源需求，转到 [input-design/lua.md](../input-design/lua.md)。

