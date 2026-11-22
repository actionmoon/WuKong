-- Vehicle: Four-wheel ground vehicle --
-- Four-wheel vehicle single-file interaction template.
-- Root-bound pi-vehicle.lua: seat lifecycle, input, Rigidbody driving,
-- wheel visuals, and yaw-only camera follow live in this file.

local UnityEngine = CS.UnityEngine
local Time = UnityEngine.Time
local Mathf = UnityEngine.Mathf
local Vector3 = UnityEngine.Vector3
local Quaternion = UnityEngine.Quaternion
local DouyinInputService = CS.DouyinInputService
local DouyinCameraService = CS.DouyinCameraService

-- BEGIN TEMPLATE CONFIG
local seatAnchorPath = "__FILL_SEAT_ANCHOR_PATH__"
local standAnchorPath = nil
local wheelPivotConfigs = {
  { path = "__FILL_FRONT_LEFT_WHEEL_PATH__",  canSteer = true,  spinSign = 1 },
  { path = "__FILL_FRONT_RIGHT_WHEEL_PATH__", canSteer = true,  spinSign = -1 },
  { path = "__FILL_REAR_LEFT_WHEEL_PATH__",   canSteer = false, spinSign = 1 },
  { path = "__FILL_REAR_RIGHT_WHEEL_PATH__",  canSteer = false, spinSign = -1 },
}

local DEAD_ZONE = 0.1
local topSpeed = 18.0
local reverseSpeed = 7.0
local acceleration = 14.0
local reverseAcceleration = 9.0
local accelerationCurve = 3.5
local braking = 24.0
local coastingDrag = 5.5
local turnSpeed = 115.0
local grip = 0.94
local minHighSpeedSteerScale = 0.42
local sidewaysFriction = 8.0

local wheelRadius = 0.42
local frontWheelMaxSteerAngle = 30.0
local wheelSpinDegreesPerMeter = 57.2957795 / wheelRadius

local tiltSafetyStart = 12.0
local maxTiltAssistAngle = 25.0
local emergencyStabilityBrake = 14.0
local yawStability = 2.4
local pitchRollDamping = 7.5
local uprightAssist = 4.2
local tiltAssistStart = 4.0
local maxAngularVelocity = 4.5

local cameraFollowEnabled = true
local cameraAlignSpeed = 120.0
local cameraAlignGrace = 0.45
local cameraBaseSpeedScale = 0.65
local cameraInputSpeedScale = 0.35
-- END TEMPLATE CONFIG

local DEG_TO_RAD = math.pi / 180

local rb = nil
local seatTrans = nil
local standTrans = nil
local localActor = nil
local currentActor = nil
local currentInside = false
local hasPassenger = false
local interactionButton = nil
local moveVec = UnityEngine.Vector2.zero
local seatedActors = {}
local savedBoardOffset = nil
local savedBoardRotation = nil

local onMoveInputStart = nil
local onMoveInputPerform = nil
local onMoveInputCancel = nil
local onLookInputStart = nil
local onLookInputPerform = nil
local onLookInputCancel = nil

local wheelStates = {}
local frontWheelSteerAngle = 0
local isLookingActive = false
local lastLookTime = -math.huge

local function clamp(value, minValue, maxValue)
  if value < minValue then return minValue end
  if value > maxValue then return maxValue end
  return value
end

local function multiplyQuaternion(lhs, rhs)
  return Quaternion(
    lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y,
    lhs.w * rhs.y - lhs.x * rhs.z + lhs.y * rhs.w + lhs.z * rhs.x,
    lhs.w * rhs.z + lhs.x * rhs.y - lhs.y * rhs.x + lhs.z * rhs.w,
    lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z
  )
end

