local UE = UnityEngine
local actor = nil
local boss = nil
local marker = nil
local locked = false
local initialized = false
local looking = false
local lastLookTime = -math.huge
local onLookStart = nil
local onLookPerform = nil
local onLookCancel = nil
local savedYaw = nil
local savedPitch = nil
local savedFov = nil
local freePitch = nil
local elapsed = 0
local nextSample = 0
local routeIndex = nil
local routeAge = 0
local routeStepAge = 0
local lastRoutePosition = nil
local routeProgressAge = 0
local poll = 0
local currentDistance = nil
local orbitProbe = 0

local function setView(distance)
    local cfg = WKArenaConfig.camera
    DouyinCameraService.SetDistance(distance)
    DouyinCameraService.SetOffset(UE.Vector3(0, cfg.height, 0))
end

function Start()
    if DouyinApplication.isServer then return end
    boss = UE.GameObject.Find("TigerBaseline")
    local canvas = UE.GameObject.Find("ArenaHUD")
    if canvas then
        local labels = canvas:GetComponentsInChildren(typeof(UE.UI.Text), true)
        for i = 0, labels.Length - 1 do
            if labels[i].gameObject.name == "LockMarker" then marker = labels[i] end
        end
    end
    onLookStart = function()
        looking = true; lastLookTime = UE.Time.time
        print("[WK-ARENA] look-start")
    end
    onLookPerform = function() looking = true; lastLookTime = UE.Time.time end
    onLookCancel = function()
        looking = false; lastLookTime = UE.Time.time
        print("[WK-ARENA] look-cancel")
    end
    DouyinInputService.onLookInputStart:AddListener(onLookStart)
    DouyinInputService.onLookInputPerform:AddListener(onLookPerform)
    DouyinInputService.onLookInputCancel:AddListener(onLookCancel)
    print("[WK-ARENA] presentation-start")
end

function OnActorSpawned(value)
    if value ~= nil and value.isLocal then actor = value end
end

local function stopRoute(reason)
    if actor ~= nil then actor:StopMove() end
    print("[WK-ARENA] route-stop reason=" .. reason .. " position=" .. tostring(actor and actor.position))
    routeIndex = nil
end

-- Manual diagnostic entry: T starts one uninterrupted traversal; Y cancels; G resets to spawn.
function StartRoute()
    if actor == nil or not actor.isLocal then return end
    routeIndex = 1; routeAge = 0; routeStepAge = 0; routeProgressAge = 0
    lastRoutePosition = actor.position
    locked = false
    print("[WK-ARENA] route-start position=" .. tostring(actor.position))
end

local function updateRoute(dt)
    if routeIndex == nil then return end
    routeAge = routeAge + dt; routeStepAge = routeStepAge + dt; routeProgressAge = routeProgressAge + dt
    local waypoint = WKArenaConfig.route[routeIndex]
    local p = actor.position
    local dx, dz = waypoint.x - p.x, waypoint.z - p.z
    local distance = math.sqrt(dx * dx + dz * dz)
    if distance < 0.7 then
        print("[WK-ARENA] route-waypoint " .. waypoint.name .. " position=" .. tostring(p) .. " age=" .. tostring(routeAge))
        routeIndex = routeIndex + 1; routeStepAge = 0
        if WKArenaConfig.route[routeIndex] == nil then stopRoute("completed"); return end
    elseif routeStepAge > 20 then
        stopRoute("waypoint-timeout-" .. waypoint.name); return
    else
        -- The installed SDK consumes world X/Z, confirmed with both 0° and 180° camera yaw.
        actor.speed=WKArenaConfig.routeSpeed or 6.5
        actor:MoveContinuously(UE.Vector2(dx / distance, dz / distance))
    end
    if routeProgressAge >= 2 then
        print("[WK-ARENA] route-progress position=" .. tostring(p) .. " moved="
            .. tostring(UE.Vector3.Distance(lastRoutePosition, p)))
        lastRoutePosition = p; routeProgressAge = 0
    end
end

