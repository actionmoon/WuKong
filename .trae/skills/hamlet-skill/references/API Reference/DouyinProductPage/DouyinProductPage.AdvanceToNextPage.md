public void AdvanceToNextPage(Action<int, string, DouyinProductPage> callback)
# 描述
获取下一页的商品数据
# 参数
| 参数 | 参数描述 |
| --- | --- |
| callback | * `callback`：结果回调 <br>       * 返回状态码：0 成功，非0 失败 <br>       * 错误信息：返回状态码非0时的错误信息描述 <br>       * 返回首页商品分页数据对象`DouyinProductPage` |
# 代码示例
```Lua
---@var TestBtn:UnityEngine.UI.Button
---@end

function Start()
    TestBtn.onClick:AddListener(function ()
        GetProductPageTest()
    end)
end

function GetProductPageTest()
    local index = 0
    DouyinMarketingService.GetProductPage(5, function (code, info, pages)
        if code ~= 0 then
            print("---获取商品列表失败：", code, info)
            return
        end

        LogProductPage(pages, index + 1)
        if pages.hasMore then
            index = index + 1
            pages:AdvanceToNextPage(function (code, info, nextPage)
                if code ~= 0 then
                    print("---获取商品列表失败：", code, info)
                    return
                end
                LogProductPage(nextPage, index)
            end)
        end
    end)
end

function LogProductPage(pages, index)
    print("---商品页信息 " , index .. " 信息 ---")
    print("商品页的起始索引: " , (pages.pageOffset or "nil"))
    print("商品页的页面大小: " , (pages.pageSize or "nil"))
    print("商品页的商品数量: " , (pages.totalSize or "nil"))
    print("查询时间: " , (pages.queryTime or "nil"))
    local productList = pages.productInfos
    for i = 0, productList.Count - 1, 1 do
        local productInfo = productList[i]
        print("---商品 " , (i + 1) .. " 信息 ---")
        print("商品ID: " , (productInfo.id or "nil"))
        print("商品名称: " , (productInfo.name or "nil"))
        print("商品描述: " , (productInfo.desc or "nil"))
        print("商品图标URL: " , (productInfo.iconUrl or "nil"))
        print("商品价格: " , (productInfo.price or "nil"))
        print("商品状态: " , (productInfo.status or "nil"))
    end
end
```


