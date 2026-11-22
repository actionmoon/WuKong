public static DouyinOrderPaymentEvent onOrderPayment = new()
# 描述
这是一个服务器事件。当支付成功后，您需要监听此事件来完成发货
# 参数
| 参数 | 参数描述 |
| --- | --- |
| string | 订单查询序列号，同一个订单如果没有完成发货，会涉及补单查询，同一个订单每次查询的序列号不同。 |
| DouyinReceiptInfo | 订单票据信息，包含订单状态、用户 OpenID、商品 ID、交易数量等详细信息。 |
# 代码示例
这是一段 DS 服务器代码，您需要将其放置在挂载了 `DouyinServerRoot` 脚本的节点下。
```Lua
function Start()
    -- DS服务器监听用户支付事件，用户支付成功，平台会向DS服务器发送此事件
    DouyinMarketingService.onOrderPayment:AddListener(OnOrderPaymentCallBack)
end

function OnOrderPaymentCallBack(sequenceId, receiptInfo)
    -- 用户支付成功
    -- TODO 验证票据信息，完成发货，通知平台发货结果
    local code = 0 -- code = 0 表示发货成功，code = 1 表示发货失败需要补单
    -- DS服务器通知平台发货结果，平台收到ConfirmOrder，会通知客户端购买结果
    DouyinMarketingService.ConfirmOrder(sequenceId, receiptInfo, code)
end

function OnDestroy()
    DouyinMarketingService.onOrderPayment:RemoveListener(OnOrderPaymentCallBack)
end
```


