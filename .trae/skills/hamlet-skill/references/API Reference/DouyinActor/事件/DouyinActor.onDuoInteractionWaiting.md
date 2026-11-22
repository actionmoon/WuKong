public UnityEvent<DouyinActor.ActorInteractionType, string, int> onDuoInteractionWaiting
# 描述
[Actor ](../../DouyinActor.md)开始等待播放双人动作事件，参数动作ID，动作名，发起双人交互方的ActorID
# 代码示例
```Lua
function OnActorSpawned(actor)
    if not actor or not actor.isLocal then
        return
    end
    actor.onDuoInteractionWaiting:AddListener(OnDuoInteractionWaitingCallBack)
end

function OnDuoInteractionWaitingCallBack(actionId, actionName, actorID1)
    print(string.format("--DouyinActorSystemSample:%d等待播放%s动作，动作Id是%s", actorID1, actionName,
        tostring(actionId)))
end
```

