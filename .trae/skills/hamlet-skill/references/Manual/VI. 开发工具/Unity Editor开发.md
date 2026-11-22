# Unity Editor 开发

> **适用范围**：当 [hamlet-preferences.md](../../../hamlet-preferences.md) 中 `DevTool=UnityEditor` 时阅读。
> `DevTool` 的详细说明请参考[开发工具概述](./开发工具概述.md)。

本文介绍如何在 Unity Editor 中使用抖音虚拟世界SDK 开发。先按任务读取本页列出的原始文档，再执行工程操作；本页不替代运行时 API、网络模型或编码规范。

## 工程与脚本

### Lua

- 在 Unity Editor 的 `Assets` 目录中通过 **Create -> Douyin -> Lua script** 创建脚本。
- Lua 文件不能像 `MonoBehaviour` 一样直接挂到 GameObject。先添加 `Douyin Script` 组件，再在组件中选择 Lua 文件。
- 需要在 Inspector 中配置的引用或参数，通过 `Douyin Script` 支持的序列化声明暴露并绑定。
- 普通行为脚本由 `Douyin Script` 挂载；配置、公共函数和纯逻辑库使用 Module Script，并由 `Douyin Script Loader` 管理。
- 使用 Module Script 时，场景只能有一个普通 Loader。Dedicated Server 专属模块放入 `Douyin Server Script Loader`，不能与普通 Loader 重复引用同一文件。
- 使用 VS Code 调试时，打开 Unity 工程根目录，通过 Lua Debugger 的 `wait` 配置等待 Unity 模拟器连接。

详细资料：

- [Lua 脚本开发](../Ⅲ.%20逻辑与脚本(Logic%26Scripting)/脚本开发/Lua脚本/Lua脚本开发.md)
- [Lua 开发环境与调试](../Ⅲ.%20逻辑与脚本(Logic%26Scripting)/脚本开发/Lua脚本/Lua脚本开发环境与调试配置.md)
- [Module Script](../Ⅲ.%20逻辑与脚本(Logic%26Scripting)/脚本开发/Lua脚本/ModuleScript.md)

### C#

- 在 `Packages/com.douyin.world/Config/simulator.json` 中将 `enableCSharp` 设为 `true`，然后重启 Unity Editor。
- 客户端及双端共享代码放在 `GameScripts/`；Dedicated Server 专属代码放在 `ServerScripts/`。
- `GameScripts/` 不能引用 `ServerScripts/` 中的类型，避免客户端构建裁剪失败。
- 需要抖音虚拟世界SDK 生命周期和事件时使用 `DouyinMonoBehaviour`；只需要 Unity 生命周期时按场景使用 `MonoBehaviour` 或 `NetworkBehaviour`。
- `NetworkBehaviour` 必须位于带有 `NetworkObject` 的对象或其子节点上。

详细资料：

