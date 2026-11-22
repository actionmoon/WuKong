-- Vehicle: Rideable animated creature (mount) --
-- Animated creature mounted interaction template baseline.
-- Template-first skeleton: seat lifecycle, motion peer API handoff,
-- and profile-specific input semantics. Do not turn this into vehicle driving.

local UnityEngine = CS.UnityEngine
local Input = UnityEngine.Input
local KeyCode = UnityEngine.KeyCode
local DouyinInputService = CS.DouyinInputService
local Debug = UnityEngine.Debug
local Vector3 = UnityEngine.Vector3
local Quaternion = UnityEngine.Quaternion
local Physics = UnityEngine.Physics
local GameObject = UnityEngine.GameObject
local HumanBodyBones = UnityEngine.HumanBodyBones

-- BEGIN TEMPLATE CONFIG
local controlProfile = "land"
local DEAD_ZONE = 0.1
local RUN_THRESHOLD = 0.75
local seatAnchorName = "SeatAnchor"
local standUpAnchorName = nil
-- controlProfile drives the default mounted semantics.
-- allowVerticalControl is only an override for special cases; by default the
-- template script derives it from the explicit Land/Flying/Fish template type.
local allowVerticalControl = false
-- END TEMPLATE CONFIG

local FACING_MISMATCH_ANGLE_THRESHOLD = 20.0
local SEAT_FALLBACK_FORWARD_RATIO = 2 / 5
local SEAT_FALLBACK_BOTTOM_MARGIN_RATIO = 0.1
local SEAT_FALLBACK_TOP_SAFE_BAND_RATIO = 0.22
local SEAT_FALLBACK_PROBE_HEIGHT = 0.25
local SEAT_FALLBACK_SURFACE_LIFT = 0.08
local SEAT_EMBEDDED_SURFACE_DELTA_RATIO = 0.05
local SEAT_EMBEDDED_SURFACE_DELTA_MIN = 0.08
local MOUNTED_HIP_CLEARANCE_RATIO = 0.08
local MOUNTED_HIP_CLEARANCE_MIN = 0.08
local MOUNTED_HIP_CLEARANCE_MAX = 0.18

local localActor = nil
local interactorBtn = nil
local hasPassenger = false
local rideInteractRoot = nil
local seatAnchor = nil
local seatTrans = nil
local standUpAnchor = nil
local seatRuntimeFallback = nil
local motionPeer = nil
local moveVec = UnityEngine.Vector2.zero
local hasFacingMismatch = false
local facingOffsetDegrees = 0.0
local cachedAnatomicalForward = nil

local onMoveInputStart = nil
local onMoveInputPerform = nil
local onMoveInputCancel = nil

local function logInfo(message)
    Debug.Log("[animated-creature-interaction] " .. tostring(message))
end

local function logWarn(message)
    Debug.LogWarning("[animated-creature-interaction][warn] " .. tostring(message))
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function arrayAt(values, index)
    if values == nil then
        return nil
    end
    local direct = values[index]
    if direct ~= nil then
        return direct
    end
    if type(values.GetValue) == "function" then
        local ok, value =
            pcall(
                function()
                    return values:GetValue(index)
                end
            )
        if ok then
            return value
        end
    end
    return nil
end

local function setButtonText(btn, text)
    if btn == nil then
        return
    end
    local label = btn:GetComponentInChildren(typeof(UnityEngine.UI.Text), true)
    if label ~= nil then
        label.gameObject:SetActive(true)
        label.text = text
    end
end

local function refreshButtonText()
    if interactorBtn == nil then
        return
    end
    setButtonText(interactorBtn, hasPassenger and "离开" or "乘坐")
end

local function ensureInteractorButton()
    if interactorBtn == nil then
        interactorBtn = self:AddInteractorButton()
    end
    refreshButtonText()
end

local function normalizePath(path)
    if path == nil then
        return ""
    end
    local result = tostring(path)
    while string.sub(result, 1, 1) == "/" do
        result = string.sub(result, 2)
    end
    while string.sub(result, -1) == "/" do
        result = string.sub(result, 1, string.len(result) - 1)
    end
    return result
