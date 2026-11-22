# 重载 1
public static GameObject ServerSpawn(string key, out int id, Action<GameObject, int> onSpawn = null)
## 参数
| 参数 | 参数描述 |
| --- | --- |
| key | 通过 prefab 创建的网络对象的 prefab 资源名称 |
| id | 生成的网络对象的唯一标识符 |
| onSpawn | 生成网络对象的回调函数 |
## 返回
GameObject
生成的网络对象。
## 描述
服务器动态生成网络对象，该函数只能在服务器端执行。注意：<span style="color: #D83931">生成的网络对象仅存在于服务器，不会同步到客户端。</span>
## 代码示例
```Lua
local Vector3 = UnityEngine.Vector3
local Quaternion = UnityEngine.Quaternion
local serverObjs = {}

function Start()
    if JudgeIsServer() then
        ServerCreateNetObj_1()
    end
end

function ServerCreateNetObj_1()
    local netObj, netObjId = DouyinObjectService.ServerSpawn("NetObj_1", function (netObj, netObjId)
        print("---DSApiTest: DS ServerCreateNetObj_1 Success, netObj: " .. netObj.name)
        table.insert(serverObjs, netObj)
    end)
end
```

# 重载 2
public static GameObject ServerSpawn(string key, Vector3 position, out int id, Action<GameObject, int> onSpawn = null)
## 参数
| 参数 | 参数描述 |
| --- | --- |
| key | 通过 prefab 创建的网络对象的 prefab 资源名称 |
| position | 指定要生成的网络对象的坐标 |
| id | 生成的网络对象的唯一标识符 |
| onSpawn | 生成网络对象的回调函数 |
## 返回
GameObject
生成的网络对象。
## 描述
服务器动态生成特定坐标位置的网络对象，该函数只能在服务器端执行。<span style="color: #D83931">注意：生成的网络对象仅存在于服务器，不会同步到客户端。</span>
## 代码示例
```Lua
local Vector3 = UnityEngine.Vector3
local Quaternion = UnityEngine.Quaternion
local serverObjs = {}

function Start()
    if JudgeIsServer() then
        ServerCreateNetObj_2()
    end
end

function ServerCreateNetObj_2()
    local netObj, netObjId = DouyinObjectService.ServerSpawn("NetObj_1", Vector3(1, 0, 0), function (netObj, netObjId)
        print("---DSApiTest: DS ServerCreateNetObj_1 Success, netObj: " .. netObj.name)
        table.insert(serverObjs, netObj)
    end)
end
```

# 重载 3
public static GameObject ServerSpawn(string key, Vector3 position, Vector3 rotation, out int id, Action<GameObject, int> onSpawn = null)
## 参数
| 参数 | 参数描述 |
| --- | --- |
| key | 通过 prefab 创建的网络对象的 prefab 资源名称 |
| position | 指定要生成的网络对象的坐标 |
| rotation | 指定要生成的网络对象的旋转 |
| id | 生成的网络对象的唯一标识符 |
| onSpawn | 生成网络对象的回调函数 |
## 返回
GameObject
生成的网络对象。
## 描述
服务器动态生成特定坐标位置，旋转的网络对象，该函数只能在服务器端执行。<span style="color: #D83931">注意：生成的网络对象仅存在于服务器，不会同步到客户端。</span>
```Lua
local Vector3 = UnityEngine.Vector3
local Quaternion = UnityEngine.Quaternion
local serverObjs = {}

function Start()
    if JudgeIsServer() then
        ServerCreateNetObj_3()
    end
end

function ServerCreateNetObj_3()
    local netObj, netObjId = DouyinObjectService.ServerSpawn("NetObj_1", Vector3(2, 0, 0), Vector3(45, 45, 45), function (netObj, netObjId)
        print("---DSApiTest: DS ServerCreateNetObj_1 Success, netObj: " .. netObj.name)
        table.insert(serverObjs, netObj)
    end)
end
```

# 重载 4
public static GameObject ServerSpawn(string key, Vector3 position, Quaternion rotation, out int id, Action<GameObject, int> onSpawn = null)
## 参数
| 参数 | 参数描述 |
| --- | --- |
| key | 通过 prefab 创建的网络对象的 prefab 资源名称 |
| position | 指定要生成的网络对象的坐标 |
| rotation | 指定要生成的网络对象的旋转 |
| id | 生成的网络对象的唯一标识符 |
| onSpawn | 生成网络对象的回调函数 |
## 返回
GameObject
生成的网络对象。
## 描述
服务器动态生成特定坐标位置，旋转的网络对象，该函数只能在服务器端执行。<span style="color: #D83931">注意：生成的网络对象仅存在于服务器，不会同步到客户端。</span>
## 代码示例
```Lua
local Vector3 = UnityEngine.Vector3
local Quaternion = UnityEngine.Quaternion
local serverObjs = {}

function Start()
    if JudgeIsServer() then
        ServerCreateNetObj_4()
    end
end

function ServerCreateNetObj_4()
    local netObj, netObjId = DouyinObjectService.ServerSpawn("NetObj_1", Vector3(3, 0, 0), Quaternion.identity, function (netObj, netObjId)
        print("---DSApiTest: DS ServerCreateNetObj_1 Success, netObj: " .. netObj.name)
        table.insert(serverObjs, netObj)
    end)
end
```


