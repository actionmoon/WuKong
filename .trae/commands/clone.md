---
name: "clone"
description: "使用Unity完成REA项目克隆"
---

1. 使用 `agent-browser` 访问项目 [saltiline](https://claude.ai/artifact/BGY1SztrAYcJQHSsnHHGmp)，并提取静态与动态资源和脚本。
2. 分析页面的脚本实现和资源引用。
3. 基于分析结果，使用下面的工具，生成项目克隆的规划文档，保存到`docs/plan.md`文件中。
- 调用`unity-mcp` 操作Unity工程
- 使用`hamlet-skill`完成代码生成
- 使用`hamlet-debugging`启动调试器调试和验证
4. 按照`docs/plan.md`文件中的步骤，执行项目克隆的步骤；每一步完成后，按照下面的流程确认是否符合预期结果，并记录验证结果到`docs/plan.md`文件中，等待人工确认是否继续执行下一步。
