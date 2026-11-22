public static void SetRankData(float score, string alias, Action<bool> callback)
# 描述
用于设置玩家的排行榜分数。
# 参数
| score <br>  | 数值 | 必填 | 1. 该参数用于排序，按照传入的 score 从大到小排序，score越大排名越靠前，若数字大小相同，按照写入时间从早到晚排序 <br> 2. alias参数为空时，score用于数据排序+排行榜外露展示 <br> 3. 当alias参数不为空时，score仅用于数据排序，不用作外露展示 |
| --- | --- | --- | --- |
| alias <br>  | 字符串 | 否 <br>  | 1. 该数值可以为空，当alias为空时，参考score 的排序和展示规则 <br> 2. 举例说明： <br>    1. 如传入 alias 为 “白银”，score 为 2，则“白银”的排序权重为 2，榜单的展示参数为 “白银” <br>    2. 如传入 alias 为 “黄金”，score 为 3，则“黄金”的排序权重为 3，榜单的展示参数为 “黄金” <br>  <br>   “黄金”的权重为3，高于 “白银”，届时生成的榜单上，黄金的用户数据展示在白银前面 <br>  |
| 回调 | function | 否 | 回调函数，返回接口调用成功失败等信息 |
# 代码示例
```Lua
---@var Btn_1:UnityEngine.UI.Button
---@end

function Start()
    Btn_1.onClick:AddListener(SetRankDataSample)
end

function SetRankDataSample()
    DouyinRankService.SetRankData(10, "", function (success)
        if success then
            DouyinUtility.Toast("SetRankData成功")
        else
            DouyinUtility.Toast("SetRankData失败")
        end
    end)
end
```


