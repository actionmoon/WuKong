public UnityEvent onActorLoaded ＝ new();
# 描述
当用户在世界内进行了切换[合养精灵]形象时的回调。调试器内是没有切换[合养精灵]形象的功能都，开发者可以在扫码调试阶段进行测试。
# 代码示例
```Lua
---@var logText:UnityEngine.UI.Text
---@end

function OnActorSpawned(actor)
    if not actor or not actor.isLocal then
        return
    end
    actor.onActorLoaded:AddListener(SwichActorCallBack)
end

function SwichActorCallBack(actor)
    if not actor then
        return
    end
    logText.text = string.format("--DouyinActorSystemSample:%s切换了精灵形象", actor.actorID)
    print(string.format("--DouyinActorSystemSample:%s切换了精灵形象", actor.actorID))
end
```


