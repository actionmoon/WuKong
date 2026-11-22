public float flyVerticalSpeed
# 描述
获取或设置当前 [Actor ](../../DouyinActor.md)的垂直飞行速度。
# 代码示例
```Lua
local localActor

function Update()
    if localActor == nil then
        return
    end
    if Input.GetKeyDown("1") then
        ActorflyVerticalSpeedSample(localActor)
    end
end

function OnActorSpawned(actor)
    if not actor or not actor.isLocal then
        return
    end
    localActor = actor
end

function ActorflyVerticalSpeedSample(actor)
    if not actor or not actor.isLocal then
        return
    end
    print("--DouyinActor3CSample:flyVerticalSpeed=" .. actor.flyVerticalSpeed)
    actor.flyVerticalSpeed = 10
end
```


