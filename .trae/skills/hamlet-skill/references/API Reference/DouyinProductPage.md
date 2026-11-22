# 描述
用于存储商品的分页数据。
# 公开属性
| 属性 | 描述 |
| --- | --- |
| pageOffset | 当前商品页的起始索引 |
| pageSize | 当前商品页的页面大小 |
| totalSize | 当前所有商品的数量 |
| queryTime | 查询时间 |
| hasMore | 是否还有更多的商品信息 |
| productInfos | 当前页面的所有的商品信息 |
# 公开方法
| 方法 | 描述 |
| --- | --- |
| AdvanceToNextPage | 获取下一页的商品数据 |
