# 虎先锋 AI 与挑战循环

场景：`unity/Assets/WuKong/Scenes/WuKongTiger.unity`。运行配置沿用 [Hamlet 偏好](../.trae/skills/hamlet-skill/hamlet-preferences.md)，开发与调试约束以 [任务计划](plan.md) 引用的规范为准。

1. 在 Unity 打开场景，执行 `Tools/ScenePackage`，确认 `Library/com.unity.addressables/aa/OSX/catalog.json` 更新时间。
2. 在项目根目录执行 `python3 -B tools/run_sample.py --dry-run`，然后执行 `python3 -B tools/run_sample.py --hold`。
3. 点击“开始挑战”或按 Enter；也可沿通道走入血池入口，服务端会按源触发盒启动战斗。操作仍为左键轻棍、右键蓄力、Space 闪避、R 葫芦、Q 锁定。
4. 虎先锋死亡后等待 2.5 秒，玩家死亡后等待 2.2 秒，点击“重新挑战”或按 Enter。角色返回出生点，双方血量、资源、动作、冷却、Buff、危险物和石像分身重新初始化。

每位玩家拥有独立挑战。DS 按真实玩家身份维护 Boss 位置、技能和结算；共享 `CombatState` 网络对象以 20 Hz 快照向所有客户端传播。每个客户端默认显示自己挑战的虎先锋及危险物；其他挑战的数据仍可在同步日志中核验。客户端脚本 `BossPresentation.Observe(actorID)` 可供诊断时选择旁观上下文，不改变战斗归属。

- 感知：听觉 12 m；视野 40 m、半角 50°；强制战斗盒沿用源位置和尺寸。
- 阶段：HP >85%、≤85%、≤60%、≤50%、≤40%。≤50% 触发 BGM 阶段事件，实际声音在步骤 7 接入。
- 行为树：选择 / 顺序节点、观察中止、连招预算、加权长度、技能评分、冷却、前置冷却、转向和追击；EQS 环形候选点经静态地面校验。
- 战斗：拳剑动作按真实骨骼扫掠；每次动作 / 命中窗口去重；霸体窗口耗尽的当次攻击保持动作，后续命中按硬直配置响应。
- 铜头铁臂：免伤并反弹玩家动作；虎先锋播放对应石化反击。没有新增架势条。
- 化石遁形：石像分身存在 2.5 秒，承受攻击时反弹并给 Boss 加标记；隐身阶段不可锁定，随后按源 15 m 环形候选点传送和攻击。
- 危险物：风刃、追踪旋风、回归挂点旋风按源体积、速度、延迟、间隔和寿命结算。无伤害的空弹不增加伤害；缺失的转化目标按原站移除。

源 51 项技能与 3 项舍弃条目见 [技能映射](reference/step5-skill-mapping.json)。81 个动画剪辑包含技能、反击、死亡及移动。当前危险物用半透明实际碰撞体表现；粒子、材质渐变、溶解、音效及完整 HUD 美化按步骤 7 完成。

固定回归：

```bash
python3 -B tools/prepare_boss.py
python3 -B tools/verify_boss.py
python3 -B tools/verify_combat.py
```

真实调试器中 F6 启动约 83 秒的 Boss 回放，包含 DS 固定用例、远近距离、血量阶段、投射物、石化、胜败、重棍和重试。技能强制施放、改血量、补血和强制死亡仅在 `DouyinApplication.isSimulator` 时接受；这些用例的启动条件与实际骨骼伤害分别记录，不作为自然完整通关证据。

导出业务证据：

```bash
python3 -B tools/record_boss_evidence.py /实际路径/hamlet-simulator-会话
```

原始平台日志保留在临时会话中；交付文件只保存悟空业务事件。

实际验证记录（2026-11-22）：

- [首轮 DS 与双端证据](reference/step5-runtime-evidence.json)：观察到拳剑伤害、旋风伤害、石像分身约 2.5 秒生灭、传送、石化免伤反弹和反击，以及胜败重试的同步。该轮胜利由调试改血量触发，不能作为棍击致死证据。
- [补充回归证据](reference/step5-runtime-regression.json)：静止、1 HP 的 Boss 由轻棍实际命中造成 55 点伤害、一级蓄力重棍实际命中造成 334 点伤害后死亡；两端均收到对应胜利状态。三次重试后 epoch 为 4，双方血量和玩家资源恢复，危险物 / 分身 / 石化 / 隐身清理，两客户端最终快照一致，三端 Lua 异常为 0。两轮实际观察到 10 项 Boss 技能。
- 固定用例 Boss 18/18、玩家 10/10 通过；21 个 Lua 文件语法校验通过。固定用例覆盖 51 项技能时间轴，实际客户端技能覆盖以证据文件中的观察列表为准。
- 最终场景已移除临时自动回放标记并保存，构建缓存更新时间 `2026-11-22 13:10:41.457657 +08:00`，启动 dry-run 通过；本轮三个调试器进程已核验退出。
- 桌面锁屏使手动键鼠、触摸输入和截图未取得证据；未验证自然完整通关。粒子、材质曲线、溶解与音效仍按步骤 7 接入。
- Unity 构建日志仍有 glTF ShaderGraph 的 BuiltIn Deferred / Metal `PBRDeferredFragment` 类型编译错误；Addressables 缓存已实际更新并用于三端运行，该着色器问题仍待视听阶段处理，未判定已修复。
