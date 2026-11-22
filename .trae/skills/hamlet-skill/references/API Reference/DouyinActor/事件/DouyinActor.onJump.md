public UnityEvnet onJump ＝ new();
# 描述
[Actor ](../../DouyinActor.md)跳起的事件。
# 代码示例
```Lua
local localActor

function OnActorSpawned(actor)
    if not actor or not actor.isLocal then
        return
    end
    localActor = actor

    actor.onJump:AddListener(OnJumpCallBack)
end

function OnJumpCallBack()
    print("--DouyinActor3CSample:起跳")
end
```


