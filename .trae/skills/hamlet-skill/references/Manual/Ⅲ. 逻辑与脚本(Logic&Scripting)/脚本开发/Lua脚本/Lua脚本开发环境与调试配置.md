> **适用范围**：当 [hamlet-preferences.md](../../../../../hamlet-preferences.md) 中 `DevTool=UnityEditor` 时阅读。
> `DevTool` 的详细说明请参考[开发工具概述](../../../VI.%20开发工具/开发工具概述.md)。

推荐使用 **VS Code** 进行 Lua 脚本的编写和调试。

### 1. 基础配置
1. 安装并打开 VS Code。
2. 在右下角的 Language Mode 中选择 **Lua**，开启语法高亮。
3. 代码编辑完成后，务必使用 `Ctrl+S` (或 `Cmd+S`) 保存，以确保 Unity 能够读取到最新代码。

### 2. 断点调试 (基于 Lua Debugger 插件)
1. 在 VS Code 扩展商店搜索并安装 **Lua Debugger** 插件。
2. 在 VS Code 中打开 Unity 项目的**根目录**。
3. 打开调试面板，点击 `create a launch.json`，选择 `Lua Debugger`。在生成的配置中，删除多余项，**只保留名为 "wait" 的启动项**。
4. 按 `F5` 启动调试，状态栏会提示等待模拟器链接。
5. 在 Lua 源码中点击行号设置断点。（若无法设置，在 VS Code 设置中搜索 `allowBreakpointsEverywhere` 并将其改为 `true`）。
6. 回到 Unity Editor 启动模拟器运行场景，代码执行到该行时即可触发断点。