function Update()
    if DouyinApplication.isServer or not DouyinNetService.isNetworkSettled then return end
    local dt = UE.Time.deltaTime
    if actor == nil then
        poll = poll + dt
        if poll < 0.5 then return end
        poll = 0
        local actors = DouyinActorService.GetActors()
        if actors ~= nil then for i = 0, actors.Length - 1 do if actors[i].isLocal then actor = actors[i] end end end
        if actor == nil then return end
    end
    elapsed = elapsed + dt
    if UE.Input.GetKeyDown(UE.KeyCode.Q) or UE.Input.GetMouseButtonDown(2) then
        locked = not locked
        if locked then freePitch = DouyinCameraService.GetPitch()
        elseif freePitch ~= nil then DouyinCameraService.SetPitch(freePitch) end
        print("[WK-ARENA] lock=" .. tostring(locked))
    end
    if UE.Input.GetKeyDown(UE.KeyCode.T) then StartRoute() end
    if UE.Input.GetKeyDown(UE.KeyCode.Y) then stopRoute("manual") end
    if UE.Input.GetKeyDown(UE.KeyCode.G) then
        stopRoute("reset")
        local s = WKArenaConfig.spawn
        actor:Teleport(UE.Vector3(s.x, s.y, s.z), UE.Quaternion.Euler(0, s.yaw, 0))
    end
    -- Deterministic camera-only probe for debugger input and obstruction checks.
    if UE.Input.GetKeyDown(UE.KeyCode.U) then
        orbitProbe = (orbitProbe + 1) % 4
        locked = false
        DouyinCameraService.SetYaw(orbitProbe * 90)
        DouyinCameraService.SetPitch(WKArenaConfig.camera.pitch)
        print("[WK-ARENA] orbit-probe yaw=" .. tostring(orbitProbe * 90))
    end
    updateRoute(dt)
end

function getCameraAlignTargetYaw()
    if not locked or actor == nil or boss == nil then return nil end
    local delta = boss.transform.position - actor.position
    return UE.Mathf.Atan2(delta.x, delta.z) * UE.Mathf.Rad2Deg
end

function getCameraAlignSpeedScale()
    return locked and 1 or 0
end

function IsLocked() return locked end
function IsRouteActive() return routeIndex ~= nil end
function SetLocked(value) locked = value == true end
function ToggleLock() locked = not locked end

local function alignCamera(dt)
    if looking or UE.Time.time - lastLookTime < WKArenaConfig.camera.alignGrace then return end
    local targetYaw = getCameraAlignTargetYaw()
    if targetYaw == nil then return end
    local speed = getCameraAlignSpeedScale()
    if speed <= 0 then return end
    local yaw = DouyinCameraService.GetYaw()
    if yaw == nil then return end
    local delta = UE.Mathf.DeltaAngle(yaw, targetYaw)
    local step = WKArenaConfig.camera.alignSpeed * speed * dt
    DouyinCameraService.SetYaw(yaw + UE.Mathf.Clamp(delta, -step, step))
    local offset = boss.transform.position + UE.Vector3(0, WKArenaConfig.boss.targetHeight, 0) - actor.position
    local horizontal = math.sqrt(offset.x * offset.x + offset.z * offset.z)
    local wantPitch = -UE.Mathf.Clamp(UE.Mathf.Atan2(offset.y - WKArenaConfig.camera.height,
        math.max(horizontal, 1)) - 0.22, -0.7, 0.3) * UE.Mathf.Rad2Deg
    local pitch = DouyinCameraService.GetPitch()
    if pitch ~= nil then DouyinCameraService.SetPitch(UE.Mathf.Lerp(pitch, wantPitch, 1 - math.exp(-8 * dt))) end
end

