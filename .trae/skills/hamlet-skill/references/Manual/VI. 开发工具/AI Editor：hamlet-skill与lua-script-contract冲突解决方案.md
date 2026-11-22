# AI Editor：hamlet-skill与lua-script-contract冲突解决方案

> **适用范围**：当 [hamlet-preferences.md](../../../hamlet-preferences.md) 中 `DevTool=AIEditor` 时阅读。

本文解决 `DevTool=AIEditor` 时，[hamlet-skill](../../../SKILL.md) 与 [lua-script-contract](../../../../lua-script-contract/SKILL.md) 之间潜在的冲突。

## 目录

- [适用优先级](#适用优先级)
- [冲突矩阵](#冲突矩阵)
- [解决步骤](#解决步骤)
- [常见改写](#常见改写)
- [不构成冲突的内容](#不构成冲突的内容)
- [交付检查](#交付检查)

## 适用优先级

同一要求出现不一致时，按以下顺序确定最终实现：

1. 当前 AI Editor 工具、工作区和归档链路实际提供的能力。
2. `lua-script-contract` 对 Lua 文件形态、参数、加载、挂载、查找和资源协作的约束。
3. [Resource Generation](../../../../resource-generation/SKILL.md) 对 Module、Runtime UI 及其源文件的约束。
4. `hamlet-skill` 对抖音虚拟世界SDK 概念、API 签名、生命周期、网络语义和平台限制的说明。
5. Hamlet Manual 与 Best Practice 中的工程步骤和示例写法。

上层约束只覆盖其明确负责的内容。例如，`lua-script-contract` 可以替换示例中的 `require`、日志和脚本查找方式，但不能修改 Hamlet API 的参数顺序或返回值语义。

## 冲突矩阵

| 冲突主题 | Hamlet 或 Unity Editor 口径 | AI Editor 最终口径 | 处理方式 |
| --- | --- | --- | --- |
| 可交付语言 | Lua 与 C# 均可使用 | 当前只交付规定目录中的 Lua | 不生成 `.cs`、`GameScripts/` 或 `ServerScripts/` |
| 脚本创建与挂载 | 在 `Assets` 创建 Lua，通过 Inspector 挂到 `Douyin Script` | 每个非空 Lua 文件是独立 DouyinScript，由资源目录和归档规则确定挂载 | 按资源类型写入脚本树；不描述已完成 Inspector 操作 |
| Loader | 使用 `Douyin Script Loader` 或 `Douyin Server Script Loader` | 不创建或配置自定义 Loader | 删除 Loader 步骤；需求依赖 DS Loader 时报告当前不可交付 |
| ModuleScript | 自定义模块返回 table，由 `index.lua` 聚合 | 资源 Lua 不是可加载模块，不返回模块表，也不创建 `index.lua` | 按职责拆成独立 DouyinScript |
| `require` | 可加载 `xlua.util`、`dkjson`、相对路径或自定义模块 | 只允许静态 `require("official.<module>")`，且模块必须存在于只读 `official/` | 优先选择已文档化的 `official.*`；没有等价模块时说明缺失 |
| 日志 | 示例可使用 `print` 或 `UnityEngine.Debug` | 使用 `official.core.logger` | 为每个脚本创建 local logger；高频和重复错误按 logger 规则处理 |
| 参数与引用 | Inspector 序列化字段、拖拽 `DouyinScript` 或 GameObject 引用 | 可调值使用 `---@var`；资源 ID、脚本 ID、节点路径等保持为 `local` 或源文件配置 | 不把不安全的结构信息暴露到参数面板 |
| 同资源脚本调用 | `myScript.script.Func()`、`GetDouyinScript("name")` | `runtimeScope:GetScript(scriptId)` 返回 script table，再用 `.` 调用公开函数 | `scriptId` 使用相对脚本树根的完整路径并保留 `.lua` |
| 当前资源节点查找 | `GameObject.Find`、按名称或场景遍历 | `FindTransform`、`FindGameObject`、`GetResourceRoot` | 使用真实完整节点路径；模型结构先由 `inspect_glb_model` 确认 |
| 跨资源访问 | 通过场景对象、脚本引用或名称直接互调 | 使用 Runtime Host；接口先写入 `docs/technical/plan.md` | Module 与 Runtime UI 不直接访问其它资源内部 |
| 组件与 Prefab | 在 Hierarchy、Inspector 或 Prefab 中配置组件、Layer、回调和资源映射 | 只使用 `resource-generation` 已定义的 `meta.json`、`anchor.json`、attributes、模型源文件或工具 | 没有对应字段或工具时停止转换并说明缺口 |
| 自定义 UI | 使用 UGUI、Canvas、Prefab、`Button.On Click()` 和横竖屏适配组件 | 使用 Runtime UI 的 HTML、图片和 Lua；默认只生成横屏 | 保留 UI 语义，按 Runtime UI 契约重做实现 |
| 网络工程 | 通过 `DouyinWorldRoot`、`DouyinServerRoot`、Loader、Prefab 表或双程序集配置网络环境 | 仅实现当前资源契约能够表达且 API 已确认可用的运行时逻辑 | DS 工程搭建、Prefab 注册和场景网络配置只作为能力说明 |
| 验证 | Unity 编译、Console、模拟器、客户端与 DS 构建 | Lua 检查、资源归档和 Creator 可用的预览 | 未执行目标端或多人验证时明确标记未验证 |

## 解决步骤

### 1. 先过滤不适用资料

- `DevTool=AIEditor` 时，不读取 C# 实践、Unity Editor 脚本开发、Module Script、工程搭建或模拟器配置作为实现说明。
- Hamlet 功能路由命中的 Lua 文档仍可用于理解 API 和玩法约束，但其中的 Unity Editor 工程步骤与示例代码不能直接交付。
- 文档仅提供 C#、Loader、Prefab 或 Inspector 方案时，不能据此生成近似 Lua 实现。

### 2. 分离语义与实现

继续保留以下内容：

- API 名称、参数类型与顺序、返回值和回调参数；
- 生命周期、网络就绪时机、主权和控制权语义；
- Actor、Pet、Avatar、物理、相机、数据与平台服务的限制；
- API 白名单、黑名单和目标环境限制。

必须替换以下内容：

- 文件路径、入口、Loader 和 ModuleScript 组织；
- Inspector 引用、Prefab 组件配置和场景挂载步骤；
- 日志、`require`、脚本查找和跨资源访问；
- Unity UGUI 制作、模拟器调试及工程构建步骤。

### 3. 核对可实现性

1. 从 `resource-generation` 确认目标行为能否由 Module 或 Runtime UI 的源文件表达。
2. 从 `lua-script-contract` 确认脚本路径、挂载节点、参数、`official.*` 模块和 RuntimeScope 接口。
3. 从 Hamlet 的 `API Reference Index` 定位具体抖音虚拟世界SDK API，并检查黑白名单和平台限制。
4. 只有三者同时成立时才生成实现。任一层缺少入口时，说明缺少的字段、工具、模块或目标环境验证，不自行发明替代接口。

## 常见改写

### 自定义模块

当 Hamlet 示例要求创建配置模块、工具模块或 `index.lua` 时：

- 只供一个脚本使用的常量和 helper 留在当前文件并声明为 `local`。
- 同一资源内需要共享行为时，拆成符合该脚本树命名和挂载规则的独立 DouyinScript，通过 `runtimeScope:GetScript(scriptId)` 调用。
- 多个资源共享状态或行为时，定义 Runtime Host 接口；不要复制同一可变状态到多个资源。
- 依赖第三方 Lua 库且没有 `official.*` 等价模块时，报告当前 AI Editor 链路不支持。

### Inspector 引用

当 Hamlet 示例要求拖拽脚本、GameObject、Prefab 或组件引用时：

- 用户可安全调整的简单值改为 `---@var` 参数。
- 当前资源的固定节点使用经模型或 UI 源文件确认的完整路径，并通过 RuntimeScope 查询。
- 组件静态配置改为 `resource-generation` 已定义的 attributes、anchor 或模型源字段。
- Prefab 资产表、场景级服务对象或未受支持的组件不能转换为字符串参数来规避配置缺口。

### 示例日志与对象查找

示例中的 `print` 统一改为 `official.core.logger`。示例中的 `GameObject.Find`、`FindGameObjectsWithTag`、`GetDouyinScript` 或脚本显示名查找，必须根据目标范围分别改为当前资源 RuntimeScope 查询、Runtime Host selector 或已确认的平台服务；不能保留全场景扫描作为兜底。

## 不构成冲突的内容

- Lua 静态方法使用 `.`、实例方法使用 `:`，Unity 类型通过允许的 `CS.*` 命名空间访问。
- DouyinScript 的生命周期和平台回调直接声明为顶层函数。
- 网络同步、主权、控制权、Actor 本地身份和清理时机仍按 Hamlet 对应功能文档处理。
- API 示例没有 AI Editor 版本，不表示 API 不受支持；是否可用取决于 API 文档、当前 Lua 环境和资源契约。

## 交付检查

- 交付内容中没有 `.cs`、Loader、`index.lua`、自定义 ModuleScript 或 Unity 工程配置。
- 所有 `require` 都是当前工作区存在的静态 `official.*` 模块。
- 没有直接使用 `print`、`UnityEngine.Debug`、`GameObject.Find` 或 `GetDouyinScript`。
- 同资源调用使用完整 `scriptId`；跨资源接口与 `docs/technical/plan.md` 一致。
- 没有把 Inspector、Prefab 或 UGUI 操作描述为已完成。
- API 签名和平台限制仍与 Hamlet API Reference 一致。
- 归档或预览未覆盖的运行时行为已明确标记为未验证。
