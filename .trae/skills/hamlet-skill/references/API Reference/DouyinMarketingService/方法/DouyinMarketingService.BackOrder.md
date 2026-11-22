public static void BackOrder()
# 描述
该函数用于在客户端手动触发补单。建议您在用户登录且数据加载完成后调用。
# 代码示例
```Lua
function OnPlayerDataLoadComplete()
    DouyinMarketingService.BackOrder()
end
```


