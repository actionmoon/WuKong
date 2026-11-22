-- Vehicle: Flying vehicle (UFO / helicopter / broom / carpet / fighter) --
-- Root-bound pi-flight.lua: full-3-axis flight control with enterFlight/exitFlight
-- hooks; vertical intent MUST expose two channels concurrently:
--   1) CustomMain/CustomSub bottom-right buttons via EventTrigger.PointerDown/Up
--   2) keyboard E (up) / Q (down)
-- Both OR-merged in computeVerticalIntent; both must be alive (mobile has no keyboard).
-- Pitch feedback is driven SOLELY by verticalIntent (ascend = nose up, descend = nose down);
-- joystick forwardInput drives horizontal motion + roll only, NEVER pitch.
-- No 5-tuning stack.

local UnityEngine = CS.UnityEngine
local Time = UnityEngine.Time
local Mathf = UnityEngine.Mathf
local Vector3 = UnityEngine.Vector3
local Quaternion = UnityEngine.Quaternion
local Input = UnityEngine.Input
local KeyCode = UnityEngine.KeyCode
local DouyinInputService = CS.DouyinInputService
local DouyinUIService = CS.DouyinUIService
local UIType = CS.UIType
local HandType = CS.HandType
local EventTrigger = UnityEngine.EventSystems.EventTrigger
local EventTriggerType = UnityEngine.EventSystems.EventTriggerType

-- BEGIN TEMPLATE CONFIG
local seatAnchorPath = "__FILL_SEAT_ANCHOR_PATH__"
local standAnchorPath = nil

local DEAD_ZONE = 0.1
local topSpeed = __FILL_TOP_SPEED__       -- 水平最高速度
local ascendSpeed = __FILL_ASCEND_SPEED__ -- 升降速度
local acceleration = 12.0
local braking = 10.0
local coastingDrag = 2.5 -- 松开摇杆时的自然减速
local idleDamping = 1.2  -- 无输入时姿态阻尼

local turnSpeed = 90.0   -- yaw 旋转速度（度/秒）
local pitchSpeed = 60.0  -- pitch 前后倾速度
local rollSpeed = 60.0   -- roll 侧倾速度
local maxPitchAngle = 25.0
local maxRollAngle = 30.0

local enablePitch = __FILL_PITCH_ENABLE__                -- 是否启用 pitch 前倾/后仰（悬停飞碟 = false）
local enableRoll = __FILL_ROLL_ENABLE__                  -- 是否启用 roll 侧倾（战斗机 = true）

local ascendButtonText = "__FILL_ASCEND_BUTTON_TEXT__"   -- 右下角上升按钮文案（默认"上升"）
local descendButtonText = "__FILL_DESCEND_BUTTON_TEXT__" -- 右下角下降按钮文案（默认"下降"）

local maxAngularVelocity = 8.0
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

local m_pitch = 0.0
local m_yaw = 0.0
local m_roll = 0.0

local btnAscend = false
local btnDescend = false

-- 右下角操作按钮（CustomMain=上升 / CustomSub=下降）引用 + EventTrigger
local ascendBtn = nil
local ascendTrigger = nil
local descendBtn = nil
local descendTrigger = nil

local savedUseGravity = true

local function findChild(parent, name)
  if parent == nil or name == nil or name == "" then return nil end
  local direct = parent:Find(name)
  if direct ~= nil then return direct end
  for i = 0, parent.childCount - 1 do
    local child = parent:GetChild(i)
    if child ~= nil then
      if child.name == name then return child end
      local found = findChild(child, name)
      if found ~= nil then return found end
    end
  end
  return nil
end

local function setButtonText(btn, text)
  if btn == nil then return end
  local label = btn:GetComponentInChildren(typeof(UnityEngine.UI.Text))
  if label ~= nil then label.text = text end
end

local function removeInteractionButton()
  if interactionButton ~= nil then self:RemoveInteractorButton(interactionButton) end
  interactionButton = nil
end

local function refreshInteractionButton()
  if interactionButton ~= nil then
    setButtonText(interactionButton, hasPassenger and "下机" or "上机")
  end
