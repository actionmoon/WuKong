public void EnableFly()
# 描述
开启飞行/悬浮
# 代码示例
```Lua
local localActor

function Update()
    if localActor == nil then
        return
    end
    if Input.GetKeyDown("1") then
        EnableFlySample(localActor)
    end
end

function OnActorSpawned(actor)
    if not actor or not actor.isLocal then
        return
    end
    localActor = actor
end

function EnableFlySample(actor)
    if not actor or not actor.isLocal then
        return
    end
    actor:EnableFly()
    print("--DouyinActor3CSample:EnableFly")
end
```


