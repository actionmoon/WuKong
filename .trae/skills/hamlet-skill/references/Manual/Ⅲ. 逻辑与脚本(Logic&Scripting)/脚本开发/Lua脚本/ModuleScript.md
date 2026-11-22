# Module Script

> **适用范围**：当 [hamlet-preferences.md](../../../../../hamlet-preferences.md) 中 `DevTool=UnityEditor` 时阅读。
> `DevTool` 的详细说明请参考[开发工具概述](../../../VI.%20开发工具/开发工具概述.md)。

在常规开发中，我们通过 `Douyin Script` 组件加载 Lua 文件，使其具备类似 Unity `MonoBehaviour` 的生命周期和序列化能力。然而，并非所有的 Lua 脚本都需要挂载到场景对象上运行。例如 **Lua 配置文件**、**公共基础库**以及**第三方逻辑库**等，这类不依赖特定游戏对象的全局脚本在抖音虚拟世界中被称为 **Module Script**。

## 1. 适合放进 Module 的内容

在开始使用 Module Script 之前，需要明确其边界：

- **适合放入 Module**：配置表、常量定义、公共工具函数、事件系统、纯数据/逻辑模块以及第三方 Lua 库封装。
- **不适合放入 Module**：依赖 `Awake / Start / Update / OnNetSpawned` 等生命周期回调的组件脚本、必须直接挂载在 GameObject 上的行为脚本，以及依赖 Inspector 暴露字段的场景脚本（此类应使用 `Douyin Script`）。

## 2. Douyin Script Loader 组件

为了加载和管理这些全局的 Module Script，平台提供了 `Douyin Script Loader` 组件。在 Dedicated Server（DS）模式下，还引入了专门用于服务器端的 `Douyin Server Script Loader`。

### 组件挂载机制与 DS 模式支持
- **基础加载器 (`Douyin Script Loader`)**：
  当你在场景的根节点上添加 `Douyin World Root` 组件时，系统会自动将 `Douyin Script Loader` 组件挂载到该对象上。
  > **注意**：每个场景只允许存在一个 `Douyin Script Loader` 实例。此加载器下的脚本，**客户端和 DS 服务器都可以使用**。

- **服务器专属加载器 (`Douyin Server Script Loader`)**：
  在 Dedicated Server（DS）模式下，需要在 Hierarchy 面板创建一个名为 `DouyinServerRoot` 的空节点，并挂载 `Douyin Server Script Loader` 组件。
  > **⚠️ DS 模式互斥约束与节点约束**：
  > 1. **不可见性**：`DouyinServerRoot` 节点及其所有子节点在**构建客户端 AssetBundle 时会被自动剔除**，仅保留在 DS 端。因此，`Douyin Server Script Loader` 目录下的脚本**只能由 DS 服务器使用**，客户端完全无法访问。
  > 2. **严格互斥**：已经放入 `Douyin Script Loader` (客户端/双端共享) 目录中的脚本，**绝对不能**再放入 `Douyin Server Script Loader` 中，二者是严格互斥的。同一份 `.lua` 文件不能同时放在两侧的 Loader 里。
  > 3. **防空载异常**：`DouyinServerRoot` 下**必须挂载至少一个服务器脚本**，否则在运行时会报 `NetworkNetPacket_PlayerEnterSyncForOther Playerlnfos miss.` 错误。
  > 4. **组件限制**：`DouyinServerRoot` 节点下**不允许挂载 Canvas 节点**。
  > 5. **模式边界**：场景内是否存在 `DouyinServerRoot` 节点是判定是否开启 DS 模式的唯一标准。若需要使用 SharedMode（共享模式），场景中**禁止**出现此节点。

### 组件配置项
该组件主要包含两个文件夹路径配置，用于定位加载 Module Script：

1. **Douyin Scripts Folder (默认配置项)**
   - 指向抖音虚拟世界提供的**官方 Module Script 目录**。
   - 该目录包含了平台预置的核心库。你可以查看并修改它们，但请注意**务必备份修改内容**。因为在 SDK 升级时，官方目录内的 Lua 文件可能会被强制重置或移除。
   
2. **Custom Scripts Folder (自定义配置项)**
   - 留给开发者配置当前场景的**自定义 Module Script 目录**位置。
   - 所有你自己编写的配置表、数据管理单例等均应放置在此目录下。

## 3. 存储、加载机制与生命周期

`Douyin Script Loader` 管理的 Module Script 会在 Unity 场景保存时，序列化成二进制数据并内嵌到 Unity 场景文件中。

### 生命周期与执行顺序

每个场景被加载并创建出新的 Lua 虚拟机后，会优先执行 `Douyin Script Loader` 所管理的 Module Script，随后才会执行那些挂载在 GameObject 上的普通 Lua 脚本。

**严格的加载顺序规则：**
1. 首先执行 `Douyin Scripts Folder` (官方目录) 下的 `index.lua`。
2. 接着执行 `Custom Scripts Folder` (自定义目录) 下的 `index.lua`。
3. 最后，执行所有通过 `Douyin Script` 组件挂载的常规 Lua 脚本。

基于此机制，**开发者可以在 `Custom Scripts Folder` 的 `index.lua` 中通过 `require` 引入所有的自定义配置文件和公共库**，以确保在场景内的其他业务 Lua 脚本启动前，所有的前置公共模块已全部初始化完毕。

## 4. 模块入口 index.lua 与 require 聚合

为了维护庞大的模块代码，官方强烈建议使用 **目录级 `index.lua` 聚合** 的方式组织 Module Script。

### `index.lua` 作为 Module 入口

在 Module Script 的架构中，`index.lua` 被严格定义为模块的**初始化与执行入口**。

- **强制要求**：Module 的根目录**必须存在** `index.lua` 文件，否则引擎无法找到模块的执行起点，上传世界时也会直接报错。
- **核心职责**：`index.lua` 应仅作为入口进行聚合和初始化，负责按需 `require` 其他模块，**避免在其中堆砌大量业务逻辑**。
- **目录级聚合**：除了根目录，公共库或配置表等子目录也应各自拥有自己的 `index.lua`，最后由根入口统一聚合。

### `require` 的使用口径
- **路径解析**：`require` 使用相对路径加载，路径基于**当前脚本所在目录**解析。同目录文件之间可直接 `require "FileName"`。
- **严格匹配**：`require` 路径字符串必须与真实的目录名和文件名**严格一致**（大小写敏感）。
- **聚合调用示例**：
  优先保持入口的清晰度，不要在根 `index.lua` 中一次性散落大量深路径的 `require`，而是优先加载子目录的 `index.lua`。

```lua
-- 根 index.lua (只负责聚合子模块)
require "Common.index"
require "Config.index"
```

```lua
-- Common/index.lua (聚合该目录下的具体工具)
local MathUtil = require "Common.MathUtil"
local EventBus = require "Common.EventBus"
```

```lua
-- ItemSystem/ItemManager.lua (跨层级调用示例)
local Config = require "../Config/GameConfig.lua"
```
