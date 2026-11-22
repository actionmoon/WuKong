public static void GetProductInfo(string productId, Action<int, string, DouyinProductInfo> callback)
# 描述
获取指定商品的信息
# 参数
| 参数 | 参数描述 |
| --- | --- |
| productId | 要查询的商品 Id。 |
| callback | 用于接收返回结果的回调函数，其参数中包含商品信息列表。 |
# 代码示例
```Lua
---@var GetBtn:UnityEngine.UI.Button
---@end

-- Start is called before the first frame update
function Start()
    GetBtn.onClick:AddListener(function ()
        DouyinMarketingService.GetProductInfo("462950401026", function (code, info, productInfo)
            if code ~= 0 then
                print("---获取商品详情失败：", code, info)
                return
            end
            if productInfo then
                -- 安全地输出C#对象信息
                print("---获取商品详情成功：")
                print("  商品ID:", productInfo.id or "nil")
                print("  商品名称:", productInfo.name or "nil")
                print("  商品描述:", productInfo.desc or "nil")
                print("  商品价格:", productInfo.price or "nil")
                print("  商品状态:", productInfo.status or "nil")
                print("  图标URL:", productInfo.iconUrl or "nil")
            end
        end)
    end)
end
```


