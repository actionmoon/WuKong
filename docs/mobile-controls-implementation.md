# 移动端按钮实施与验收

日期：2026-11-23。状态：代码实现与场景装配完成，桌面回归通过；目标手机验收待进行。用户已明确确认按[设计方案](mobile-controls-design.md)实现。

## 实施顺序

1. 装配四层圆形按钮、容器内状态提示、冷却及能量反馈。半径、直径和角度沿用设计表，按真实屏幕与安全区等比缩放。
2. 统一触摸归属、按下去重、多指按住与生命周期清理；沿用原战斗命令与服务端判定。
3. 更新触屏帮助、技能状态提示、锁定／疾跑／棍势反馈与蓄力显示。
4. 验证生产 Lua 语法、技能固定用例及输入状态转换；通过 Unity MCP 装配保存、构建，再执行 Hamlet 运行核验。
5. 更新实际操作说明、任务计划与本页证据。真实点击、多指与固定输入回归分别记录。

## 实现结果

- `WuKongPresentationBuilder.cs` 生成 408×408 容器、四层 1／2／4／5 圆形按钮及容器内提示。半径 44／156／260／356，直径 92／84／76／68，径向净间隙 24。圆形贴图作为实际场景资源保存。
- `PresentationHUD.lua` 根据真实屏幕、安全区与画布缩放系数等比调整操作区；显示冷却遮罩、能量进度、形态返回、按住状态和触屏帮助。技能资格读取生产配置与快照，不因攻击动作禁止合法技能排队。提示区为 180×24，与最外层按钮保留间隙。
- `CombatInput.lua` 使用手指 ID 记录首次按下的归属，UGUI PointerDown／Drag／PointerUp 与屏幕轮询进入同一生命周期。平台无 ID／阶段的通知不单独提交命令。点击队列保留每次按下；重棍、棍花按多指聚合，滑出后不重新获取按钮。
- 帮助、竖屏、失焦、死亡、epoch 切换、角色销毁与世界退出清理待提交点击和按住状态。中央开始／重试按钮保留独立入口。
- 场景 `Assets/WuKong/Scenes/WuKongTiger.unity` 已通过 Unity MCP 装配保存并构建。最初 MCP 服务断开已恢复，临时重连脚本已移除。

## 验收结果

| 范围 | 结果与证据 |
| --- | --- |
| 生产 Lua 语法 | 31 个 Lua 文件加载检查通过 |
| 固定战斗回归 | Lua 5.3 下 59 项通过：[固定结果](reference/mobile-controls-fixed-evidence.json) |
| 输入与技能资格 | 7 组通过，覆盖重复回调、滑出不转交、空白滑入、同按钮双指、取消、面板／重置及冷却／资源／形态／动作排队：[用例证据](reference/mobile-controls-input-layout-evidence.json) |
| 数学布局 | 5 组尺寸与安全区计算通过，包括 960×540 留白 18；外层触达尺寸 51×51，按钮与提示不重叠 |
| 最终实际横屏 | 960×540、1280×720、1600×720、1024×768：按钮越界 0、重叠 0，容器、交互矩形和提示区的操作区域违规 0：[最终测量](reference/mobile-controls-final-runtime-evidence.json) |
| Hamlet 运行 | Unity 2021.3.45f2，DS＋两客户端，新网络、Avatar、存储关闭。F8＋F5 合计 69 项固定用例通过，技能回放完成；三端 Lua／空引用错误 0：[运行证据](reference/mobile-controls-runtime-evidence.json) |
| 最终构建 | 2026-11-23 12:06:16 更新 catalog；提示区域调整后重新启动 DS＋两端，F8 的 10 项通过，三端错误 0，F4 四种尺寸补测通过 |
| 可见布局 | 最终构建模拟器实际加载圆形扇形按钮：[截图](reference/mobile-controls-simulator.jpg) |
| 真实点击 | 桌面工具三次不同位置点击均返回相同输入位置 `(182,332)`，未观察到预期按钮操作；保留为未验证。程序回放与生命周期用例不代替真实点击 |
| 手机 | 真机多指、触达舒适度、触摸滑出及镜头隔离尚未验证 |

运行原始会话：`/var/folders/t5/cx_l90z95vx72xgc8ps0j8n80000gn/T/hamlet-simulator-8uewyqm0/session.json`。原始账号及 SDK 日志留在本机临时目录，文档仅引用必要的业务证据。

最终构建补验会话：`/var/folders/t5/cx_l90z95vx72xgc8ps0j8n80000gn/T/hamlet-simulator-bcgtumsq/session.json`，两客户端保留运行供查看。构建过程中 SDK 自动改写的全局 GraphicsSettings 已恢复原设置，按钮布局与当前场景缓存已保存。

## 复验

1. `python3 tools/verify_mobile_controls.py`。
2. `python3 tools/verify_skills.py --output mobile-controls-fixed-evidence.json`。
3. 按[运行说明](run-and-controls.md)构建启动，F4 测量布局，F5 执行技能回放，F8 执行基础固定用例。
4. 在目标手机逐项检查[设计验收表](mobile-controls-design.md#验收)，分别记录真实点击、多指与镜头操作。

本记录独立于步骤 8 的历史验收，不回写其结果。
