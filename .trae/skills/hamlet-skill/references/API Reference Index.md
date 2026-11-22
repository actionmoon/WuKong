# API 参考目录 (API Reference Index)

欢迎来到 API 参考字典。本目录按照《创作者手册》的五大核心架构层级进行分类，方便您快速定位并查阅具体的 API 说明。所有详细的类、属性、方法、事件文档请点击下方链接查阅。

---

## Ⅰ. 核心系统 (Core)
核心系统是虚拟世界的基石，涵盖对象生命周期、角色控制、玩家与合养精灵、输入机制以及相机等底层能力。

### [`DouyinApplication`](./API%20Reference/DouyinApplication.md)
应用生命周期与环境状态

- **属性**:
  - [`isServer`](./API%20Reference/DouyinApplication/DouyinApplication.isServer.md) (用于标识当前是否是Dedicated Server)
  - [`isSimulator`](./API%20Reference/DouyinApplication/DouyinApplication.isSimulator.md) (是否为调试器)
- **方法**:
  - [`Quit`](./API%20Reference/DouyinApplication/DouyinApplication.Quit.md) (退出游戏)

### [`DouyinRoomService`](./API%20Reference/DouyinRoomService.md)
房间信息与状态服务

- **方法**:
  - [`GetCurrentRoomInfo`](./API%20Reference/DouyinRoomService/DouyinRoomService.GetCurrentRoomInfo.md) (获取房间信息)

### [`DouyinPlayer`](./API%20Reference/DouyinPlayer.md)
玩家数据类

- **属性**:
  - [`gameObject`](./API%20Reference/DouyinPlayer/DouyinPlayer.gameObject.md) (与玩家关联的 GameObject)
  - [`isLocal`](./API%20Reference/DouyinPlayer/DouyinPlayer.isLocal.md) (是否是MainPlayer，本地玩家)
  - [`isServer`](./API%20Reference/DouyinPlayer/DouyinPlayer.isServer.md) (是否是Dedicated Server的DouyinPlayer；Dedicated Server 是特殊的DouyinPlayer；)
  - [`playerID`](./API%20Reference/DouyinPlayer/DouyinPlayer.playerID.md) (房间内玩家实例ID，每次进房都会重新生成，客户端可以用该ID来标识玩家。)
  - [`playerName`](./API%20Reference/DouyinPlayer/DouyinPlayer.playerName.md) (玩家名称)
  - [`playerOpenID`](./API%20Reference/DouyinPlayer/DouyinPlayer.playerOpenID.md) (房间内玩家的抖音开放ID，玩家ID的唯一标识)
- **方法**:
  - [`GetActor`](./API%20Reference/DouyinPlayer/DouyinPlayer.GetActor.md) (获取此玩家当前控制的Actor对象实例，返回可能为Null，表示还没有控制的Actor对象实例)
  - [`GetPlayerPortrait`](./API%20Reference/DouyinPlayer/DouyinPlayer.GetPlayerPortrait.md) (获取玩家头像)

### [`DouyinPlayerService`](./API%20Reference/DouyinPlayerService.md)
玩家数据服务

- **方法**:
  - [`GetLocalPlayer`](./API%20Reference/DouyinPlayerService/DouyinPlayerService.GetLocalPlayer.md) (获取本地玩家)
  - [`GetPlayer`](./API%20Reference/DouyinPlayerService/DouyinPlayerService.GetPlayer.md) (通过 playerID，获取指定 DouyinPlayer 的信息)
  - [`GetPlayerByOpenID`](./API%20Reference/DouyinPlayerService/DouyinPlayerService.GetPlayerByOpenID.md) (通过open ID获取房间内的DouyinPlayer)
  - [`GetPlayerCount`](./API%20Reference/DouyinPlayerService/DouyinPlayerService.GetPlayerCount.md) (获取当前房间 DouyinPlayer 的数量)
  - [`GetPlayers`](./API%20Reference/DouyinPlayerService/DouyinPlayerService.GetPlayers.md) (获取当前房间内所有的 DouyinPlayer)

### [`DouyinActor`](./API%20Reference/DouyinActor.md)
角色对象类（移动、动画、交互等）

- **属性**:
  - [`actorID`](./API%20Reference/DouyinActor/属性/DouyinActor.actorID.md) (Actor 实例 ID，用来判断是否是同一个玩家（重复进房间会变化）)
  - [`allowAccessUserPanel`](./API%20Reference/DouyinActor/属性/DouyinActor.allowAccessUserPanel.md) (开启/禁用用户3D点击，访问用户的信息面板，默认开启)
  - [`allowPushByOtherActor`](./API%20Reference/DouyinActor/属性/DouyinActor.allowPushByOtherActor.md) (当前 Actor 是否能被其他 Actor 推动)
  - [`disableActorCollider`](./API%20Reference/DouyinActor/属性/DouyinActor.disableActorCollider.md) (用于禁用精灵（Actor）之间的碰撞)
  - [`displayName`](./API%20Reference/DouyinActor/属性/DouyinActor.displayName.md) (Actor 的名称)
  - [`douyinPet`](./API%20Reference/DouyinActor/属性/DouyinActor.douyinPet.md) (当 isPet 为 true 的时候，返回当前 Actor 关联的 DouyinPet；否则返回 null)
  - [`flyMaxHeight`](./API%20Reference/DouyinActor/属性/DouyinActor.flyMaxHeight.md) (飞行最大高度)
  - [`flyMinHeight`](./API%20Reference/DouyinActor/属性/DouyinActor.flyMinHeight.md) (飞行最小高度)
  - [`flySpeed`](./API%20Reference/DouyinActor/属性/DouyinActor.flySpeed.md) (飞行水平速度)
  - [`flyVerticalSpeed`](./API%20Reference/DouyinActor/属性/DouyinActor.flyVerticalSpeed.md) (飞行垂直速度)
  - [`gameObject`](./API%20Reference/DouyinActor/属性/DouyinActor.gameObject.md) (获取关联 GameObject 实例)
  - [`gravityScale`](./API%20Reference/DouyinActor/属性/DouyinActor.gravityScale.md) (设置重力缩放系数)
  - [`isLocal`](./API%20Reference/DouyinActor/属性/DouyinActor.isLocal.md) (返回这个 Actor 是否是 Local 玩家)
  - [`isPet`](./API%20Reference/DouyinActor/属性/DouyinActor.isPet.md) (是否为精灵)
  - [`jumpHeight`](./API%20Reference/DouyinActor/属性/DouyinActor.jumpHeight.md) (获取或设置当前Actor的跳跃高度)
  - [`minSlopeAngleLimit`](./API%20Reference/DouyinActor/属性/DouyinActor.minSlopeAngleLimit.md) (当前 Actor 在斜坡上最小能站立的角度)
  - [`position`](./API%20Reference/DouyinActor/属性/DouyinActor.position.md) (位置)
  - [`rotation`](./API%20Reference/DouyinActor/属性/DouyinActor.rotation.md) (朝向)
  - [`scale`](./API%20Reference/DouyinActor/属性/DouyinActor.scale.md) (获取/设置 Actor 的缩放，角色的大小限制（0，2）之间)
  - [`speed`](./API%20Reference/DouyinActor/属性/DouyinActor.speed.md) (移动速度)
  - [`velocity`](./API%20Reference/DouyinActor/属性/DouyinActor.velocity.md) (移动方向和速度)