- [C# 脚本开发](../Ⅲ.%20逻辑与脚本(Logic%26Scripting)/脚本开发/CSharp脚本/CSharp脚本开发.md)
- [SinglePlayer C#](../../../skills/singleplayer-design/csharp.md)

## 场景与网络配置

- 场景根节点使用 `DouyinWorldRoot` 承载世界级配置和普通 Module Script Loader。
- SharedMode 场景不能存在 `DouyinServerRoot`。
- Dedicated Server 场景需要在 Hierarchy 中创建 `DouyinServerRoot`，并配置至少一个服务端脚本。该节点及其子节点只保留在服务端构建中，不能放置 Canvas。
- DS 专属节点不要挂 `NetworkObject`。需要稳定 GUID 时使用文档指定的 `DouyinNetworkGuid`。
- 调用 `NetSpawn` 前，在 `DouyinWorldRoot.NetSpawnObjectAsset` 中配置 `key -> Prefab` 映射。
- `ServerSpawn` 使用 DS 侧资源配置；不要把 `NetSpawn` 的资产表放在 `DouyinServerRoot`。
- 网络 Prefab 必须满足对应脚本和网络组件要求。网络对象只能通过 `NetSpawn`、`ServerSpawn` 及配套销毁 API 管理，不能使用 Unity 原生 `Instantiate` 或 `Destroy` 代替。

详细资料：

- [网络模型概述](../Ⅳ.%20多人游戏与网络(Multiplayer)/网络模型/网络模型概述.md)
- [SharedMode](../Ⅳ.%20多人游戏与网络(Multiplayer)/网络模型/网络模型-Shared%20Mode.md)
- [Dedicated Server](../Ⅳ.%20多人游戏与网络(Multiplayer)/网络模型/网络模型-Dedicated%20Server.md)
- [SharedMode 升级到 Dedicated Server](../Ⅳ.%20多人游戏与网络(Multiplayer)/网络模型/SharedMode%20模式升级到Dedicated%20Server模式.md)
- [网络对象的动态创建](../Ⅳ.%20多人游戏与网络(Multiplayer)/网络基础/网络对象的动态创建.md)

## 组件、Prefab 与物理

- 通过 Hierarchy 组织 GameObject，通过 Inspector 添加 `Douyin Script`、Collider、Rigidbody、NetworkObject 和其它 抖音虚拟世界SDK 组件。
- 可直接使用 抖音虚拟世界SDK 提供的 `DouyinInteractor`、`DouyinPickUp`、`DouyinSeat` 示例脚本或 Prefab，再在 Inspector 中配置触发范围、按钮、挂点和回调。
- Rigidbody、Collider、Trigger、Layer 和碰撞矩阵优先在 Prefab 阶段配置。运行时只修改确实需要动态变化的参数。
- 保存 Prefab 前检查脚本引用、组件依赖、Collider 层级和网络组件；动态生成对象还要检查资源 key 已注册。

详细资料：

- [基础交互组件](../../Best%20Practice/基础交互/基础交互组件.md)
- [碰撞体与触发器](../Ⅰ.%20核心系统(Core)/物理/碰撞体与触发器.md)
- [刚体与运动模型](../Ⅰ.%20核心系统(Core)/物理/刚体与运动模型.md)
- [物理对象层级约束](../Ⅲ.%20逻辑与脚本(Logic%26Scripting)/编码约束与开发规范/物理对象层级约束.md)
- [刚体运动控制约束](../Ⅲ.%20逻辑与脚本(Logic%26Scripting)/编码约束与开发规范/刚体运动控制约束.md)

## UGUI

- 使用 Canvas 和 UGUI 制作界面。普通屏幕界面使用 `Screen Space - Overlay`，场景内界面使用 `World Space`；当前不使用 `Screen Space - Camera`。
- Canvas Scaler 使用 `Scale With Screen Size`。按文档规定设置 Sort Order，避开系统 UI 保留层级。
- 无代码按钮可在 Inspector 的 `Button.On Click()` 中绑定 `GameObject.SetActive`；需要业务逻辑时绑定 `Douyin Script` 方法。
- 横竖屏差异较小时使用单 Prefab 适配组件；差异较大时使用双 Prefab 适配组件。
- UI Sprite 在 Project 窗口中关闭 `Generate Mip Maps`，避免移动端画质降级。

详细资料：

- [界面开发概述与规范](../Ⅱ.%20界面与交互(UI)/界面开发概述与规范.md)
- [自定义界面](../Ⅱ.%20界面与交互(UI)/自定义界面.md)
- [系统界面](../Ⅱ.%20界面与交互(UI)/系统界面.md)

## 验证

1. 保存场景和 Prefab，确认 Unity 完成脚本编译且 Console 没有错误。
2. 使用 抖音虚拟世界SDK 模拟器验证脚本生命周期、Inspector 引用、交互按钮、物理和 UI。
3. 多人功能必须在所选网络模型中验证主权、同步、断线重连和动态对象生命周期。
4. Dedicated Server 功能必须分别验证客户端与服务端，并确认服务端专属对象和代码未进入客户端构建。
5. 发布前按 [Code Review](../../Code%20Review/README.md) 检查硬性规则，并通过 [API Reference Index](../../API%20Reference%20Index.md)核对实际调用的 API。
