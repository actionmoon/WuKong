# 条件 (Condition) 概述

条件（Condition）用于在执行动作或触发事件前进行状态检查，以决定是否允许执行下一步逻辑。
本手册从多个维度整理了虚拟世界 SDK 中常用的状态判断和权限校验方法。

---

## 1. 角色状态条件 (Character Condition)

用于判断玩家角色（Actor）当前处于什么行为状态，以及是否允许执行某种行为。

### 状态判断
| 方法/属性 | 归属模块 | 描述 |
| --- | --- | --- |
| `IsGrounded()` | `DouyinActor` | 判断角色是否站在地面上。 |
| `IsFlying()` | `DouyinActor` | 判断角色当前是否处于飞行状态。 |
| `IsSwimming()` | `DouyinActor` | 判断角色当前是否处于游泳状态。 |
| `IsSitting()` | `DouyinActor` | 判断角色当前是否处于坐下状态。 |
| `IsHoldHand()` | `DouyinActor` | 判断角色当前是否处于牵手状态。 |
| `IsPickup()` | `DouyinActor` | 判断角色当前是否处于拾取（手持物品）状态。 |
| `IsDuoInteracting()` | `DouyinActor` | 判断角色当前是否正在进行双人交互。 |
| `IsDuoInteractionWaiting()` | `DouyinActor` | 判断角色当前是否处于等待双人交互的响应状态。 |
| `isPet` | `DouyinActor` | 判断该角色对象是否为宠物（合养精灵）。 |
| `GetStateEnabled(state)` | `DouyinActor` | 检查角色特定的状态（如移动、跳跃、交互等）是否被启用。 |
| `disableActorCollider` | `DouyinActor` | 检查/判断当前角色是否禁用了物理碰撞体。 |

### 行为许可判断
| 方法/属性 | 归属模块 | 描述 |
| --- | --- | --- |
| `CanMove()` | `DouyinActor` | 检查当前角色是否被允许移动。 |
| `CanFly()` | `DouyinActor` | 检查当前角色是否满足起飞条件。 |
| `CanSwim()` | `DouyinActor` | 检查当前角色是否可以游泳。 |
| `CanHoldHand()` | `DouyinActor` | 检查当前角色是否可以进行牵手交互。 |
| `allowAccessUserPanel` | `DouyinActor` | 检查当前角色是否被允许访问个人资料面板。 |

---

## 2. 玩家与网络权限条件 (Network & Permission)

用于判断当前代码运行的端（客户端/服务端），以及对网络对象的控制权和主权归属。

### 网络端点判断
| 方法/属性 | 归属模块 | 描述 |
| --- | --- | --- |
| `isLocal` | `DouyinActor`/`DouyinPlayer` | 判断该角色/玩家是否是当前本地客户端的玩家（即自己）。 |
| `isServer` | `DouyinApplication`/`DouyinPlayer` | 判断当前代码是否运行在服务端（Dedicated Server 环境）。 |
| `isNetworkSettled` | `DouyinNetService` | 标识为 `true` 时，代表本地数据与服务器已完全同步完成，可以安全调用网络 API。 |
| `IsSpawned()` | `DouyinScript` | 判断当前网络对象是否已经在网络上成功生成（NetSpawned）。 |
| `isMaster` | `DouyinPet` | 检查本地玩家是否为当前宠物（合养精灵）的主人。 |

### 主权与控制权 (Ownership & Controllership)
| 方法/属性 | 归属模块 | 描述 |
| --- | --- | --- |
| `HasOwnership()` | `DouyinScript` | 判断当前本地玩家是否拥有该网络对象的主权（可以修改同步变量）。 |
| `IsOwner(player)` | `DouyinScript` | 检查指定的玩家是否为当前网络对象的主权方。 |
| `HasControllership()` | `DouyinScript` | 判断当前本地玩家是否拥有该网络对象的控制权（可以物理操作）。 |
| `IsController(player)` | `DouyinScript` | 检查指定的玩家是否为当前网络对象的控制方。 |

---

## 3. 界面与系统环境条件 (UI & System)

用于检查系统环境状态，如模拟器、相机模式或界面显示状态。

| 方法/属性 | 归属模块 | 描述 |
| --- | --- | --- |
| `isSimulator` | `DouyinApplication` | 判断当前是否运行在 Unity Editor 模拟器环境下。 |
| `IsPhotographMode()` | `DouyinCameraService` | 判断相机当前是否处于拍照模式下。 |
| `hasMore` | `DouyinProductPage` | (商业化) 判断当前商品列表分页是否还有下一页。 |

---

## 4. 交互与配置限制 (Settings & Constraints)

通过全局或对象级配置，判断某些功能是否被启用或禁用。

| 方法/属性 | 归属模块 | 描述 |
| --- | --- | --- |
| `allowActorChange` | `DouyinPlayerSettings`| 检查是否允许玩家在世界内切换合养精灵形象。 |
| `allowAction` | `DouyinPlayerSettings`| 检查是否允许玩家使用动作功能。 |
| `allowEmotion` | `DouyinPlayerSettings`| 检查是否允许玩家使用表情功能。 |
| `allowRespawn` | `DouyinPlayerSettings`| 检查是否允许玩家使用重生功能。 |
| `allowPushByOtherActor` | `DouyinActor` | 检查当前角色是否允许被其他角色推动。 |
