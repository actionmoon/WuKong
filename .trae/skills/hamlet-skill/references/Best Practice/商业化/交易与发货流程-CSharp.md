# 交易与发货流程 — C# 实践

> 本篇带你从 0 到 1 跑通交易全链路的 C# 回调式实现：客户端购买 → DS 服务端监听扣款 → 幂等发货落库 → 确认订单 / 补单。C# 侧**无 `async/await`**，一律用回调 + `code` / `res.Code` 判断结果。发货落库依赖 [自定义数据库管理系统 - C#](../数据库/自定义数据库管理系统-CSharp.md)。

---

## 一、客户端：发起购买

```csharp
using System.Collections.Generic;

// 客户端购买脚本
public class ClientShop
{
    private readonly List<string> _productIds = new List<string>();

    public void Start()
    {
        // 1. 监听购买结果
        DouyinMarketingService.onPurchaseResult.AddListener(OnPurchaseResult);

        // 2. 必须先获取商品信息并缓存
        DouyinMarketingService.GetProductInfos((code, info, productList) =>
        {
            if (code != 0)
            {
                CommonDebug.LogError($"获取商品列表失败 code={code} info={info}");
                return;
            }
            foreach (var product in productList)
                _productIds.Add(product.id);
        });
    }

    public void OnBuyClicked()
    {
        if (_productIds.Count == 0)
        {
            DouyinUtility.Toast("请先选择商品");
            return;
        }
        // 3. 发起购买：商品ID, 数量, 自定义透传数据(orderData)
        DouyinMarketingService.Purchase(_productIds[0], 1, "custom_order_data");
    }

    // 购买结果：code=0 成功（订单一般为 Paid 待发货），非 0 失败
    private void OnPurchaseResult(int code, string info, List<DouyinReceiptInfo> receiptInfoList)
    {
        if (receiptInfoList == null || receiptInfoList.Count == 0)
        {
            DouyinUtility.Toast("购买失败，票据列表为空");
            return;
        }
        if (code == 0)
        {
            foreach (var receipt in receiptInfoList)
                if (receipt != null)
                    CommonDebug.Log($"购买成功，商品ID：{receipt.productId}");
            DouyinUtility.Toast("购买成功");
        }
        else
        {
            DouyinUtility.Toast($"购买失败：{info}");
        }
    }

    public void OnDestroy()
    {
        DouyinMarketingService.onPurchaseResult.RemoveListener(OnPurchaseResult);
    }
}
```

## 二、DS 服务端：幂等发货

**该脚本必须挂载到带 `DouyinServerRoot` 组件的节点下（发货落库只能在服务端）。** 以 `purchaseOrder` 为主键查库判重后再发货，最后 `ConfirmOrder` 回执。发货需在约 2 秒内完成并回执，否则会被判定超时进入补单队列。

```csharp
// DS 服务端发货脚本（挂在 DouyinServerRoot 节点下）
public class ServerDelivery
{
    private const string OrderStore = "orders";

    public void Start()
    {
        // 监听扣款成功事件（含补单时的重复触发）
        DouyinMarketingService.onOrderPayment.AddListener(OnOrderPayment);
    }

    private void OnOrderPayment(string sequenceId, DouyinReceiptInfo receiptInfo)
    {
        string orderId   = receiptInfo.purchaseOrder;  // 全网唯一订单号，幂等主键
        string openId    = receiptInfo.playerOpenId;
        string productId = receiptInfo.productId;
        int    num       = receiptInfo.productNum;
        string scope     = "player_" + openId;

        DouyinDataStoreService.GetDataStore(OrderStore, scope, storeRes =>
        {
            if (storeRes.Code != 0)
            {
                // 读取 store 失败：回执 code>0 触发补单
                DouyinMarketingService.ConfirmOrder(sequenceId, receiptInfo, 1);
                return;
            }

            var store = storeRes.Store;

            // 1. 幂等判重：订单已处理则直接回执成功
            store.Get(orderId, getRes =>
            {
                bool alreadyDelivered = getRes.Code == 0; // 已存在标记
                if (alreadyDelivered)
                {
                    DouyinMarketingService.ConfirmOrder(sequenceId, receiptInfo, 0);
                    return;
                }

                // 2. 执行发货：给玩家累加商品持有数量（示例）
                store.Increment(productId, num, null, incRes =>
                {
                    if (incRes.Code != 0)
                    {
                        DouyinMarketingService.ConfirmOrder(sequenceId, receiptInfo, 1); // 失败，补单
                        return;
                    }

                    // 3. 写入幂等标记，成功后回执 code=0
                    store.Set(orderId, "1", null, setRes =>
                    {
                        int code = setRes.Code == 0 ? 0 : 1;
                        DouyinMarketingService.ConfirmOrder(sequenceId, receiptInfo, code);
                    });
                });
            });
        });
    }

    public void OnDestroy()
    {
        // 监听务必移除，避免悬挂回调
        DouyinMarketingService.onOrderPayment.RemoveListener(OnOrderPayment);
    }
}
```

## 三、客户端：手动补单

```csharp
// 玩家数据加载完毕后安全触发补单
public void OnPlayerDataLoadComplete()
{
    DouyinMarketingService.BackOrder();
}
```

## 四、相关文档

- Lua 版：[交易与发货流程 - Lua](交易与发货流程-Lua.md)
- Manual：[交易与发货流程](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/商业化/交易与发货流程.md)
- 发货落库：[自定义数据库管理系统 - C#](../数据库/自定义数据库管理系统-CSharp.md) / [用户维度数据存储方式 - C#](../数据库/数据存储方式/用户维度数据存储方式-CSharp.md)
- 落库规范：[编码约束与开发规范](../../Manual/Ⅲ.%20逻辑与脚本%28Logic%26Scripting%29/编码约束与开发规范/数据库开发约束.md)
- API Reference：[Purchase](../../API%20Reference/DouyinMarketingService/方法/DouyinMarketingService.Purchase.md) / [ConfirmOrder](../../API%20Reference/DouyinMarketingService/方法/DouyinMarketingService.ConfirmOrder.md) / [BackOrder](../../API%20Reference/DouyinMarketingService/方法/DouyinMarketingService.BackOrder.md) / [onOrderPayment](../../API%20Reference/DouyinMarketingService/事件/DouyinMarketingService.onOrderPayment.md)
