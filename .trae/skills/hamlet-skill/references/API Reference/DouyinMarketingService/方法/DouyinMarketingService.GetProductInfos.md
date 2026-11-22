public static void GetProductInfos(Action<int, string, List<DouyinProductInfo>> callback)
# 描述
获取当前世界中所有已上线的开发者商品信息
# 参数
| 参数 | 参数描述 |
| --- | --- |
| callback | * 用于接收返回结果的回调函数，其参数中包含商品信息列表。 <br>    * 状态码（int）：0 表示成功，非 0 表示失败； <br>    * 错误信息（string）：状态码非 0 时返回具体错误描述； <br>    * 商品信息列表（List<DouyinProductInfo>）：包含商品 ID、名称、描述、图标、价格、状态等详细信息 |
# 代码示例
```Lua
---@var BuyBtn:UnityEngine.UI.Button
---@var ShopBtn:UnityEngine.UI.Button
---@end

function Start()
    DouyinMarketingService.onPurchaseResult:AddListener(PurchaseResultCallBack)
    
    ShopBtn.onClick:AddListener(function ()
        InitShop()
    end)
    
    BuyBtn.onClick:AddListener(function ()
        local productId = productIds[1]
        if not productId then
            DouyinUtility.Toast("请先选择商品")
            return
        end
        DouyinMarketingService.Purchase(productId, 1)
    end)
end

function InitShop()
    DouyinMarketingService.GetProductInfos(function (code, info, productList)
        if code ~= 0 then
            print("---获取商品列表失败：", code, info)
            return
        end

        for i = 0, productList.Count - 1, 1 do
            local productInfo = productList[i]
            productIds[i] = productInfo.id
            
            print("---商品 " , (i + 1) .. " 信息 ---")
            print("商品ID: " , (productInfo.id or "nil"))
            print("商品名称: " , (productInfo.name or "nil"))
            print("商品描述: " , (productInfo.desc or "nil"))
            print("商品图标URL: " , (productInfo.iconUrl or "nil"))
            print("商品价格: " , (productInfo.price or "nil"))
            print("商品状态: " , (productInfo.status or "nil"))
        end
    end)
end

function PurchaseResultCallBack(code, info, receiptInfoList)
    if not receiptInfoList or receiptInfoList.Count == 0 then
        DouyinUtility.Toast("购买失败，票据列表为空")
        print("---Purchase Failed, code: " .. code .. ", info: " .. info)
        return
    end
    if code == 0 then
        for i = 0, receiptInfoList.Count - 1, 1 do
            local receiptInfo = receiptInfoList[i]
            if receiptInfo then
                print("---Purchase Success, receiptInfo: ", receiptInfo.productId)
            else
                print("---Purchase Failed, receiptInfo is nil")
            end
        end
        DouyinUtility.Toast("购买成功")
    else
        DouyinUtility.Toast("购买失败")
        print("---Purchase Failed, code: " .. code .. ", info: " .. info)
        return
    end
end

function OnDestroy()
    DouyinMarketingService.onPurchaseResult:RemoveListener(PurchaseResultCallBack)
end
```