- **方法**:
  - [`AcceptDuoInteraction`](./API%20Reference/DouyinActor/方法/DouyinActor.AcceptDuoInteraction.md) (Actor接受其他Actor发起的交互)
  - [`CalculatePalmTransform`](./API%20Reference/DouyinActor/方法/DouyinActor.CalculatePalmTransform.md) (计算当前 Actor 手部挂点)
  - [`CanFly`](./API%20Reference/DouyinActor/方法/DouyinActor.CanFly.md) (是否能飞行)
  - [`CanHoldHand`](./API%20Reference/DouyinActor/方法/DouyinActor.CanHoldHand.md) (当前 Actor 是否可以牵手)
  - [`CanMove`](./API%20Reference/DouyinActor/方法/DouyinActor.CanMove.md) (判断当前 Actor 是否能移动)
  - [`CanSwim`](./API%20Reference/DouyinActor/方法/DouyinActor.CanSwim.md) (是否能游泳)
  - [`ChangeState`](./API%20Reference/DouyinActor/方法/DouyinActor.ChangState.md) (切换到某个状态)
  - [`ClearActorTags`](./API%20Reference/DouyinActor/方法/DouyinActor.ClearActorTags.md) (清除指定 tag，如果参数为空则清除所有 Tags，无需权限，任何人都可清除)
  - [`DisableFly`](./API%20Reference/DouyinActor/方法/DouyinActor.DisableFly.md) (禁止飞行/悬浮)
  - [`DisableHoldHand`](./API%20Reference/DouyinActor/方法/DouyinActor.DisableHoldHand.md) (禁止牵手行为)
  - [`DisableInteraction`](./API%20Reference/DouyinActor/方法/DouyinActor.DisableInteraction.md) (把当前对象移除掉可交互对象)
  - [`Drop`](./API%20Reference/DouyinActor/方法/DouyinActor.Drop.md) (丢弃指定物体，该方法只对本地玩家有效)
  - [`EnableFly`](./API%20Reference/DouyinActor/方法/DouyinActor.EnableFly.md) (开启飞行/悬浮)
  - [`EnableHoldHand`](./API%20Reference/DouyinActor/方法/DouyinActor.EnableHoldHand.md) (开启牵手行为)
  - [`EnableInteraction`](./API%20Reference/DouyinActor/方法/DouyinActor.EnableInteraction.md) (把当前对象设置为可交互对象)
  - [`GetActorTag`](./API%20Reference/DouyinActor/方法/DouyinActor.GetActorTag.md) (获取 Actor 标签)
  - [`GetBonePosition`](./API%20Reference/DouyinActor/方法/DouyinActor.GetBonePosition.md) (获取 Actor 的人骨位置信息)
  - [`GetBoneRotation`](./API%20Reference/DouyinActor/方法/DouyinActor.GetBoneRotation.md) (获取 Actor 的人骨角度信息)
  - [`GetBoneTransform`](./API%20Reference/DouyinActor/方法/DouyinActor.GetBoneTransform.md) (获取 Actor 的人骨下的 Transform 对象)
  - [`GetHoldHandState`](./API%20Reference/DouyinActor/方法/DouyinActor.GetHoldHandState.md) (返回牵手状态的枚举类型)
  - [`GetNameplate`](./API%20Reference/DouyinActor/方法/DouyinActor.GetNameplate.md) (获取名字片对象)
  - [`GetPickupInHand`](./API%20Reference/DouyinActor/方法/DouyinActor.GetPickupInHand.md) (返回 Actor 特定手的 Pickup 物件，这个函数仅针对 local actor 生效，没有 pickup 时返回 null)
  - [`GetState`](./API%20Reference/DouyinActor/方法/DouyinActor.GetState.md) (获取 Actor 状态)
  - [`GetStateEnabled`](./API%20Reference/DouyinActor/方法/DouyinActor.GetStateEnabled.md) (获取 Actor 状态是否生效)
  - [`Immobilize`](./API%20Reference/DouyinActor/方法/DouyinActor.Immobilize.md) (是否可以通过摇杆移动)
  - [`Interact`](./API%20Reference/DouyinActor/方法/DouyinActor.Interact.md) (交互，该方法最对本地玩家有效)
  - [`InviteDuoInteraction`](./API%20Reference/DouyinActor/方法/DouyinActor.InviteDuoInteraction.md) (Actor发起一次多人交互)
  - [`IsDuoInteracting`](./API%20Reference/DouyinActor/方法/DouyinActor.IsDuoInteracting.md) (Actor正在多人交互交互中)
  - [`IsDuoInteractionWaiting`](./API%20Reference/DouyinActor/方法/DouyinActor.IsDuoInteractionWaiting.md) (Actor等待多人交互，当发起多人交互，其他Actor没有接受多人交互的时候，会处于等待状态。)
  - [`IsFlying`](./API%20Reference/DouyinActor/方法/DouyinActor.IsFlying.md) (当前是否飞行)
  - [`IsGrounded`](./API%20Reference/DouyinActor/方法/DouyinActor.IsGrounded.md) (判断 Actor 是否在地面的参数)
  - [`IsHoldHand`](./API%20Reference/DouyinActor/方法/DouyinActor.IsHoldHand.md) (当前 Actor 是否处于牵手状态)
  - [`IsPickup`](./API%20Reference/DouyinActor/方法/DouyinActor.IsPickup.md) (手中是否有物体)
  - [`IsSitting`](./API%20Reference/DouyinActor/方法/DouyinActor.IsSitting.md) (获取玩家是否坐着)
  - [`IsSwimming`](./API%20Reference/DouyinActor/方法/DouyinActor.IsSwimming.md) (当前是否在游泳)
  - [`Jump`](./API%20Reference/DouyinActor/方法/DouyinActor.Jump.md) (跳跃)
  - [`MoveContinuously`](./API%20Reference/DouyinActor/方法/DouyinActor.MoveContinuously.md) (向某个方向移动，参数是移动速度的倍速（相当于一直朝某个方向推动摇杆，只能平面移动），该方法只对本地玩家有效)
  - [`NetSpawn`](./API%20Reference/DouyinActor/方法/DouyinActor.NetSpawn.md) (动态生成和Actor绑定的网络对象，Actor销毁时，该Actor创建的网络对象也会被销毁)
  - [`Pickup`](./API%20Reference/DouyinActor/方法/DouyinActor.Pickup.md) (拾取指定物体，该方法只对本地玩家有效)
  - [`PlayAnimation`](./API%20Reference/DouyinActor/方法/DouyinActor.PlayAnimation.md) (播放一个动作，支持使用 Animation Event，可传回调函数)
  - [`PlayEmoji`](./API%20Reference/DouyinActor/方法/DouyinActor.PlayEmoji.md) (播放表情)
  - [`Respawn`](./API%20Reference/DouyinActor/方法/DouyinActor.Respawn.md) (角色重生)
  - [`SetActorTag`](./API%20Reference/DouyinActor/方法/DouyinActor.SetActorTag.md) (给 Actor 增加标签，无需权限，任何人都可以添加)
  - [`SetAlpha`](./API%20Reference/DouyinActor/方法/DouyinActor.SetAlpha.md) (设置当前 Actor 的透明度，alpha 取值范围[0-1])
  - [`SetFlyMode`](./API%20Reference/DouyinActor/方法/DouyinActor.SetFlyMode.md) (设置飞行模式)
  - [`SetFootstepAudioClips`](./API%20Reference/DouyinActor/方法/DouyinActor.SetFootstepAudioClips.md) (设置脚步声。传入的数组应包含两个音效，分别对应：左脚的声音、右脚的声音。)
  - [`SetJumpAudioClip`](./API%20Reference/DouyinActor/方法/DouyinActor.SetJumpAudioClip.md) (设置跳跃的音效)
  - [`SetOverrideAnimation`](./API%20Reference/DouyinActor/方法/DouyinActor.SetOverrideAnimation.md) (设置重载动画，重载为 nil，就会还原，支持使用 Animation Event，可传回调函数)
  - [`SetOverrideAnimationController`](./API%20Reference/DouyinActor/方法/DouyinActor.SetOverrideAnimationController.md) (设置重载的动画状态机)
  - [`SetSpeed`](./API%20Reference/DouyinActor/方法/DouyinActor.SetSpeed.md) (设置精灵移动速度，并自动联动行走动画的播放速度；速度高于默认基础速度时动画相应加快，避免"脚步打滑"，否则保持原速。)
  - [`SetStateEnabled`](./API%20Reference/DouyinActor/方法/DouyinActor.SetStateEnabled.md) (设置 Actor 状态是否生效)
  - [`SetVisible`](./API%20Reference/DouyinActor/方法/DouyinActor.SetVisible.md) (是否隐藏当前 Actor)
  - [`ShowNameplate`](./API%20Reference/DouyinActor/方法/DouyinActor.ShowNameplate.md) (显示/隐藏 Actor 名字片)
  - [`SitDown`](./API%20Reference/DouyinActor/方法/DouyinActor.SitDown.md) (坐下，该方法只对本地玩家有效)
  - [`StandUp`](./API%20Reference/DouyinActor/方法/DouyinActor.StandUp.md) (站起，该方法只对本地玩家有效)
  - [`StartDuoInteraction`](./API%20Reference/DouyinActor/方法/DouyinActor.StartDuoInteraction.md) (Actor开始多人交互，交互的对象是传入的actor)
  - [`StartFly`](./API%20Reference/DouyinActor/方法/DouyinActor.StartFly.md) (开始飞行)
  - [`StopAnimation`](./API%20Reference/DouyinActor/方法/DouyinActor.StopAnimation.md) (停止播放动作)
  - [`StopDuoInteraction`](./API%20Reference/DouyinActor/方法/DouyinActor.StopDuoInteraction.md) (退出双人交互，如果是引导者，停止所有的双人交互；如果是跟随者，停止跟随者后续的所有双人交互)
  - [`StopDuoInteractionWaiting`](./API%20Reference/DouyinActor/方法/DouyinActor.StopDuoInteractionWaiting.md) (停止交互等待)
  - [`StopFly`](./API%20Reference/DouyinActor/方法/DouyinActor.StopFly.md) (停止飞行)
  - [`StopHoldHand`](./API%20Reference/DouyinActor/方法/DouyinActor.StopHoldHand.md) (结束当前 Actor 的牵手状态)
  - [`StopMove`](./API%20Reference/DouyinActor/方法/DouyinActor.StopMove.md) (停止移动，相当于取消上个 Api 的持续移动效果)
  - [`Teleport`](./API%20Reference/DouyinActor/方法/DouyinActor.Teleport.md) (传送)
