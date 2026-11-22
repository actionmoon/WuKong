# 悟空 · 虎先锋运行与操作

交付场景为 `unity/Assets/WuKong/Scenes/WuKongTiger.unity`。使用 Unity `2021.3.45f2`、URP `12.1.15`，网络与角色配置沿用 [项目偏好](../.trae/skills/hamlet-skill/hamlet-preferences.md)。开发、打包和验证规则统一见 [任务计划](plan.md) 引用的技能。

## 启动

1. 用指定 Unity 版本打开 `unity/`，登录抖音虚拟世界 SDK，打开并保存交付场景。首次使用新环境时，通过 SDK 模拟器窗口构建、启动一次，以取得本机调试器与登录记录。
2. 选择 Unity 菜单 `Tools/ScenePackage`，等待打包结束。确认 `unity/Library/com.unity.addressables/aa/OSX/catalog.json` 已更新；实际启动缓存位于 `unity/AddressableAssetsData/StandaloneOSX/WuKongTiger/OSX/addrsettingcache/`。
3. 在仓库根目录执行本地校验：

   ```bash
   python3 tools/run_sample.py --dry-run
   ```

4. 校验通过后启动：

   ```bash
   python3 tools/run_sample.py --hold
   ```

   启动器创建一个 DS 和“悟空测试A / 悟空测试B”两个客户端，使用新网络、新房间、Avatar、关闭数据存储。登录凭据由本机已登录的 Editor 读取到进程环境。此项目的窗口副本为 `ClientA.app`、`ClientB.app`；换机器后需先在 SDK 安装对应调试器，按 [启动器参数](../.trae/skills/hamlet-debugging/SKILL.md) 指定实际可执行文件。

5. 等待两端显示卧虎寺、天命人、虎先锋和开始面板。按 Enter 开始挑战，再沿通道走向血池。完成验证后用 macOS 的 Command-Q 退出客户端，再停止保留运行的启动命令。每次启动输出的临时 `session.json` 记录本轮 PID 与日志位置。

`--dry-run` 只核验本机启动前提。启动成功与实际玩法验证分别记录。修改 Lua、场景或资源后应重新打包。

## 游戏操作

| 操作 | 键鼠 |
| --- | --- |
| 移动 / 疾跑 / 慢走 | WASD / Shift / Ctrl 或 Alt |
| 轻棍 | 鼠标左键 |
| 重棍 / 蓄力 | 鼠标右键，按住蓄力、松开释放 |
| 闪避 | Space |
| 棍花 | V，按住持续 |
| 劈棍 / 立棍 / 戳棍 | Z / X / C |
| 定身法 / 聚形散气 | 1 / 2 |
| 赤潮变身 / 返回 | 4 |
| 广谋精魄 | F |
| 葫芦 | R |
| 锁定 / 解除 | Q 或鼠标中键 |
| 开始 / 重新挑战 | Enter |
| 帮助 / 静音 | H / M |

触屏提供官方摇杆及右侧战斗按钮。项目已核验四种横屏尺寸的按钮边界；真机、多指蓄力与操作听感尚未验收。macOS 本轮实际鼠标左键已触发轻棍；右键长按、UGUI 按钮点击仍需独立验证。

每个真实玩家拥有独立的 Boss、资源和挑战结算。另一客户端接收共享战斗快照用于观察，不增加合作伤害或共用血条。杀端重进后重新建立该玩家的挑战，其他玩家的挑战继续；当前挑战没有存档。

## 复现回归

1. 使用上述最终缓存启动三端。A 按 F5，等待日志出现 `[WK-SKILLS-REPLAY] finished`，约 77 秒。它执行棍势、法术、变身、精魄、死亡和重试，并运行 59 项固定用例。
2. A 按 F6，等待 `[WK-BOSS-REPLAY] finished`，约 83 秒。它补跑 Boss 18 项固定用例，并覆盖远近距离、五个血量阶段、投射物、石化、轻重棍致死和胜败重试。
3. B 按 T 走固定路线，日志应依次出现出生点、通道、楼梯、战斗入口、血池，最后 `route-stop reason=completed`；Y 停止路线。B 可独立按 Enter 开始，再观察其结算不影响 A。
4. F4 检查四种横屏布局。F7 是基础战斗回放；F8 是基础固定用例；F9 将本地角色移到 Boss 附近并重置诊断战斗；F10 发起诊断伤害。
5. 将实际会话路径传给取证器：

   ```bash
   python3 tools/record_presentation_evidence.py /实际会话/session.json --output step8-runtime-evidence.json
   python3 tools/verify_skills.py --output step8-fixed-evidence.json
   python3 tools/record_delivery_evidence.py /实际会话/session.json
   ```

   后两项需要运行脚本所用 Python 环境已安装 `lupa`。交付证据采集器应在验证结束、所有实例退出后执行；它核对参考 SHA-256、Lua 语法、源码清单、退房事件及两端相同快照。

F4～F10 的诊断入口均限制在 Hamlet 调试器。回放会使用重置、固定血量或强制施法，不能作为无辅助自然通关证据。资源映射与已验结果见 [交付报告](step8-delivery.md)。
