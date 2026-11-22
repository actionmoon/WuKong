# 描述
`DouyinRemoteFunction` 对象用于在客户端与服务器之间进行双向通信。您可以为 `DouyinRemoteFunction.onClientInvoke` 或 `DouyinRemoteFunction.onServerInvoke` 事件设置回调函数，来处理来自另一方的调用请求。
# 公开事件
| 事件 | 描述 |
| --- | --- |
| [onClientInvoke](./DouyinRemoteFunction/DouyinRemoteFunction.onClientInvoke.md) | 客户端的事件：服务器调用客户端，客户端需要侦听该事件，处理业务逻辑并返回结果 |
| [onServerInvoke](./DouyinRemoteFunction/DouyinRemoteFunction.onServerInvoke.md) | 服务端的事件：客户端调用服务器，服务器需要侦听该事件，处理业务逻辑并返回结果 |
# 公开方法
| 方法 | 描述 |
| --- | --- |
| [InvokeServer](./DouyinRemoteFunction/DouyinRemoteFunction.InvokeServer.md) | 客户端调用服务器，并处理服务器的响应 |
| [InvokeClient](./DouyinRemoteFunction/DouyinRemoteFunction.InvokeClient.md) | 服务器调用指定的客户端， 并处理客户端响应 |