- **事件**:
  - [`onActionPlay`](./API%20Reference/DouyinActor/事件/DouyinActor.onActionPlay.md) (Actor使用动作事件)
  - [`onActorLoaded`](./API%20Reference/DouyinActor/事件/DouyinActor.onActorLoaded.md) (切换 Actor 形象时回调)
  - [`onDrop`](./API%20Reference/DouyinActor/事件/DouyinActor.onDrop.md) (Actor丢弃物体的事件)
  - [`onDuoInteractionEnd`](./API%20Reference/DouyinActor/事件/DouyinActor.onDuoInteractionEnd.md) (Actor结束播放双人动作事件)
  - [`onDuoInteractionStart`](./API%20Reference/DouyinActor/事件/DouyinActor.onDuoInteractionStart.md) (Actor开始播放双人动作事件)
  - [`onDuoInteractionWaiting`](./API%20Reference/DouyinActor/事件/DouyinActor.onDuoInteractionWaiting.md) (Actor开始等待播放双人动作事件)
  - [`onEmotionPlay`](./API%20Reference/DouyinActor/事件/DouyinActor.onEmotionPlay.md) (Actor使用表情事件)
  - [`onFallingGround`](./API%20Reference/DouyinActor/事件/DouyinActor.onFallingGround.md) (Actor 落地的事件)
  - [`onFlyStart`](./API%20Reference/DouyinActor/事件/DouyinActor.onFlyStart.md) (Actor 开始飞行的事件)
  - [`onFlyStop`](./API%20Reference/DouyinActor/事件/DouyinActor.onFlyStop.md) (Actor 结束飞行的事件)
  - [`onHoldHandStart`](./API%20Reference/DouyinActor/事件/DouyinActor.onHoldHandStart.md) (Actor进入牵手状态事件)
  - [`onHoldHandStop`](./API%20Reference/DouyinActor/事件/DouyinActor.onHoldHandStop.md) (Actor结束牵手状态事件)
  - [`onJump`](./API%20Reference/DouyinActor/事件/DouyinActor.onJump.md) (Actor 起跳的事件)
  - [`onPickup`](./API%20Reference/DouyinActor/事件/DouyinActor.onPickup.md) (Actor捡起物体的事件)
  - [`onSitDown`](./API%20Reference/DouyinActor/事件/DouyinActor.onSitDown.md) (Actor坐下的事件)
  - [`onStandUp`](./API%20Reference/DouyinActor/事件/DouyinActor.onStandUp.md) (Actor站起的事件)
  - [`onSwimStart`](./API%20Reference/DouyinActor/事件/DouyinActor.onSwimStart.md) (Actor开始游泳的事件)
  - [`onSwimStop`](./API%20Reference/DouyinActor/事件/DouyinActor.onSwimStop.md) (Actor停止游泳的事件)

