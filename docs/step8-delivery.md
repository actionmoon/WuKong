# 悟空 · 虎先锋交付报告

场景、玩法与表现的本轮实现和回归已交付。固定用例、实际回放、双端同步与正常退房分别记录；自然完整通关、目标手机及完整视觉一致性仍未验收。使用方式见 [运行与操作说明](run-and-controls.md)，分步历史见 [任务计划](plan.md)。

**2026-11-23 渲染更新已交付**：恢复 462 个源材质、ACES、环境光与阴影，修复本轮 BuiltIn Deferred / Metal 编译阻塞，重新构建并完成双端 77/77 与 F5 / F6 回归。最新缓存、截图、性能和边界见[渲染实施记录](render-restoration-implementation.md)。下文保留步骤 8 的历史验收数据；其中旧构建时间、材质路径及 Shader 编译问题不再描述最新渲染版本。

## 交付内容

| 内容 | 位置 |
| --- | --- |
| Unity 场景 | `unity/Assets/WuKong/Scenes/WuKongTiger.unity` |
| 场景、角色、碰撞、动画与材质 | `unity/Assets/WuKong/Art/`、`Animations/`、`Materials/` |
| HUD、声音与特效 | `unity/Assets/WuKong/Prefabs/`、`Audio/`、`VFX/` |
| 客户端输入、镜头和表现 | `unity/Assets/WuKong/Lua/Client/` |
| 共享配置、快照与模型 | `unity/Assets/WuKong/Lua/Shared/` |
| DS 战斗、Boss、技能与结算 | `unity/Assets/WuKong/Lua/Server/` |
| 导入与场景装配 | `unity/Assets/WuKong/Editor/`、`tools/prepare_*.py` |
| 原网页和原资源契约 | `docs/reference/wukong/` |
| 最终启动缓存 | `unity/AddressableAssetsData/StandaloneOSX/WuKongTiger/OSX/addrsettingcache/` |

源文件与 SHA-256 清单、构建缓存、退房事件、固定用例及相同快照计数见 [最终交付证据](reference/step8-delivery-evidence.json)。最终资源构建于 **2026-11-22 16:16:45 +08:00**。场景保持保存状态，无自动回放标记；运行时手动按键启动诊断。场景依赖及 Console 见 [编辑器核验](reference/step8-editor-audit.json)。

资源映射沿用 [步骤 2](reference/step2-runtime-evidence.json)、[步骤 3](reference/step3-runtime-regression.json)、[步骤 5](reference/step5-runtime-regression.json)、[步骤 6](step6-skills.md) 和 [步骤 7](step7-presentation.md) 的实现与证据。27 项核心资源、10 个 GLB、场景碰撞、304 个动画剪辑、619 个声音片段、四段 BGM、39 张表现纹理和 80 项表现映射已进入转换链路。它们的数量不等于全部源行为已逐项视觉验收。

## 本轮验收

最终会话为 `hamlet-simulator-imtm7zj4`，原始日志位于：

`/var/folders/t5/cx_l90z95vx72xgc8ps0j8n80000gn/T/hamlet-simulator-imtm7zj4/`

服务端和原 A / B 的 PID 为 `46908 / 46913 / 46956`；B 同身份、同房间重新加入的 PID 为 `47207`。原始日志保留在本机临时目录，交付 JSON 只摘录业务数据和必要的脱敏生命周期字段。

| 检查 | 结果与边界 |
| --- | --- |
| 加载与资源 | 最终缓存可加载卧虎寺、天命人、虎先锋和 HUD；参考资源按原清单重新校验 |
| Lua 与固定模块 | 本地 59/59 固定用例；全部生产 Lua 文件语法通过 |
| DS 固定回归 | 77/77，包含 59 项及 Boss 18 项再次执行 |
| 棍势、法术、变身、精魄 | F5 实际回放，覆盖消耗、定身、化气、破隐、广智、毒蛇与毒弹、死亡和重试 |
| Boss 类别与阶段 | F6 覆盖远近决策、五个血量阶段、拳剑、投射物、石化、隐身与结算；51 项技能时间轴由固定用例执行 |
| 轻重棍致死 | 实际 DS 命中后进入胜利并重试；回放将 Boss 血量设为 1，属于致死链验证 |
| 第二端与独立挑战 | B 后加入接收 A 的战斗状态，同时拥有自己的资源和 Boss；其请求和结算没有改写 A 的挑战 |
| 离开与重新加入 | B 在聚形散气状态下 Command-Q 正常退房，DS 收到 `ExitRoom`；以相同身份再次入房，创建新的挑战并同步现存状态 |
| 保活网络重连 | 未模拟 Wi-Fi 断开、弱网和 SDK 保活恢复；正常退房重进、首轮杀端重进不能替代该用例 |
| 场景路线 | B 重新加入后按 T，经出生点、通道、楼梯、入口到血池；该路线属于固定输入辅助 |
| 自然战斗与真实输入 | 首轮 B 实际 Enter 开始、鼠标左键触发轻棍、Boss 正常攻击致死、Enter 重试；最终 B 真实键盘 2 施法和退房已取证 |
| 界面布局 | 步骤 7 的四种横屏项目按钮边界与重叠检查通过；部分 SDK 叠层仍可见 |
| 音效与特效 | 有实际播放、粒子、拖尾及状态切换记录；仍存在未映射通知，见步骤 7 和最终计数 |
| 运行与退出日志 | 项目 Lua 退出异常已修复；SDK 关闭阶段仍输出 `GamePlayEntry Shutdown Exception` / `NullReferenceException` |
| Console 与渲染 | 场景缺失脚本为 0；glTF ShaderGraph BuiltIn Deferred / Metal 编译错误仍存在，不能标记无错误构建 |

