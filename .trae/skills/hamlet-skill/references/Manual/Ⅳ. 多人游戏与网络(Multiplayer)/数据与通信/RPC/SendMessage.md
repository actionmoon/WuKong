# SendMessage 与 [Rpc] (消息互通)

消息互通是指跨端直接互发事件指令的方式。这种方式具有更高的自由度，允许一次性传递多个参数，方便实现诸如“播放动作”、“触发特效”等一次性事件的同步。

## Lua 接口 (SendMessage)

在 Lua 中，消息互通主要通过 `DouyinScript` 提供的 `SendMessageTo*` 等接口完成：

| API | 说明 |
| --- | --- |
| `SendMessageToOwner(string method, ...)` | 向当前网络对象的主权方发送消息 |
| `SendMessageToAll(string method, ...)` | 向所有人发送消息（包括自己） |
| `SendMessageToTarget(string method, targetId, ...)` | 向特定的某个玩家客户端发送消息 |
| `SendMessageToOthers(string method, ...)` | 广播给除自己以外的所有在线玩家 |
| `SendMessageToServer(string method, ...)` | 仅发送给 DS 服务端 (DS 模式) |
| `OwnerCall(string method, onFinish, ...)` | 通知主权方，主权方 return 的结果会回传给 `onFinish` |
| `TargetCall(string method, target, onFinish, ...)`| 通知指定玩家，目标玩家 return 的结果会回传给 `onFinish` |

### 消息分派规则 (Lua)
- 发送时第一个参数 `method` 是字符串，接收端会在**同一份 DouyinScript** 中查找同名 `function`。
- 如果找不到该函数，**不会抛出异常（静默失败）**。
- 接收端的函数签名必须与发送端传递的可变参数一一对应。

### Lua 示例：通知所有人播放特效
**发送方逻辑：**
```lua
function PlayEffect()
    -- 通知所有人执行 PlayEffectRpc 方法，并传递参数
    self:SendMessageToAll("PlayEffectRpc", "FireEffect", 1.5)
end
```

**接收方逻辑（同一脚本中定义同名函数）：**
```lua
-- 自动响应收到的消息
function PlayEffectRpc(effectName, duration)
    print("收到播放特效通知:", effectName, duration)
    -- 执行播放特效的逻辑
end
```

## C# 接口 ([Rpc])

在 C# 中，跨端通信不使用 SendMessage，而是采用强类型的特性标注方式。发送目标统一通过 `[Rpc(SendTo.X)]` 特性进行控制。
注意：网络对象必须挂载 `NetworkObject` 组件，C# 脚本必须继承 `NetworkBehaviour`。

### 消息分派规则 (C#)
C# 不使用字符串，而是**编译期方法引用**。IL 编织在编译期为该调用生成 SDK 注册与转发代码，方法名拼错会导致**编译错误**。
必须**同时满足**以下两个硬性要求，否则调用将退化为普通本地函数调用，没有网络效果：
1. **特性标注**：方法上方必须添加 `[Rpc(SendTo.XXX)]` 特性。
2. **方法名强制约束**：方法名称**必须以 `Rpc` 结尾**（例如 `PlayEffectRpc`）。

### SendTo 目标选项与特殊参数
- `SendTo.Everyone`：所有人（包括发送方自己）。
- `SendTo.NotMe`：除发送方自己外的所有人。
- `SendTo.Owner`：仅发送给该对象的主权方（等价于 Lua 的 `ToOwner`）。
- `SendTo.NotOwner`：除主权方外的所有人。
  > 💡 **`NotMe` vs `NotOwner` 的区别**：如果调用方本身就是主权方，两者行为一致；如果调用方不是主权方，`NotOwner` 会跳过主权方而 `NotMe` 只跳过自己。
- `SendTo.Server`：仅发送给 DS 服务端。
- `SendTo.Client`：仅发送给 DS 客户端。
- `SendTo.SpecifiedInParams`：精确指定目标。
  > ⚠️ **强制要求**：使用此选项时，方法的参数列表必须包含一个 `RpcTarget` 参数，调用时传入如 `RpcTarget.Single(clientId)` 或 `RpcTarget.Group(clientIds)`。漏写会导致编译报错或运行时异常。