### [`DouyinActorService`](./API%20Reference/DouyinActorService.md)
角色对象服务

- **方法**:
  - [`ClearAllActorsTag`](./API%20Reference/DouyinActorService/DouyinActorService.ClearAllActorsTag.md) (清除所有 Actor 的标签)
  - [`GetActor`](./API%20Reference/DouyinActorService/DouyinActorService.GetActor.md) (通过 GameObject 获取 Actor)
  - [`GetActorById`](./API%20Reference/DouyinActorService/DouyinActorService.GetActorById.md) (通过 ID 获取 Actor)
  - [`GetActors`](./API%20Reference/DouyinActorService/DouyinActorService.GetActors.md) (获取 Actor 列表)
  - [`GetActorsWithTag`](./API%20Reference/DouyinActorService/DouyinActorService.GetActorsWithTag.md) (获取拥有标签的 Actor)
  - [`GetLocalActor`](./API%20Reference/DouyinActorService/DouyinActorService.GetLocalActor.md) (获取本地 Actor)
  - [`GetMaxActorCount`](./API%20Reference/DouyinActorService/DouyinActorService.GetMaxActorCount.md) (获取最大 Actor 数量)

### [`DouyinObject`](./API%20Reference/DouyinObject.md)
网络对象基础类

- **属性**:
  - [`gameObject`](./API%20Reference/DouyinObject/DouyinObject.gameObject.md) (该类实例关联的 Unity 游戏对象，在对象创建时初始化)
  - [`UID`](./API%20Reference/DouyinObject/DouyinObject.UID.md) (该类实例的唯一标识符，在对象创建时初始化)
- **方法**:
  - [`EnableSync`](./API%20Reference/DouyinObject/DouyinObject.EnableSync.md) (开或关闭网络同步，默认是开启)
  - [`SetDestoryWhenDrop`](./API%20Reference/DouyinObjectService/DouyinObjectService.SetDestroyWhenDrop.md) (房间内最后一个用户断线的时候，是否当玩家丢弃此对象时立即销毁此对象)

### [`DouyinObjectService`](./API%20Reference/DouyinObjectService.md)
网络对象服务（生成、销毁等）

- **方法**:
  - [`GetDouyinObject`](./API%20Reference/DouyinObjectService/DouyinObjectService.GetDouyinObject.md) (通过objectID获取对应的DouyinObject对象)
  - [`NetDestroy`](./API%20Reference/DouyinObjectService/DouyinObjectService.NetDestroy.md) (可以销毁所有的网络对象，只有主权方可以销毁物体；  autoRequest 代表是否自动请求主权)
  - [`NetSpawn`](./API%20Reference/DouyinObjectService/DouyinObjectService.NetSpawn.md) (动态生成网络对象)
  - [`ServerSpawn（重载方法）`](./API%20Reference/DouyinObjectService/DouyinObjectService.ServerSpawn.md) (在服务器端动态生成网络对象，该对象不会同步到客户端。)

### [`DouyinPet`](./API%20Reference/DouyinPet.md)
合养精灵类

- **属性**:
  - [`isMaster`](./API%20Reference/DouyinPet/DouyinPet.isMaster.md) (判断当前用户是不是控制者)
  - [`petAccesory`](./API%20Reference/DouyinPet/DouyinPet.petAccesory.md) (获取合养精灵的装扮列表)
  - [`petAppearance`](./API%20Reference/DouyinPet/DouyinPet.petAppearance.md) (获取合养精灵的形象)
  - [`petID`](./API%20Reference/DouyinPet/DouyinPet.petID.md) (获取合养精灵的 ID)
  - [`petLevel`](./API%20Reference/DouyinPet/DouyinPet.petLevel.md) (获取合养精灵等级)
  - [`petName`](./API%20Reference/DouyinPet/DouyinPet.petName.md) (获取合养精灵的名称)
  - [`petOpenID`](./API%20Reference/DouyinPet/DouyinPet.petOpenID.md) (合养精灵的唯一标识符，在创建合养精灵对象时进行初始化，属性为只读。)
