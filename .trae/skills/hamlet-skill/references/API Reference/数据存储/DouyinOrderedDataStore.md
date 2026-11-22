# 描述
这种对象为持久化数据提供统一的 API。只能存储数值数据，不支持元数据或历史版本数据。
# 公开方法
| 方法 | 描述 |
| --- | --- |
| [GetData](./DouyinOrdededDataStore/DouyinOrderedDataStore.GetData.md) | 获取数据。如果键存在，也会返回DouyinOrderedDataInfo |
| [SetData](./DouyinOrdededDataStore/DouyinOrderedDataStore.SetData.md) | 设置数据。如果操作成功，也会返回DouyinOrderedDataInfo |
| [IncrementData](./DouyinOrdededDataStore/DouyinOrderedDataStore.IncrementData.md) | 递增与键对应的值，并返回新的值 |
| [UpdateData](./DouyinOrdededDataStore/DouyinOrderedDataStore.UpdateData.md) | 通过回调函数更新与键对应的数据。回调函数获取当前值，并根据定义的逻辑返回新值。回调函数一旦执行，便不能暂停。 |
| [RemoveData](./DouyinOrdededDataStore/DouyinOrderedDataStore.RemoveData.md) | 删除与键对应的数据。 |
| [GetSortedData](./DouyinOrdededDataStore/DouyinOrderedDataStore.GetSortedData.md) | 按顺序获取数据。 |
