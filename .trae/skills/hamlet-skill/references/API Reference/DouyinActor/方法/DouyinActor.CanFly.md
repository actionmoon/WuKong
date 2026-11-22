public bool CanFly()
# 返回
bool
true: 可以飞行。
false: 不可以飞行。
# 描述
获取 [Actor ](../../DouyinActor.md)是否可以飞行。
# 代码示例
```Lua
local localActor

function Update()
    if localActor == nil then
        return
    end
    if Input.GetKeyDown("1") then
        CanFlySample(localActor)
    end
end

function OnActorSpawned(actor)
    if not actor or not actor.isLocal then
        return
    end
    localActor = actor
end

function CanFlySample(actor)
    if not actor or not actor.isLocal then
        return
    end
    local canfly = actor:CanFly()
    print("--DouyinActor3CSample:CanFly=" .. tostring(canfly))
    actor.flyVerticalSpeed = 10
end
```


