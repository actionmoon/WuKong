public UnityEvent onHoldHandStop
# 描述
[Actor](../../DouyinActor.md)结束牵手状态时从触发该事件
AvatarHoldHandStateType.None 的时候触发该事件
# 代码示例
```Lua
function OnActorSpawned(actor)
    if not actor or not actor.isLocal then
        return
    end
    actor.onHoldHandStop:AddListener(HoldHandStopCallBack)
end

function HoldHandStopCallBack()
    print("--DouyinActorSystemSample:结束牵手")
end
```


