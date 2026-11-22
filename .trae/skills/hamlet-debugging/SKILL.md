---
name: hamlet-debugging
description: 使用抖音虚拟资产调试器运行单机、SharedMode 和 DedicatedServer；需要验证功能、分析客户端与服务端日志、定位运行问题、修复并回归时使用。
---

# 平台调试

## 调试流程

按「明确用例 → 打包 → 本地校验 → 启动 → 操作与日志验证 → 定位修复 → 重新打包回归」执行。启动器为 [scripts/simulator.py](scripts/simulator.py)，要求 Python 3.9+，仅使用标准库，支持 macOS 和 Windows。

1. 确定 Unity 项目、场景、网络模式、角色类型、客户端昵称和存储需求。默认配置读取 [项目偏好](../hamlet-skill/hamlet-preferences.md)，结合本次需求显式传参，避免最近一次 SDK 启动记录改变测试条件。
2. 将功能拆为可复现的操作步骤和可观察的预期结果，标明哪些结果应出现在操作客户端、其他客户端及 DS 服务端。
3. 涉及平台 API、生命周期、主权或同步逻辑的修改时，按 [hamlet-skill](../hamlet-skill/SKILL.md) 查阅对应语言与模块文档。
4. 每轮保留启动条件、资源构建时间、会话目录、操作步骤及关键日志位置，供修复前后对照。

## 准备与打包

1. 在 Unity Editor 打开并保存目标场景，等待脚本编译完成，处理阻塞构建的 Console 错误。
2. 通过 `unity-mcp` 调用 Unity 菜单 `Tools/ScenePackage`。本项目菜单位于 `unity/Assets/Scripts/Editor/ScenePackage.cs`，内部调用 `SimulatorUtils.BuildActiveDebugScene()`。
3. 等待实际构建结束，检查 Unity Console / Editor 日志与资源更新时间，确认产物对应目标场景。菜单调用返回不代表构建已经完成。其他项目没有该菜单时，使用 SDK 模拟器窗口构建当前场景资源。
4. 首次使用或登录、设备、C# 脚本包记录缺失时，在 Editor 登录 SDK，并通过 SDK 模拟器窗口构建、启动一次。

启动器不构建 Unity，也不判断已有资源是否为最新版本；修改场景或脚本后重新构建。它检查并安装以下已有产物：

- Addressables 默认根目录为项目下的 `AddressableAssetsData/StandaloneOSX` 或 `AddressableAssetsData/StandaloneWindows64`，也可由 `worldAddressableBundle` 配置。
- 在根目录下查找 `OSX/addrsettingcache` 或 `Windows/addrsettingcache`；找不到 `settings.json` 时，再尝试根目录下的场景同名子目录。
- 缓存须包含可解析的 `settings.json` 和 `catalog.json`。实际启动时，复制到调试器的 `StreamingAssets/aa` 并覆盖同名缓存；同一个调试器安装目录的资源切换应串行执行。
- AssetBundle 模式须同时配置 `worldAssetBundle` 和 `worldAssetName`，会优先于 Addressables 场景配置。此时仅修改 `--scene` 不会切换实际加载的 AssetBundle。
- `worldScriptBundle` 指定的 C# 脚本包必须存在；SDK 配置 `enableCSharp` 为真时必须提供脚本包。

## 启动参数

在技能所在仓库目录运行下列命令；若工作目录不同，使用启动脚本的绝对路径。`--project` 指向含 `ProjectSettings/ProjectVersion.txt` 的 Unity 项目，本仓库为 `unity`。

```bash
python3 .trae/skills/hamlet-debugging/scripts/simulator.py --help
```

