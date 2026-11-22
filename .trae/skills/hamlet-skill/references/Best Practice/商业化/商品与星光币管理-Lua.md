# 商品与星光币管理 — Lua 实践

> 本篇带你从 0 到 1 实现商品与星光币的常用能力：全量/分页拉取商品、过滤上架商品、星光币余额监听与充值跳转。

---

## 一、全量获取商品（数量 ≤ 50）

```lua
local ONLINE = 2 -- DouyinProductStatus.Online（上架）

function InitShop()
    DouyinMarketingService.GetProductInfos(function(code, info, productList)
        if code ~= 0 then
            print("获取商品列表失败：", code, info)
            return
        end

        -- 跨语言 List 需用 Count 和索引访问
        for i = 0, productList.Count - 1, 1 do
            local product = productList[i]
            -- 仅展示上架商品（过滤下架/删除/测试商品）
            if product.status == ONLINE then
                print("商品名称：" .. (product.name or "nil"))
                print("商品价格：" .. tostring(product.price))
            end
        end
    end)
end
```

## 二、分页获取商品（数量 > 50）

```lua
-- 递归拉取后续分页
local function FetchNextPage(page)
    if not page.hasMore then return end
    page:AdvanceToNextPage(function(code, info, nextPage)
        if code ~= 0 then
            print("获取分页失败：", code, info)
            return
        end
        LogPage(nextPage)
        FetchNextPage(nextPage)
    end)
end

-- 拉取首页并递归翻页
function FetchAllProducts()
    DouyinMarketingService.GetProductPage(50, function(code, info, page)
        if code ~= 0 then
            print("获取商品首页失败：", code, info)
            return
        end
        LogPage(page)
        FetchNextPage(page)
    end)
end

function LogPage(page)
    local list = page.productInfos
    for i = 0, list.Count - 1, 1 do
        local product = list[i]
        print("商品名称：" .. (product.name or "nil"))
    end
end
```

## 三、星光币：查询、监听与充值

```lua
-- StarLightUI.lua（客户端）
---@var StarLightText:UnityEngine.UI.Text
---@var RechargeBtn:UnityEngine.UI.Button
---@end

function Start()
    -- 1. 初始化显示当前星光币
    StarLightText.text = tostring(DouyinMarketingService.StarLight)

    -- 2. 监听余额变化，实时刷新 UI
    DouyinMarketingService.onStarLightChanged:AddListener(OnStarLightChanged)

    -- 3. 余额不足时拉起官方充值面板
    RechargeBtn.onClick:AddListener(function()
        DouyinMarketingService.OpenRechargePage()
    end)
end

function OnStarLightChanged(starLight)
    StarLightText.text = tostring(starLight)
end

function OnDestroy()
    -- 4. 必须移除监听
    DouyinMarketingService.onStarLightChanged:RemoveListener(OnStarLightChanged)
end
```

## 四、相关文档

- C# 版：[商品与星光币管理 - C#](商品与星光币管理-CSharp.md)
- Manual：[商品与星光币管理](../../Manual/Ⅴ.%20平台服务(Cloud%20Services)/商业化/商品与星光币管理.md)
- 交易发货：[交易与发货流程 - Lua](交易与发货流程-Lua.md)
- API Reference：[GetProductInfos](../../API%20Reference/DouyinMarketingService/方法/DouyinMarketingService.GetProductInfos.md) / [GetProductPage](../../API%20Reference/DouyinMarketingService/方法/DouyinMarketingService.GetProductPage.md) / [OpenRechargePage](../../API%20Reference/DouyinMarketingService/方法/DouyinMarketingService.OpenRechargePage.md) / [StarLight](../../API%20Reference/DouyinMarketingService/DouyinMarketingService.StarLight.md)