- **方法**:
  - [`GetActor`](./API%20Reference/DouyinPet/DouyinPet.GetActor.md) (获取该 Douyinpet 关联的 Actor)
  - [`GetPetPortrait`](./API%20Reference/DouyinPet/DouyinPet.GetPetPortrait.md) (获取该DouyinPet的头像)

### [`DouyinPetService`](./API%20Reference/DouyinPetService.md)
合养精灵服务

- **方法**:
  - [`GetLocalPet`](./API%20Reference/DouyinPetService/DouyinPetService.GetLocalPet.md) (获取当前玩家控制的合养精灵)
  - [`GetPet`](./API%20Reference/DouyinPetService/DouyinPetService.GetPet.md) (通过 PetID，获取当前场景内的合养精灵)
  - [`GetPetCount`](./API%20Reference/DouyinPetService/DouyinPetService.GetPetCount.md) (获取当前场景内合养精灵的数量)
  - [`GetPets`](./API%20Reference/DouyinPetService/DouyinPetService.GetPets.md) (获取当前场景内所有的合养精灵)

### [`DouyinInputService`](./API%20Reference/DouyinInputService.md)
输入监听服务（摇杆、跳跃、拖屏等）

- **事件**:
  - [`onJumpInputCancel`](./API%20Reference/DouyinInputService/DouyinInputService.onJumpInputCancel.md) (取消跳跃事件)
  - [`onJumpInputPerform`](./API%20Reference/DouyinInputService/DouyiuInputService.onJumpInputPerform.md) (跳跃时事件)
  - [`onJumpInputStart`](./API%20Reference/DouyinInputService/DouyinInputService.onJumpInputStart.md) (跳跃，无论在 PC 上按下空格，还是手机屏幕点击跳跃，均触发跳跃输入事件)
  - [`onLookInputCancel`](./API%20Reference/DouyinInputService/DouyinInputService.onLookInputCancel.md) (旋转视角操作取消)
  - [`onLookInputPerform`](./API%20Reference/DouyinInputService/DouyinInputService.onLookInputPerform.md) (旋转视角（屏幕空白区域）)
  - [`onLookInputStart`](./API%20Reference/DouyinInputService/DouyinInputService.onLookInputStart.md) (旋转视角操作开始)
  - [`onMoveInputCancel`](./API%20Reference/DouyinInputService/DouyinInputService.onMoveInputCancel.md) (移动输入取消)
  - [`onMoveInputPerform`](./API%20Reference/DouyinInputService/DouyinInputService.onMoveInputPerform.md) (持续有移动输入)
  - [`onMoveInputStart`](./API%20Reference/DouyinInputService/DouyinInputService.onMoveInputStart.md) (开始有移动输入)
  - [`onTouchEvent`](./API%20Reference/DouyinInputService/DouyinInputService.onTouchEvent.md) (屏幕点击事件)
  - [`onZoomInput`](./API%20Reference/DouyinInputService/DouyinInputService.onZoomInput.md) (屏幕缩放（双指）)

### [`DouyinCameraService`](./API%20Reference/DouyinCameraService.md)
相机控制与参数服务

- **方法**:
  - [`GetCamera`](./API%20Reference/DouyinCameraService/DouyinCameraService.GetCamera.md) (获取与主角绑定的相机)
  - [`GetPitch`](./API%20Reference/DouyinCameraService/DouyinCameraService.GetPitch.md) (获取主相机与主角之间的俯仰角，游戏模式有效)
  - [`GetYaw`](./API%20Reference/DouyinCameraService/DouyinCameraService.GetYaw.md) (获取主相机与主角之间的偏航角，游戏模式有效)
  - [`IsPhotographMode`](./API%20Reference/DouyinCameraService/DouyinCameraService.IsPhotographMode.md) (判断当前相机功能模式的状态)
  - [`SetDistance`](./API%20Reference/DouyinCameraService/DouyinCameraService.SetDistance.md) (设置主相机与主角之间的距离，游戏模式有效)
  - [`SetOffset`](./API%20Reference/DouyinCameraService/DouyinCameraService.SetOffset.md) (设置主相机主角（目标点）位置偏移，游戏模式有效)
  - [`SetPitch`](./API%20Reference/DouyinCameraService/DouyinCameraService.SetPitch.md) (设置主相机与主角之间的俯仰角，游戏模式有效)
  - [`SetYaw`](./API%20Reference/DouyinCameraService/DouyinCameraService.SetYaw.md) (设置主相机与主角之间的偏航角，游戏模式有效)
  - [`StartPhotograph`](./API%20Reference/DouyinCameraService/DouyinCameraService.StartPhotograph.md) (进入相机功能模式)
  - [`StopPhotograph`](./API%20Reference/DouyinCameraService/DouyinCameraService.StopPhotograph.md) (停止相机功能模式)
- **事件**:
  - [`onCameraModeChanged`](./API%20Reference/DouyinCameraService/DouyinCameraService.onCameraModeChanged.md) (相机模式切换)

### [`DouyinPlayerSettings`](./API%20Reference/DouyinPlayerSettings.md)
玩家全局设置

- **属性**:
  - [`allowAction`](./API%20Reference/DouyinPlayerSettting/DouyinPlayerSettings.allowAction.md) (是否允许合养精灵动作功能)
  - [`allowActorChange`](./API%20Reference/DouyinPlayerSettting/DouyinPlayerSettings.allowActorChange.md) (是否允许切换合养精灵形象)
  - [`allowEmotion`](./API%20Reference/DouyinPlayerSettting/DouyinPlayerSettings.allowEmotion.md) (是否允许使用合养精灵表情功能)
  - [`allowRespawn`](./API%20Reference/DouyinPlayerSettting/DouyinPlayerSettings.allowRespawn.md) (是否允许重生)


## Ⅱ. 界面与交互 (UI)
负责呈现游戏状态并接收玩家的屏幕交互。

### [`DouyinUIService`](./API%20Reference/DouyinUIService.md)
界面与交互系统服务