| 参数 | 用法与默认行为 |
| --- | --- |
| `--project` | Unity 项目或包含它的目录，默认当前目录；自动向上查找，或查找唯一的直接子项目 |
| `--mode single\|shared\|ds` | 显式选择模式；省略时结合 SDK 记录、EditorPrefs 和项目偏好推断 |
| `--players 昵称...` | 单机恰好一个，多人至少两个客户端；默认单机“玩家1”，多人“玩家1”“玩家2”；昵称去除首尾空白后须互不相同 |
| `--scene` | `Assets` 下的目标场景路径；省略时优先使用 Editor 活动场景，找不到时沿用启动记录 |
| `--room` | 旧网络使用最终房间 ID；新网络使用正整数房间 ID，填 `0` 创建新房间 |
| `--network auto\|legacy\|new` | 默认 `auto`；详见下节网络规则 |
| `--data-store on\|off` | 默认沿用 SDK 设置；开启时需要有效测试世界 |
| `--pawn-actor-type pet\|avatar` | Pet 对应 `0`，Avatar 对应 `1`；默认沿用记录或项目偏好 |
| `--relation` | Pet 客户端共享关系名，默认“模拟器合养关系” |
| `--executable` | 覆盖调试器路径，macOS 也接受 `.app`；否则读取 EditorPrefs 的 `HamletSimulator`，再回退到项目内 `DouyinWorldDebuggerEditor` |
| `--instance-executable ROLE=PATH` | 可重复；为 `server` 或 `client-N` 指定本地调试器副本。副本使用不同 Bundle ID 时，桌面工具可分别定位窗口；每个副本都会安装本轮场景缓存 |
| `--editor-log` | 添加 SDK Editor 日志，可重复；仍会读取默认 Editor 日志 |
| `--config` | JSON 公共参数覆盖文件，规则见下文 |
| `--windowless` | 仅设置 DS 服务端无窗口，客户端仍有窗口 |
| `--server-ready-pattern` | DS 服务端 Player 日志的就绪正则；匹配后才启动客户端 |
| `--timeout` | 等待 DS 就绪标记的秒数，默认 `60`，须为有限正数 |
| `--dry-run` | 仅本地校验；不联网、不构建、不复制资源、不启动进程、不写日志 |
| `--hold` | 保持启动器存活，供会在命令结束后回收子进程的受管终端使用；以后台命令运行，验证完成后停止该命令 |

### 网络与房间

- `auto` 实际启动时查询 SDK `/resource/editor/get_config`，根据 `net_module.pure_tcp`（兼容大写字段）选择网络；若 JSON 显式配置了 `isNewNetModule`，则使用配置值。`--network legacy/new` 优先于 JSON。
- `auto --dry-run` 不查询远端，使用本地配置或记录；通过仅代表本地前提满足，实际启动的网络选择和房间有效性仍需确认。
- 旧网络 SharedMode / DS 必须提供或从本项目 SDK 记录恢复最终房间 ID，不再拼接设备前缀。单机未指定有效房间时生成 `local-...`。
- 新网络未传房间时可能沿用启动记录或 EditorPrefs 的 `HamletSimulatorRoomID`；需要新房间时显式传 `--room 0`。启动器通过 `/room/user/create_local` 建房，或通过 `/room/user/get_local` 查询已有房间，所有实例使用接口返回的同一房间 ID。
- 新网络房间请求及 `auto` 配置查询依赖有效的 SDK 登录和设备记录。可由 `HAMLET_ACCESS_TOKEN`、`HAMLET_DEVICE_ID` 环境变量补充；非 `online` 环境还需对应 HTTPS `resourceUrl` 与 `envMark`。
- `--data-store on` 要求 `worldId` 为正整数，且 SDK 中选择的测试世界已启用存储。关闭存储时，脚本将 `worldId` 设为新网络 `1`、旧网络 `0`。

### 配置覆盖

启动器读取本项目的 SDK 启动记录、EditorPrefs、活动场景及 `Packages/com.douyin.world/Config/simulator.json`、`Packages/com.douyin.common/Config/SdkConfig.json`，随后应用 JSON 覆盖和对应命令行选项。SDK 记录只接受 `workingDir` 与目标项目一致的 `StartSimulatorProcess arguments:` 行；每个日志读取末尾最多 16 MiB，跨文件选择修改时间最新的有效来源。

- macOS 默认日志为 `~/Library/Logs/Unity/Editor.log` 和 `Editor-prev.log`；Windows 为 `%LOCALAPPDATA%/Unity/Editor` 下同名文件。
- JSON 顶层须为对象，键名不带前导 `-`，值不预先 URL 编码；布尔值使用 `true/false`，JSON 中 `pawnActorType` 使用 `0/1`。
- 可覆盖参数以脚本 `RUNTIME_KEYS` 为准，另支持 `resourceUrl`、`envMark`。常用项包括 `worldId`、`worldAddressableBundle`、`worldScriptBundle`、`worldAssetBundle`、`worldAssetName`、`environment` 和窗口宽高。
- `openId`、`nickName`、`relationName`、`workingDir`、`logFile`、`hdbLogFile`、`isDsServer`、`isWindowless` 由启动器管理，不能放入 JSON。模式与身份使用对应命令行选项设置。

