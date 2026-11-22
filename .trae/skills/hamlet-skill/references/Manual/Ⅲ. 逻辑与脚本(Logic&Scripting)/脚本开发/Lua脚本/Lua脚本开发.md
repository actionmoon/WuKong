# Lua 脚本开发

在抖音虚拟世界中，使用 Lua 脚本（当前支持 Lua 5.3 版本）可以非常便捷地实现各种交互逻辑。平台已经将绝大多数的 `UnityEngine` API 映射至 Lua 环境中，让习惯于使用 Unity API 的开发者能无缝过渡。

## 一、 Lua 脚本的创建与挂载

> **适用范围**：当 [hamlet-preferences.md](../../../../../hamlet-preferences.md) 中 `DevTool=UnityEditor` 时阅读。
> `DevTool` 的详细说明请参考[开发工具概述](../../../VI.%20开发工具/开发工具概述.md)。

### 1. 创建 Lua 脚本
1. 在 Unity 编辑器的 `Assets` 文件夹内，通过右键菜单选择 **Create -> Douyin -> Lua script**。
2. 默认生成的脚本名为 `LuaScript`，可根据具体的业务逻辑对其进行重命名（例如：`MyScript`）。

### 2. 挂载 Lua 脚本
与 C# 原生的 `MonoBehaviour` 不同，Lua 脚本**不能直接拖拽挂载到场景对象上**。
1. 在目标 GameObject 上添加 **Douyin Script** 组件，该组件充当运行 Lua 脚本的容器。
2. 将刚才创建的 Lua 脚本拖入 `Douyin Script` 组件的脚本文件属性框中，或者点击圆形按钮进行搜索选择。
3. **注意**：不建议对挂载 Lua 脚本的对象执行 `SetActive(false)` 操作，如果需要隐藏物体，可将 Lua 脚本挂载到空父节点上，去控制其子节点的显隐。

## 二、 在 Lua 中调用 Unity API

抖音虚拟世界通过表（Table）结构模拟了 C# 的命名空间（Namespace），你可以像在 C# 中一样调用对应的接口。

### 1. 静态方法与属性的调用
带有 `static` 标记的 C# 静态函数或静态属性，在 Lua 中使用 **点号 `.`** 进行调用。
```lua
function Start()
    -- 调用 C# 静态方法
    local objFinded = UnityEngine.GameObject.Find("ObjectName")
    
    -- 访问 C# 静态属性
    if DouyinNetService.isNetworkSettled then
        print("Network is settled")
    end
end
```

### 2. 成员方法的调用
调用对象实例的成员函数时，**必须使用冒号 `:`** 进行调用。
```lua
function Start()
    local objFinded = UnityEngine.GameObject.Find("ObjectName")
    if objFinded then
        -- 使用冒号调用成员方法
        print(string.format("Instance ID: %d", objFinded:GetInstanceID()))
    end
end
```

### 3. 创建对象与添加组件
可以使用 `()` 来模拟 C# 的 `new` 操作符，并通过 `typeof` 获取类型信息。
```lua
-- 为了简化代码，可提前局部缓存命名空间
local GameObject = UnityEngine.GameObject
local Button = UnityEngine.UI.Button

function Start()
    -- 相当于 C# 的 new UnityEngine.GameObject("buttonObj")
    local obj = GameObject("buttonObj")
    
    -- 给对象添加组件
    local buttonInst = obj:AddComponent(typeof(Button))
    buttonInst.onClick:AddListener(function()
        print("Button Clicked!")
    end)
end
```

### 4. C# 数组的遍历
C# 导出的数组在 Lua 中**索引从 0 开始**，且包含 `Length` 属性。
```lua
local GameObject = UnityEngine.GameObject

function Awake()
    local objs = GameObject.FindGameObjectsWithTag("Actor")
    -- 注意：C# 数组在 Lua 中的遍历必须是从 0 到 Length - 1
    for i = 0, objs.Length - 1 do
        print("obj id: ", objs[i]:GetInstanceID())
    end
end
```

## 三、 进阶开发技巧

### 1. `self` 与 `script` 的区别与使用
在编写 Lua 脚本时，常会混淆 `self` 和 `script` 的概念：
- **`self`**：指向当前挂载的 `DouyinScript` C# 组件实例。
  - 获取物体：`self.gameObject`
  - 获取主权：`self:HasOwnership()`
  - 启动协程：`self:StartCoroutine()`
- **`script`**：指向该 `DouyinScript` 容器中引用的**Lua 脚本逻辑对象**。

### 2. 脚本间的调用
如果需要在 A 脚本中调用 B 脚本的非 local 方法，必须通过 `script` 关键字。
```lua
---@var myScript:DouyinScript
function Start()
    -- 注意使用的是点号，不是冒号
    myScript.script.Func() 
end
```
如果在同一个 GameObject 上挂载了多个 Lua 脚本，可以通过名字获取：
```lua
local bScript = self:GetDouyinScript("BScriptName")
if bScript then
    bScript.script.Func()
end
```

### 3. 支持使用 xlua 协程
你可以搭配 `xlua.util` 使用 Unity 引擎的协程及 `WaitForSeconds` 等延时方法：
```lua
local util = require('xlua.util')
local UE = UnityEngine

function Start()
    local action = util.cs_generator(function(second)
        for i = 1, 10, 1 do
            coroutine.yield(UE.WaitForSeconds(second))
            print("Coroutine tick: " .. i)
        end
    end, 1) -- 这里的 1 会传给匿名函数的 second 参数
    
    -- 通过 self 启动协程
    self:StartCoroutine(action)
end
```
