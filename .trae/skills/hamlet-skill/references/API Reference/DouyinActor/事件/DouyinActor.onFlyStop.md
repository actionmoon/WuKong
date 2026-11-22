public UnityEvent onFlyStop ＝ new();
# 描述
[Actor ](../../DouyinActor.md)结束飞行的事件。
# 代码示例
```Lua
local localActor

function OnActorSpawned(actor)
    if not actor or not actor.isLocal then
        return
    end
    localActor = actor

    actor.onFlyStop:AddListener(OnFlyStopCallBack)
end

function OnFlyStopCallBack()
    print("--DouyinActor3CSample:停止飞行")
end
```