例如，存储用例的配置文件可仅包含测试世界 ID（替换为 SDK 中的实际值）：

```json
{
  "worldId": "123456789"
}
```

通过 `--config /绝对路径/配置文件.json --data-store on` 使用。

## 本地校验与运行示例

以下示例以本仓库 `unity` 项目和 `SampleScene` 为例，执行前按目标用例调整。每次先在实际启动命令末尾加 `--dry-run` 校验，通过后去掉该参数启动。

### 单机

```bash
python3 .trae/skills/hamlet-debugging/scripts/simulator.py \
  --project unity \
  --mode single \
  --players '抖音仔仔1' \
  --scene Assets/Scenes/SampleScene.unity \
  --network legacy \
  --data-store on \
  --pawn-actor-type avatar \
  --dry-run
```

### SharedMode

启动两个客户端。下面使用新网络创建房间，需已具备 SDK 登录和设备记录：

```bash
python3 .trae/skills/hamlet-debugging/scripts/simulator.py \
  --project unity \
  --mode shared \
  --players '抖音仔仔1' '抖音仔仔2' \
  --scene Assets/Scenes/SampleScene.unity \
  --room 0 \
  --network new \
  --data-store on \
  --pawn-actor-type avatar
```

使用旧网络时，将 `--network new --room 0` 换为 `--network legacy --room <最终房间ID>`，填写本次测试实际使用的 ID。

### DedicatedServer

启动一个服务端和两个客户端，服务端先启动：

```bash
python3 .trae/skills/hamlet-debugging/scripts/simulator.py \
  --project unity \
  --mode ds \
  --players '抖音仔仔1' '抖音仔仔2' \
  --scene Assets/Scenes/SampleScene.unity \
  --room 0 \
  --network new \
  --data-store on \
  --pawn-actor-type avatar \
  --windowless
```

项目有明确的服务端就绪日志时，加 `--server-ready-pattern '实际就绪标记的正则' --timeout 60`，使用已确认代表场景和服务初始化完成的标记。该正则只匹配 `server.log`，不是 `server-console.log`，也不会等待客户端就绪。

未指定就绪标记时，脚本只在服务端之后等 3 秒、客户端之间等 2 秒，最后观察进程 1 秒。退出码 `0` 表示启动阶段完成；`session.json` 仍标记 `started; gameplay unverified`，需要继续验证功能。

## 会话与日志

每次实际启动在系统临时目录创建独立的 `hamlet-simulator-*` 目录，以启动器输出的路径为准。启动成功后进程继续运行，脚本不持续监控。

| 文件 | 内容与用途 |
| --- | --- |
| `session.json` | 实例角色、PID、启动时间、Player / console 日志路径、`identityTag`、`roomTag` 和启动状态 |
| `client-1.log`、`client-2.log`… | 客户端 Player 日志，序号对应 `--players` 顺序 |
| `server.log` | DS 服务端 Player 日志；单机和 SharedMode 没有此文件 |
| `client-1-console.log`、`server-console.log`… | 对应进程的 stdout / stderr，补充启动或崩溃信息 |
| `server-hdb.log`、`client-N-hdb.log` | 调试桥日志，显式写入本轮会话目录，避免默认写入工作区外的 `.hdb/logs` |

先读本轮 `session.json` 建立角色与日志的对应关系，再检查日志。`roomTag` 可核对本轮实例是否使用相同房间参数，不能证明已成功入房；`identityTag` 用于比对重启前后的身份。

用实际会话路径替换下例变量值，先检索错误和业务标记，再读取命中位置附近的上下文：

```bash
run_dir='/实际临时目录/hamlet-simulator-xxxx'
cat "$run_dir/session.json"
rg -n -i -C 5 'exception|error|failed|timeout|堆栈|异常' "$run_dir"/*.log
```

`rg` 不可用时使用 `grep -n -i -E -C 5`。根据代码中的实际日志标记继续检索场景加载、入房、角色创建、输入、RPC、主权、同步和存储事件；没有错误日志不代表用例通过。

原始 Player 日志可能包含账号信息，保留在本机临时目录。汇报时只引用必要且已脱敏的片段，不输出完整启动参数、token 或设备标识。

