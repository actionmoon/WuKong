public bool IsSwimming()
# 返回
bool
true：[Actor ](../../DouyinActor.md)当前正在游泳。
false：[Actor ](../../DouyinActor.md)当前不在游泳。
# 描述
获取 [Actor ](../../DouyinActor.md)当前是否在游泳。
# 代码示例
```Lua
local localActor

function Update()
    if localActor == nil then
        return
    end
    if Input.GetKeyDown("1") then
        IsSwimming(localActor)
    end
end

function OnActorSpawned(actor)
    if not actor or not actor.isLocal then
        return
    end
    localActor = actor
end

function IsSwimming(actor)
    if not actor or not actor.isLocal then
        return
    end
    local isSwimming = actor:IsSwimming()
    print("--DouyinActor3CSample:IsSwimming=" .. tostring(isSwimming))
end
```


