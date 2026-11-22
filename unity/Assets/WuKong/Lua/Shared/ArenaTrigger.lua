local inside = {}

function OnActorTriggerEnter(actor)
    if actor == nil or inside[actor.actorID] then return end
    inside[actor.actorID] = true
    print("[WK-ARENA] fight-box-enter actor=" .. tostring(actor.actorID)
        .. " server=" .. tostring(DouyinApplication.isServer) .. " position=" .. tostring(actor.position))
    if not DouyinApplication.isServer and actor.isLocal then
        local go = UnityEngine.GameObject.Find("ArenaStatus")
        if go then go:GetComponent(typeof(UnityEngine.UI.Text)).text = "血池 · 虎先锋" end
    end
end

function OnActorTriggerExit(actor)
    if actor == nil then return end
    inside[actor.actorID] = nil
    print("[WK-ARENA] fight-box-exit actor=" .. tostring(actor.actorID)
        .. " server=" .. tostring(DouyinApplication.isServer))
end

function OnActorDespawned(actor)
    if actor then inside[actor.actorID] = nil end
end

function OnDestroy()
    inside = {}
end
