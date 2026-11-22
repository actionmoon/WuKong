public static Int64 StarLight
# 描述
当前用户的星光币。
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


