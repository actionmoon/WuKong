public static void ConfirmOrder(string sequenceId, DouyinReceiptInfo receiptInfo, int code)
# 描述
服务器函数，通知平台发货结果。
# 参数
| 参数 | 参数描述 |
| --- | --- |
| sequenceId | 订单查询序列号，同一个订单如果没有完成发货，会涉及补单查询，同一个订单每次查询的序列号不同。 |
| receiptInfo | 订单票据信息，包含订单状态、用户 OpenID、商品 ID、交易数量等详细信息。 |
| code | 通知平台订单的发货状态。 <br>  <br> * `code = 0`：表示发货成功，平台将标记订单为已发货状态； <br> * `code > 0`：表示发货失败，平台将触发补单机制； <br> * `code < 0`：表示发货失败且需退款，平台将直接执行退款流程； |
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
    -- DS服务器通知平台发货结果，平台收到ConfirmOrder后，会通知客户端购买结果
    DouyinMarketingService.ConfirmOrder(sequenceId, receiptInfo, code)
end

function OnDestroy()
    DouyinMarketingService.onOrderPayment:RemoveListener(OnOrderPaymentCallBack)
end
```


