public UnityEvent onHoldHandStart
# 描述
[Actor](../../DouyinActor.md)进入牵手状态触发该事件
# 代码示例
```Lua
function OnActorSpawned(actor)
    if not actor or not actor.isLocal then
        return
    end
    actor.onHoldHandStart:AddListener(HoldHandStartCallBack)
end

function HoldHandStartCallBack()
    print("--DouyinActorSystemSample:开始牵手")
end
```