function LateUpdate()
    if DouyinApplication.isServer or actor == nil then return end
    local camera = DouyinCameraService.GetCamera()
    if camera == nil then return end
    local cfg = WKArenaConfig.camera
    if not initialized then
        savedYaw = DouyinCameraService.GetYaw(); savedPitch = DouyinCameraService.GetPitch(); savedFov = camera.fieldOfView
        DouyinCameraService.SetYaw(WKArenaConfig.spawn.yaw); DouyinCameraService.SetPitch(cfg.pitch)
        setView(cfg.distance); currentDistance = cfg.distance
        initialized = true
        print("[WK-ARENA] camera-ready position=" .. tostring(camera.transform.position) .. " actor=" .. tostring(actor.position))
    end
    local dt = UE.Time.deltaTime
    alignCamera(dt)
    camera.fieldOfView = UE.Mathf.Lerp(camera.fieldOfView, cfg.fov, math.min(1, 6 * dt))
    local yaw = DouyinCameraService.GetYaw(); local pitch = DouyinCameraService.GetPitch()
    if yaw == nil or pitch == nil then return end
    local desired = locked and cfg.lockDistance or cfg.distance
    local focus = actor.position + UE.Vector3(0, cfg.height, 0)
    local rotation = UE.Quaternion.Euler(pitch, yaw, 0)
    local backward = rotation * UE.Vector3(0, 0, -1)
    local hits = UE.Physics.SphereCastAll(focus, cfg.probeRadius, backward, desired, cfg.mask, UE.QueryTriggerInteraction.Collide)
    local safe = desired
    if hits ~= nil then
        for i = 0, hits.Length - 1 do
            local hit = hits[i]
            if hit.collider ~= nil and (not hit.collider.isTrigger or hit.collider.gameObject.layer == 9)
                and hit.distance > 0.001 then safe = math.min(safe, math.max(cfg.minDistance, hit.distance - cfg.clearance)) end
        end
    end
    -- Retract immediately; recover gradually. The platform remains the camera pose owner.
    currentDistance = safe < currentDistance and safe or UE.Mathf.Lerp(currentDistance, safe, math.min(1, 3 * dt))
    setView(currentDistance)
    if marker ~= nil then
        marker.gameObject:SetActive(locked)
        if locked and boss ~= nil then
            local screen = camera:WorldToViewportPoint(boss.transform.position + UE.Vector3(0, WKArenaConfig.boss.targetHeight, 0))
            marker.gameObject:SetActive(screen.z > 0 and screen.x >= 0 and screen.x <= 1 and screen.y >= 0 and screen.y <= 1)
            marker.rectTransform.anchorMin = UE.Vector2(screen.x, screen.y)
            marker.rectTransform.anchorMax = UE.Vector2(screen.x, screen.y)
            marker.rectTransform.anchoredPosition = UE.Vector2.zero
        end
    end
    if elapsed >= nextSample then
        nextSample = elapsed + 2
        local ground = UE.Physics.RaycastAll(actor.position + UE.Vector3(0, 0.6, 0), UE.Vector3.down, 3, 1, UE.QueryTriggerInteraction.Ignore)
        local floorY = nil
        if ground ~= nil then
            for i = 0, ground.Length - 1 do
                if floorY == nil or ground[i].point.y > floorY then floorY = ground[i].point.y end
            end
        end
        print("[WK-ARENA] sample actor=" .. tostring(actor.actorID) .. " position=" .. tostring(actor.position)
            .. " yaw=" .. tostring(actor.rotation.eulerAngles.y) .. " floor=" .. tostring(floorY)
            .. " camera=" .. tostring(camera.transform.position) .. " distance=" .. tostring(currentDistance)
            .. " locked=" .. tostring(locked))
    end
end

function OnActorDespawned(value)
    if actor ~= nil and value.actorID == actor.actorID then
        stopRoute("despawn"); actor = nil; initialized = false
    end
end

function OnDestroy()
    if DouyinApplication.isServer then return end
    if routeIndex ~= nil then stopRoute("destroy") end
    if onLookStart ~= nil then DouyinInputService.onLookInputStart:RemoveListener(onLookStart) end
    if onLookPerform ~= nil then DouyinInputService.onLookInputPerform:RemoveListener(onLookPerform) end
    if onLookCancel ~= nil then DouyinInputService.onLookInputCancel:RemoveListener(onLookCancel) end
    if initialized then
        local cfg = WKArenaConfig.camera
        DouyinCameraService.SetDistance(cfg.restoreDistance)
        DouyinCameraService.SetOffset(UE.Vector3(0, cfg.restoreHeight, 0))
        if savedPitch ~= nil then DouyinCameraService.SetPitch(savedPitch) end
        if savedYaw ~= nil then DouyinCameraService.SetYaw(savedYaw) end
        local camera = DouyinCameraService.GetCamera()
        if camera ~= nil and savedFov ~= nil then camera.fieldOfView = savedFov end
    end
end
