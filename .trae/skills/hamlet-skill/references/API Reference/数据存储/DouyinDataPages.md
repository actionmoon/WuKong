# 描述
这项服务提供了一个 API，用于访问和分页版本列表和排序数据。
# 公开属性
| 属性 | 类型 | 描述 |
| --- | --- | --- |
| pageIndex | int | 当前页码 |
| pageCount | int | 最大页码 |
| isFinished | boolean | 指定这是否是最后一页 |
# 公开方法
| 方法 | 描述 |
| --- | --- |
| [GetCurrentPage](./DouyinDataPages/DouyinDataPages.GetCurrentPage.md) | 获取当前页面的所有数据。返回的数据以表格形式保存，表格中数据的具体类型取决于DouyinDataPages 实例的来源。 |
| [GetPageByIndex](./DouyinDataPages/DouyinDataPages.GetPageByIndex.md) | 获取指定页面的所有数据。返回的数据以表格形式保存，表格中数据的具体类型取决于DouyinDataPages 实例的来源。 |
| [AdvanceToNextPage](./DouyinDataPages/DouyinDataPages.AdvanceToNextPage.md) | 转至下一页 |
