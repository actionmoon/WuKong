# 交易与发货流程 — Lua 实践

> 本篇带你从 0 到 1 跑通交易全链路：客户端购买 → DS 服务端监听扣款 → 幂等发货落库 → 确认订单 / 补单。发货落库依赖 [自定义数据库管理系统 - Lua](../数据库/自定义数据库管理系统-Lua.md)。

---

## 一、客户端：发起购买

客户端负责获取商品、拉起支付、展示结果。**购买前必须先获取一次商品信息并缓存。**

```lua
-- ClientShop.lua（客户端）
---@var BuyBtn:UnityEngine.UI.Button
---@end

local productIds = {}

function Start()
    -- 1. 监听购买结果
    DouyinMarketingService.onPurchaseResult:AddListener(OnPurchaseResult)

    -- 2. 必须先获取商品信息并缓存
    DouyinMarketingService.GetProductInfos(function(code, info, productList)
        if code ~= 0 then
            print("获取商品列表失败：", code, info)
            return
        end
        for i = 0, productList.Count - 1, 1 do
            productIds[i] = productList[i].id
        end
    end)

    BuyBtn.onClick:AddListener(OnBuyClicked)
end

function OnBuyClicked()
    local productId = productIds[0]
    if not productId then
        DouyinUtility.Toast("请先选择商品")
        return
    end
    -- 3. 发起购买：商品ID, 数量, 自定义透传数据(orderData)
    DouyinMarketingService.Purchase(productId, 1, "custom_order_data")
end

-- 购买结果：code=0 成功（此时订单一般为 Paid 待发货），非 0 失败
function OnPurchaseResult(code, info, receiptInfoList)
    if not receiptInfoList or receiptInfoList.Count == 0 then
        DouyinUtility.Toast("购买失败，票据列表为空")
        return
    end
    if code == 0 then
        for i = 0, receiptInfoList.Count - 1, 1 do
            local receipt = receiptInfoList[i]
            if receipt then
                print("购买成功，商品ID：", receipt.productId)
            end
        end
        DouyinUtility.Toast("购买成功")
    else
        DouyinUtility.Toast("购买失败：" .. info)
    end
end

function OnDestroy()
    DouyinMarketingService.onPurchaseResult:RemoveListener(OnPurchaseResult)
end
```

## 二、DS 服务端：幂等发货

**该脚本必须挂载到带 `DouyinServerRoot` 组件的节点下（发货落库只能在服务端，客户端易受弱网/闪退丢单）。** 服务端监听 `onOrderPayment`，以 `purchaseOrder` 为主键查库判重后再发货，最后 `ConfirmOrder` 回执。发货需在约 2 秒内完成并回执，否则会被判定超时进入补单队列。

```lua
-- ServerDelivery.lua（DS 服务端，挂在 DouyinServerRoot 节点下）
function Start()
    -- 监听扣款成功事件（含补单时的重复触发）
    DouyinMarketingService.onOrderPayment:AddListener(OnOrderPayment)
end

function OnOrderPayment(sequenceId, receiptInfo)
    local orderId  = receiptInfo.purchaseOrder   -- 全网唯一订单号，幂等主键
    local openId   = receiptInfo.playerOpenId
    local productId = receiptInfo.productId
    local num       = receiptInfo.productNum

    -- 以 "player_"+openId 作 Scope，用订单号做幂等标记
    DATASTORE(function()
        local scope = "player_" .. openId
        local code, store = DouyinDataService.GetDataStore("orders", scope, false)
        if code ~= 0 then
            -- 读取 store 失败：回执 code>0 触发补单，下次重试
            DouyinMarketingService.ConfirmOrder(sequenceId, receiptInfo, 1)
            return
        end

        -- 1. 幂等判重：订单已处理则直接回执成功，不重复发货
        local rCode, delivered = store:GetData(orderId)
        if rCode == 0 and delivered ~= nil then
            DouyinMarketingService.ConfirmOrder(sequenceId, receiptInfo, 0)
            return
        end

        -- 2. 执行发货（示例：给玩家背包发放商品，此处按业务写库）
        local ok = DeliverGoods(store, openId, productId, num)

        -- 3. 写入幂等标记并回执
        if ok then
            store:SetData(orderId, 1)                 -- 标记该订单已发货
            DouyinMarketingService.ConfirmOrder(sequenceId, receiptInfo, 0)  -- 发货成功
        else
            DouyinMarketingService.ConfirmOrder(sequenceId, receiptInfo, 1)  -- 失败，触发补单
        end
    end)
end

-- 业务发货逻辑：写入玩家数据，返回是否成功
function DeliverGoods(store, openId, productId, num)
    local code = store:IncrementData(productId, num)  -- 示例：按商品ID累加持有数量
    return code == 0
end

function OnDestroy()
    -- 监听务必移除，避免悬挂回调
    DouyinMarketingService.onOrderPayment:RemoveListener(OnOrderPayment)
end
```

## 三、客户端：手动补单

在玩家数据完全加载完成后，主动拉取遗漏订单（平台会对未发货订单重新抛出 `onOrderPayment`）：

```lua
-- 数据加载完毕后安全触发补单
function OnPlayerDataLoadComplete()
    DouyinMarketingService.BackOrder()
end
```

## 四、相关文档

- C# 版：[交易与发货流程 - C#](交易与发货流程-CSharp.md)
- Manual：[交易与发货流程](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/商业化/交易与发货流程.md)
- 发货落库：[自定义数据库管理系统 - Lua](../数据库/自定义数据库管理系统-Lua.md) / [用户维度数据存储方式 - Lua](../数据库/数据存储方式/用户维度数据存储方式-Lua.md)
- 落库规范：[编码约束与开发规范](../../Manual/Ⅲ.%20逻辑与脚本%28Logic%26Scripting%29/编码约束与开发规范/数据库开发约束.md)
- API Reference：[Purchase](../../API%20Reference/DouyinMarketingService/方法/DouyinMarketingService.Purchase.md) / [ConfirmOrder](../../API%20Reference/DouyinMarketingService/方法/DouyinMarketingService.ConfirmOrder.md) / [BackOrder](../../API%20Reference/DouyinMarketingService/方法/DouyinMarketingService.BackOrder.md) / [onOrderPayment](../../API%20Reference/DouyinMarketingService/事件/DouyinMarketingService.onOrderPayment.md)