local function findChild(parent, name)
  if parent == nil or name == nil or name == "" then return nil end

  local lookupName = name
  local prefix = parent.name .. "/"
  if string.sub(lookupName, 1, string.len(prefix)) == prefix then
    lookupName = string.sub(lookupName, string.len(prefix) + 1)
  end
  if lookupName == "" then return parent end

  local direct = parent:Find(lookupName)
  if direct ~= nil then return direct end

  for i = 0, parent.childCount - 1 do
    local child = parent:GetChild(i)
    if child ~= nil then
      if child.name == lookupName then return child end
      local found = findChild(child, lookupName)
      if found ~= nil then return found end
    end
  end

  local slashIdx = string.find(lookupName, "/", 1, true)
  if slashIdx ~= nil then
    local stripped = string.sub(lookupName, slashIdx + 1)
    if stripped ~= "" and stripped ~= lookupName then
      return findChild(parent, stripped)
    end
  end

  return nil
end

local function setButtonText(text)
  if interactionButton == nil then return end
  local label = interactionButton:GetComponentInChildren(typeof(UnityEngine.UI.Text))
  if label ~= nil then
    label.text = text
  end
end

local function removeInteractionButton()
  if interactionButton ~= nil then
    self:RemoveInteractorButton(interactionButton)
  end
  interactionButton = nil
end

local function refreshInteractionButton()
  if interactionButton ~= nil then
    setButtonText(hasPassenger and "下车" or "上车")
  end
end

local function ensureInteractionButton()
  if interactionButton == nil then
    interactionButton = self:AddInteractorButton()
  end
  refreshInteractionButton()
end

function resolveSeatTrans()
  return seatTrans
end

local function setActorColliderEnabled(actor, enabled)
  if actor == nil or actor.gameObject == nil then return end
  local collider = actor.gameObject:GetComponent(typeof(UnityEngine.Collider))
  if collider ~= nil then
    collider.enabled = enabled
  end
end

local function alignActorHipsToSeat(actor, target)
  target = target or resolveSeatTrans()
  if actor == nil or actor.gameObject == nil or target == nil then return end

  local actorTrans = actor.gameObject.transform
  actorTrans:SetParent(target)
  actorTrans.localPosition = Vector3.zero
  actorTrans.localRotation = Quaternion.identity

  local animator = actor.gameObject:GetComponentInChildren(typeof(UnityEngine.Animator))
  if animator == nil then return end
  local hips = animator:GetBoneTransform(UnityEngine.HumanBodyBones.Hips)
  if hips == nil then return end

  local hipsPos = hips.position
  local transPos = actorTrans.position
  actorTrans.position = Vector3(
    transPos.x - (hipsPos.x - transPos.x),
    transPos.y - (hipsPos.y - transPos.y),
    transPos.z - (hipsPos.z - transPos.z)
  )
end

local function placeActorAtStandPoint(actor)
  if actor == nil or actor.gameObject == nil then return end
  actor.gameObject.transform:SetParent(nil)

  if standTrans ~= nil then
    actor.position = standTrans.position
    actor.rotation = standTrans.rotation
  elseif savedBoardOffset ~= nil then
    actor.position = Vector3(
      self.transform.position.x + savedBoardOffset.x,
      self.transform.position.y + savedBoardOffset.y,
      self.transform.position.z + savedBoardOffset.z
    )
    actor.rotation = savedBoardRotation
    savedBoardOffset = nil
    savedBoardRotation = nil
  else
    local right = self.transform.right
    actor.position = Vector3(
      self.transform.position.x + right.x * 1.2,
      self.transform.position.y,
      self.transform.position.z + right.z * 1.2
    )
    actor.rotation = self.transform.rotation
  end
end

local function clearDriveInput()
  moveVec = UnityEngine.Vector2.zero
end

local function stopHorizontalVelocity()
  if rb == nil then return end
  local v = rb.velocity
  rb.velocity = Vector3(0, v.y, 0)
end

local function enterDriving(actor)
  currentActor = actor
  hasPassenger = true
  clearDriveInput()
end

local function exitDriving()
  hasPassenger = false
  currentActor = nil
  clearDriveInput()
  stopHorizontalVelocity()
  frontWheelSteerAngle = 0
end

local function addWheelPivot(path, canSteer, spinSign)
  if path == nil or path == "" then return end
  local wheelTrans = findChild(self.transform, path)
  if wheelTrans == nil then return end

  table.insert(wheelStates, {
    transform = wheelTrans,
    baseRotation = wheelTrans.localRotation,
    spinAngle = 0,
    canSteer = canSteer == true,
    spinSign = spinSign or 1,
  })
