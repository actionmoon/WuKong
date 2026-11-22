# 描述
DouyinObjectService 是一个静态类，主要用于管理 DouyinObjectService 实例。
提供网络对象操作相关功能。
# 静态方法
| [NetSpawn](./DouyinObjectService/DouyinObjectService.NetSpawn.md)（重载方法） | 动态生成网络对象 |
| --- | --- |
| [NetDestroy](./DouyinObjectService/DouyinObjectService.NetDestroy.md) | 可以销毁所有的网络对象，只有主权方可以销毁物体； <br> autoRequest 代表是否自动请求主权 |
| [GetDouyinObject](./DouyinObjectService/DouyinObjectService.GetDouyinObject.md) | 通过objectID获取对应的DouyinObject对象 |
| ServerSpawn（重载方法） | 在服务器端动态生成网络对象，该对象不会同步到客户端。 |

