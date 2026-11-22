---
name: hamlet-skill
description: 抖音虚拟创作平台开发技能，按功能模块与开发语言动态读取 Hamlet 文档。覆盖 Lua / C#、SharedMode / DedicatedServer / SinglePlayer，Avatar/Pet、以及交互、网络、数据、主权、生命周期、移动、输入、物理、相机、平台服务等功能模块。
---

# Hamlet Skill — 抖音虚拟创作平台

本 skill 是 Hamlet / 抖音虚拟创作平台 的开发入口。它不一次性加载所有资料，而是按「项目偏好 → 开发语言 → 功能模块入口 → references 原文」逐步读取，确保生成代码前获取所有必要的文档。

***

## 执行流程

### 1. 读取偏好设置

首先读取 [hamlet-preferences.md](./hamlet-preferences.md) 获取项目的默认配置。确定当前任务使用的 `Language`（开发语言）、`Network`（网络模式）、 `AvatarOrPet`（角色模式）和 `DevTool`（工具类型）。除非用户在提问时明确指定了其他选项，否则必须严格遵守这些配置。

### 2. 查阅通用开发规范

在编写任何代码前，必须先阅读 [编码约束与开发规范](./references/Manual/Ⅲ.%20逻辑与脚本(Logic%26Scripting)/编码约束与开发规范.md)。这是所有开发工作都必须遵守的强制规则。

### 3. 明确开发语言

结合 [hamlet-preferences.md](./hamlet-preferences.md) 中的 `DevTool` 与 `Language` 选择语言资料：

- `DevTool=UnityEditor`：Unity Editor 工程支持 Lua 与 C#。先读取[脚本开发概述](./references/Manual/Ⅲ.%20逻辑与脚本(Logic%26Scripting)/脚本开发/脚本概述.md)，再按 `Language` 读取 [Lua 脚本开发](./references/Manual/Ⅲ.%20逻辑与脚本(Logic%26Scripting)/脚本开发/Lua脚本/Lua脚本开发.md)或 [C# 脚本开发](./references/Manual/Ⅲ.%20逻辑与脚本(Logic%26Scripting)/脚本开发/CSharp脚本/CSharp脚本开发.md)。
- `DevTool=AIEditor`：只生成当前 AI 编辑器支持的 Lua，不读取 C# 或 Unity Editor 工程制作资料；Lua 的文件、挂载、模块加载和协作方式由 `lua-script-contract` 定义。

### 4. 明确网络模型

抖音虚拟世界SDK 支持 **SharedMode**、**DedicatedServer**、**SinglePlayer** 三种网络模型。在开始编写代码前，读取 [hamlet-preferences.md](./hamlet-preferences.md) 配置的`Network`（网络模型），获取所使用的网络模型，加载并遵循对应网络模型的特性与规范：

- [网络模型概述](./references/Manual/Ⅳ.%20多人游戏与网络(Multiplayer)/网络模型/网络模型概述.md)
- **SharedMode**：
  - **相关文档**：[网络模型-SharedMode](./references/Manual/Ⅳ.%20多人游戏与网络(Multiplayer)/网络模型/网络模型-Shared%20Mode.md)
- **DedicatedServer**：
  - **相关文档**：[网络模型-DedicatedServer](./references/Manual/Ⅳ.%20多人游戏与网络(Multiplayer)/网络模型/网络模型-Dedicated%20Server.md)
- **SinglePlayer**：
  - **相关文档**：[网络模型-SinglePlayer](./references/Manual/Ⅳ.%20多人游戏与网络(Multiplayer)/网络模型/网络模型-Single%20Player.md)

### 5. 明确角色模式

抖音虚拟世界SDK 中的玩家网络对象（Actor）支持 **Avatar 模式**（虚拟形象）和 **Pet 模式**（合养精灵）。在开始编写代码前，读取 [hamlet-preferences.md](./hamlet-preferences.md) 配置的 `AvatarOrPet`（角色模式），获取所使用的角色模式，加载并遵循对应模式的特性与规范。该配置只能使用 `Avatar` 或 `Pet`：