end

local function setupWheelPivots()
  wheelStates = {}
  for _, config in ipairs(wheelPivotConfigs) do
    addWheelPivot(config.path, config.canSteer, config.spinSign)
  end
end

local function registerMoveInputListeners()
  onMoveInputStart = function(vec)
    if hasPassenger then
      moveVec = vec
    end
  end
  onMoveInputPerform = function(vec)
    if hasPassenger then
      moveVec = vec
    end
  end
  onMoveInputCancel = function()
    clearDriveInput()
  end

  DouyinInputService.onMoveInputStart:AddListener(onMoveInputStart)
  DouyinInputService.onMoveInputPerform:AddListener(onMoveInputPerform)
  DouyinInputService.onMoveInputCancel:AddListener(onMoveInputCancel)
end

local function removeMoveInputListeners()
  if onMoveInputStart ~= nil then
    DouyinInputService.onMoveInputStart:RemoveListener(onMoveInputStart)
    onMoveInputStart = nil
  end
  if onMoveInputPerform ~= nil then
    DouyinInputService.onMoveInputPerform:RemoveListener(onMoveInputPerform)
    onMoveInputPerform = nil
  end
  if onMoveInputCancel ~= nil then
    DouyinInputService.onMoveInputCancel:RemoveListener(onMoveInputCancel)
    onMoveInputCancel = nil
  end
end

local function registerCameraAlignInputListeners()
  onLookInputStart = function()
    isLookingActive = true
    lastLookTime = Time.time
  end
  onLookInputPerform = function()
    isLookingActive = true
    lastLookTime = Time.time
  end
  onLookInputCancel = function()
    isLookingActive = false
    lastLookTime = Time.time
  end

  DouyinInputService.onLookInputStart:AddListener(onLookInputStart)
  DouyinInputService.onLookInputPerform:AddListener(onLookInputPerform)
  DouyinInputService.onLookInputCancel:AddListener(onLookInputCancel)
end

local function removeCameraAlignInputListeners()
  if onLookInputStart ~= nil then
    DouyinInputService.onLookInputStart:RemoveListener(onLookInputStart)
    onLookInputStart = nil
  end
  if onLookInputPerform ~= nil then
    DouyinInputService.onLookInputPerform:RemoveListener(onLookInputPerform)
    onLookInputPerform = nil
  end
  if onLookInputCancel ~= nil then
    DouyinInputService.onLookInputCancel:RemoveListener(onLookInputCancel)
    onLookInputCancel = nil
  end
end

local function clampHorizontal(vx, vz, maxSpeed)
  local mag = math.sqrt(vx * vx + vz * vz)
  if maxSpeed > 0.0001 and mag > maxSpeed then
    local s = maxSpeed / mag
    return vx * s, vz * s, maxSpeed
  end
  return vx, vz, mag
end

local function moveHorizontalTowardsZero(vx, vz, maxDelta)
  local mag = math.sqrt(vx * vx + vz * vz)
  if mag <= maxDelta or mag <= 0.0001 then
    return 0, 0
  end
  local nextMag = mag - maxDelta
  local s = nextMag / mag
  return vx * s, vz * s
end

local function rotateHorizontal(vx, vz, degrees)
  local rad = degrees * DEG_TO_RAD
  local c = math.cos(rad)
  local s = math.sin(rad)
  return vx * c + vz * s, -vx * s + vz * c
end

local function getTiltAngles()
  if self == nil or self.transform == nil then
    return 0, 0
  end
  local euler = self.transform.eulerAngles
  return Mathf.DeltaAngle(0, euler.x), Mathf.DeltaAngle(0, euler.z)
end

local function applyTiltSafetyBrake(vx, vz, dt)
  local pitch, roll = getTiltAngles()
  local tiltMagnitude = Mathf.Max(Mathf.Abs(pitch), Mathf.Abs(roll))
  if tiltMagnitude <= tiltSafetyStart then
    return vx, vz
  end

  local span = Mathf.Max(1.0, maxTiltAssistAngle - tiltSafetyStart)
  local brakeRatio = Mathf.Clamp01((tiltMagnitude - tiltSafetyStart) / span)
  return moveHorizontalTowardsZero(vx, vz, emergencyStabilityBrake * brakeRatio * dt)
