# 描述
DouyinScript 是抖音开发的用户生成内容（UGC）组件。它实现了类似 Unity 的 MonoBehaviour 组件的功能，允许您创建包含逻辑代码的预制件。
# 公开属性
| 属性 | 描述 |
| --- | --- |
| [douyinObject](./DouyinScript/属性/DouyinScript.douyinObject.md) | 逻辑对象，面板不可见 |
| [douyinActor](./DouyinScript/属性/DouyinScript.douyinActor.md) | 当 DouyinScript 作为角色脚本挂载到角色 GameObject 上时，该属性返回对应的 DouyinScript |
# 公开方法
| 方法 | 描述 |
| --- | --- |
| [SendMessageToOwner](./DouyinScript/方法/DouyinScript.SendMessageToOwner.md) | 发送网络事件给当前脚本对应的主权人 |
| [SendMessageToAll](./DouyinScript/方法/DouyinScript.SendMessageToAll.md) | 发送网络事件给所有人，包括自己 |
| [SendMessageToTarget](./DouyinScript/方法/DouyinScript.SendMessageToTarget.md) | 发送网络事件给某人 |
| [SendMessageToOthers](./DouyinScript/方法/DouyinScript.SendMessageToOthers.md) | 发送网络事件给房间内其他玩家，不包括自己 |
| [OwnerCall](./DouyinScript/方法/DouyinScript.OwnerCall.md) | 非主权方调用主权方的函数 |
| [TargetCall](./DouyinScript/方法/DouyinScript.TargetCall.md) | 调用任意人的函数 |
| [RequestOwnership](./DouyinScript/方法/DouyinScript.RequestOwnership.md) | 请求主权 |
| [SetOwnership](./DouyinScript/方法/DouyinScript.SetOwnership.md) | 把所有权转移给指定的 Actor |
| [HasOwnership](./DouyinScript/方法/DouyinScript.HasOwnership.md) | 是否有主权 |
| [SetOwner](./DouyinScript/方法/DouyinScript.SetOwner.md) | 设置一个对象的同步 owner，只有 owner 才能执行成功 |
| [IsOwner](./DouyinScript/方法/DouyinScript.IsOwner.md) | 判断对象是否为 Owner |
| [GetOwner](./DouyinScript/方法/DouyinScript.GetOwner.md) | 获取一个对象的 Owner |
| [RequestControllership](./DouyinScript/方法/DouyinScript.RequestControllership.md) | 申请控制权 |
| [ReleaseControllership](./DouyinScript/方法/DouyinScript.ReleaseControllership.md) | 释放控制权 |
| [SetControllership](./DouyinScript/方法/DouyinScript.SetControllership.md) | 把控制权转移给指定的 Actor |
| [HasControllership](./DouyinScript/方法/DouyinScript.HasControllership.md) | 是否有控制权 |
| [IsController](./DouyinScript/方法/DouyinScript.IsController.md) | 判断是否为控制者 |
| [SetController](./DouyinScript/方法/DouyinScript.SetController.md) | 设置物体的控制者 |
| [GetController](./DouyinScript/方法/DouyinScript.GetController.md) | 获取当前物体的控制者 |
| [GetDouyinScript](./DouyinScript/方法/DouyinScript.GetDouyinScript.md) | 获得同物体上的 DouyinScript，同名返回第一个 |
| [GetDouyinScripts](./DouyinScript/方法/DouyinScript.GetDouyinScripts.md) | 获得同物体上的 DouyinScript 数组 |
| [EnableInteraction](./DouyinScript/方法/DouyinScript.EnableInteraction.md) | 设置为可交互，包括 3D 交互和 2D 交互 |
| [DisableInteraction](./DouyinScript/方法/DouyinScript.DisableInteraction.md) | 禁止交互 |
| [IsSpawned](./DouyinScript/方法/DouyinScript.IsSpawned.md) | 判断某一个 DouyinScript 里面的网络对象有没有完成 spawn |
| [Respawn](./DouyinScript/方法/DouyinScript.Respawn.md) | 重生   DouyinScript  对象，根据场景初始状态，设置对象的位置和旋转 |
| [AddInteractorButton](./DouyinScript/方法/DouyinScript.AddInteractorButton.md) | 新增基础交互按钮 |
| [RemoveInteractorButton](./DouyinScript/方法/DouyinScript.RemoveInteractorButton.md) | 移除指定的基础交互按钮 |
| [RemoveInteractorButtonAt](./DouyinScript/方法/DouyinScript.RemoveInteractorButtonAt.md) | 移除指定index的基础交互按钮 |
| [RemoveAllInteractorButtons](./DouyinScript/方法/DouyinScript.RemoveAllInteractorButtons.md) | 移除该脚本对象内添加的基础交互按钮 |
| [SetAnimationEvent](./DouyinScript/方法/DouyinScript.SetAnimationEvent.md) | 设置一个动作的Animation Event回调，当播放此动作时会触发回调函数 |
# 消息
| 消息 | 描述 |
| --- | --- |
| [Awake](./DouyinScript/消息/DouyinScript.Awake.md) | 当脚本实例被加载时，会调用  Awake |
| [Start](./DouyinScript/消息/DouyinScript.Start.md) | 当在第一次调用任何 Update 方法之前启用脚本时，会在框架上调用 Start。 |
| [Update](./DouyinScript/消息/DouyinScript.Update.md) | 如果启用了 MonoBehaviour，则每帧都会调用更新 |
| [FixedUpdate](./DouyinScript/消息/DouyinScript.FixedUpdate.md) | 用于物理计算的帧速率独立的   MonoBehavior.FixedUpdate  消息 |
| [LateUpdate](./DouyinScript/消息/DouyinScript.LateUpdate.md) | 如果启用了 Behaviour，则每帧都会调用 LateUpdate |
| [OnDisable](./DouyinScript/消息/DouyinScript.OnDisable.md) | 当行为被禁用时，将调用此函数 |
| [OnEnable](./DouyinScript/消息/DouyinScript.OnEnable.md) | 当对象变为启用和活动状态时，将调用此函数 |
| [OnCollisionEnter](./DouyinScript/消息/DouyinScript.OnCollisionEnter.md) | 当此碰撞器/刚体开始接触另一个刚体/碰撞器时，将调用 OnCollisionEnter |
| [OnCollisionExit](./DouyinScript/消息/DouyinScript.OnCollisionExit.md) | 当此碰撞器/刚体停止接触另一个刚体/碰撞器时，将调用 OnCollisionExit |
| [OnTriggerEnter](./DouyinScript/消息/DouyinScript.OnTriggerEnter.md) | 当一个 GameObject 与另一个 GameObject 碰撞时，Unity 会调用 OnTriggerEnter |
| [OnTriggerExit](./DouyinScript/消息/DouyinScript.OnTriggerExit.md) | 当 Collider 停止接触触发器时，会调用 OnTriggerExit |
| [OnNetSpawned](./DouyinScript/消息/DouyinScript.OnNetSpawned.md) | 对象的网络属性初始化之后 |
| [OnOwnershipRequest](./DouyinScript/消息/DouyinScript.OnOwnershipRequest.md) | 请求主权的事件 |
| [OnOwnershipTransferred](./DouyinScript/消息/DouyinScript.OnOwnershipTransferred.md) | 当主权转移时 |
| [OnControllershipTransferred](./DouyinScript/消息/DouyinScript.OnControllershipTransferred.md) | 当控制权转移时 |
| [OnNetDestroy](./DouyinScript/消息/DouyinScript.OnNetDestroy.md) | 网络对象销毁前触发 |
| [OnVariablesSynced](./DouyinScript/消息/DouyinScript.OnVariablesSynced.md) | 同步变量需要更新时触发 |
| [OnUIPointerDown](./DouyinScript/消息/DouyinScript.OnUIPointerDown.md) | 当指定类型的按钮被按下时触发 |
| [OnUIPointerUp](./DouyinScript/消息/DouyinScript.OnUIPointerUp.md) | 当指定类型的按钮被抬起时触发 |
| [OnUIPointerClick](./DouyinScript/消息/DouyinScript.OnUIPointerClick.md) | 当指定类型的按钮完成一次点击时触发 |
| [OnUILongPress](./DouyinScript/消息/DouyinScript.OnUILongPress.md) | 当指定类型的按钮被长按时触发 |
| [OnUIDrag](./DouyinScript/消息/DouyinScript.OnUIDrag.md) | 当指定类型的按钮被拖拽时触发 |
| [OnFocus](./DouyinScript/消息/DouyinScript.OnFocus.md) | 获得焦点对象，在交互队列的前三个对象即为焦点对象 |
| [OnLostFocus](./DouyinScript/消息/DouyinScript.OnLostFocus.md) | 丢失焦点对象 |
| [On3DTouchBegin](./DouyinScript/消息/DouyinScript.On3DTouchBegin.md) | 3D 触摸开始 |
| [On3DTouchDrag](./DouyinScript/消息/DouyinScript.On3DTouchDrag.md) | 3D 触摸拖拽 |
| [On3DTouchEnd](./DouyinScript/消息/DouyinScript.On3DTouchEnd.md) | 3D 触摸结束 |
| [On3DClick](./DouyinScript/消息/DouyinScript.On3DClick.md) | 3D 触摸点击 |
| [OnInteract](./DouyinScript/消息/DouyinScript.OnInteract.md) | 当有玩家与之交互时触发，物体上需要挂上基础交互组件，交互规则符合组件配置内容 |
| [OnDrop](./DouyinScript/消息/DouyinScript.OnDrop.md) | 当被玩家丢弃时触发，调用 API 时触发 |
| [OnTheft](./DouyinScript/消息/DouyinScript.OnTheft.md) | 当被玩家抢夺时触发，调用  API 时触发 |
| [OnPickup](./DouyinScript/消息/DouyinScript.OnPickUp.md) | 当被玩家捡起时触发，调用 API    时触发 |
| [OnRespawn](./DouyinScript/消息/DouyinScript.OnRespawn.md) | 物体重生时，目前是低于世界配置重生高度时重生 |
| [OnSeatEntered](./DouyinScript/消息/DouyinScript.OnSeatEntered.md) | 当被玩家坐下时，调用 API 时触发 |
| [OnSeatExited](./DouyinScript/消息/DouyinScript.OnSeatExited.md) | 当被玩家从座位上站起离开时，调用 API  时触发 |
| [OnActorTriggerEnter](./DouyinScript/消息/DouyinScript.OnActorTriggerEnter.md) | 当 Actor  的胶囊进入触发碰撞器时触发 |
| [OnActorTriggerExit](./DouyinScript/消息/DouyinScript.OnActorTriggerExit.md) | 当 Actor 的胶囊离开触发碰撞器时触发 |
| [OnActorCollisionEnter](./DouyinScript/消息/DouyinScript.OnActorCollisionEnter.md) | 当 Actor 的胶囊进入碰撞器时触发 |
| [OnActorCollisionExit](./DouyinScript/消息/DouyinScript.OnActorCollisionExit.md) | 当 Actor 的胶囊离开碰撞器时触发 |
| [OnPlayerJoined](./DouyinScript/消息/DouyinScript.OnPlayerJoined.md) | 当有玩家加入房间时 |
| [OnPlayerRejoined](OnPlayerRejoined) | 当有玩家断线重连时触发 |
| [OnPlayerLeft](./DouyinScript/消息/DouyinScript.OnPlayerLeft.md) | 当有玩家离开房间时 |
| [OnPlayerTriggerEnter](./DouyinScript/消息/DouyinScript.OnPlayerTriggerEnter.md) | 当玩家的胶囊进入触发碰撞器时触发 |
| [OnPlayerTriggerExit](./DouyinScript/消息/DouyinScript.OnPlayerTriggerExit.md) | 当玩家的胶囊立刻触发碰撞器时触发 |
| [OnActorSpawned](./DouyinScript/消息/DouyinScript.OnActorSpawned.md) | Actor 出生 Spawn 的事件 |
| [OnActorDespawned](./DouyinScript/消息/DouyinScript.OnActorDespawned.md) | Actor 销毁 Despawn 的事件 |
| [OnActorRespawn](./DouyinScript/消息/DouyinScript.OnActorRespawn.md) | Actor 重生 |
| [OnMouseDown](./DouyinScript/消息/DouyinScript.OnMouseDown.md) | 当用户在 Collider 上按下鼠标按钮时，将调用 OnMouseDown |
| [OnMouseDrag](./DouyinScript/消息/DouyinScript.OnMouseDrag.md) | 当用户点击 Collider 并仍然按住鼠标时，将调用 OnMouseDrag |
| [OnMouseExit](./DouyinScript/消息/DouyinScript.OnMouseExit.md) | 当鼠标不再位于 Collider 上方时调用 |
| [OnMouseEnter](./DouyinScript/消息/DouyinScript.OnMouseEnter.md) | 当鼠标进入碰撞器时调用 |
| [OnMouseOver](./DouyinScript/消息/DouyinScript.OnMouseOver.md) | 当鼠标位于碰撞器上方时，每一帧都会调用 |
| [OnMouseUp](./DouyinScript/消息/DouyinScript.OnMouseUp.md) | 当用户释放鼠标按钮时，会调用 OnMouseUp |
| [OnMouseUpAsButton](./DouyinScript/消息/DouyinScript.OnMouseUpAsButton.md) | 仅当鼠标在按下时所在的 Collider 上释放时，才会调用 OnMouseUpAsButton |
| [OnPointerClick](./DouyinScript/消息/DouyinScript.OnPointerClick.md) | 如果您希望接收 OnPointerClick 回调，则需要实现该接口 |
| [OnPointerDown](./DouyinScript/消息/DouyinScript.OnPointerDown.md) | 如果您希望接收 OnPointerDown 回调，则需要实现该接口 |
| [OnPointerEnter](./DouyinScript/消息/DouyinScript.OnPointerEnter.md) | 如果您希望接收 OnPointerEnter 回调，则需要实现该接口 |
| [OnPointerExit](./DouyinScript/消息/DouyinScript.OnPointerExit.md) | 如果您希望接收 OnPointerExit 回调，则需要实现该接口 |
| [OnPointerUp](./DouyinScript/消息/DouyinScript.OnPointerUp.md) | 如果您希望接收 OnPointerUp 回调，则需要实现该接口 |
| [OnBeginDrag](./DouyinScript/消息/DouyinScript.OnBeginDrag.md) | 如果您希望接收 OnBeginDrag 回调，则需要实现该接口 |
| [OnCancel](./DouyinScript/消息/DouyinScript.OnCancel.md) | 如果您希望接收 OnCancel 回调，则需要实现该接口 |
| [OnDrag](./DouyinScript/消息/DouyinScript.OnDrag.md) | 如果您希望接收 OnDrag 回调，则需要实现该接口 |
| [OnUnityDrop](./DouyinScript/消息/DouyinScript.OnUnityDrop.md) | 如果您希望接收 OnUnityDrop 回调，则需要实现该接口 |
| [OnEndDrag](./DouyinScript/消息/DouyinScript.OnEndDrag.md) | 如果您希望接收 OnEndDrag 回调，则需要实现该接口 |