- [Actor模式概述](./references/Manual/Ⅰ.%20核心系统(Core)/玩家网络对象/Actor模式/Actor模式概述.md)
- [Actor模式开发约束](./references/Manual/Ⅲ.%20逻辑与脚本(Logic%26Scripting)/编码约束与开发规范/Actor模式开发约束.md)
- **Avatar 模式**：
  - **相关文档**：[虚拟形象Avatar模式](./references/Manual/Ⅰ.%20核心系统(Core)/玩家网络对象/Actor模式/虚拟形象Avatar模式.md)
- **Pet 模式**：
  - 两个玩家共享一只精灵，存在“主控”与“观察者”的**控制权切换**。
  - **相关文档**：[合养精灵Pet模式](./references/Manual/Ⅰ.%20核心系统(Core)/玩家网络对象/Actor模式/合养精灵Pet模式.md)

### 6. 明确开发工具

读取 [hamlet-preferences.md](./hamlet-preferences.md) 中的 `DevTool`，并先阅读[开发工具概述](./references/Manual/VI.%20开发工具/开发工具概述.md)：

- `DevTool=UnityEditor` 表示在 Unity Editor 中使用抖音虚拟世界SDK 开发。必须读取 [Unity Editor开发](./references/Manual/VI.%20开发工具/Unity%20Editor开发.md)；使用 Lua Module Script 时再读取 [Module Script](./references/Manual/Ⅲ.%20逻辑与脚本(Logic%26Scripting)/脚本开发/Lua脚本/ModuleScript.md)。
- `DevTool=AIEditor` 表示在 AI 编辑器中开发。先读取 [AI Editor 开发](./references/Manual/VI.%20开发工具/AI%20Editor开发.md)；编写或修改 Lua 前必须加载 [lua-script-contract](../lua-script-contract/SKILL.md)，并以它作为 Hamlet 运行时 API 之上的文件、挂载、模块与资源协作约束。Hamlet 示例与该约束不一致时，读取 [AI Editor：hamlet-skill与lua-script-contract冲突解决方案](./references/Manual/VI.%20开发工具/AI%20Editor：hamlet-skill与lua-script-contract冲突解决方案.md)。
- `DevTool` 缺失或不是 `UnityEditor`、`AIEditor` 时，先要求用户明确开发工具，不根据目录、语言或示例推断。

### 7. 加载核心模块

抖音虚拟世界SDK 中的支持**非网络对象**和**网络对象**，对玩家实体有专门的**玩家网络对象**封装。在深入具体功能模块前，按需了解这些核心对象的概念、分类与生命周期：

- **游戏对象概述**：
  - [游戏对象的概述](./references/Manual/Ⅰ.%20核心系统(Core)/游戏对象/游戏对象的概述.md)：介绍网络与非网络对象的区别、静态与动态网络对象的分类、数量限制以及动态生成的规范。
  - [游戏对象的生命周期](./references/Manual/Ⅰ.%20核心系统(Core)/游戏对象/游戏对象的生命周期.md)
  - [游戏对象的属性](./references/Manual/Ⅰ.%20核心系统(Core)/游戏对象/游戏对象的属性.md)

- **玩家网络对象概述**：
  - [玩家网络对象概述](./references/Manual/Ⅰ.%20核心系统(Core)/玩家网络对象/玩家网络对象概述.md)：介绍 `DouyinPlayer`（玩家实体）、`DouyinActor`（显示实体）的层级关系，以及动态创建玩家关联对象的规则。

- **应用与通用工具**：
  - [应用程序](./references/Manual/Ⅰ.%20核心系统(Core)/应用程序.md)：介绍宿主进程环境、服务端判断和模拟器状态。
  - [通用工具集](./references/Manual/Ⅰ.%20核心系统(Core)/通用工具集.md)：介绍 Toast、Alert、服务端时间和文本过滤等基础工具。

### 8. 按需加载功能模块

根据当前任务的目标，依据「游戏开发常见核心维度拆解」查询关联功能模块，并加载「功能模块路由表」中对应的文档。

- 如果路由表理论列中的 `common.md` 或其他通用理论文档存在，必须读取；不存在则跳过。
- 根据第 1 步确认的 `Language`（开发语言）选择对应的语言文档：`Language=Lua` 时读取 `lua.md`（如果存在），`Language=C#` 时读取 `csharp.md`（如果存在）。对应文档不存在时跳过，不得因此判断为不支持，也不得跨开发语言读取文档。
- 如果路由表中的编码约束文档存在，必须读取；不存在则跳过。
- 路由表明确标注暂不支持的模块，不读取该模块文档，也不根据其中的参考资料生成内容。
- **严禁一次性读取所有文档**。
- 涉及多个模块，所有相关的模块文档都需要读取。

