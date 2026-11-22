public static void Purchase(string productId, int productNum, string orderData)
# 描述
发起一次购买请求，用于购买指定数量的特定商品。
在调用DouyinMarketingService.Purchase方法之前，需要先调用一次DouyinMarketingService.GetProductInfos()或DouyinMarketingService.GetProductInfo()方法先获取对应的商品信息，否则会出现购买失败/无法调起购买等情况。

# 参数
| 参数 | 参数描述 |
| --- | --- |
| productId | 要购买的商品 Id。 |
| productNum | 要购买的商品数量。 |
| orderData | 创作者的自定义数据。购买成功后，该数据将通过 `DouyinReceiptInfo` 原样返回。 |
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