end

local function ensureInteractionButton()
  if interactionButton == nil then
    interactionButton = self:AddInteractorButton()
  end
  refreshInteractionButton()
end

local function setActorColliderEnabled(actor, enabled)
  if actor == nil or actor.gameObject == nil then return end
  local collider = actor.gameObject:GetComponent(typeof(UnityEngine.Collider))
  if collider ~= nil then collider.enabled = enabled end
end

local function alignActorHipsToSeat(actor, target)
  target = target or seatTrans
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
      self.transform.position.x + right.x * 1.5,
      self.transform.position.y,
      self.transform.position.z + right.z * 1.5
    )
    actor.rotation = self.transform.rotation
  end
end

local function clearDriveInput() moveVec = UnityEngine.Vector2.zero end

-- ============ 飞行钩子（关键差异化） ============
local function enterFlight()
  if rb == nil then return end
  savedUseGravity = rb.useGravity
  rb.useGravity = false
  rb.angularVelocity = Vector3.zero
  -- 从当前世界姿态初始化三轴
  local euler = self.transform.eulerAngles
  m_pitch = 0.0
  m_yaw = euler.y
  m_roll = 0.0
end

local function exitFlight()
  if rb == nil then return end
  rb.useGravity = savedUseGravity
  -- 保留当前 velocity，让飞行器自由落体/惯性飞行
end

local function enterDriving(actor)
  currentActor = actor
  hasPassenger = true
  clearDriveInput()
  enterFlight()
end

local function exitDriving()
  hasPassenger = false
  currentActor = nil
  clearDriveInput()
  btnAscend = false
  btnDescend = false
  exitFlight()
end

local function registerMoveInputListeners()
  onMoveInputStart = function(vec) if hasPassenger then moveVec = vec end end
  onMoveInputPerform = function(vec) if hasPassenger then moveVec = vec end end
  onMoveInputCancel = function() clearDriveInput() end
  DouyinInputService.onMoveInputStart:AddListener(onMoveInputStart)
  DouyinInputService.onMoveInputPerform:AddListener(onMoveInputPerform)
  DouyinInputService.onMoveInputCancel:AddListener(onMoveInputCancel)
end

local function removeMoveInputListeners()
  if onMoveInputStart ~= nil then
    DouyinInputService.onMoveInputStart:RemoveListener(onMoveInputStart); onMoveInputStart = nil
  end
  if onMoveInputPerform ~= nil then
    DouyinInputService.onMoveInputPerform:RemoveListener(onMoveInputPerform); onMoveInputPerform = nil
  end
  if onMoveInputCancel ~= nil then
    DouyinInputService.onMoveInputCancel:RemoveListener(onMoveInputCancel); onMoveInputCancel = nil
  end
end

-- ============ 右下角操作按钮：升降双通道之一（配合键盘 E/Q） ============
-- 硬约束：飞行-Lua.md § 三 #7 —— 按钮 + 键盘两条通路必须并存
-- 工具函数完整实现见：基础交互/右下角操作按钮-Lua.md § 四
local function clearTrigger(trigger)
  if trigger == nil then return end
  if trigger.triggers ~= nil then trigger.triggers:Clear() end
end

local function bindActionButtonTrigger(btn, onDown, onUp)
  if btn == nil or btn.gameObject == nil then return nil end
  if EventTrigger == nil or EventTriggerType == nil then return nil end
  local trigger = btn.gameObject:GetComponent(typeof(EventTrigger))
  if trigger == nil then
    trigger = btn.gameObject:AddComponent(typeof(EventTrigger))
  end
  clearTrigger(trigger)
  local entryDown = EventTrigger.Entry()
  entryDown.eventID = EventTriggerType.PointerDown
  entryDown.callback:AddListener(function(_) onDown() end)
  trigger.triggers:Add(entryDown)
  local entryUp = EventTrigger.Entry()
  entryUp.eventID = EventTriggerType.PointerUp
  entryUp.callback:AddListener(function(_) onUp() end)
  trigger.triggers:Add(entryUp)
  return trigger
end