### 9. API检索与安全边界线

- **核对 API 签名**：调用具体 API 前，必须通过 [API Reference Index](./references/API%20Reference%20Index.md) 定位对应参考链接，完整阅读该 API 文档。严格核对参数类型、顺序、返回值及回调方法。**绝不能凭记忆写代码，也不能直接照抄其他无关的 Demo。**
- **校验安全边界**：如果需要调用 `Unity/C#` 的原生类型或者调用 `Lua` 等底层接口，必须先查阅 [API白名单.md](./references/API%E7%99%BD%E5%90%8D%E5%8D%95.md) 和 [API黑名单.md](./references/API%E9%BB%91%E5%90%8D%E5%8D%95.md)，确保这些调用是被允许的。

***

## 功能模块路由表

> 1. 根据「关键字」和「主要职责」确定功能模块。
> 2. 根据[hamlet-preferences.md](./hamlet-preferences.md) 中的 `Language`（开发语言）读取与开发语言相关的文档。

| 功能模块 | 关键字 | 主要职责 | 理论 | Lua开发 | CSharp | 编码约束 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 基础交互 | C 区 / 右下角按钮、拾取、座位、开门、NPC 对话 | - 负责玩家靠近、点击、按住后触发动作的入口和按钮生命周期。- 不负责物理接触施力、输入采样或平台 helper 本身。 | [通用](./skills/interaction-design/common.md) | [Lua](./skills/interaction-design/lua.md) | [C#](./skills/interaction-design/csharp.md) | [触发器生命周期约束](./references/Manual/Ⅲ.%20逻辑与脚本(Logic%26Scripting)/编码约束与开发规范/触发器生命周期约束.md) |
| 网络同步与通信 | RPC、`SendMessage`、SharedMode、DS、跨端同步、断线重连 | - 负责跨端状态同步、消息通信、动态网络对象及网络模式分流。- 不负责单机逻辑或主权 / 控制权边界。 | [通用](./skills/network-design/common.md) | [Lua](./skills/network-design/lua.md) | [C#](./skills/network-design/csharp.md) | [网络开发约束](./references/Manual/Ⅲ.%20逻辑与脚本(Logic%26Scripting)/编码约束与开发规范/网络开发约束.md) |
| 主权与控制权 | 主权、控制权、写权限、请求 / 审批、主权转移、断线迁移、谁能写状态、谁在使用 | - 负责主权决定网络状态写入的权限分配，控制权作为“谁在使用”的业务标签，以及转移和断线迁移链路。- 不负责具体同步和通信；框架接管的拾取/放下无需手写主权。 | [通用](./skills/ownership-design/common.md) | [Lua](./skills/ownership-design/lua.md) | [C#](./skills/ownership-design/csharp.md) | --- |
| 生命周期 | 进房完成、网络就绪、销毁、重连、回调注册 / 反注册 | - 负责判断什么时候初始化、读写、注册回调和清理资源。- 不承接同步、交互、存档等具体业务实现。 | [通用](./skills/lifecycle-design/common.md) | --- | --- | [脚本沙箱开发约束](./references/Manual/Ⅲ.%20逻辑与脚本(Logic%26Scripting)/编码约束与开发规范/脚本开发约束.md) |
| 玩家移动 | 移动、速度、传送、跳跃、飞行、游泳、加速 / 减速、冰面、玩家运动状态 | - 负责玩家 Actor 自身移动能力和运动状态。 | [通用](./skills/movement-design/common.md) | [Lua](./skills/movement-design/lua.md) | --- | [角色控制开发约束](./references/Manual/Ⅲ.%20逻辑与脚本(Logic%26Scripting)/编码约束与开发规范/角色控制开发约束.md) |
| 玩家输入 | 摇杆、WASD、触摸、缩放、Look 输入、长按、蓄力、UI、多输入源 | - 负责输入采样、多输入源汇入和输入状态聚合。- 不负责 C 区 / 右下角交互按钮，也不负责输入后的移动或物理效果； | [通用](./skills/input-design/common.md) | [Lua](./skills/input-design/lua.md) | --- | [多输入源与UI协作约束](./references/Manual/Ⅲ.%20逻辑与脚本(Logic%26Scripting)/编码约束与开发规范/多输入源与UI协作约束.md) |
| 场景物理 | 1. 核心组件与 API：Rigidbody、Collider、Joint、AddForce、velocity、MoveRotation、碰撞 / 触发器、碰撞过滤（Layer Matrix）、物理材质（Physic Material）、射线与区域检测；<br> 2. 受重力、碰撞、力、质量、摩擦力等影响运动的物体，如球、载具、可推动箱子、移动平台、传送带、布娃娃角色、可破坏碎片、绳索 / 吊桥、水面漂浮物；<br> 3. 符合物理规则的操作，如施加力（AddForce / AddTorque / AddExplosionForce）、驱动速度（velocity / angularVelocity）、平滑移动旋转（MovePosition / MoveRotation）、关节约束；如推箱、踢球、赛车漂移、爆炸冲击波、角色跳跃与受击击退；<br> 4. 需要处理物理事件结算与查询，如碰撞 / 触发回调（OnCollisionEnter / OnTriggerEnter）、进球得分、拾取判定、伤害范围（OverlapSphere）、落地检测、射线命中、压力板触发机关。 | - 负责场景物体的物理运动、碰撞触发和物理结算。<br>- 不负责玩家 Actor 移动能力或靠近弹出的交互按钮。 | [通用](./skills/physics-design/common.md) | [Lua](./skills/physics-design/lua.md) | [C#](./skills/physics-design/csharp.md) | [物理对象层级约束](./references/Manual/Ⅲ.%20逻辑与脚本(Logic%26Scripting)/编码约束与开发规范/物理对象层级约束.md)<br>[实体去重](./references/Manual/Ⅲ.%20逻辑与脚本(Logic%26Scripting)/编码约束与开发规范/物理结算与实体去重约束.md)<br>[刚体运动控制约束](./references/Manual/Ⅲ.%20逻辑与脚本(Logic%26Scripting)/编码约束与开发规范/刚体运动控制约束.md)<br>[碰撞与触发器规范](./references/Manual/Ⅲ.%20逻辑与脚本(Logic%26Scripting)/编码约束与开发规范/碰撞与触发器规范.md) |
| 相机 | yaw / pitch / distance / offset / FOV、镜头回正、追尾视角、拍照模式、玩家拖视角 | - 负责平台相机参数、镜头模式和视角控制。- 不负责触发相机逻辑的业务按钮。 | [通用](./skills/camera-design/common.md) | [Lua](./skills/camera-design/lua.md) | [C#](./skills/camera-design/csharp.md) |
| 界面与UI | UGUI、Sort Order、自定义UI、界面层级、HUD | - 负责游戏界面的分辨率适配、UI层级（Sort Order）管理及自定义界面展示。<br>- 涵盖系统级原生 UI 调用（如 Toast、Alert）及右下角 HUD 操作按钮规范。 | - [界面开发概述与规范](./references/Manual/Ⅱ.%20界面与交互(UI)/界面开发概述与规范.md)<br>- [系统界面](./references/Manual/Ⅱ.%20界面与交互(UI)/系统界面.md)<br>- [交互按钮分类与使用规范](./references/Manual/Ⅱ.%20界面与交互(UI)/系统交互按钮/交互按钮分类与使用规范.md)<br>- [操作按钮](./references/Manual/Ⅱ.%20界面与交互(UI)/系统交互按钮/操作按钮.md)<br>- [基础交互按钮](./references/Manual/Ⅱ.%20界面与交互(UI)/系统交互按钮/基础交互按钮.md) | --- | --- | --- |
| 平台服务 | 关注、排行榜、创作者服务、图片服务、社交服务等 | 负责提供除数据存储与商业化之外的其他平台生态能力，涵盖房间服务、创作者服务、社交服务与图片服务等通用接口。 | [通用](./skills/platform-service-design/common.md) | [Lua](./skills/platform-service-design/lua.md) | [C#](./skills/platform-service-design/csharp.md) | --- |
| 数据存储 | 存档、读档、自定义排行榜、分页、货币 / 背包 / 进度持久化 | 负责平台云端数据的持久化存储，包括通用键值对存储（DouyinDataStore）、自定义排行榜/数值排序存储（DouyinOrderedDataStore）、分页逻辑以及数据读写的错误处理 | [通用](./skills/database-design/common.md) | [Lua](./skills/database-design/lua.md) | [C#](./skills/database-design/csharp.md) | [数据库开发约束](./references/Manual/Ⅲ.%20逻辑与脚本(Logic%26Scripting)/编码约束与开发规范/数据库开发约束.md) |
| 商业化 | 商品、星光币、充值、购买、订单、发货、补单、幂等 | 提供创作者内容变现解决方案：涵盖获取商品列表、展示价格、跳转充值、客户端购买链路，以及安全的服务端发货、补单、幂等落库闭环。| [通用](./skills/commercialization-design/common.md) | [Lua](./skills/commercialization-design/lua.md) | [C#](./skills/commercialization-design/csharp.md) | --- |
<br />

***

## 游戏开发常见核心维度拆解

| 核心维度 | 涵盖模块与对象 | 典型业务需求 | 涉及核心知识领域 | 关联功能模块 |
| :--- | :--- | :--- | :--- | :--- |
| **交互对象**（道具、NPC、机关） | **可交互道具**：拾取物、开关、武器、消耗品**NPC与AI**：任务发布者、敌对怪物、跟随伙伴**场景机关**：门、陷阱、解谜机关、可破坏物件 | - **状态与控制**：道具的拾取/使用状态变化。- **场景联动**：条件触发、连锁机关、环境状态管理。- **行为与反馈**：NPC巡逻/战斗/对话触发；多人交互冲突与权限校验。 | 交互设计、物理与碰撞检测、刚体与运动学、AI状态机与行为树、关卡逻辑与事件驱动架构。 | 基础交互、场景物理、玩家移动、玩家输入、Avatar / Pet、相机 |
| **玩法系统**（战斗、任务、经济、成长） | **战斗数值**：属性、伤害判定、技能、Buff机制**任务剧情**：主线/支线任务、对话分支**经济商店**：软/硬货币、商品售卖、交易抽奖**成长系统**：等级提升、经验获取 | - **战斗与成长**：命中/范围判定、平衡性调优；任务进度追踪与奖励发放。- **经济流转**：商品限购/折扣处理、订单状态管理。- **玩法联动**：任务与NPC/道具状态的耦合联动。 | 数值策划、战斗判定与服务端权威计算、任务状态机、虚拟经济设计、剧情脚本与事件总线。 | 数据存储、平台服务 |
| **玩家系统**（背包、排行榜、存档） | **背包物品**：物品定义、分类堆叠、装备栏**排行榜**：本局榜、全服榜、赛季结算**存档系统**：进度保存、数据迁移、回档恢复 | - **资产管理**：物品的使用/出售/合成/分解；背包容量控制。- **数据展示**：排行的实时刷新与奖励结算。- **数据持久化**：自动/手动存档、断线恢复、跨版本兼容。 | 数据建模、配置驱动设计、排序与数据聚合、数据持久化（存档 Schema 设计）、容错与幂等设计。 | 数据存储、平台服务 |
| **联机同步**（端端同步、状态一致性） | **网络同步**：多人冲突、状态复制**控制权**：NPC一致性 | - **生命周期**：房间状态切换、玩家重生与复活。- **状态一致性**：多人同时交互的冲突处理；网络对象的所有权分配与同步。- **网络优化**：同步延迟纠正、客户端预测与服务端校正。 | 网络编程、主从/权威模型、状态复制、延迟补偿、客户端预测与服务端校正、断线重连。 | 网络同步与主权、生命周期 |
| **表现层**（UI、音效、动画、反馈） | **UI反馈**：交互提示、界面动效、音效 | - **表现与体验**：数据与UI解耦、视觉与听觉反馈。 | UI架构与用户体验设计 | 界面与UI |
| **技术底座**（物理、AI、数据、性能、安全） | **物理与AI**：碰撞结算、防穿模、路径规划**安全风控**：防作弊、服务端校验**运营配置**：管理后台、活动开关、日志 | - **底层支撑**：刚体运动学结算、防穿模/防飞天处理、导航网格寻路与刷怪密度控制。- **安全合规**：防刷分/刷道具、支付风控、封禁补偿操作。 | 物理引擎、路径规划与导航、安全校验与反作弊、配置中心与GM工具设计、性能优化。 | 场景物理、相机、生命周期、平台服务 |
