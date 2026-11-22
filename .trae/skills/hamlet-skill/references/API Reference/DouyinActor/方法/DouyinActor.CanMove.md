public bool CanMove()
# 返回
bool
true: 可以移动。
false: 不能移动。
# 描述
判断当前 [Actor ](../../DouyinActor.md)是否可以移动。
# 代码示例
```Lua
local localActor

function Update()
    if localActor == nil then
        return
    end
    if Input.GetKeyDown("1") then
        ActorCanMoveSample(localActor)
    end
end

function OnActorSpawned(actor)
    if not actor or not actor.isLocal then
        return
    end
    localActor = actor
end

function ActorCanMoveSample(actor)
    if not actor or not actor.isLocal then
        return
    end
    local canMove = actor:CanMove()
    print("--DouyinActor3CSample:CanMove=" .. tostring(canMove))
end
```