local function setupActionButton(uiType, text, onDown, onUp)
  if DouyinUIService == nil or uiType == nil then return nil, nil end
  local btn = nil
  if HandType ~= nil and HandType.Right ~= nil then
    local ok, r = pcall(function() return DouyinUIService.GetInteractionButton(HandType.Right, uiType) end)
    if ok then btn = r end
  end
  if btn == nil then
    local ok, r = pcall(function() return DouyinUIService.GetInteractionButton(uiType) end)
    if ok then btn = r end
  end
  if btn == nil or btn.gameObject == nil then return nil, nil end
  btn.gameObject:SetActive(true)
  btn.transition = UnityEngine.UI.Selectable.Transition.None
  if CS.ButtonTweenEffect ~= nil then
    local tween = btn.gameObject:GetComponentInChildren(typeof(CS.ButtonTweenEffect), true)
    if tween ~= nil then tween.enabled = false end
  end
  setButtonText(btn, text)
  return btn, bindActionButtonTrigger(btn, onDown, onUp)
end

local function hideActionButton(btn, trigger)
  if trigger ~= nil then clearTrigger(trigger) end
  if btn ~= nil and btn.gameObject ~= nil then btn.gameObject:SetActive(false) end
end

local function hideFlightActionButtons()
  hideActionButton(ascendBtn, ascendTrigger); ascendBtn = nil; ascendTrigger = nil
  hideActionButton(descendBtn, descendTrigger); descendBtn = nil; descendTrigger = nil
  btnAscend = false
  btnDescend = false
end

local function showFlightActionButtons()
  if UIType == nil then return end
  hideFlightActionButtons()
  ascendBtn, ascendTrigger = setupActionButton(
    UIType.CustomMain, ascendButtonText,
    function() if hasPassenger then btnAscend = true end end,
    function() btnAscend = false end
  )
  descendBtn, descendTrigger = setupActionButton(
    UIType.CustomSub, descendButtonText,
    function() if hasPassenger then btnDescend = true end end,
    function() btnDescend = false end
  )
end

-- 键盘 E/Q 与右下角按钮 or 合并（双通路，两侧都是活的）
local function computeVerticalIntent()
  local up = btnAscend or Input.GetKey(KeyCode.E)
  local down = btnDescend or Input.GetKey(KeyCode.Q)
  if up and down then return 0 end -- 同时按下抵消
  if up then return 1 end
  if down then return -1 end
  return 0
end

function Start()
  rb = self.gameObject:GetComponent(typeof(UnityEngine.Rigidbody))
  if rb ~= nil then rb.maxAngularVelocity = maxAngularVelocity end
  seatTrans = findChild(self.transform, seatAnchorPath)
  standTrans = findChild(self.transform, standAnchorPath)
  registerMoveInputListeners()
end

function OnDestroy()
  hideFlightActionButtons()
  exitDriving()
  removeInteractionButton()
  removeMoveInputListeners()
end

function OnDisable()
  hideFlightActionButtons()
  clearDriveInput()
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
    ensureInteractionButton(); return
  end
  removeInteractionButton()
  ensureInteractionButton()
end

function OnLostFocus(handType)
  if not hasPassenger then removeInteractionButton() end
end

function OnInteractorButtonClick(index)
  if hasPassenger and currentActor ~= nil then
    currentActor:StandUp(self.gameObject); return
  end
  if localActor == nil or seatTrans == nil then return end
  localActor:SitDown(self.gameObject)
end

function OnSeatEntered(actor, handType)
  if actor == nil then return end
  if seatTrans == nil then
    setActorColliderEnabled(actor, true)
    if actor.isLocal then
      exitDriving(); refreshInteractionButton()
    end
    return
  end
  if actor.isLocal then
    local actorPos = actor.gameObject.transform.position
    local vehiclePos = self.transform.position
    savedBoardOffset = Vector3(actorPos.x - vehiclePos.x, actorPos.y - vehiclePos.y, actorPos.z - vehiclePos.z)
    savedBoardRotation = actor.gameObject.transform.rotation
    localActor = actor
    enterDriving(actor)
    showFlightActionButtons() -- 硬约束 #7：进入驾驶挂 CustomMain/Sub 按钮
    removeInteractionButton()
    self:EnableInteraction()
    ensureInteractionButton()
  end
  alignActorHipsToSeat(actor, seatTrans)
  seatedActors[actor] = seatTrans
  setActorColliderEnabled(actor, false)
