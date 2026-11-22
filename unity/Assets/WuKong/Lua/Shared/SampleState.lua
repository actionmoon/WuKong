---@varSync revision:int
---@varSync contextCount:int
---@end

local request = nil
local response = nil
local spawned = false
local contexts = {}
local nextContext = 0

function Start()
    request = DouyinRemoteEvent(WKSampleConfig.requestChannel)
    response = DouyinRemoteEvent(WKSampleConfig.responseChannel)
    if DouyinApplication.isServer then
        request.onServerEvent:AddListener(OnRequest)
    else
        response.onClientEvent:AddListener(OnResponse)
    end
    print("[WK-SAMPLE] state-start server=" .. tostring(DouyinApplication.isServer))
end

function OnNetSpawned()
    spawned = true
    revision:OnValueChange(function(cur, prev)
        print("[WK-SAMPLE] revision " .. tostring(prev) .. " -> " .. tostring(cur))
        RefreshStatus()
    end)
    contextCount:OnValueChange(function(cur, prev)
        print("[WK-SAMPLE] contexts " .. tostring(prev) .. " -> " .. tostring(cur))
        RefreshStatus()
    end)
    print("[WK-SAMPLE] net-spawned revision=" .. tostring(revision:GetValue()))
end

function RefreshStatus()
    if DouyinApplication.isServer or not spawned then return end
    local go = UnityEngine.GameObject.Find("SampleStatus")
    if go then
        local label = go:GetComponent(typeof(UnityEngine.UI.Text))
        label.text = "悟空 · 资源与联机样例\n挑战上下文：" .. tostring(contextCount:GetValue())
            .. "  同步版本：" .. tostring(revision:GetValue()) .. "\n按 P 验证客户端 → DS → 双端同步"
    end
end

function RequestProbe()
    if DouyinApplication.isServer or not spawned or not DouyinNetService.isNetworkSettled then return end
    print("[WK-SAMPLE] request-sent")
    request:FireServer("probe")
end

function OnRequest(player, ...)
    local args = { ... }
    if player == nil or player.isServer or #args == 0 then return end
    if not spawned or not DouyinNetService.isNetworkSettled or not self:HasOwnership() then return end
    print("[WK-SAMPLE] request-received type=" .. type(args[1]) .. " command=" .. tostring(args[1]))
    if args[1] ~= "probe" then return end
    local key = player.playerOpenID
    if contexts[key] == nil then
        nextContext = nextContext + 1
        contexts[key] = { id = nextContext, hp = WKSampleConfig.initialHp }
        contextCount:SetValue(nextContext)
        print("[WK-SAMPLE] context-created id=" .. tostring(nextContext) .. " hp=390")
    end
    local value = revision:GetValue() + 1
    revision:SetValue(value)
    print("[WK-SAMPLE] request-processed context=" .. tostring(contexts[key].id) .. " revision=" .. tostring(value))
    response:FireAllClients(value)
end

function OnResponse(value)
    print("[WK-SAMPLE] response-received revision=" .. tostring(value))
end

function Update()
    if not DouyinApplication.isServer and spawned and DouyinNetService.isNetworkSettled then
        RefreshStatus()
        if UnityEngine.Input.GetKeyDown("p") then RequestProbe() end
    end
end

function OnNetDestroy()
    spawned = false
end

function OnDestroy()
    if request then
        if DouyinApplication.isServer then request.onServerEvent:RemoveListener(OnRequest) end
        request:Dispose()
        request = nil
    end
    if response then
        if not DouyinApplication.isServer then response.onClientEvent:RemoveListener(OnResponse) end
        response:Dispose()
        response = nil
    end
end
