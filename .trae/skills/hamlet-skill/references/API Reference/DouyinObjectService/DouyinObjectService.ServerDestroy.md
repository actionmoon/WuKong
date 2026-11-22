public static void ServerDestroy(GameObject go,bool autoRequest = false)
# 参数
| 参数 | 参数描述 |
| --- | --- |
| go | 要销毁的 unity 游戏对象 |
| autoRequest | true：自动请求主权 <br> false：不自动请求主权 <br> 默认为 false |
# 描述
服务器销毁网络对象，该函数只能在服务器端执行
# 代码示例
```Lua
local Vector3 = UnityEngine.Vector3
local Quaternion = UnityEngine.Quaternion
local Input = UnityEngine.Input
local serverObjs = {}

function Start()
    if JudgeIsServer() then
        ServerCreateNetObj_1()
        ServerCreateNetObj_2()
        ServerCreateNetObj_3()
        ServerCreateNetObj_4()
    end
end

function Update()
    if Input.GetKeyDown("1") then
        ServerDestroyNetObjs()
    end
end

function JudgeIsServer()
    local isServer = DouyinApplication.isServer
    print("---isServer: " .. tostring(isServer))
    return isServer
end

function ServerCreateNetObj_1()
    local netObj, netObjId = DouyinObjectService.ServerSpawn("NetObj_1", function (netObj, netObjId)
        print("---DSApiTest: DS ServerCreateNetObj_1 Success, netObj: " .. netObj.name)
        table.insert(serverObjs, netObj)
    end)
end

function ServerCreateNetObj_2()
    local netObj, netObjId = DouyinObjectService.ServerSpawn("NetObj_1", Vector3(1, 0, 0), function (netObj, netObjId)
        print("---DSApiTest: DS ServerCreateNetObj_1 Success, netObj: " .. netObj.name)
        table.insert(serverObjs, netObj)
    end)
end

function ServerCreateNetObj_3()
    local netObj, netObjId = DouyinObjectService.ServerSpawn("NetObj_1", Vector3(2, 0, 0), Vector3(45, 45, 45), function (netObj, netObjId)
        print("---DSApiTest: DS ServerCreateNetObj_1 Success, netObj: " .. netObj.name)
        table.insert(serverObjs, netObj)
    end)
end

function ServerCreateNetObj_4()
    local netObj, netObjId = DouyinObjectService.ServerSpawn("NetObj_1", Vector3(3, 0, 0), Quaternion.identity, function (netObj, netObjId)
        print("---DSApiTest: DS ServerCreateNetObj_1 Success, netObj: " .. netObj.name)
        table.insert(serverObjs, netObj)
    end)
end

function ServerDestroyNetObjs()
    for i = #serverObjs, 1, -1 do
        local netObj = serverObjs[i]
        DouyinObjectService.ServerDestroy(netObj)
        table.remove(serverObjs, i)
    end
end
```


