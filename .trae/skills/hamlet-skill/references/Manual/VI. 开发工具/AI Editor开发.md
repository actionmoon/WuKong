# AI Editor 开发

> **适用范围**：当 [hamlet-preferences.md](../../../hamlet-preferences.md) 中 `DevTool=AIEditor` 时阅读。

AI Editor 使用资源源文件和归档工具生成运行时内容，不直接操作 Unity 工程。Hamlet 文档负责说明抖音虚拟世界SDK 的概念、API 语义和平台限制；[Resource Generation](../../../../resource-generation/SKILL.md) 负责 Module 与 Runtime UI 的源文件；[Lua 编写规则](../../../../lua-script-contract/SKILL.md) 负责 Lua 的文件形态、挂载、模块加载和资源协作。Hamlet 示例与 AI Editor 约束不一致时，按 [AI Editor：hamlet-skill与lua-script-contract冲突解决方案](./AI%20Editor：hamlet-skill与lua-script-contract冲突解决方案.md)处理。

## 执行顺序

1. 读取 `hamlet-preferences.md`，确认 `DevTool=AIEditor`。
2. 确认交付对象是 Module、Runtime UI、Runtime Host、Map 还是最终 Mix，并取得对应的合法目标 ID。
3. 创建或修改 Module、Runtime UI 时读取 `resource-generation`；编写或修改任意 Lua 时同时读取 `lua-script-contract` 和 `hamlet-skill`。
4. 按任务涉及的功能，从 `hamlet-skill` 读取对应概念、编码约束和 API 页面。只读取当前任务需要的内容。
5. 先确认目标路径、挂载节点和实际可用接口，再写源文件。不能从 Unity Editor 示例推断 AI Editor 的目录、组件或加载方式。
6. 完成源文件检查后，通过 `archive` 归档对应资源；最终 Mix 在所需资源与 Map 已归档后再归档。

## 可交付内容

| 对象 | 可编辑源文件 | 入口与限制 |
| --- | --- | --- |
| Module | `assets/module/<resource-id>/` 下的模型源文件、`meta.json`、`anchor.json` 和 `scripts/**` | Lua 文件名使用 `pi-*.lua` 或 `ms-*.lua`；脚本目录对应实际挂载节点 |
| Runtime UI | `assets/ui/<resource-id>/html/**`、`images/**`、`scripts/**` 和 `meta.json` | 横屏入口为 `html/1920x1080.html`；只有明确要求竖屏时才增加 `1170x2532.html`；Lua 入口为 `scripts/ui.lua` |
| Runtime Host | 工作区 `scripts/**` 与 `docs/technical/plan.md` | `scripts/runtime-host.lua` 是公共入口；仅在多个资源确实需要通信或共享状态时创建 |
| Map | `assets/map/<map-id>/source/**` | 由 Placement 规则生成和归档，不在 Lua 中补造布局 |
| 归档产物 | 各资源的 `package/**` 与顶层 `package/**` | 由 `archive` 管理，不手写或修改 |

当前归档链路不交付 `.cs`、`GameScripts/`、`ServerScripts/`、Unity 场景、Prefab、Package 配置或自定义 Loader。

## Lua 操作规范

- 每个非空 Lua 文件都是独立 DouyinScript，直接声明生命周期和平台回调。不要创建 `DouyinScriptLoader`、`DouyinServerScriptLoader`、`index.lua` 或返回模块表的自定义 ModuleScript。
- `require` 只接受静态 `official.*` 模块名。使用前读取 `lua-script-contract` 中对应的 `references/official-api/` 页面，并确认模块文件实际存在于工作区只读的 `official/`。
- 不复制或修改 `official/**`，也不使用 `xlua.util`、`dkjson`、自定义 Lua 文件或其它私有路径作为 `require` 目标。所需模块不存在时，说明能力缺失。
- 用户可理解且能独立安全调整的参数使用一个 `---@start` / `---@end` 声明块。资源 ID、节点路径、接口名、运行状态和安全阈值保留为 `local`。
- 使用 `official.core.logger` 输出日志；不直接调用 `print`、`_G.print`、`_ENV.print` 或 `UnityEngine.Debug.Log*`。
- 同一脚本树内通过已保存的 `runtimeScope:GetScript(scriptId)` 调用其它脚本。`scriptId` 从当前 `scripts/` 根目录计算，使用完整路径并保留 `.lua`。
- 当前资源节点使用 `runtimeScope:FindTransform(nodePath)`、`FindGameObject(nodePath)` 或 `GetResourceRoot()`。不要使用脚本显示名、`GetDouyinScript`、`GameObject.Find`、向上遍历父节点或全场景扫描代替精确路径。
- 多个资源需要协作时，先在 `docs/technical/plan.md` 定义参与资源、接口、目标选择、payload、返回值和共享状态，再由 Module 或 Runtime UI 调用 Runtime Host。资源之间不直接访问对方的脚本、节点或目录。
- Hamlet 文档中的生命周期、回调参数、静态与实例调用规则仍然适用；文件组织、挂载和脚本发现方式以 `lua-script-contract` 为准。

