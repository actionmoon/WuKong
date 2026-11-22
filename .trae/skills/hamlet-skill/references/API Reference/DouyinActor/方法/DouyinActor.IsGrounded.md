public bool IsGrounded()
# 返回
bool
true：当前 [Actor ](../../DouyinActor.md)处于地面。
false：当前 [Actor ](../../DouyinActor.md)不在地面。
# 描述
获取当前 [Actor ](../../DouyinActor.md)是否在地面。
# 代码示例
```Lua
local localActor

function Update()
    if localActor == nil then
        return
    end
    if Input.GetKeyDown("1") then
        ActorIsGrounded(localActor)
    end
end

function OnActorSpawned(actor)
    if not actor or not actor.isLocal then
        return
    end
    localActor = actor
end

function ActorIsGrounded(actor)
    if not actor or not actor.isLocal then
        return
    end
    local isGround = actor:IsGrounded()
    print("--DouyinActor3CSample:IsGrounded=" .. tostring(isGround))
end
```