end

local function dampSidewaysSlip(vx, vz, speedRatio, dt)
  if self == nil or self.transform == nil then
    return vx, vz
  end
  local right = self.transform.right
  local lateralSpeed = vx * right.x + vz * right.z
  local dampingStrength = Mathf.Lerp(sidewaysFriction, sidewaysFriction * 1.35, speedRatio)
  local correction = lateralSpeed * Mathf.Clamp01(dampingStrength * dt)
  return vx - right.x * correction, vz - right.z * correction
end

local function stabilizeAngularMotion(turnInput, speedRatio, dt)
  if rb == nil or self == nil or self.transform == nil then return end
  rb.maxAngularVelocity = maxAngularVelocity

  local localAngular = self.transform:InverseTransformDirection(rb.angularVelocity)
  local pitch, roll = getTiltAngles()

  local pitchRollDampingT = Mathf.Clamp01(pitchRollDamping * dt)
  local yawDampingT = Mathf.Clamp01(yawStability * dt * (0.6 + speedRatio * 0.8))
  if math.abs(turnInput) > DEAD_ZONE then
    yawDampingT = yawDampingT * 0.35
  end

  local correctedX = Mathf.Lerp(localAngular.x, 0, pitchRollDampingT)
  local correctedY = Mathf.Lerp(localAngular.y, 0, yawDampingT)
  local correctedZ = Mathf.Lerp(localAngular.z, 0, pitchRollDampingT)

  local tiltMagnitude = Mathf.Max(Mathf.Abs(pitch), Mathf.Abs(roll))
  if tiltMagnitude > tiltAssistStart then
    local span = Mathf.Max(1.0, maxTiltAssistAngle - tiltAssistStart)
    local tiltRatio = Mathf.Clamp01((tiltMagnitude - tiltAssistStart) / span)
    local assistT = Mathf.Clamp01(tiltRatio * dt * 4.0)
    correctedX = Mathf.Lerp(correctedX, -pitch * DEG_TO_RAD * uprightAssist, assistT)
    correctedZ = Mathf.Lerp(correctedZ, -roll * DEG_TO_RAD * uprightAssist, assistT)
  end

  local correctedWorld = self.transform:TransformDirection(Vector3(correctedX, correctedY, correctedZ))
  rb.angularVelocity = Vector3.ClampMagnitude(correctedWorld, maxAngularVelocity)
end

local function updateWheelVisuals()
  if rb == nil then return end
  local dt = Time.deltaTime

  local targetSteer = 0
  if hasPassenger and math.abs(moveVec.x) > DEAD_ZONE then
    targetSteer = moveVec.x * frontWheelMaxSteerAngle
  end
  frontWheelSteerAngle = Mathf.Lerp(frontWheelSteerAngle, targetSteer, clamp(10 * dt, 0, 1))

  local speed = rb.velocity.magnitude
  if Vector3.Dot(rb.velocity, self.transform.forward) < 0 then
    speed = -speed
  end
  local spinDelta = speed * wheelSpinDegreesPerMeter * dt

  for _, state in ipairs(wheelStates) do
    if state.transform ~= nil then
      state.spinAngle = state.spinAngle + spinDelta * state.spinSign
      local steerAngle = state.canSteer and frontWheelSteerAngle or 0
      state.transform.localRotation = multiplyQuaternion(state.baseRotation,
        Quaternion.Euler(state.spinAngle, steerAngle, 0))
    end
  end
end

function getCameraAlignTargetYaw()
  if not cameraFollowEnabled then return nil end
  if not hasPassenger then return nil end
  if self == nil or self.transform == nil then return nil end
  return self.transform.eulerAngles.y
end

function getCameraAlignSpeedScale()
  if not cameraFollowEnabled then return 0 end
  if not hasPassenger then return 0 end
  local inputStrength = 0
  if moveVec ~= nil then
    inputStrength = math.max(math.abs(moveVec.x), math.abs(moveVec.y))
  end
  return cameraBaseSpeedScale + Mathf.Clamp01(inputStrength) * cameraInputSpeedScale
