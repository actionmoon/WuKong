---
title: Ownership Design — C# 版本
language: csharp
description: 本文档汇总使用 C# 实现主权 / 控制权的相关说明与代码示例索引。
---

## 适用场景（什么时候读这个文件）

- 主权方要写 `NetworkVariable / NetworkList / NetworkDictionary`，或非主权方要通过 RPC 请求主权方代写
- 请求主权后要等 `OnOwnershipRequestResponse` 回传结果，而不是靠同步返回值判断成功
- 主权方断线后要让新主权方在 `OnGainedOwnership / OnOwnershipChanged` 里接管逻辑
- 需要理解 C# 控制权 API 暴露范围，避免误造 Lua 式主动控制权接口
- 排查 `IsOwner` 未确定、主权请求无响应、断线后管理器不接管等问题

---

## 文档索引（以此表为准）

匹配到相关功能时，**必须先完整读取对应的参考文档**再开始编码。严禁凭记忆或拼凑现有 Demo 调用 API。

### 代码示例（确定功能后按 C# 读具体写法）

| 资料 | 路径 | 什么时候读 |
|---|---|---|
| 主权-CSharp | [主权-CSharp](../../references/Best%20Practice/主权/主权-CSharp.md) | C# 主权代码的完整写法：判断本端是否主权方、请求主权、审批请求、主权变化后接管 / 清理，以及把非主权方请求转发给 Owner。写网络变量代写、权威逻辑接管或 Owner RPC 时读。漏读易犯：把 `RequestOwnership()` 返回值当最终成功，或照搬 Lua 的主动控制权 API。 |
