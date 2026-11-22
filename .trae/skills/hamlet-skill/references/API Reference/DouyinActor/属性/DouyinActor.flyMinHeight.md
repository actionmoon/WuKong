public float flyMinHeight
# 描述
获取或设置当前 [Actor ](../../DouyinActor.md)的最小飞行高度。
# 代码示例
```Lua
local localActor

function Update()
    if localActor == nil then
        return
    end
    if Input.GetKeyDown("1") then
        ActorflyMinHeightSample(localActor)
    end
end

function OnActorSpawned(actor)
    if not actor or not actor.isLocal then
        return
    end
    localActor = actor
end

function ActorflyMinHeightSample(actor)
    if not actor or not actor.isLocal then
        return
    end
    print("--DouyinActor3CSample:flyMinHeight=" .. actor.flyMinHeight)
    actor.flyMinHeight = 5
end
```


