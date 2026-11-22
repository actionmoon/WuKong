public float flySpeed。
# 描述
获取或设置当前 [Actor ](../../DouyinActor.md)的水平飞行速度。
# 代码示例
```Lua
local localActor

function Update()
    if localActor == nil then
        return
    end
    if Input.GetKeyDown("1") then
        ActorFlySpeedSample(localActor)
    end
end

function OnActorSpawned(actor)
    if not actor or not actor.isLocal then
        return
    end
    localActor = actor
end

function ActorFlySpeedSample(actor)
    if not actor or not actor.isLocal then
        return
    end
    print("--DouyinActor3CSample:flySpeed=" .. actor.flySpeed)
    actor.flySpeed = 5
end
```


