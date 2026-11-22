public UnityEvent<DouyinActor.ActorInteractionType, string, int, int> onDuoInteractionStart
# 描述
[Actor ](../../DouyinActor.md)开始播放双人动作事件，参数动作ID，动作名，双人交互的ActorID
# 代码示例
```Lua
function OnActorSpawned(actor)
    if not actor or not actor.isLocal then
        return
    end
    actor.onDuoInteractionStart:AddListener(OnDuoInteractionStartCallBack)
end

function OnDuoInteractionStartCallBack(actionId, actionName, actorID1, actorID2)
    print(string.format("--DouyinActorSystemSample:%d和%d播放了%s动作，动作Id是%s", actorID1, actorID2, actionName,
        tostring(actionId)))
end
```


