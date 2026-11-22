public UnityEvent<DouyinActor.ActorInteractionType, string, int, int> onDuoInteractionEnd
# 描述
[Actor ](../../DouyinActor.md)结束播放双人动作事件，参数动作ID，动作名，双人交互的Actor ID
# 代码示例
```Lua
function OnActorSpawned(actor)
    if not actor or not actor.isLocal then
        return
    end
    actor.onDuoInteractionEnd:AddListener(OnDuoInteractiontStopCallBack)
end

function OnDuoInteractiontStopCallBack(actionId, actionName, actorID1, actorID2)
    print(string.format("--DouyinActorSystemSample:%d和%d停止了%s动作，动作Id是%s", actorID1, actorID2, actionName,
        tostring(actionId)))
end
```


