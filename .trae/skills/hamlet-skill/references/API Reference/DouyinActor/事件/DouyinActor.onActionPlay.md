public UnityEvent<string> onActionPlay
# 描述
[Actor ](../../DouyinActor.md)使用动作事件，参数表情名
# 代码示例
```Lua
function OnActorSpawned(actor)
    if not actor or not actor.isLocal then
        return
    end
    actor.onActionPlay:AddListener(ActionPlayCallBack)
end

function ActionPlayCallBack(action)
    print("--DouyinActorSystemSample:action=" .. action)
end
```


