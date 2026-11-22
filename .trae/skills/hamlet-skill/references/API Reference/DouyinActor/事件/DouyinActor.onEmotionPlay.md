public UnityEvent<string> onEmotionPlay
# 描述
[Actor ](../../DouyinActor.md)使用表情事件，参数表情名
# 代码示例
```Lua
function OnActorSpawned(actor)
    if not actor or not actor.isLocal then
        return
    end
    actor.onEmotionPlay:AddListener(PlayEmojiCallBack)
end

function PlayEmojiCallBack(emotion)
    print("--DouyinActorSystemSample:emotion=" .. emotion)
end
```


