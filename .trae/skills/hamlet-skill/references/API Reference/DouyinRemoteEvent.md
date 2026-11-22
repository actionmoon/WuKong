# 描述
`DouyinRemoteEvent` 对象用于在客户端与服务器之间进行异步单向通信，调用方无需等待响应。
它支持以下几种通信方式：

* 从客户端发送至服务器
* 从服务器发送至单个客户端
* 从服务器广播至所有客户端

# 公开事件
| 事件 | 描述 |
| --- | --- |
| [onClientEvent](./DouyinRemoteEvent/DouyinRemoteEvent.onClientEvent.md) | 客户端的事件：服务器调用客户端，客户端需要侦听该事件，并处理业务逻辑 |
| [onServerEvent](./DouyinRemoteEvent/DouyinRemoteEvent.onServerEvent.md) | 服务端的事件：客户端调用服务器，服务器需要侦听该事件，并处理业务逻辑 |
# 公开方法
| 方法 | 描述 |
| --- | --- |
| [FireClient](./DouyinRemoteEvent/DouyinRemoteEvent.FireClient.md) | 服务器调用指定的客户端 |
| [FireAllClients](./DouyinRemoteEvent/DouyinRemoteEvent.FireAllClients.md) | 服务器广播给所有的客户端 |
| [FireServer](./DouyinRemoteEvent/DouyinRemoteEvent.FireServer.md) | 客户端调用服务器 |
