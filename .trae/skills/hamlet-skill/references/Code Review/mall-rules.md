---
title: MALL 规则速查
scope: Hamlet 代码硬红线检查
applies-to: lua, csharp
language: any
project-usage: reference
last-synced: 2026-07-15
---

# MALL 规则速查 — 商业化 / 商品与订单

严重等级：🔴 禁止 · 🟠 强烈不建议 · 🟡 警告

> ⚠️ `ReceiptInfo.productId` 服务端收到时**一定是 string**，即使客户端传入 int；对比/取值前统一 `tostring(...)`。

---

## MALL-001 GetProductInfos 必须在进房完成后（🔴）

**判据**：`Awake / Start` 中调用 `DouyinMarketingService.GetProductInfos` 等商品接口；进房未完成时返回空或直接失败。

```lua
-- ❌
function Start()
    DouyinMarketingService.GetProductInfos(ids, callback)
end

-- ✅
function OnNetworkSettled()
    DouyinMarketingService.GetProductInfos(ids, callback)
end
```

---

## MALL-002 先持久化再确认订单（🔴）

**判据**：`onOrderPayment` 回调中，必须**先** `store:SetData` 落库成功，**再**调 `ConfirmOrder(sequenceId, receiptInfo, 0)`。顺序颠倒会出现「已确认但未发货」，玩家掉单无法追回。

```lua
-- ❌ 先确认后发货
DouyinMarketingService.ConfirmOrder(seqId, receiptInfo, 0)
store:SetData("coins", newCoins)  -- 若这里失败，钱已扣、货未发

-- ✅ 先发货后确认
local ok = store:SetData("coins", newCoins)
if ok then
    DouyinMarketingService.ConfirmOrder(seqId, receiptInfo, 0)
end
```

---

## MALL-003 客户端禁止执行发货逻辑（🔴）

**判据**：客户端代码里出现 `onOrderPayment` 监听或 `ConfirmOrder` 调用。发货必须由 DS 服务端执行。

Shared 模式**不允许**发放具备经济价值的资产（见 SHR-001）。

---

## MALL-004 发货必须幂等（🔴）

**判据**：以 `receiptInfo.purchaseOrder` 作为幂等键；同一订单重入必须命中已发货记录并**跳过**再次发货，且 `ConfirmOrder` 返回 code 一旦为 0，后续同订单必须继续返回 0。

```lua
-- ✅ 幂等发货
local orderKey = receiptInfo.purchaseOrder
local ok, delivered = store:GetData("order_" .. orderKey)
if ok and delivered == "1" then
    DouyinMarketingService.ConfirmOrder(seqId, receiptInfo, 0)
    return
end
-- 首次发货
if DeliverGoods(receiptInfo) then
    store:SetData("order_" .. orderKey, "1")
    DouyinMarketingService.ConfirmOrder(seqId, receiptInfo, 0)
end
```

---

## MALL-005 购买回调必须双重校验（🟡）

**判据**：`onPurchaseResult` 中必须同时校验：
- `code == 0`（业务成功）
- `orderStatus == 3`（Paid）；`2`=Timeout、`5`=Failed 需按失败处理
- 商品展示前需校验 `product.status == 2`（Online），下架商品不得挂到 UI 上

```lua
-- ✅
function OnPurchaseResult(code, receiptInfo, orderStatus)
    if code ~= 0 or orderStatus ~= 3 then
        ShowToast("购买失败，请稍后重试")
        return
    end
    -- 成功流程
end
```
