public static void OpenRechargePage()
# 描述
打开充值页面
# 代码示例
```Lua

---@var RechargeBtn:UnityEngine.UI.Button
---@end

function Start()
    RechargeBtn.onClick:AddListener(function ()
        DouyinMarketingService.OpenRechargePage()
    end)
end
```


