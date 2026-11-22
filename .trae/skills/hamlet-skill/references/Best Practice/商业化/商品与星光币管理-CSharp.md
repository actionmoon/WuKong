# 商品与星光币管理 — C# 实践

> 本篇带你从 0 到 1 实现商品与星光币的 C# 回调式能力：全量/分页拉取商品、过滤上架商品、星光币余额监听与充值跳转。C# 侧接口为静态类回调形态（`code==0` 成功），商品状态枚举见 [数据结构参考](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/商业化/数据结构参考.md)。

---

## 一、全量获取商品（数量 ≤ 50）

```csharp
using System.Collections.Generic;

public class ShopSample
{
    public void InitShop()
    {
        DouyinMarketingService.GetProductInfos((code, info, productList) =>
        {
            if (code != 0)
            {
                CommonDebug.LogError($"获取商品列表失败 code={code} info={info}");
                return;
            }

            foreach (var product in productList)
            {
                // 仅展示上架商品（过滤下架/删除/测试商品）
                if (product.status == DouyinProductStatus.Online)
                {
                    CommonDebug.Log($"商品名称：{product.name}，价格：{product.price}");
                }
            }
        });
    }
}
```

## 二、分页获取商品（数量 > 50）

```csharp
public class ShopPagingSample
{
    public void FetchAllProducts()
    {
        DouyinMarketingService.GetProductPage(50, (code, info, page) =>
        {
            if (code != 0)
            {
                CommonDebug.LogError($"获取商品首页失败 code={code} info={info}");
                return;
            }
            LogPage(page);
            FetchNextPage(page);
        });
    }

    private void FetchNextPage(DouyinProductPage page)
    {
        if (!page.hasMore) return;
        page.AdvanceToNextPage((code, info, nextPage) =>
        {
            if (code != 0)
            {
                CommonDebug.LogError($"获取分页失败 code={code} info={info}");
                return;
            }
            LogPage(nextPage);
            FetchNextPage(nextPage);
        });
    }

    private void LogPage(DouyinProductPage page)
    {
        foreach (var product in page.productInfos)
            CommonDebug.Log($"商品名称：{product.name}");
    }
}
```

## 三、星光币：查询、监听与充值

```csharp
using UnityEngine.UI;

public class StarLightUI
{
    public Text starLightText;
    public Button rechargeBtn;

    public void Start()
    {
        // 1. 初始化显示当前星光币
        starLightText.text = DouyinMarketingService.StarLight.ToString();

        // 2. 监听余额变化，实时刷新 UI
        DouyinMarketingService.onStarLightChanged.AddListener(OnStarLightChanged);

        // 3. 余额不足时拉起官方充值面板
        rechargeBtn.onClick.AddListener(() => DouyinMarketingService.OpenRechargePage());
    }

    private void OnStarLightChanged(long starLight)
    {
        starLightText.text = starLight.ToString();
    }

    public void OnDestroy()
    {
        // 4. 必须移除监听
        DouyinMarketingService.onStarLightChanged.RemoveListener(OnStarLightChanged);
    }
}
```

## 四、相关文档

- Lua 版：[商品与星光币管理 - Lua](商品与星光币管理-Lua.md)
- Manual：[商品与星光币管理](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/商业化/商品与星光币管理.md)
- 交易发货：[交易与发货流程 - C#](交易与发货流程-CSharp.md)
- API Reference：[GetProductInfos](../../API%20Reference/DouyinMarketingService/方法/DouyinMarketingService.GetProductInfos.md) / [GetProductPage](../../API%20Reference/DouyinMarketingService/方法/DouyinMarketingService.GetProductPage.md) / [OpenRechargePage](../../API%20Reference/DouyinMarketingService/方法/DouyinMarketingService.OpenRechargePage.md) / [StarLight](../../API%20Reference/DouyinMarketingService/DouyinMarketingService.StarLight.md)