- **方法**:
  - [`GetDefaultIcon`](./API%20Reference/DouyinUIService/DouyinUIService.GetDefaultIcon.md) (获取默认摇杆icon)
  - [`GetInteractionButton`](./API%20Reference/DouyinUIService/DouyinUIService.GetInteractionButton.md) (得到交互按钮)
  - [`GetJoyStickControl`](./API%20Reference/DouyinUIService/DouyinUIService.GetJoyStickControl.md) (获取摇杆)
  - [`SetNativeUIVisible`](./API%20Reference/DouyinUIService/DouyinUIService.SetNativeUIVisible.md) (显示/隐藏Native界面)
  - [`SetUIVisible`](./API%20Reference/DouyinUIService/DouyinUIService.SetUIVisible.md) (显示/隐藏Unity界面)
- **事件**:
  - [`onScreenResolutionChanged`](./API%20Reference/DouyinUIService/DouyinUIService.onScreenResolutionChanged.md) (屏幕分辨率改变的事件)

### [`DouyinJoyStickControl`](./API%20Reference/DouyinJoyStickControl.md)
虚拟摇杆 UI 控件

- **属性**:
  - [`background`](./API%20Reference/DouyinJoyStickControl/DouyinJoyStickControl.background.md) (背景图)
  - [`frontground`](./API%20Reference/DouyinJoyStickControl/DouyinJoyStickControl.frontground.md) (前景图)
  - [`gameObject`](./API%20Reference/DouyinJoyStickControl/DouyinJoyStickControl.gameObject.md) (物体)
  - [`overrideFunctionEnabled`](./API%20Reference/DouyinJoyStickControl/DouyinJoyStickControl.overrideFunctionEnabled.md) (摇杆操作默认功能是否启用)
- **方法**:
  - [`OnUIDrag`](./API%20Reference/DouyinJoyStickControl/DouyinJoyStickControl.OnUIDrag.md) (摇杆拖拽事件)
  - [`OnUIPointerDown`](./API%20Reference/DouyinJoyStickControl/DouyinJoyStickControl.OnUIPointerDown.md) (摇杆按下事件)
  - [`OnUIPointerUp`](./API%20Reference/DouyinJoyStickControl/DouyinJoyStickControl.OnUIPointerUp.md) (摇杆抬起事件)


## Ⅲ. 逻辑与脚本 (Logic & Scripting)
提供游戏业务的逻辑控制、运行环境上下文及调试输出能力。

### [`DouyinScript`](./API%20Reference/DouyinScript.md)
脚本挂载组件（包含控制权与主权的基础能力）

- **属性**:
  - [`douyinActor`](./API%20Reference/DouyinScript/属性/DouyinScript.douyinActor.md) (当 DouyinScript 作为角色脚本挂载到角色 GameObject 上时，该属性返回对应的 DouyinScript)
  - [`douyinObject`](./API%20Reference/DouyinScript/属性/DouyinScript.douyinObject.md) (逻辑对象，面板不可见)
- **方法**:
  - [`AddInteractorButton`](./API%20Reference/DouyinScript/方法/DouyinScript.AddInteractorButton.md) (新增基础交互按钮)
  - [`DisableInteraction`](./API%20Reference/DouyinScript/方法/DouyinScript.DisableInteraction.md) (禁止交互)
  - [`EnableInteraction`](./API%20Reference/DouyinScript/方法/DouyinScript.EnableInteraction.md) (设置为可交互，包括 3D 交互和 2D 交互)
  - [`GetController`](./API%20Reference/DouyinScript/方法/DouyinScript.GetController.md) (获取当前物体的控制者)
  - [`GetDouyinScript`](./API%20Reference/DouyinScript/方法/DouyinScript.GetDouyinScript.md) (获得同物体上的 DouyinScript，同名返回第一个)
  - [`GetDouyinScripts`](./API%20Reference/DouyinScript/方法/DouyinScript.GetDouyinScripts.md) (获得同物体上的 DouyinScript 数组)
  - [`GetOwner`](./API%20Reference/DouyinScript/方法/DouyinScript.GetOwner.md) (获取一个对象的 Owner)
  - [`HasControllership`](./API%20Reference/DouyinScript/方法/DouyinScript.HasControllership.md) (是否有控制权)
  - [`HasOwnership`](./API%20Reference/DouyinScript/方法/DouyinScript.HasOwnership.md) (是否有主权)
  - [`IsController`](./API%20Reference/DouyinScript/方法/DouyinScript.IsController.md) (判断是否为控制者)
  - [`IsOwner`](./API%20Reference/DouyinScript/方法/DouyinScript.IsOwner.md) (判断对象是否为 Owner)
  - [`IsSpawned`](./API%20Reference/DouyinScript/方法/DouyinScript.IsSpawned.md) (判断某一个 DouyinScript 里面的网络对象有没有完成 spawn)
  - [`OwnerCall`](./API%20Reference/DouyinScript/方法/DouyinScript.OwnerCall.md) (非主权方调用主权方的函数)
  - [`ReleaseControllership`](./API%20Reference/DouyinScript/方法/DouyinScript.ReleaseControllership.md) (释放控制权)
  - [`RemoveAllInteractorButtons`](./API%20Reference/DouyinScript/方法/DouyinScript.RemoveAllInteractorButtons.md) (移除该脚本对象内添加的基础交互按钮)
  - [`RemoveInteractorButton`](./API%20Reference/DouyinScript/方法/DouyinScript.RemoveInteractorButton.md) (移除指定的基础交互按钮)
  - [`RemoveInteractorButtonAt`](./API%20Reference/DouyinScript/方法/DouyinScript.RemoveInteractorButtonAt.md) (移除指定index的基础交互按钮)
  - [`RequestControllership`](./API%20Reference/DouyinScript/方法/DouyinScript.RequestControllership.md) (申请控制权)
  - [`RequestOwnership`](./API%20Reference/DouyinScript/方法/DouyinScript.RequestOwnership.md) (请求主权)
  - [`Respawn`](./API%20Reference/DouyinScript/方法/DouyinScript.Respawn.md) (重生   DouyinScript  对象，根据场景初始状态，设置对象的位置和旋转)
  - [`SendMessageToAll`](./API%20Reference/DouyinScript/方法/DouyinScript.SendMessageToAll.md) (发送网络事件给所有人，包括自己)
  - [`SendMessageToOthers`](./API%20Reference/DouyinScript/方法/DouyinScript.SendMessageToOthers.md) (发送网络事件给房间内其他玩家，不包括自己)
  - [`SendMessageToOwner`](./API%20Reference/DouyinScript/方法/DouyinScript.SendMessageToOwner.md) (发送网络事件给当前脚本对应的主权人)
  - [`SendMessageToTarget`](./API%20Reference/DouyinScript/方法/DouyinScript.SendMessageToTarget.md) (发送网络事件给某人)
  - [`SetAnimationEvent`](./API%20Reference/DouyinScript/方法/DouyinScript.SetAnimationEvent.md) (设置一个动作的Animation Event回调，当播放此动作时会触发回调函数)
  - [`SetController`](./API%20Reference/DouyinScript/方法/DouyinScript.SetController.md) (设置物体的控制者)
  - [`SetControllership`](./API%20Reference/DouyinScript/方法/DouyinScript.SetControllership.md) (把控制权转移给指定的 Actor)
  - [`SetOwner`](./API%20Reference/DouyinScript/方法/DouyinScript.SetOwner.md) (设置一个对象的同步 owner，只有 owner 才能执行成功)
  - [`SetOwnership`](./API%20Reference/DouyinScript/方法/DouyinScript.SetOwnership.md) (把所有权转移给指定的 Actor)
  - [`TargetCall`](./API%20Reference/DouyinScript/方法/DouyinScript.TargetCall.md) (调用任意人的函数)

