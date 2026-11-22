public UnityEvent onFlyStart ＝ new();
# 描述
[Actor ](../../DouyinActor.md)开始飞行的事件。
# 代码示例
```Lua
local localActor

function OnActorSpawned(actor)
    if not actor or not actor.isLocal then
        return
    end
    localActor = actor

    actor.onFlyStart:AddListener(OnFlyStartCallBack)
end

function OnFlyStartCallBack()
    print("--DouyinActor3CSample:开始飞行")
end
```