end

local function collectTransformPaths(parent, currentPath, entries)
    entries[#entries + 1] = { path = currentPath, transform = parent }
    for i = 0, parent.childCount - 1 do
        local child = parent:GetChild(i)
        if child ~= nil then
            local childPath = child.name
            if currentPath ~= "" then
                childPath = currentPath .. "/" .. child.name
            end
            collectTransformPaths(child, childPath, entries)
        end
    end
end

local function pathHasSuffix(path, suffix)
    if path == suffix then
        return true
    end
    local pathLen = string.len(path)
    local suffixLen = string.len(suffix)
    if suffixLen <= 0 or pathLen <= suffixLen then
        return false
    end
    if string.sub(path, pathLen - suffixLen + 1) ~= suffix then
        return false
    end
    return string.sub(path, pathLen - suffixLen, pathLen - suffixLen) == "/"
end

local function findUniquePathSuffix(entries, suffix)
    local found = nil
    local count = 0
    for i = 1, #entries do
        local entry = entries[i]
        if pathHasSuffix(entry.path, suffix) then
            found = entry.transform
            count = count + 1
        end
    end
    return found, count
end

local function findChild(parent, targetPath)
    if parent == nil or targetPath == nil then
        return nil
    end

    local entries = {}
    collectTransformPaths(parent, normalizePath(parent.name), entries)

    local lookupPath = normalizePath(targetPath)
    if lookupPath == "" then
        return parent
    end

    while lookupPath ~= "" do
        local found, count = findUniquePathSuffix(entries, lookupPath)
        if count == 1 then
            return found
        end
        if count > 1 then
            return nil
        end

        -- Fallback by progressively stripping the first path segment: A/B/C -> B/C -> C.
        local slashIdx = string.find(lookupPath, "/", 1, true)
        if slashIdx == nil then
            break
        end
        lookupPath = string.sub(lookupPath, slashIdx + 1)
        lookupPath = normalizePath(lookupPath)
    end

    return nil
end

local function getCombinedRendererBounds(root)
    if root == nil or root.gameObject == nil then
        return nil
    end

    local renderers = root.gameObject:GetComponentsInChildren(typeof(UnityEngine.Renderer), true)
    if renderers == nil or renderers.Length == nil or renderers.Length <= 0 then
        return nil
    end

    local bounds = nil
    for i = 0, renderers.Length - 1 do
        local renderer = arrayAt(renderers, i)
        if renderer ~= nil then
            if bounds == nil then
                bounds = renderer.bounds
            else
                bounds:Encapsulate(renderer.bounds)
            end
        end
    end
    return bounds
end

local function sameRootObject(a, b)
    if a == nil or b == nil or a.transform == nil or b.transform == nil then
        return false
    end
    return a.transform.root == b.transform.root
end

local function getHorizontalForward(root)
    local forward = root and root.forward or Vector3.forward
    local horizontal = Vector3(forward.x, 0, forward.z)
    if horizontal.sqrMagnitude == nil or horizontal.sqrMagnitude < 0.0001 then
        return Vector3.forward
    end
    return horizontal.normalized
end

local function findFirstByNameToken(parent, token)
    if parent == nil or token == nil or token == "" then
        return nil
    end
    local lowerToken = string.lower(token)
    local selfName = string.lower(tostring(parent.name or ""))
    if string.find(selfName, lowerToken, 1, true) ~= nil then
        return parent
    end
    for i = 0, parent.childCount - 1 do
        local child = parent:GetChild(i)
        if child ~= nil then
            local found = findFirstByNameToken(child, token)
            if found ~= nil then
                return found
            end
        end
    end
    return nil
end

local function findPelvisLikeNode(root)
    if root == nil then
        return nil
    end
    local direct = findChild(root, "pelvis")
    if direct ~= nil then
        return direct
    end
    direct = findChild(root, "Pelvis")
    if direct ~= nil then
        return direct
    end
    return findFirstByNameToken(root, "pelvis")
end

local function findHeadLikeNode(root)
    if root == nil then
        return nil
    end
    local direct = findChild(root, "head")
    if direct ~= nil then
        return direct
    end
    direct = findChild(root, "Head")
    if direct ~= nil then
        return direct
    end
    return findFirstByNameToken(root, "head")
end

local function getAnatomicalForward(root)
    if root == nil then
        return Vector3.forward
    end
    local pelvis = findPelvisLikeNode(root)
    local head = findHeadLikeNode(root)
    if pelvis ~= nil and head ~= nil and pelvis.position ~= nil and head.position ~= nil then
        local forward = Vector3(head.position.x - pelvis.position.x, 0, head.position.z - pelvis.position.z)
        if forward.sqrMagnitude ~= nil and forward.sqrMagnitude >= 0.0001 then
            return forward.normalized
        end
    end
    return getHorizontalForward(root)
end

local function getCreatureUp(root)
    local up = root and root.up or Vector3.up
    if up.sqrMagnitude == nil or up.sqrMagnitude < 0.0001 then
        return Vector3.up
    end
    return up.normalized
end

local function signedYawDegrees(fromVec, toVec)
    local from = Vector3(fromVec.x, 0, fromVec.z)
    local to = Vector3(toVec.x, 0, toVec.z)
    if from.sqrMagnitude == nil or from.sqrMagnitude < 0.0001 then
        from = Vector3.forward
    else
        from = from.normalized
    end
    if to.sqrMagnitude == nil or to.sqrMagnitude < 0.0001 then
        to = Vector3.forward
    else
        to = to.normalized
    end
    local cross = from.x * to.z - from.z * to.x
    local dot = clamp(from.x * to.x + from.z * to.z, -1.0, 1.0)
    local angleRadians = nil
    local ok, result =
        pcall(
            function()
                return math.atan(cross, dot)
            end
        )
    if ok then
        angleRadians = result
    else
        angleRadians = math.atan(cross / math.max(math.abs(dot), 0.0001))
        if dot < 0 then
            if cross >= 0 then
                angleRadians = angleRadians + math.pi
            else
                angleRadians = angleRadians - math.pi
            end
        end
    end
    return math.deg(angleRadians)
end

local function ensureFacingMismatchState(root)
    if root == nil then
        hasFacingMismatch = false
        facingOffsetDegrees = 0.0
        cachedAnatomicalForward = Vector3.forward
        return false
    end
    local anatomicalForward = getAnatomicalForward(root)
    local rootForward = getHorizontalForward(root)
    local mismatchAngle = signedYawDegrees(rootForward, anatomicalForward)
    facingOffsetDegrees = mismatchAngle
    cachedAnatomicalForward = anatomicalForward
    hasFacingMismatch = math.abs(mismatchAngle) >= FACING_MISMATCH_ANGLE_THRESHOLD
    return hasFacingMismatch
end

local function getBoundsExtentAlongDirection(bounds, direction)
    local dir = direction.normalized
    local extents = bounds.extents
    return math.abs(dir.x) * extents.x + math.abs(dir.y) * extents.y + math.abs(dir.z) * extents.z
end

local function buildSeatFallbackReferencePoint(root, bounds, pelvis)
    if root == nil or bounds == nil then
        return nil
    end

    local forward = cachedAnatomicalForward or getAnatomicalForward(root)
    local up = getCreatureUp(root)
    local probeBase = bounds.center
    if pelvis ~= nil and pelvis.position ~= nil then
        probeBase = pelvis.position
    end

    local forwardExtent = getBoundsExtentAlongDirection(bounds, forward)
    local upExtent = getBoundsExtentAlongDirection(bounds, up)
    local directionScale = 1
    if controlProfile == "flying" or controlProfile == "fish" then
        directionScale = -1
    end
    local forwardOffset = forwardExtent * SEAT_FALLBACK_FORWARD_RATIO * directionScale
    local upOffset = math.max(SEAT_FALLBACK_SURFACE_LIFT, upExtent * 0.14)
    return Vector3(
        probeBase.x + forward.x * forwardOffset + up.x * upOffset,
        probeBase.y + forward.y * forwardOffset + up.y * upOffset,
        probeBase.z + forward.z * forwardOffset + up.z * upOffset
    )
end

local function isSeatReferenceInsideBounds(bounds, point)
    if bounds == nil or point == nil then
        return false
    end
    local sizeY = bounds.size.y
    local bottomMargin = math.max(0.05, sizeY * SEAT_FALLBACK_BOTTOM_MARGIN_RATIO)
    local topSafeBand = math.max(0.18, sizeY * SEAT_FALLBACK_TOP_SAFE_BAND_RATIO)
    return point.x >= bounds.min.x and point.x <= bounds.max.x and point.z >= bounds.min.z and point.z <= bounds.max.z and
        point.y >= bounds.min.y + bottomMargin and
        point.y <= bounds.max.y - topSafeBand
end

local function isSeatReferenceEmbedded(bounds, point, surfacePoint)
    if not isSeatReferenceInsideBounds(bounds, point) then
        return false
    end
    if surfacePoint == nil then
        return true
    end
    local maxSurfaceDelta = math.max(SEAT_EMBEDDED_SURFACE_DELTA_MIN, bounds.size.y * SEAT_EMBEDDED_SURFACE_DELTA_RATIO)
    return (surfacePoint.y - point.y) > maxSurfaceDelta
end

local function tryFindSeatSurfaceHit(root, bounds, pelvis)
    if root == nil or bounds == nil then
        return nil
    end

    local referencePoint = buildSeatFallbackReferencePoint(root, bounds, pelvis)
    if referencePoint == nil then
        return nil
    end
    local origin = Vector3(referencePoint.x, referencePoint.y + SEAT_FALLBACK_PROBE_HEIGHT, referencePoint.z)
    local maxDistance = bounds.size.y + SEAT_FALLBACK_PROBE_HEIGHT * 2.0
    local hits = Physics.RaycastAll(origin, Vector3.down, maxDistance)
    if hits == nil or hits.Length == nil or hits.Length <= 0 then
        return referencePoint
    end

    local preferredHit = nil
    local preferredDistance = nil
    local triggerHit = nil
    local triggerDistance = nil
    for i = 0, hits.Length - 1 do
        local hit = arrayAt(hits, i)
        if
            hit ~= nil and hit.collider ~= nil and hit.collider.transform ~= nil and
            hit.collider.transform.root == root.root
        then
            local hitDistance = tonumber(hit.distance) or 0.0
            if hit.collider.isTrigger then
                if triggerHit == nil or hitDistance < triggerDistance then
                    triggerHit = hit
                    triggerDistance = hitDistance
                end
            else
                if preferredHit == nil or hitDistance < preferredDistance then
                    preferredHit = hit
                    preferredDistance = hitDistance
                end
            end
        end
    end

    local finalHit = preferredHit or triggerHit
    if finalHit == nil or finalHit.point == nil then
        return referencePoint
    end

    return Vector3(finalHit.point.x, finalHit.point.y + SEAT_FALLBACK_SURFACE_LIFT, finalHit.point.z)
end

local function ensureSeatRuntimeFallback(root)
    if root == nil then
        return nil
    end
    local fallbackParent = findPelvisLikeNode(root) or root
    if seatRuntimeFallback == nil then
        local go = GameObject("SeatRuntimeFallback")
        if go == nil then
            return nil
        end
        seatRuntimeFallback = go.transform
        seatRuntimeFallback:SetParent(fallbackParent)
    elseif seatRuntimeFallback.parent ~= fallbackParent then
        local worldPos = seatRuntimeFallback.position
        local worldRot = seatRuntimeFallback.rotation
        seatRuntimeFallback:SetParent(fallbackParent)
        seatRuntimeFallback.position = worldPos
        seatRuntimeFallback.rotation = worldRot
    end
    return seatRuntimeFallback
end

local function applySeatFallbackFromBounds(root)
    local bounds = getCombinedRendererBounds(root)
    if bounds == nil then
        return nil
    end

    local pelvis = findPelvisLikeNode(root)
    local fallback = ensureSeatRuntimeFallback(root)
    if fallback == nil then
        return nil
    end

    local candidate = tryFindSeatSurfaceHit(root, bounds, pelvis)
    fallback.position = candidate
    fallback.rotation = Quaternion.LookRotation(cachedAnatomicalForward or getAnatomicalForward(root), Vector3.up)
    return fallback
end

local function sampleSeatSurfaceAtWorldPoint(root, bounds, worldPoint)
    if root == nil or bounds == nil or worldPoint == nil or Physics == nil then
        return worldPoint
    end
    local origin = Vector3(worldPoint.x, bounds.max.y + SEAT_FALLBACK_PROBE_HEIGHT, worldPoint.z)
    local maxDistance = bounds.size.y + SEAT_FALLBACK_PROBE_HEIGHT * 2.0
    local hits = Physics.RaycastAll(origin, Vector3.down, maxDistance)
    if hits == nil or hits.Length == nil or hits.Length <= 0 then
        return worldPoint
    end

    local preferredHit = nil
    local preferredDistance = nil
    local triggerHit = nil
    local triggerDistance = nil
    for i = 0, hits.Length - 1 do
        local hit = arrayAt(hits, i)
        if
            hit ~= nil and hit.collider ~= nil and hit.collider.transform ~= nil and
            hit.collider.transform.root == root.root
        then
            local hitDistance = tonumber(hit.distance) or 0.0
            if hit.collider.isTrigger then
                if triggerHit == nil or hitDistance < triggerDistance then
                    triggerHit = hit
                    triggerDistance = hitDistance
                end
            else
                if preferredHit == nil or hitDistance < preferredDistance then
                    preferredHit = hit
                    preferredDistance = hitDistance
                end
            end
        end
    end

    local finalHit = preferredHit or triggerHit
    if finalHit == nil or finalHit.point == nil then
        return worldPoint
    end
    return Vector3(finalHit.point.x, finalHit.point.y + SEAT_FALLBACK_SURFACE_LIFT, finalHit.point.z)
end

local function projectPointToPlane(point, planeOrigin, planeNormal)
    if point == nil or planeOrigin == nil or planeNormal == nil then
        return point
    end
    local normal = planeNormal.normalized
    local toPoint = Vector3(point.x - planeOrigin.x, point.y - planeOrigin.y, point.z - planeOrigin.z)
    local distance = toPoint.x * normal.x + toPoint.y * normal.y + toPoint.z * normal.z
    return Vector3(point.x - normal.x * distance, point.y - normal.y * distance, point.z - normal.z * distance)
end

local function applySeatMidlineAdjustment(root, bounds)
    if not hasFacingMismatch or root == nil or bounds == nil or seatTrans == nil then
        return
    end
    local pelvis = findPelvisLikeNode(root)
    if pelvis == nil or pelvis.position == nil then
        return
    end
    local forward = cachedAnatomicalForward or getAnatomicalForward(root)
    local up = getCreatureUp(root)
    local planeNormal = Vector3.Cross(forward, up)
    if planeNormal.sqrMagnitude == nil or planeNormal.sqrMagnitude < 0.0001 then
        return
    end
    local projected = projectPointToPlane(seatTrans.position, pelvis.position, planeNormal)
    local adjusted = sampleSeatSurfaceAtWorldPoint(root, bounds, projected)
    local seatPositionHost = seatTrans == seatRuntimeFallback and seatTrans or (seatAnchor or seatTrans)
    if seatPositionHost ~= nil then
        seatPositionHost.position = adjusted
    end
end

local function alignSeatFacing(root, anchor, seat)
    if root == nil then
        return
    end
    local targetRotation = Quaternion.LookRotation(cachedAnatomicalForward or getAnatomicalForward(root), Vector3.up)
    if anchor ~= nil then
        anchor.rotation = targetRotation
    end
    if seat ~= nil then
        seat.rotation = targetRotation
    end
end

local function resolveMountHelpers()
    local root = self and self.transform or nil
    if root == nil then
        return
    end

    ensureFacingMismatchState(root)
    rideInteractRoot = findChild(root, "RideInteractRoot")
    if rideInteractRoot == nil then
        logWarn("RideInteractRoot missing; mount interaction anchor degraded")
    end

    local seatAnchorHost = rideInteractRoot or root
    seatAnchor = findChild(seatAnchorHost, seatAnchorName)
    if seatAnchor == nil then
        logWarn("SeatAnchor missing; mount seat alignment degraded")
    end

    if seatAnchor ~= nil then
        seatTrans = seatAnchor:Find("Seat")
        if seatTrans == nil then
            seatTrans = findChild(seatAnchor, "Seat")
        end
        if seatTrans == nil then
            logWarn("SeatAnchor exists but child Seat missing; seat alignment degraded")
        end
    else
        seatTrans = findChild(root, "Seat")
        if seatTrans == nil then
            logWarn("SeatAnchor and Seat missing; ride mount unavailable")
        end
    end

    local bounds = getCombinedRendererBounds(root)
    local seatReference = seatTrans or seatAnchor
    local sampledSeatSurface = nil
    if seatReference ~= nil and bounds ~= nil then
        sampledSeatSurface = sampleSeatSurfaceAtWorldPoint(root, bounds, seatReference.position)
    end
    if
        seatReference ~= nil and bounds ~= nil and
        isSeatReferenceEmbedded(bounds, seatReference.position, sampledSeatSurface)
    then
        local fallback = applySeatFallbackFromBounds(root)
        if fallback ~= nil then
            seatTrans = fallback
            if controlProfile == "flying" or controlProfile == "fish" then
                logWarn("SeatAnchor appears inside body; using pelvis-linked back-surface seat fallback")
            else
                logWarn("SeatAnchor appears inside body; using pelvis-linked forward-surface seat fallback")
            end
        end
    elseif seatTrans == nil then
        local fallback = applySeatFallbackFromBounds(root)
        if fallback ~= nil then
            seatTrans = fallback
            if controlProfile == "flying" or controlProfile == "fish" then
                logWarn("Seat helper missing or incomplete; using pelvis-linked back-surface seat fallback")
            else
                logWarn("Seat helper missing or incomplete; using pelvis-linked forward-surface seat fallback")
            end
        end
    end

    if bounds ~= nil then
        applySeatMidlineAdjustment(root, bounds)
    end

    alignSeatFacing(root, seatAnchor, seatTrans)

    if standUpAnchorName ~= nil then
        standUpAnchor = findChild(root, standUpAnchorName)
    else
        local standUpHost = rideInteractRoot or root
        standUpAnchor = findChild(standUpHost, "StandUpAnchor")
    end
    if standUpAnchor == nil then
        logInfo("StandUpAnchor missing; current world position will be kept on dismount")
    end
end

local function resolveMotionPeer()
    if self ~= nil and type(self.GetDouyinScript) == "function" then
        local ok, ds =
            pcall(
                function()
                    return self:GetDouyinScript("motion-state")
                end
            )
        if ok and ds ~= nil and ds.script ~= nil and sameRootObject(ds.script.self, self) then
            return ds.script
        end

        ok, ds =
            pcall(
                function()
                    return self:GetDouyinScript("ms-root.lua")
                end
            )
        if ok and ds ~= nil and ds.script ~= nil and sameRootObject(ds.script.self, self) then
            return ds.script
        end
    end

    local bindings = _G and rawget(_G, "__luaHostBindings") or nil
    if type(bindings) ~= "table" then
        return nil
    end

    for _, record in pairs(bindings) do
        if type(record) == "table" and record.env ~= nil then
            local id = tostring(record.scriptId or "")
            local env = record.env
            local envSelf = env and env.self or nil
            if
                (id == "motion-state" or id == "ms-root.lua" or string.find(id, "motion-state", 1, true) ~= nil) and
                sameRootObject(envSelf, self) and
                type(env.SetMountedRider) == "function"
            then
                return env
            end
        end
    end

    return nil
end

local function callMotion(methodName, ...)
    if motionPeer == nil then
        return nil
    end
    local fn = motionPeer[methodName]
    if type(fn) ~= "function" then
        return nil
    end
    local ok, result = pcall(fn, ...)
    if ok then
        return result
    end
    return nil
end

local function setActorColliderEnabled(actor, enabled)
    if actor == nil or actor.gameObject == nil then
        return
    end
    local collider = actor.gameObject:GetComponent(typeof(UnityEngine.CapsuleCollider))
    if collider ~= nil then
        collider.enabled = enabled
    end
end

local function applyMountedSeatLift(actor, actorTransform, hips)
    if actor == nil or actorTransform == nil or hips == nil then
        return
    end
    local creatureRoot = self and self.transform or nil
    if creatureRoot == nil or seatTrans == nil then
        return
    end
    local creatureBounds = getCombinedRendererBounds(creatureRoot)
    local actorBounds = getCombinedRendererBounds(actorTransform)
    if creatureBounds == nil or actorBounds == nil then
        return
    end
    local surfacePoint = sampleSeatSurfaceAtWorldPoint(creatureRoot, creatureBounds, seatTrans.position)
    if surfacePoint == nil then
        return
    end
    local clearance =
        clamp(
            (tonumber(actorBounds.size.y) or 1.0) * MOUNTED_HIP_CLEARANCE_RATIO,
            MOUNTED_HIP_CLEARANCE_MIN,
            MOUNTED_HIP_CLEARANCE_MAX
        )
    local desiredHipY = math.max(surfacePoint.y + clearance, seatTrans.position.y)
    local currentHipY = hips.position.y
    if currentHipY < desiredHipY then
        local deltaY = desiredHipY - currentHipY
        actorTransform.position =
            Vector3(actorTransform.position.x, actorTransform.position.y + deltaY, actorTransform.position.z)
    end
end

local function alignActorHipsToSeat(actor)
    if actor == nil or actor.gameObject == nil or seatTrans == nil then
        return
    end
    local actorTransform = actor.gameObject.transform
    actorTransform:SetParent(seatTrans)
    actorTransform.localPosition = Vector3.zero
    actorTransform.localRotation = Quaternion.identity
    local root = self and self.transform or seatTrans
    actorTransform.rotation = Quaternion.LookRotation(cachedAnatomicalForward or getAnatomicalForward(root), Vector3.up)
    local animator = actor.gameObject:GetComponentInChildren(typeof(UnityEngine.Animator))
    if animator == nil then
        return
    end
    local hips = animator:GetBoneTransform(HumanBodyBones.Hips)
    if hips == nil then
        return
    end
    local hipsPos = hips.position
    local actorPos = actorTransform.position
    actorTransform.position =
        Vector3(
            actorPos.x - (hipsPos.x - actorPos.x),
            actorPos.y - (hipsPos.y - actorPos.y),
            actorPos.z - (hipsPos.z - actorPos.z)
        )
    applyMountedSeatLift(actor, actorTransform, hips)
end

local function handoffMoveIntent()
    local forward = moveVec.y
    if math.abs(forward) < DEAD_ZONE then
        forward = 0
    end
    callMotion("SetMountedMoveIntent", forward, 0)
end

local function handoffMoveState()
    local moveMode = "idle"
    if moveVec.y <= -DEAD_ZONE then
        moveMode = "back"
    elseif moveVec.y >= DEAD_ZONE then
        moveMode = moveVec.y > RUN_THRESHOLD and "run" or "walk"
    end
    callMotion("SetMountedMoveMode", moveMode)
end

local function handoffTurnIntent()
    local x = moveVec.x
    if math.abs(x) < DEAD_ZONE then
        x = 0
    end
    callMotion("SetMountedTurnIntent", x)
end

local function handoffVerticalIntent()
    if not allowVerticalControl then
        callMotion("SetMountedVerticalIntent", 0)
        return
    end
    local verticalIntent = 0
    if Input.GetKey(KeyCode.E) then
        verticalIntent = verticalIntent + 1
    end
    if Input.GetKey(KeyCode.Q) then
        verticalIntent = verticalIntent - 1
    end
    callMotion("SetMountedVerticalIntent", verticalIntent)
end

local function handoffJumpIntent()
    -- Only grounded profiles expose jump from interaction; flying/fish use
    -- vertical intent instead.
    local shouldJump = controlProfile == "land" and Input.GetKeyDown(KeyCode.Space)
    callMotion("SetMountedJumpIntent", shouldJump)
end

function Start()
    resolveMountHelpers()
    motionPeer = resolveMotionPeer()

    onMoveInputStart = function(vec)
        moveVec = vec
    end
    onMoveInputPerform = function(vec)
        moveVec = vec
    end
    onMoveInputCancel = function()
        moveVec = UnityEngine.Vector2.zero
    end

    DouyinInputService.onMoveInputStart:AddListener(onMoveInputStart)
    DouyinInputService.onMoveInputPerform:AddListener(onMoveInputPerform)
    DouyinInputService.onMoveInputCancel:AddListener(onMoveInputCancel)
end

function OnDestroy()
    if onMoveInputStart ~= nil then
        DouyinInputService.onMoveInputStart:RemoveListener(onMoveInputStart)
    end
    if onMoveInputPerform ~= nil then
        DouyinInputService.onMoveInputPerform:RemoveListener(onMoveInputPerform)
    end
    if onMoveInputCancel ~= nil then
        DouyinInputService.onMoveInputCancel:RemoveListener(onMoveInputCancel)
    end
end

function OnActorTriggerEnter(actor)
    if actor == nil or not actor.isLocal then
        return
    end
    if seatTrans == nil then
        return
    end
    localActor = actor
    self:EnableInteraction()
end

function OnActorTriggerExit(actor)
    if actor == nil or not actor.isLocal then
        return
    end
    if hasPassenger then
        return
    end
    self:DisableInteraction()
end

function OnFocus(handType)
    ensureInteractorButton()
end

function OnLostFocus(handType)
    if interactorBtn ~= nil then
        self:RemoveInteractorButton(interactorBtn)
        interactorBtn = nil
    end
end

function OnInteractorButtonClick(index)
    if localActor == nil then
        return
    end
    if hasPassenger then
        localActor:StandUp(self.gameObject)
    else
        localActor:SitDown(self.gameObject)
    end
end

function OnSeatEntered(actor, handType)
    if actor == nil or not actor.isLocal then
        return
    end
    if seatTrans == nil then
        resolveMountHelpers()
    end
    if seatTrans == nil then
        return
    end
    hasPassenger = true
    motionPeer = resolveMotionPeer()
    alignActorHipsToSeat(actor)
    setActorColliderEnabled(actor, false)
    callMotion("SetMountedRider", actor)
    -- Grounded profiles need one grounding refresh when the rider mounts.
    if controlProfile == "land" then
        callMotion("RefreshMountedGrounding", true)
    end
    ensureInteractorButton()
end

function OnSeatExited(actor)
    if actor == nil or not actor.isLocal then
        return
    end
    hasPassenger = false
    actor.gameObject.transform:SetParent(nil)
    if standUpAnchor ~= nil then
        actor.gameObject.transform.position = standUpAnchor.position
    end
    setActorColliderEnabled(actor, true)
    callMotion("ClearMountedRider")
    callMotion("ClearMountedGroundingState")
    callMotion("SetMountedVerticalIntent", 0)
    refreshButtonText()
end

function Update()
    if not hasPassenger then
        return
    end
    handoffMoveIntent()
    handoffMoveState()
    handoffTurnIntent()
    handoffJumpIntent()
    handoffVerticalIntent()
end