end

local function applyCameraYawFollow()
  if DouyinCameraService == nil then return end
  if isLookingActive then return end
  if Time.time - lastLookTime < cameraAlignGrace then return end

  local targetYaw = getCameraAlignTargetYaw()
  if targetYaw == nil then return end

  local speedScale = getCameraAlignSpeedScale()
  if speedScale == nil or speedScale <= 0 then return end

  local currentYaw = DouyinCameraService.GetYaw()
  local delta = Mathf.DeltaAngle(currentYaw, targetYaw)
  local maxStep = cameraAlignSpeed * speedScale * Time.deltaTime
  local step = 0

  if math.abs(delta) <= maxStep then
    step = delta
  elseif delta >= 0 then
    step = maxStep
  else
    step = -maxStep
  end

  DouyinCameraService.SetYaw(currentYaw + step)
end

function Start()
  rb = self.gameObject:GetComponent(typeof(UnityEngine.Rigidbody))
  if rb ~= nil then
    rb.maxAngularVelocity = maxAngularVelocity
  else
    UnityEngine.Debug.LogWarning("four-wheel-vehicle-template: root Rigidbody missing; driving is disabled.")
  end

  seatTrans = findChild(self.transform, seatAnchorPath)
  standTrans = findChild(self.transform, standAnchorPath)
  if seatTrans == nil then
    UnityEngine.Debug.LogWarning("four-wheel-vehicle-template: SeatAnchor missing; seat alignment will be disabled.")
  end

  setupWheelPivots()
  registerMoveInputListeners()
  registerCameraAlignInputListeners()
end

function OnDestroy()
  exitDriving()
  removeInteractionButton()
  removeMoveInputListeners()
  removeCameraAlignInputListeners()
end

function OnActorTriggerEnter(actor)
  if actor == nil or not actor.isLocal then return end
  localActor = actor
  currentInside = true
  self:EnableInteraction()
end

function OnActorTriggerExit(actor)
  if actor == nil or not actor.isLocal then return end
  currentInside = false
  if not hasPassenger then
    localActor = nil
    self:DisableInteraction()
  end
end

function OnFocus(handType)
  if hasPassenger and currentActor ~= nil then
    ensureInteractionButton()
    return
  end
  removeInteractionButton()
  ensureInteractionButton()
end

function OnLostFocus(handType)
  if not hasPassenger then
    removeInteractionButton()
  end
end

function OnInteractorButtonClick(index)
  if hasPassenger and currentActor ~= nil then
    currentActor:StandUp(self.gameObject)
    return
  end

  if localActor == nil or seatTrans == nil then
    return
  end

  localActor:SitDown(self.gameObject)
end

function OnSeatEntered(actor, handType)
  if actor == nil then return end
  local target = resolveSeatTrans()
  if target == nil then
    setActorColliderEnabled(actor, true)
    if actor.isLocal then
      exitDriving()
      refreshInteractionButton()
    end
    return
  end

  if actor.isLocal then
    local actorPos = actor.gameObject.transform.position
    local carPos = self.transform.position
    savedBoardOffset = Vector3(actorPos.x - carPos.x, actorPos.y - carPos.y, actorPos.z - carPos.z)
    savedBoardRotation = actor.gameObject.transform.rotation
    localActor = actor
    enterDriving(actor)
    removeInteractionButton()
    self:EnableInteraction()
    ensureInteractionButton()
  end

  alignActorHipsToSeat(actor, target)
  seatedActors[actor] = target
  setActorColliderEnabled(actor, false)
end

function OnSeatExited(actor)
  if actor == nil then return end

  seatedActors[actor] = nil
  placeActorAtStandPoint(actor)
  setActorColliderEnabled(actor, true)

  if actor.isLocal then
    exitDriving()
    localActor = actor
    currentInside = true
    self:EnableInteraction()
    refreshInteractionButton()
  end
end