end

function OnSeatExited(actor)
  if actor == nil then return end
  seatedActors[actor] = nil
  placeActorAtStandPoint(actor)
  setActorColliderEnabled(actor, true)
  if actor.isLocal then
    hideFlightActionButtons() -- 硬约束 #7：离开驾驶清 EventTrigger
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
  -- 前置守卫：无乘客时不接管，rb.useGravity 已在 exitFlight 里还原
  if not hasPassenger then return end

  local dt = Time.fixedDeltaTime
  local forwardInput = 0
  if math.abs(moveVec.y) > DEAD_ZONE then forwardInput = moveVec.y end
  local turnInput = 0
  if math.abs(moveVec.x) > DEAD_ZONE then turnInput = moveVec.x end
  local verticalIntent = computeVerticalIntent()

  -- ============ 三轴姿态更新 ============
  m_yaw = m_yaw + turnInput * turnSpeed * dt

  if enablePitch then
    -- 硬约束 #12：pitch 唯一驱动源 = verticalIntent（上升抬头、下降低头）
    -- 摇杆 forwardInput 只驱动水平位移（下方 targetVx/Vz）与 roll，不得参与 pitch
    local targetPitch = -verticalIntent * maxPitchAngle
    m_pitch = Mathf.MoveTowards(m_pitch, targetPitch, pitchSpeed * dt)
  else
    m_pitch = Mathf.MoveTowards(m_pitch, 0, pitchSpeed * dt * idleDamping)
  end

  if enableRoll then
    local targetRoll = -turnInput * maxRollAngle
    m_roll = Mathf.MoveTowards(m_roll, targetRoll, rollSpeed * dt)
  else
    m_roll = Mathf.MoveTowards(m_roll, 0, rollSpeed * dt * idleDamping)
  end

  -- 每帧完整重写 rotation（**禁用 Rigidbody.constraints 锁 X/Z**）
  rb:MoveRotation(Quaternion.Euler(m_pitch, m_yaw, m_roll))

  -- ============ 速度控制（完整覆盖三轴，不保留 y）============
  local fwd = self.transform.forward
  local currentVelocity = rb.velocity
  local currentSpeed = math.sqrt(
    currentVelocity.x * currentVelocity.x +
    currentVelocity.y * currentVelocity.y +
    currentVelocity.z * currentVelocity.z
  )

  local targetVx = fwd.x * forwardInput * topSpeed
  local targetVy = verticalIntent * ascendSpeed
  local targetVz = fwd.z * forwardInput * topSpeed

  -- 摇杆 / 升降都不输入时用 idleDamping 自然减速
  local hasHorizontalInput = math.abs(forwardInput) >= DEAD_ZONE
  local hasVerticalInput = verticalIntent ~= 0
  if not hasHorizontalInput then
    targetVx = currentVelocity.x * math.max(0, 1 - coastingDrag * dt)
    targetVz = currentVelocity.z * math.max(0, 1 - coastingDrag * dt)
  end
  if not hasVerticalInput then
    targetVy = currentVelocity.y * math.max(0, 1 - idleDamping * dt)
  end

  -- Lerp 到目标速度（避免瞬间加速）
  local lerpT = Mathf.Clamp01(acceleration * dt / math.max(topSpeed, 1.0))
  local newVx = Mathf.Lerp(currentVelocity.x, targetVx, lerpT)
  local newVy = Mathf.Lerp(currentVelocity.y, targetVy, lerpT)
  local newVz = Mathf.Lerp(currentVelocity.z, targetVz, lerpT)

  rb.velocity = Vector3(newVx, newVy, newVz)
end

function LateUpdate()
  for actor, target in pairs(seatedActors) do
    alignActorHipsToSeat(actor, target)
  end
end
