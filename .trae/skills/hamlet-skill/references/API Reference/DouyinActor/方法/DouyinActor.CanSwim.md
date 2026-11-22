public bool CanSwim()
# 返回
bool
true: 可以游泳。
flase：不可以游泳。
# 描述
获取 [Actor ](../../DouyinActor.md)是否可以游泳。
# 代码示例
```Lua
local localActor

function Update()
    if localActor == nil then
        return
    end
    if Input.GetKeyDown("1") then
        CanSwimSample(localActor)
    end
end

function OnActorSpawned(actor)
    if not actor or not actor.isLocal then
        return
    end
    localActor = actor
end

function CanSwimSample(actor)
    if not actor or not actor.isLocal then
        return
    end
    local canswim = actor:CanSwim()
    print("--DouyinActor3CSample:CanSwim=" .. tostring(canswim))
end
```