### [`DouyinUtility`](./API%20Reference/DouyinUtility.md)
通用工具类方法

- **方法**:
  - [`Alert`](./API%20Reference/DouyinUtility/DouyinUtility.Alert.md) (弹出一个native窗口)
  - [`FilteEmoji`](./API%20Reference/DouyinUtility/DouyinUtility.FilteEmoji.md) (过滤输入框里的表情符号（iOS表情符号显示成乱码）)
  - [`GetServerTime`](./API%20Reference/DouyinUtility/DouyinUtility.GetServerTime.md) (返回服务器时间DateTime)
  - [`GetServerUnixTime`](./API%20Reference/DouyinUtility/DouyinUtility.GetServerUnixTime.md) (返回服务器时间Unix Time)
  - [`Toast`](./API%20Reference/DouyinUtility/DouyinUtility.Toast.md) (Toast提示)


## Ⅳ. 多人游戏与网络 (Multiplayer)
处理房间状态同步、RPC 通信与网络事件广播。

### [`DouyinNetService`](./API%20Reference/DouyinNetService.md)
基础网络状态服务

- **属性**:
  - [`isNetworkSettled`](./API%20Reference/DouyinNetService/DouyinNetService.isNetworkSettled.md) (房间的数据是否同步完成)
- **方法**:
  - [`OnNetworkSettled`](./API%20Reference/DouyinNetService/DouyinNetService.OnNetworkSettled.md) (房间的数据同步完成)

### [`DouyinRemoteEvent`](./API%20Reference/DouyinRemoteEvent.md)
远程事件通信（单向通知）

- **方法**:
  - [`FireAllClients`](./API%20Reference/DouyinRemoteEvent/DouyinRemoteEvent.FireAllClients.md) (服务器广播给所有的客户端)
  - [`FireClient`](./API%20Reference/DouyinRemoteEvent/DouyinRemoteEvent.FireClient.md) (服务器调用指定的客户端)
  - [`FireServer`](./API%20Reference/DouyinRemoteEvent/DouyinRemoteEvent.FireServer.md) (客户端调用服务器)
- **事件**:
  - [`onClientEvent`](./API%20Reference/DouyinRemoteEvent/DouyinRemoteEvent.onClientEvent.md) (客户端的事件：服务器调用客户端，客户端需要侦听该事件，并处理业务逻辑)
  - [`onServerEvent`](./API%20Reference/DouyinRemoteEvent/DouyinRemoteEvent.onServerEvent.md) (服务端的事件：客户端调用服务器，服务器需要侦听该事件，并处理业务逻辑)

### [`DouyinRemoteFunction`](./API%20Reference/DouyinRemoteFunction.md)
远程函数调用（带返回值通信）

- **方法**:
  - [`InvokeClient`](./API%20Reference/DouyinRemoteFunction/DouyinRemoteFunction.InvokeClient.md) (服务器调用指定的客户端， 并处理客户端响应)
  - [`InvokeServer`](./API%20Reference/DouyinRemoteFunction/DouyinRemoteFunction.InvokeServer.md) (客户端调用服务器，并处理服务器的响应)
- **事件**:
  - [`onClientInvoke`](./API%20Reference/DouyinRemoteFunction/DouyinRemoteFunction.onClientInvoke.md) (客户端的事件：服务器调用客户端，客户端需要侦听该事件，处理业务逻辑并返回结果)
  - [`onServerInvoke`](./API%20Reference/DouyinRemoteFunction/DouyinRemoteFunction.onServerInvoke.md) (服务端的事件：客户端调用服务器，服务器需要侦听该事件，处理业务逻辑并返回结果)


## Ⅴ. 平台服务 (Cloud Services)
提供抖音平台的云端生态能力，包括创作者信息、商业化发货、排行榜等运营后盾。

### [`DouyinCreatorService`](./API%20Reference/DouyinCreatorService.md)
创作者信息与关注服务

- **方法**:
  - [`Follow`](./API%20Reference/DouyinCreatorService/DouyinCreatorService.Follow.md) (关注创作者)
  - [`GetCreatorInfo`](./API%20Reference/DouyinCreatorService/DouyinCreatorService.GetCreatorInfo.md) (获取创作者信息)
  - [`OpenCreatorInformation`](./API%20Reference/DouyinCreatorService/DouyinCreatorService.OpenCreatorInformation.md) (打开创作者信息)

### [`DouyinImageService`](./API%20Reference/DouyinImageService.md)
云端图片下载与处理服务

- **方法**:
  - [`DownloadImage`](./API%20Reference/DouyinImageService/DouyinImageService.DownloadImage.md) (通过url下载图片)

### [`DouyinMarketingService`](./API%20Reference/DouyinMarketingService.md)
商业化营销与内购服务