最终运行计数、性能和两端逐条快照见 [完整运行证据](reference/step8-runtime-evidence.json)。该证据的整体 `pass` 仍会因 SDK 关闭空引用而为 `false`，与表中的固定用例及项目 Lua 检查分别解释。

最终资源校验为 **161/161**，语法为 **31/31**，运行固定用例为 **77/77**。后加入客户端覆盖全部五个阶段，两端有 **55 条完整内容相同的快照**。最终重棍命中造成 **326** 点伤害并致死；A 重试后处于 epoch 5 的满血、满法力待战状态，精魄能量约 211.836。全部验证进程已退出，项目 Lua 异常为 **0**；三个客户端各保留一条 SDK 关闭空引用日志。

最终两份 catalog 的 SHA-256 相同，实际四个资源包合计 1,327,477,083 字节，逐包哈希保存在交付证据中。资源包体积约 1.24 GiB，本轮尚未进行目标手机包体优化。

本机 A 1084×644、B 1158×632，A 战斗均值 **57.40 FPS**、最低五秒区间 **56.49 FPS**，帧时间 P95 最大 **17.59 ms**，Unity 分配内存峰值约 **1.35 GiB**。输入 / 快照 JSON 均值为 **2.91 / 23.74 KiB/s**。声音播放 357 次、采样声源峰值 9；特效爆发 134 次、活跃实例峰值 8、粒子峰值 414；15 次声音与 1 次特效通知未映射。不同轮的窗口尺寸、行为和统计时长不同，不据此宣称性能提升。

## 本步修复

正常退出暴露了销毁顺序问题：世界服务已关闭，部分 UGUI 和 Renderer 也已销毁，而清理回调仍访问 Actor 或组件属性。

1. `CombatInput.lua` 在 Actor 销毁时清空输入状态；世界销毁时只释放监听和引用，不再访问失效 Actor。按钮解除监听前检查 `IsNull()`。
2. `PresentationFX.lua` 写回原材质前检查 Renderer 是否有效；`PresentationHUD.lua` 解除按钮监听前作同样检查。
3. `PresentationAudio.lua` 清理声源前检查有效性；`AvatarVisualSample.lua` 的销毁回调不再调用失效 Actor 的可见性服务。
4. 补充 `tools/record_delivery_evidence.py` 和实际操作说明。没有提交 Git；现有 `GraphicsSettings.asset` 变更为同一组 Always Included Shader 的顺序变化，保留用户已有工作。

输入 / 特效失败轮保留在 [首轮记录](reference/step8-first-attempt.json)，HUD 清理失败轮保留在 [第二轮记录](reference/step8-hud-cleanup-attempt.json)。最终正常退出没有这些项目 Lua 异常；SDK 关闭日志另列为剩余问题。

最终核验命令结束后，沙箱报告回收了 `/Users/bytedance/Documents/aireverse/WuKong/.git/index`。Git 索引需要用户在 Finder 打开废纸篓，先检查 `sboxbackup`，再将文件拖回原路径。未访问或自动恢复废纸篓内容；本轮没有提交 Git。

## 与原站的差异

- **场景与镜头**：沿用原资源、坐标与路线。Unity 材质、URP 光照、阴影、血池和毛发观感仍与 Three.js 原站有差异，未声称像素一致。场景实际同时引用 `World_Lit`、glTF ShaderGraph、URP Unlit 和 Particles Unlit；不是全部材质都已替换为 `World_Lit`。
- **多人结构**：原网页是单机，本项目用 DS 为每个玩家维护独立挑战；其他客户端可观察共享快照，不增加合作玩法。正常退出或杀端后重新加入会重新建立该玩家的挑战。
- **特效**：源 Niagara / 网页的网格、折射、屏幕后处理与部分曲线使用 Unity 粒子近似。死亡使用透明淡出；武器拖尾、噪声溶解、毛发及石化材质曲线尚未完全还原。
- **声音**：保留源片段、随机变体和事件映射；快照区间内多次命中可能合并播放。部分声音与特效通知仍无映射，播放统计不替代听感验收。
- **操作**：真实键盘、鼠标左键动作和诊断回放已有证据。鼠标右键长按、UGUI 按钮点击、手机多指操作与目标手机性能仍待验。
- **通关与网络**：回放使用固定血量、重置和强制技能。无辅助自然完整通关、实际断网后的 SDK 保活重连、真机退出恢复尚未验证。

## 截图对照

- [原站出生角度](reference/step3-reference-spawn-wk-arena-114152.png) / [最终 Unity 出生角度](reference/step8-final-spawn.jpg)。
- [原站血池角度](reference/step3-reference-blood-pool-wk-arena-114152.png) / [首轮 Unity 实际战斗](reference/step8-battle-window.jpg)。
- [最终聚形散气、正常退出前](reference/step8-cloud-before-exit.jpg)、[首轮自然死亡](reference/step8-natural-defeat.jpg)、[首轮 Enter 重试](reference/step8-natural-retry.jpg)。

截图来自各自运行窗口，分辨率、相机角度与时间不同，用于核对场景和表现，不构成逐像素对比。