function FixedUpdate()
  if rb == nil then return end
  if rb.isKinematic then return end
  if not hasPassenger then return end

  local dt = Time.fixedDeltaTime
  local accelInput = 0
  if math.abs(moveVec.y) > DEAD_ZONE then
    accelInput = moveVec.y
  end
  local turnInput = 0
  if math.abs(moveVec.x) > DEAD_ZONE then
    turnInput = moveVec.x
  end

  local fwd = self.transform.forward
  local fwdLen = math.sqrt(fwd.x * fwd.x + fwd.z * fwd.z)
  if fwdLen <= 0.0001 then return end
  local forwardX = fwd.x / fwdLen
  local forwardZ = fwd.z / fwdLen

  local currentVelocity = rb.velocity
  local horizontalSpeed = math.sqrt(currentVelocity.x * currentVelocity.x + currentVelocity.z * currentVelocity.z)
  local speedRatio = 0
  if topSpeed > 0.0001 then
    speedRatio = Mathf.Clamp01(horizontalSpeed / topSpeed)
  end
  local steerScale = Mathf.Lerp(1.0, minHighSpeedSteerScale, speedRatio * speedRatio)
  local turningPower = turnInput * turnSpeed * dt * steerScale

  local localVel = self.transform:InverseTransformDirection(currentVelocity)
  local forwardVelSign = localVel.z
  if math.abs(turnInput) > DEAD_ZONE and (horizontalSpeed > 0.2 or math.abs(accelInput) > DEAD_ZONE) then
    local steerDir = 1
    if forwardVelSign < -0.05 then steerDir = -1 end
    rb:MoveRotation(multiplyQuaternion(self.transform.rotation, Quaternion.Euler(0, turningPower * steerDir, 0)))
  end

  local movingForward = forwardVelSign >= -0.05
  local accelForward = accelInput >= 0
  local maxSpd = movingForward and topSpeed or reverseSpeed
  if horizontalSpeed < 0.2 then
    maxSpd = accelForward and topSpeed or reverseSpeed
  end
  local accelPower = accelForward and acceleration or reverseAcceleration

  local accelRampT = 0
  if maxSpd > 0.0001 then
    accelRampT = Mathf.Clamp01(horizontalSpeed / maxSpd)
  end
  local accelRamp = Mathf.Lerp(accelerationCurve, 1, accelRampT * accelRampT)
  local isBraking = (movingForward and accelInput < -0.01) or ((not movingForward) and accelInput > 0.01)
  local finalAccelPower = isBraking and braking or accelPower
  local finalAcceleration = finalAccelPower * accelRamp

  local vx = currentVelocity.x
  local vz = currentVelocity.z
  if not (horizontalSpeed >= maxSpd and not isBraking) then
    vx = vx + forwardX * (accelInput * finalAcceleration * dt)
    vz = vz + forwardZ * (accelInput * finalAcceleration * dt)
  end

  vx, vz = clampHorizontal(vx, vz, maxSpd)

  if math.abs(accelInput) < 0.01 then
    vx, vz = moveHorizontalTowardsZero(vx, vz, coastingDrag * dt)
  end

  if math.abs(turnInput) > DEAD_ZONE and math.abs(forwardVelSign) > 0.1 then
    local dir = 1
    if forwardVelSign < -0.05 then dir = -1 end
    local steerAngle = turningPower * dir * grip
    vx, vz = rotateHorizontal(vx, vz, steerAngle)
  end

  vx, vz = dampSidewaysSlip(vx, vz, speedRatio, dt)
  vx, vz = applyTiltSafetyBrake(vx, vz, dt)
  vx, vz = clampHorizontal(vx, vz, maxSpd)

  rb.velocity = Vector3(vx, currentVelocity.y, vz)
  stabilizeAngularMotion(turnInput, speedRatio, dt)
end

function Update()
  updateWheelVisuals()

  if hasPassenger and currentActor ~= nil and UnityEngine.Input.GetKeyDown(UnityEngine.KeyCode.Space) then
    currentActor:StandUp(self.gameObject)
  end
end

function LateUpdate()
  for actor, target in pairs(seatedActors) do
    alignActorHipsToSeat(actor, target)
  end

  applyCameraYawFollow()
end
