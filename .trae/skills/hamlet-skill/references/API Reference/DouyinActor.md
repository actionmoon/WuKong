在阅读此章节前，强烈建议参阅[玩家与合养精灵]章节，以了解更多关于玩家（Player）和合养精灵（Actor）的背景信息。
# 描述
控制对象类，目前对应着在世界内的每个精灵对象，可通过 isPet 属性来判断是否是精灵。

* 可以获得显示相关的一系列属性，包括显示名称、位置、移动相关信息、形象相关信息；
* 包含操控对象的一些函数，比如设置速度、改变动作等；
* 可以使用 Tag 相关 API 给对象赋予一些数据，从而进行对象管理。 （Tag相关API当前版本无法使用，请期待该功能上线）

# 公开事件
| 事件 | 描述 |
| --- | --- |
| [onActorLoaded](./DouyinActor/事件/DouyinActor.onActorLoaded.md) | 切换 Actor 形象时回调 |
| [onFallingGround](./DouyinActor/事件/DouyinActor.onFallingGround.md) | Actor 落地的事件 |
| [onJump](./DouyinActor/事件/DouyinActor.onJump.md) | Actor 起跳的事件 |
| [onFlyStart](./DouyinActor/事件/DouyinActor.onFlyStart.md) | Actor 开始飞行的事件 |
| [onFlyStop](./DouyinActor/事件/DouyinActor.onFlyStop.md) | Actor 结束飞行的事件 |
| [onEmotionPlay](./DouyinActor/事件/DouyinActor.onEmotionPlay.md) | Actor使用表情事件  |
| [onActionPlay](./DouyinActor/事件/DouyinActor.onActionPlay.md) | Actor使用动作事件 |
| [onDuoInteractionStart](./DouyinActor/事件/DouyinActor.onDuoInteractionStart.md) | Actor开始播放双人动作事件 |
| [onDuoInteractionEnd](./DouyinActor/事件/DouyinActor.onDuoInteractionEnd.md) | Actor结束播放双人动作事件 |
| [onDuoInteractionWaiting](./DouyinActor/事件/DouyinActor.onDuoInteractionWaiting.md) | Actor开始等待播放双人动作事件 |
| [onHoldHandStart](./DouyinActor/事件/DouyinActor.onHoldHandStart.md) | Actor进入牵手状态事件 |
| [onHoldHandStop](./DouyinActor/事件/DouyinActor.onHoldHandStop.md) | Actor结束牵手状态事件 |
| [onPickup](./DouyinActor/事件/DouyinActor.onPickup.md) | Actor捡起物体的事件 |
| [onDrop](./DouyinActor/事件/DouyinActor.onDrop.md) | Actor丢弃物体的事件 |
| [onSitDown](./DouyinActor/事件/DouyinActor.onSitDown.md) | Actor坐下的事件 |
| [onStandUp](./DouyinActor/事件/DouyinActor.onStandUp.md) | Actor站起的事件 |
| [onSwimStart](./DouyinActor/事件/DouyinActor.onSwimStart.md) | Actor开始游泳的事件 |
| [onSwimStop](./DouyinActor/事件/DouyinActor.onSwimStop.md) | Actor停止游泳的事件 |
# 公开属性
| 属性 | 描述 |
| --- | --- |
| [velocity](./DouyinActor/属性/DouyinActor.velocity.md) | 移动方向和速度 |
| [gameObject](./DouyinActor/属性/DouyinActor.gameObject.md) | 获取关联 GameObject 实例 |
| [position](./DouyinActor/属性/DouyinActor.position.md) | 位置 |
| [rotation](./DouyinActor/属性/DouyinActor.rotation.md) | 朝向 |
| [scale](./DouyinActor/属性/DouyinActor.scale.md) | 获取/设置 Actor 的缩放，角色的大小限制（0，2）之间 |
| [actorID](./DouyinActor/属性/DouyinActor.actorID.md) | Actor 实例 ID，用来判断是否是同一个玩家（重复进房间会变化） |
| [displayName](./DouyinActor/属性/DouyinActor.displayName.md) | Actor 的名称 |
| [isPet](./DouyinActor/属性/DouyinActor.isPet.md) | 是否为精灵 |
| [douyinPet](./DouyinActor/属性/DouyinActor.douyinPet.md) | 当 isPet 为 true 的时候，返回当前 Actor 关联的 DouyinPet；否则返回 null |
| [isLocal](./DouyinActor/属性/DouyinActor.isLocal.md) | 返回这个 Actor 是否是 Local 玩家 |
| [flySpeed](./DouyinActor/属性/DouyinActor.flySpeed.md) | 飞行水平速度 |
| [flyVerticalSpeed](./DouyinActor/属性/DouyinActor.flyVerticalSpeed.md) | 飞行垂直速度 |
| [flyMaxHeight](./DouyinActor/属性/DouyinActor.flyMaxHeight.md) | 飞行最大高度 |
| [flyMinHeight](./DouyinActor/属性/DouyinActor.flyMinHeight.md) | 飞行最小高度 |
| [speed](./DouyinActor/属性/DouyinActor.speed.md) | 移动速度 |
| [gravityScale](./DouyinActor/属性/DouyinActor.gravityScale.md) | 设置重力缩放系数 |
| [minSlopeAngleLimit](./DouyinActor/属性/DouyinActor.minSlopeAngleLimit.md) | 当前 Actor 在斜坡上最小能站立的角度 |
| [allowPushByOtherActor](./DouyinActor/属性/DouyinActor.allowPushByOtherActor.md) | 当前 Actor 是否能被其他 Actor 推动 |
| [allowAccessUserPanel](./DouyinActor/属性/DouyinActor.allowAccessUserPanel.md) | 开启/禁用用户3D点击，访问用户的信息面板，默认开启 |
| [jumpHeight](./DouyinActor/属性/DouyinActor.jumpHeight.md) | 获取或设置当前Actor的跳跃高度 |
| [disableActorCollider](./DouyinActor/属性/DouyinActor.disableActorCollider.md) | 用于禁用精灵（Actor）之间的碰撞 |
# 公开方法
| 方法 | 描述 |
| --- | --- |
| [GetBonePosition](./DouyinActor/方法/DouyinActor.GetBonePosition.md) | 获取 Actor 的人骨位置信息 |
| [GetBoneRotation](./DouyinActor/方法/DouyinActor.GetBoneRotation.md) | 获取 Actor 的人骨角度信息 |
| [GetBoneTransform](./DouyinActor/方法/DouyinActor.GetBoneTransform.md) | 获取 Actor 的人骨下的 Transform 对象 |
| [SetOverrideAnimationController](./DouyinActor/方法/DouyinActor.SetOverrideAnimationController.md) | 设置重载的动画状态机 |
| [SetOverrideAnimation](./DouyinActor/方法/DouyinActor.SetOverrideAnimation.md) | 设置重载动画，重载为 nil，就会还原，支持使用 Animation Event，可传回调函数 |
| [PlayAnimation](./DouyinActor/方法/DouyinActor.PlayAnimation.md) | 播放一个动作，支持使用 Animation Event，可传回调函数 |
| [StopAnimation](./DouyinActor/方法/DouyinActor.StopAnimation.md) | 停止播放动作 |
| [ShowNameplate](./DouyinActor/方法/DouyinActor.ShowNameplate.md) | 显示/隐藏 Actor 名字片 |
| [GetNameplate](./DouyinActor/方法/DouyinActor.GetNameplate.md) | 获取名字片对象 |
| [Interact](./DouyinActor/方法/DouyinActor.Interact.md) | 交互，该方法最对本地玩家有效 |
| [GetPickupInHand](./DouyinActor/方法/DouyinActor.GetPickupInHand.md) | 返回 Actor 特定手的 Pickup 物件，这个函数仅针对 local actor 生效，没有 pickup 时返回 null |
| [IsPickup](./DouyinActor/方法/DouyinActor.IsPickup.md) | 手中是否有物体 |
| [Pickup](./DouyinActor/方法/DouyinActor.Pickup.md) | 拾取指定物体，该方法只对本地玩家有效 |
| [Drop](./DouyinActor/方法/DouyinActor.Drop.md) | 丢弃指定物体，该方法只对本地玩家有效 |
| [PlayEmoji](./DouyinActor/方法/DouyinActor.PlayEmoji.md) | 播放表情 |
| [Respawn](./DouyinActor/方法/DouyinActor.Respawn.md) | 角色重生 |
| [Teleport](./DouyinActor/方法/DouyinActor.Teleport.md)（重载方法） | 传送 |
| [SetActorTag](./DouyinActor/方法/DouyinActor.SetActorTag.md) | 给 Actor 增加标签，无需权限，任何人都可以添加 |
| [GetActorTag](./DouyinActor/方法/DouyinActor.GetActorTag.md) | 获取 Actor 标签 |
| [ClearActorTags](./DouyinActor/方法/DouyinActor.ClearActorTags.md) | 清除指定 tag，如果参数为空则清除所有 Tags，无需权限，任何人都可清除 |
| [GetState](./DouyinActor/方法/DouyinActor.GetState.md) | 获取 Actor 状态 |
| [ChangeState](./DouyinActor/方法/DouyinActor.ChangState.md) | 切换到某个状态 |
| [GetStateEnabled](./DouyinActor/方法/DouyinActor.GetStateEnabled.md) | 获取 Actor 状态是否生效 |
| [SetStateEnabled](./DouyinActor/方法/DouyinActor.SetStateEnabled.md) | 设置 Actor 状态是否生效 |
| [Jump](./DouyinActor/方法/DouyinActor.Jump.md) | 跳跃 |
| [IsGrounded](./DouyinActor/方法/DouyinActor.IsGrounded.md) | 判断 Actor 是否在地面的参数 |
| [CanMove](./DouyinActor/方法/DouyinActor.CanMove.md) | 判断当前 Actor 是否能移动 |
| [StopMove](./DouyinActor/方法/DouyinActor.StopMove.md) | 停止移动，相当于取消上个 Api 的持续移动效果 |
| [MoveContinuously](./DouyinActor/方法/DouyinActor.MoveContinuously.md) | 向某个方向移动，参数是移动速度的倍速（相当于一直朝某个方向推动摇杆，只能平面移动），该方法只对本地玩家有效 |
| [IsSitting](./DouyinActor/方法/DouyinActor.IsSitting.md) | 获取玩家是否坐着 |
| [SitDown](./DouyinActor/方法/DouyinActor.SitDown.md) | 坐下，该方法只对本地玩家有效 |
| [StandUp](./DouyinActor/方法/DouyinActor.StandUp.md) | 站起，该方法只对本地玩家有效 |
| [SetFlyMode](./DouyinActor/方法/DouyinActor.SetFlyMode.md) | 设置飞行模式 |
| [StartFly](./DouyinActor/方法/DouyinActor.StartFly.md) | 开始飞行 |
| [StopFly](./DouyinActor/方法/DouyinActor.StopFly.md) | 停止飞行 |
| [CanFly](./DouyinActor/方法/DouyinActor.CanFly.md) | 是否能飞行 |
| [IsFlying](./DouyinActor/方法/DouyinActor.IsFlying.md) | 当前是否飞行 |
| [CanSwim](./DouyinActor/方法/DouyinActor.CanSwim.md) | 是否能游泳 |
| [IsSwimming](./DouyinActor/方法/DouyinActor.IsSwimming.md) | 当前是否在游泳 |
| [Immobilize](./DouyinActor/方法/DouyinActor.Immobilize.md) | 是否可以通过摇杆移动 |
| [SetAlpha](./DouyinActor/方法/DouyinActor.SetAlpha.md) | 设置当前 Actor 的透明度，alpha 取值范围[0-1] |
| [SetVisible](./DouyinActor/方法/DouyinActor.SetVisible.md) | 是否隐藏当前 Actor  |
| [EnableInteraction](./DouyinActor/方法/DouyinActor.EnableInteraction.md) | 把当前对象设置为可交互对象 |
| [DisableInteraction](./DouyinActor/方法/DouyinActor.DisableInteraction.md) | 把当前对象移除掉可交互对象 |
| [CalculatePalmTransform](./DouyinActor/方法/DouyinActor.CalculatePalmTransform.md) | 计算当前 Actor 手部挂点 |
| [EnableFly](./DouyinActor/方法/DouyinActor.EnableFly.md) | 开启飞行/悬浮 |
| [DisableFly](./DouyinActor/方法/DouyinActor.DisableFly.md) | 禁止飞行/悬浮 |
| [EnableHoldHand](./DouyinActor/方法/DouyinActor.EnableHoldHand.md) | 开启牵手行为 |
| [DisableHoldHand](./DouyinActor/方法/DouyinActor.DisableHoldHand.md) | 禁止牵手行为 |
| [IsHoldHand](./DouyinActor/方法/DouyinActor.IsHoldHand.md) | 当前 Actor 是否处于牵手状态 |
| [CanHoldHand](./DouyinActor/方法/DouyinActor.CanHoldHand.md) | 当前 Actor 是否可以牵手 |
| [GetHoldHandState](./DouyinActor/方法/DouyinActor.GetHoldHandState.md) | 返回牵手状态的枚举类型 |
| [StopHoldHand](./DouyinActor/方法/DouyinActor.StopHoldHand.md) | 结束当前 Actor 的牵手状态 |
| [InviteDuoInteraction](./DouyinActor/方法/DouyinActor.InviteDuoInteraction.md) | Actor发起一次多人交互 |
| [AcceptDuoInteraction](./DouyinActor/方法/DouyinActor.AcceptDuoInteraction.md) | Actor接受其他Actor发起的交互 |
| [IsDuoInteractionWaiting](./DouyinActor/方法/DouyinActor.IsDuoInteractionWaiting.md) | Actor等待多人交互，当发起多人交互，其他Actor没有接受多人交互的时候，会处于等待状态。 |
| [StopDuoInteractionWaiting](./DouyinActor/方法/DouyinActor.StopDuoInteractionWaiting.md) | 停止交互等待 |
| [StartDuoInteraction](./DouyinActor/方法/DouyinActor.StartDuoInteraction.md) | Actor开始多人交互，交互的对象是传入的actor |
| [StopDuoInteraction](./DouyinActor/方法/DouyinActor.StopDuoInteraction.md) | 退出双人交互，如果是引导者，停止所有的双人交互；如果是跟随者，停止跟随者后续的所有双人交互 |
| [IsDuoInteracting](./DouyinActor/方法/DouyinActor.IsDuoInteracting.md) | Actor正在多人交互交互中 |
| [NetSpawn](./DouyinActor/方法/DouyinActor.NetSpawn.md) | 动态生成和Actor绑定的网络对象，Actor销毁时，该Actor创建的网络对象也会被销毁 |
| [SetJumpAudioClip](./DouyinActor/方法/DouyinActor.SetJumpAudioClip.md) | 设置跳跃的音效 |
| [SetFootstepAudioClips](./DouyinActor/方法/DouyinActor.SetFootstepAudioClips.md) | 设置脚步声。传入的数组应包含两个音效，分别对应：左脚的声音、右脚的声音。 |
| [SetSpeed](./DouyinActor/方法/DouyinActor.SetSpeed.md) | 设置精灵移动速度，并自动联动行走动画的播放速度；速度高于默认基础速度时动画相应加快，避免"脚步打滑"，否则保持原速。 |
