public Vector3 velocity
# 描述
获取或设置当前 [Actor ](../../DouyinActor.md)的移动方向和速度。
# 代码示例
```Lua
local localActor

function Update()
    if localActor == nil then
        return
    end
    if Input.GetKeyDown("1") then
        ActorVelocitySample(localActor)
    end
end

function OnActorSpawned(actor)
    if not actor or not actor.isLocal then
        return
    end
    localActor = actor
end

function ActorVelocitySample(actor)
    if not actor or not actor.isLocal then
        return
    end
    local curVelocity = actor.velocity
    print(string.format("--DouyinActor3CSample:curVelocity=((%f,%f,%f))", curVelocity.x, curVelocity.y, curVelocity.z))
    local newVelocity = Vector3(curVelocity.x, curVelocity.y, curVelocity.z * 10)
    actor.velocity = newVelocity
    print(string.format("--DouyinActor3CSample:curVelocity=((%f,%f,%f))", newVelocity.x, newVelocity.y, newVelocity.z))
end
```


