# 描述
 该类提供了商业化相关的接口，可用于获取商品信息、购买商品等操作。
# 静态事件
| 事件 | 描述 |
| --- | --- |
| onPurchaseResult | 这是一个客户端事件。当客户端发起购买操作后，会触发此事件并返回购买结果 |
| onOrderPayment | 这是一个服务器事件。当支付成功后，您需要监听此事件来完成发货 |
| onStarLightChanged | 当星光币数量发生变化时，将触发此事件 |
# 静态方法
| 方法 | 描述 |
| --- | --- |
| OpenRechargePage | 打开充值页面 |
| GetProductInfos | 获取当前世界中所有已上线的开发者商品信息 |
| GetProductInfo | 获取指定商品的信息 |
| Purchase | 购买指定商品ID和数量的商品 |
| ConfirmOrder | 服务器函数，通知平台发货结果 |
| GetProductPage | 该接口用于获取商品分页的首页数据，并返回`DouyinProductPage` |
| BackOrder | 该函数用于在客户端手动触发补单。建议您在用户登录且数据加载完成后调用 |