## 模型、组件与 UI

- Module 的模型、组件声明、Collider、Rigidbody、trigger、interaction、anchor 和脚本绑定，只能通过 `resource-generation` 已定义的源文件字段或生成工具表达。
- Unity Hierarchy、Inspector、Prefab、`Button.On Click()` 和资源映射表仅说明 Unity Editor 的制作方式，不能作为 AI Editor 已完成的交付。
- 当前源文件契约没有对应字段或工具时，停止转换并说明缺少的配置入口。不要通过运行时脚本猜测或补造静态组件配置。
- 独立 Canvas、复杂布局、HUD、状态面板或独立控件使用 Runtime UI。只服务单个 Module 的简单提示或操作控件，能够由 Module Lua 使用现有平台能力完成时保留在 Module 内。
- Runtime UI 使用 HTML、PNG/SVG 和 Lua 生成。Unity UGUI 文档只能用于理解 Canvas、层级、系统 UI 避让和生命周期，不能照搬 Inspector 或 Prefab 操作。

## API、网络与平台能力

- 抖音虚拟世界SDK API 必须通过 [API Reference Index](../../API%20Reference%20Index.md) 定位具体页面，并核对参数、返回值、回调、网络模型及 [API 白名单](../../API白名单.md)和 [API 黑名单](../../API黑名单.md)。
- `official.*` 是 AI Editor 工作区模块，不属于 Hamlet API Reference；以 `lua-script-contract` 的 API 页面和当前 `official/` 文件是否存在为准。
- Unity API 只有在当前 Lua 运行时允许该类型和调用方式，并通过 Hamlet API 黑白名单检查后才能使用。
- `Network`、`AvatarOrPet` 只在需求明确且会影响实现时参与设计。“局部逻辑”不等于 `SinglePlayer`，普通交互也不应自动增加同步变量、主权、RPC 或重连逻辑。
- Dedicated Server 的 Loader、`DouyinServerRoot`、`ServerScripts/`、`enableCSharp` 和客户端/服务端工程拆分不在当前 AI Editor 交付范围。需求依赖这些能力时，只能说明方案和缺失能力，不能声称已经实现。
- Hamlet 示例首先用于确认 API 语义。示例中的工程路径、Loader、`require`、日志、Inspector 引用、脚本查找、Prefab 和 UI 制作步骤必须按 AI Editor 契约改写；无法改写时不使用该示例实现。

## 验证与交付

1. 检查所有 Lua 文件符合 Lua 5.3 语法、角色命名、`require`、日志和脚本调用规则。
2. 检查 Module 的模型节点、`anchor.json`、`meta.json.attributes`、`targetPath` 和脚本目录一致。
3. 检查 Runtime UI 的 HTML 根节点、图片引用、Lua 节点路径、事件注册和清理一致。
4. 涉及多个资源时，对照 `docs/technical/plan.md` 检查 Runtime Host 与全部客户端的接口。
5. 使用 `archive(target=resource, targetId=<resource-id>)` 完成单资源归档，并修复归档返回的错误。需要最终 Mix 时，再使用对应 Mix 归档流程。
6. 只把实际完成的语法检查、归档或预览结果写入交付说明。未运行 Creator 预览、多人环境或目标端验证时，明确标记为未验证。