- **方法**:
  - [`BackOrder`](./API%20Reference/DouyinMarketingService/方法/DouyinMarketingService.BackOrder.md) (该函数用于在客户端手动触发补单。建议您在用户登录且数据加载完成后调用)
  - [`ConfirmOrder`](./API%20Reference/DouyinMarketingService/方法/DouyinMarketingService.ConfirmOrder.md) (服务器函数，通知平台发货结果)
  - [`GetProductInfo`](./API%20Reference/DouyinMarketingService/方法/DouyinMarketingService.GetProductInfo.md) (获取指定商品的信息)
  - [`GetProductInfos`](./API%20Reference/DouyinMarketingService/方法/DouyinMarketingService.GetProductInfos.md) (获取当前世界中所有已上线的开发者商品信息)
  - [`GetProductPage`](./API%20Reference/DouyinMarketingService/方法/DouyinMarketingService.GetProductPage.md) (该接口用于获取商品分页的首页数据，并返回`DouyinProductPage`)
  - [`OpenRechargePage`](./API%20Reference/DouyinMarketingService/方法/DouyinMarketingService.OpenRechargePage.md) (打开充值页面)
  - [`Purchase`](./API%20Reference/DouyinMarketingService/方法/DouyinMarketingService.Purchase.md) (购买指定商品ID和数量的商品)
- **事件**:
  - [`onOrderPayment`](./API%20Reference/DouyinMarketingService/事件/DouyinMarketingService.onOrderPayment.md) (这是一个服务器事件。当支付成功后，您需要监听此事件来完成发货)
  - [`onPurchaseResult`](./API%20Reference/DouyinMarketingService/事件/DouyinMarketingService.onPurchaseResult.md) (这是一个客户端事件。当客户端发起购买操作后，会触发此事件并返回购买结果)
  - [`onStarLightChanged`](./API%20Reference/DouyinMarketingService/事件/DouyinMarketingService.onStarLightChanged.md) (当星光币数量发生变化时，将触发此事件)

### [`DouyinProductPage`](./API%20Reference/DouyinProductPage.md)
商业化商品分页数据

- **属性**:
  - [`hasMore`](./API%20Reference/DouyinProductPage/DouyinProductPage.hasMore.md) (是否还有更多的商品信息)
  - [`pageOffset`](./API%20Reference/DouyinProductPage/DouyinProductPage.pageOffset.md) (当前商品页的起始索引)
  - [`pageSize`](./API%20Reference/DouyinProductPage/DouyinProductPage.pageSize.md) (当前商品页的页面大小)
  - [`productInfos`](./API%20Reference/DouyinProductPage/DouyinProductPage.productInfos.md) (当前页面的所有的商品信息)
  - [`queryTime`](./API%20Reference/DouyinProductPage/DouyinProductPage.queryTime.md) (查询时间)
  - [`totalSize`](./API%20Reference/DouyinProductPage/DouyinProductPage.totalSize.md) (当前所有商品的数量)
- **方法**:
  - [`AdvanceToNextPage`](./API%20Reference/DouyinProductPage/DouyinProductPage.AdvanceToNextPage.md) (获取下一页的商品数据)

### [`DouyinRankService`](./API%20Reference/DouyinRankService.md)
排行榜服务

- **方法**:
  - [`SetRankData`](./API%20Reference/DouyinRankService/DouyinRankService.SetRankData.md) (设置排行榜数据)

### [`DouyinSocialService`](./API%20Reference/DouyinSocialService.md)
社交互动服务

- **事件**:
  - [`onPublishProcessEvent`](./API%20Reference/DouyinSocialService/DouyinSocialService.onPublishProcessEvent.md) (监听玩家的抖音视频的投稿发布状态)
  - [`onPublishResultEvent`](./API%20Reference/DouyinSocialService/DouyinSocialService.onPublishResultEvent.md) (用于监听玩家的抖音视频的投稿结果)
  - [`ShareTexture`](./API%20Reference/DouyinSocialService/DouyinSocialService.ShareTexture.md) (该函数用于将指定的图片分享给他人)
  - [`ShareWorld`](./API%20Reference/DouyinSocialService/DouyinSocialService.ShareWorld.md) (该函数用于将当前的游戏世界分享给他人)

### [`DouyinTaskService`](./API%20Reference/DouyinTaskService.md)
任务系统服务

- **方法**:
  - [`SendEvent`](./API%20Reference/DouyinTaskService/DouyinTaskService.SendEvent.md) (通知任务平台完成任务)

### [`DouyinThirdPartyService`](./API%20Reference/DouyinThirdPartyService.md)
第三方平台接入服务

- **方法**:
  - [`SendRequest`](./API%20Reference/DouyinThirdPartyService/DouyinThirdPartyService.SendRequest.md) (向第三方发消息)
- **事件**:
  - [`onThirdPartyMessage`](./API%20Reference/DouyinThirdPartyService/DouyinThirdPartyService.onThirdPartyMessage.md) (监听第三方消息事件)

### [`DouyinUserService`](./API%20Reference/DouyinUserService.md)
用户账号与状态服务

- **方法**:
  - [`GetUserInfo`](./API%20Reference/DouyinUserService/DouyinUserService.GetUserInfo.md) (通过openID获取抖音用户的信息)
  - [`GetUserInfos`](./API%20Reference/DouyinUserService/DouyinUserService.GetUserInfos.md) (通过openID列表获取抖音多个用户的信息，批量查询阈值。目前单次查询用户数量最多支持50个。)

### [`DouyinLogService`](./API%20Reference/DouyinLogService.md)
日志与调试输出服务

- **方法**:
  - [`Debug`](./API%20Reference/DouyinLogService/DouyinLogService.Debug.md) (开发阶段使用的调试日志，用于辅助定位问题；不会上报到后台。)
  - [`Error`](./API%20Reference/DouyinLogService/DouyinLogService.Error.md) (错误日志。表示发生功能异常或关键流程失败，可能导致部分功能不可用，需要尽快处理。)
  - [`Info`](./API%20Reference/DouyinLogService/DouyinLogService.Info.md) (信息日志，用于记录关键流程、状态变化与重要事件，便于追踪与排查问题。)
  - [`Log`](./API%20Reference/DouyinLogService/DouyinLogService.Log.md) (通用日志，用于记录常规运行信息、简单流程节点与基础状态，内容轻量无特殊优先级。)
  - [`Warning`](./API%20Reference/DouyinLogService/DouyinLogService.Warning.md) (警告日志。表示出现了需要关注的异常或潜在风险，但通常不会立即中断当前流程。)