**获取发送方信息**：若要在接收端方法内知道“是谁调用了我”，可以在方法参数末尾添加可选的 `RpcParams rpcParams = default`，通过 `rpcParams.SenderClientId` 识别。

### C# 示例：定义与调用 RPC
```csharp
using Douyin.Netcode;
using UnityEngine;

public class MyNetworkScript : NetworkBehaviour
{
    // 定义一个向所有人广播的 RPC
    [Rpc(SendTo.Everyone)]
    public void PlayEffectRpc(string effectName, float duration, RpcParams rpcParams = default)
    {
        Debug.Log($"来自 {rpcParams.SenderClientId} 的播放特效通知: {effectName} {duration}");
    }

    private void Update()
    {
        if (condition) {
            // 直接像调用普通方法一样调用 RPC
            PlayEffectRpc("FireEffect", 1.5f);
        }
    }
}
```

### C# 侧如何替代 Lua 的 OwnerCall？
C# 侧没有类似 `OwnerCall` 的“带回调”变体（即 `[Rpc]` 只有单向语义）。非主权方如果想让主权方执行逻辑并拿回结果，推荐做法是：
**用 `[Rpc(SendTo.Owner)]` 触发请求，主权方处理后将结果写入 `NetworkVariable<T>`，发起方通过监听 `OnValueChanged` 获取结果**。这也比 Lua 的 `OwnerCall` 更可靠。

## 注意事项 (Lua/CSharp开发通用规则)

- **支持的参数类型**：RPC 参数必须是基础数据类型（`int`, `float`, `string`, `bool`, `Vector3` 等）。
- **严禁在 RPC 参数中传递复杂的 `table` (Lua) 或 `class` 对象与泛型 `List` (C#)**，否则会发生静默丢包。
- **不可靠性**：RPC 底层基于 UDP，存在丢包可能且**不保证送达**，新进房间的玩家也收不到之前发过的消息。如需强一致性请使用同步变量。
- **网络就绪前置**：如果 `isNetworkSettled` 还未变为 `true`，发出的 RPC 会被系统静默丢弃。

## 常见坑点与避坑指南 (FAQ)

### 坑 1：`Awake / Start` 中直接调用静默失败
**现象**：脚本 `Start` 里立刻 `SendMessageToAll` / `SendToEveryoneRpc`，其他玩家没收到。
**原因**：`Start` 触发时网络环境未必就绪。
**修复**：所有网络 API 调用前必须查 `DouyinNetService.isNetworkSettled`。推荐将首次发起的时机放在 `OnNetworkSpawn` 之后。

### 坑 2：C# 侧忘写 `Rpc` 后缀或漏写 `[Rpc]` 特性
**现象**：方法定义看着一样，但调用后接收端从来没执行。
**原因**：任一缺失都不会被 IL 识别为 RPC，调用退化为普通本地方法。
**修复**：严格遵守 `[Rpc(SendTo.xxx)] void XxxRpc(...)` 的命名规范。

### 坑 3：传了 `List<T>` / `table` / 自定义 class
**现象**：Lua 端接收到 `nil`，C# 端接收到 `null` 或抛出序列化异常。
**原因**：RPC 参数仅支持基础类型 + Unity 值类型（C#）。
**修复**：用多个基础类型参数分开传，或序列化为 JSON 字符串。

### 坑 4：`SendTo.Everyone` / `SendMessageToAll` 后本地立刻读出旧值
**现象**：广播消息，消息内部修改了状态，本地紧接着读取发现是旧值。
**原因**：广播是异步的，本地也要等网络消息回环才会执行。
**修复**：如果需要本地立刻响应，请拆分为：先直接调用本地函数处理，然后使用 `SendTo.NotMe` / `SendMessageToOthers` 通知其他人。

### 坑 5：SharedMode 下使用了 `SendTo.Server`
**现象**：调用后无任何网络效果。
**原因**：`SendTo.Server / SendTo.Client` 只在 DS 模式下生效。
**修复**：SharedMode 下请使用 `SendTo.Owner / Everyone / NotMe` 等。
