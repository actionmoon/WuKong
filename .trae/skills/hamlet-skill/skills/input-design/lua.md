---
title: Input Design — Lua 版本
language: lua
description: 本文档汇总使用 Lua 实现玩家输入采样的相关说明与代码示例索引。
---

## 适用场景（什么时候读这个文件）

用 Lua 写玩家输入采样代码时，遇到以下场景读本文件：

- 消费摇杆 / WASD / 触摸 / 跳跃 / 缩放输入
- 把摇杆、键盘、Runtime UI、官方按钮汇入同一状态
- 写长按、抬起、蓄力、连发、持续开火、持续升降
- 排查“UI 按钮生效但 WASD 不生效”“松手后还在移动 / 开火”等问题

---

## 文档索引（以此表为准）

匹配到相关功能时，**必须先完整读取对应的参考文档**再开始编码。严禁凭记忆或拼凑现有 Demo 使用 API。

| 资料 | 路径 | 什么时候读 |
|---|---|---|
| 输入监听-Lua | [输入监听-Lua.md](../../references/Best%20Practice/%E8%BE%93%E5%85%A5/%E8%BE%93%E5%85%A5%E7%9B%91%E5%90%AC-Lua.md) | 摇杆、视角、跳跃、缩放、触摸输入的监听写法：三事件闭环、注册 / 解绑、`moveVec` 采样和事件参数。写任何 `DouyinInputService.on*` 输入监听前读。漏读易犯：漏 `Cancel`、注册在 `Awake`、解绑时 `RemoveAllListeners`。 |
| 右下角操作按钮-Lua | [右下角操作按钮-Lua.md](../../references/Best%20Practice/%E8%BE%93%E5%85%A5/%E5%8F%B3%E4%B8%8B%E8%A7%92%E6%93%8D%E4%BD%9C%E6%8C%89%E9%92%AE-Lua.md) | 实现全局单例右下角自定义按钮（CustomMain/CustomSub 等）并绑定 PointerDown / PointerUp 长按/短按逻辑时阅读。漏读易犯：靠近物体弹出的按钮误用此 API、多实例同时绑定导致冲突、在 PointerDown 回调中直接写物理而不设标志位供 FixedUpdate 消费。 |