## 功能验证与根因定位

### 按模式验证

| 范围 | 操作与预期证据 |
| --- | --- |
| 基础运行 | 确认加载目标场景、角色生成、镜头与界面正常；执行实际输入，观察移动或交互结果 |
| 单机 | 完成目标功能闭环，核对状态变化、界面反馈及本地日志 |
| SharedMode | A 发起操作，核对 A 和 B 的结果；再由 B 操作，检查主权归属及状态传播符合设计 |
| DedicatedServer | 核对服务端初始化、两客户端入房与角色生成；关联客户端请求、服务端处理及两端最终状态 |
| 存储功能 | 验证写入完成后退出重启并读回；保持项目路径、角色、昵称、世界和关系配置，核对身份及持久化结果 |

按功能需要补充重复交互、晚加入、断线重连、主权转移或服务端重启用例。启动器只提供启动能力；操作通过可用的窗口交互或项目测试入口执行，无法完成的操作记录为未验证，不以进程存活代替结果。

脚本依据项目绝对路径、服务端/客户端角色和昵称生成固定 `openId`，可跨重启、跨房间复用身份；更换昵称或移动项目会改变身份。SDK 窗口使用不同的身份算法，脚本启动的测试存档不与 SDK 窗口互通。多人启动要求至少两个客户端；测试单个客户端断开或重连时，结合本轮已有实例和项目支持的入口操作。

### 沿事件链查找第一处偏差

1. 记录触发时间、操作端、对象、预期结果和实际结果，保留异常堆栈及相邻日志。
2. 对照各端时间戳、同一对象或业务事件，建立「输入 → 请求 → 主权端/服务端处理 → 状态同步 → 客户端表现」的事件链；跨进程日志写入可能延迟，不仅凭文件行顺序判断因果。
3. 找到事件链中第一处缺失或错误：区分输入未触发、请求未到达、处理端逻辑错误、同步未传播及表现未更新，再定位对应代码和生命周期。
4. 日志不足时，在相关节点加入最少量诊断信息，包含端角色、事件、对象、主权与前后状态；重新打包并用相同步骤复现。
5. 用日志与代码验证假设，再做最小修复；若只有推测，明确保留待验证项。

常见问题按以下入口排查：

| 现象 | 优先检查 |
| --- | --- |
| 找不到调试器或项目 | `--project`、EditorPrefs 的 `HamletSimulator`、`--executable` 和可执行权限 |
| 缺少缓存 / 脚本包，或运行仍是旧逻辑 | 构建结果、场景路径、资源更新时间及继承的 AssetBundle / C# 包路径 |
| 缺少 SDK 登录或设备记录 | 在 Editor 登录并启动一次，确认日志属于同一项目、同一环境；必要时使用 `--editor-log` |
| 房间或网络请求失败 | `auto/legacy/new` 实际选择、最终房间 ID、SDK 环境和登录；本地校验不覆盖远端有效性 |
| DS 就绪等待超时 | `server.log` 中是否存在正确标记、正则是否匹配、初始化是否阻塞；不要仅延长超时 |
| 进程提前退出或 Player 日志为空 | 对应 console 日志、Player 日志最后一段及 Unity 构建错误 |
| 只有一端表现正确 | 同一房间的实际入房记录、主权归属、请求处理与同步接收日志 |
| 重启后读不到存储 | 存储开关、测试世界、写入完成证据、`identityTag`、昵称与 Pet 关系配置 |

## 修复与回归

1. 修复根因后，等待编译完成并重新打包，确认当前产物包含修复。
2. 退出本轮旧实例，用相同测试条件重新启动，记录新的会话目录。先重跑失败用例，再验证受影响的相邻功能和跨端结果。
3. 存储回归保留原测试身份与世界；跨房间或新身份行为作为独立用例记录。
4. 对照修复前后的行为、关键事件链及异常日志，只有预期结果已观察到才标记通过。
5. 汇报测试条件、复现步骤、根因与证据、修改文件、回归结果和未验证项；提供对应会话与日志位置。

启动中失败或取消时，脚本会终止本次已创建的进程，并在已创建的会话清单中标记 `launch aborted`。成功启动后，脚本没有停止子命令；关闭本轮窗口，或结合 `session.json` 核实 PID 当前仍属于该实例后逐个结束。需要继续人工验证时保留实例并说明会话位置。
