public static UnityEvent<Int64> onStarLightChanged = new();
# 描述
当星光币数量发生变化时，将触发此事件
# 代码示例
```Lua
---@var StarLightText:UnityEngine.UI.Text
---@end

function Start()
    StarLightText.text = DouyinMarketingService.StarLight
    DouyinMarketingService.onStarLightChanged:AddListener(StarLightUpdate)
end

function StarLightUpdate(starLight)
    StarLightText.text = starLight
end

function OnDestroy()
    DouyinMarketingService.onStarLightChanged:RemoveListener(StarLightUpdate)
end
```


