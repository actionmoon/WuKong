# Hamlet Preferences

> 这是一个用于配置 Hamlet 项目开发偏好的文件。
> AI Agent（如 hamlet-programmer）在生成代码和检索文档时，会优先读取此文件的配置作为默认上下文。

## 核心配置选项

请根据你的项目实际情况修改以下选项（保留你需要的选项，删除或注释掉其他的）：

- **Language**: Lua  *(可选值: C# | Lua)*
- **Network**: DedicatedServer  *(可选值: SharedMode | DedicatedServer | SinglePlayer)*
- **AvatarOrPet**: Avatar  *(可选值: Avatar | Pet)*
- **DevTool**: UnityEditor  *(可选值: UnityEditor | AIEditor)*

## 附加说明

- **Language**: 决定 AI 默认使用哪种语言进行开发。C# 是基于 Unity 的原生开发，Lua 是基于 DouyinScript 虚拟机的开发。**当 Language 为 Lua 时，Agent 需自动加载 [lua-project-conventions.md](./references/Manual/Ⅲ.%20逻辑与脚本%28Logic%26Scripting%29/编码约束与开发规范.md)**；**当 Language 为 C# 时，Agent 需自动加载 [csharp-project-conventions.md](./references/Manual/Ⅲ.%20逻辑与脚本%28Logic%26Scripting%29/编码约束与开发规范.md)**。
- **Network**: 决定网络同步的架构。SharedMode 为客户端主权/分布式，DedicatedServer 为中心化服务端逻辑，SinglePlayer 为纯单机（禁用网络 API）。
- **AvatarOrPet**: 决定项目是否涉及虚拟形象或宠物开发，影响相关 API 黑名单和最佳实践的应用。
- **DevTool**: 决定开发工具。`AIEditor` 表示在 AI 编辑器中开发；`UnityEditor` 表示在 Unity Editor 中使用抖音虚拟世界SDK 开发。
