public static UnityEvent<int, string, List<DouyinReceiptInfo>> onPurchaseResult = new()
# 描述
客户端事件，当客户端发起购买操作后，会触发此事件并返回购买结果
# 参数
| 参数 | 参数描述 |
| --- | --- |
| int | 支付结果。0：成功，1：失败 |
| string | 支付失败信息描述 |
| List<DouyinReceiptInfo> | 支付票据信息 |
# 代码示例
```Lua
---@var BuyBtn:UnityEngine.UI.Button
---@end

function Start()
    DouyinMarketingService.onPurchaseResult:AddListener(PurchaseResultCallBack)
    
    BuyBtn.onClick:AddListener(function ()
        local productId = productIds[1]
        if not productId then
            DouyinUtility.Toast("请先选择商品")
            return
        end
        DouyinMarketingService.Purchase(productId, 1)
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


