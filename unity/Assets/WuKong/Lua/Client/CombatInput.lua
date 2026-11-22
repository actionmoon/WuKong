local UE = UnityEngine
local json = WKJson
local C,K=WKCombatConfig,WKCombatClock
local actor,state,arena,boss=nil,nil,nil,nil
local stick=UE.Vector2.zero
local moveStart,movePerform,moveCancel=nil,nil,nil
local pending,sequence={},0
local sendAge,poll=0,0
local pose=nil
local uiHeld,uiPressed={},{}
local uiBindings={}
local sprintToggle=false
local logCache={}
local velocityX,velocityZ=0,0
local replay=nil
local onTouch=nil
local lastPress={}
local pointerConsumed={}
local epoch=nil
local bossReplay=nil
local autoProbeStarted=false
local skillsReplay=nil
local hud=nil

local function enqueue(name)
    sequence=sequence+1;pending[#pending+1]={id=sequence,name=name}
end
function Press(name)
    local now=UE.Time.time
    if lastPress[name] and now-lastPress[name]<0.12 then return end
    lastPress[name]=now;uiPressed[name]=true
end
function SetHeld(name,value)
    if value and not uiHeld[name] then Press(name);pointerConsumed[name]=true end
    uiHeld[name]=value
end
local function bind(name)
    local go=UE.GameObject.Find("CombatButton_"..name)
    if not go then return end
    local button=go:GetComponent(typeof(UE.UI.Button))
    local click=function()
        if pointerConsumed[name] then pointerConsumed[name]=nil else Press(name) end
    end
    button.onClick:AddListener(click)
    uiBindings[#uiBindings+1]={name=name,rect=go:GetComponent(typeof(UE.RectTransform)),button=button,click=click}
end
local function pointerControls()
    -- Poll the actual screen rectangles, independently of the platform UI module.
    -- Merge all fingers before changing held state, so releasing one does not
    -- release a control still held by another finger.
    local held={}
    local function point(position)
        local screenPoint=UE.Vector2(position.x,position.y)
        for _,b in ipairs(uiBindings) do
            if b.button.gameObject.activeInHierarchy and b.button.interactable
                and not (hud and hud.IsModal())
                and UE.RectTransformUtility.RectangleContainsScreenPoint(b.rect,screenPoint,nil) then held[b.name]=true end
        end
    end
    if UE.Input.touchCount>0 then
        for i=0,UE.Input.touchCount-1 do
            local touch=UE.Input.GetTouch(i)
            if touch.phase~=UE.TouchPhase.Ended and touch.phase~=UE.TouchPhase.Canceled then point(touch.position) end
        end
    elseif UE.Input.GetMouseButton(0) then point(UE.Input.mousePosition) end
    for _,b in ipairs(uiBindings) do SetHeld(b.name,held[b.name]==true) end
end
function Start()
    if DouyinApplication.isServer then return end
    state=UE.GameObject.Find("CombatState"):GetComponent(typeof(DouyinScript)).script
    arena=UE.GameObject.Find("ArenaPresentation"):GetComponent(typeof(DouyinScript)).script
    boss=UE.GameObject.Find("TigerBaseline")
    local hudObject=UE.GameObject.Find("PresentationHUD")
    if hudObject then hud=hudObject:GetComponent(typeof(DouyinScript)).script end
    moveStart=function() end
    movePerform=function(v) stick=v end
    moveCancel=function() stick=UE.Vector2.zero end
    DouyinInputService.onMoveInputStart:AddListener(moveStart)
    DouyinInputService.onMoveInputPerform:AddListener(movePerform)
    DouyinInputService.onMoveInputCancel:AddListener(moveCancel)
    for _,name in ipairs({"light","heavy","dodge","gourd","lock","sprint","challenge","stanceCycle","spin","immobilize","cloud","transform","spirit"}) do bind(name) end
    onTouch=function(position)
        local screenPoint=UE.Vector2(position.x,position.y)
        if DouyinApplication.isSimulator then
            print("[WK-COMBAT-POINTER] touch="..tostring(position).." mouse="..tostring(UE.Input.mousePosition))
        end
        for _,b in ipairs(uiBindings) do
            if b.button.gameObject.activeInHierarchy and b.button.interactable and not (hud and hud.IsModal())
                and UE.RectTransformUtility.RectangleContainsScreenPoint(b.rect,screenPoint,nil) then Press(b.name);return end
        end
    end
    DouyinInputService.onTouchEvent:AddListener(onTouch)
end
local function initialize(value)
    if actor then return end
    actor=value
    actor.jumpHeight=0;actor:Immobilize(false)
    print("[WK-COMBAT] input-ready actor="..tostring(actor.actorID))
end
function OnActorSpawned(value)
    if not DouyinApplication.isServer and value and value.isLocal then initialize(value) end
end
function OnActorDespawned(value)
    if value==actor then
        actor=nil;pose=nil;stick=UE.Vector2.zero
        uiHeld={};uiPressed={};pending={};sprintToggle=false
    end
end
function GetPose(actorID)
    if actor and actor.actorID==actorID then return pose end
    local views=state and state.GetViews()
    return views and views[tostring(actorID)]
end
function GetView(actorID)
    local views=state and state.GetViews()
    return views and views[tostring(actorID)]
end
function GetLocalView() return actor and GetView(actor.actorID) end
function GetLocalPosition() return actor and actor.position end
function GetLocalActorID() return actor and actor.actorID end
local function keyboardDirection()
    local x,z=0,0
    if UE.Input.GetKey("w") then z=z+1 end;if UE.Input.GetKey("s") then z=z-1 end
    if UE.Input.GetKey("d") then x=x+1 end;if UE.Input.GetKey("a") then x=x-1 end
    -- Platform WASD already participates in stick; choose one source to avoid doubling.
    if x==0 and z==0 then x=stick.x;z=stick.y end
    local length=math.sqrt(x*x+z*z)
    if length>1 then x=x/length;z=z/length end
    local yaw=(DouyinCameraService.GetYaw() or 0)*math.pi/180
    return x*math.cos(yaw)+z*math.sin(yaw),z*math.cos(yaw)-x*math.sin(yaw)
end
local function label(name,text)
    local go=UE.GameObject.Find(name)
    if go then go:GetComponent(typeof(UE.UI.Text)).text=text end
end
local function bar(name,value,maxValue)
    local go=UE.GameObject.Find(name.."Fill")
    if go then go.transform.localScale=UE.Vector3(K.clamp(value/maxValue,0,1),1,1) end
end
local function updateHUD(v)
    label("PlayerResources",string.format("%.0f / %.0f   体力 %.0f   葫芦 %d",v.hp,v.hpMax or 390,v.stamina,v.gourd))
    local name=v.form=="lang" and "广智" or v.form=="she" and "广谋" or v.stance=="pillar" and "立棍" or v.stance=="thrust" and "戳棍" or "劈棍"
    label("StanceBaseline",string.format("%s   棍势 %d   %.0f",name,v.pips,v.focus))
    label("BossName",string.format("虎先锋   %.0f / 6480",v.bossHp))
    bar("PlayerHP",v.hp,v.hpMax or 390);bar("PlayerMP",v.mp,220);bar("PlayerStamina",v.stamina,v.staminaMax or 250);bar("BossHP",v.bossHp,6480)
    label("SkillBaseline",string.format("定身 %.0fs  散气 %.0fs%s\n赤潮 %.0f / 150  精魄 %.0f / 212",
        v.cooldowns and v.cooldowns.immobilize or 0,v.cooldowns and v.cooldowns.cloud or 0,v.cloud and " · 化气" or "",v.transEnergy or 150,v.vigor or 212))
    local title=v.challenge=="ready" and "开始挑战" or (v.challenge=="victory" or v.challenge=="defeat") and "重新挑战" or "挑战中"
    label("ChallengeButtonLabel",title)
    label("ArenaStatus",v.challenge=="victory" and (v.resultReady and "虎先锋 · 伏诛" or "虎先锋 · 伏诛…")
        or v.challenge=="defeat" and (v.resultReady and "身死 · 重新挑战" or "身死…")
        or v.challenge=="ready" and "卧虎寺 · 按 Enter 开始挑战"
        or "血池 · "..(v.boss and v.boss.phase or "虎先锋"))
end
local function bossReplayInput(v,dt)
    bossReplay.age=bossReplay.age+dt;local t=bossReplay.age
    local function once(key,at,fn)
        if t>=at and not bossReplay.fired[key] then bossReplay.fired[key]=true;fn() end
    end
    local function reset(z)
        enqueue("test-reset");velocityX=0;velocityZ=0;arena.SetLocked(true)
        actor:Teleport(UE.Vector3(1.226,-6.3,z or 45),UE.Quaternion.identity)
    end
    once("suite",0,function() enqueue("boss-suite") end)
    once("near",0.3,function() reset(45);enqueue("boss-ai") end)
    once("far",8,function() actor:Teleport(UE.Vector3(0,-6.3,30),UE.Quaternion.identity) end)
    once("p85",12,function() enqueue("player-heal");enqueue("boss-hp:5400") end)
    once("p60",15,function() enqueue("player-heal");enqueue("boss-hp:3800") end)
    once("p50",18,function() enqueue("player-heal");enqueue("boss-hp:3100") end)
    once("p40",21,function() enqueue("player-heal");enqueue("boss-hp:2500") end)
    once("wind",24,function() reset(44);enqueue("boss-cast:202207") end)
    once("stone",33,function() reset(43);enqueue("boss-cast:202298") end)
    once("guard",45,function() reset(45.5);enqueue("boss-cast:202240") end)
    once("guard-hit",46.5,function() enqueue("light") end)
    once("defeat",51,function() enqueue("player-defeat") end)
    once("retry-defeat",54,function() enqueue("retry") end)
    once("victory-setup",57,function() reset(45.5);enqueue("boss-idle");enqueue("boss-hp:1") end)
    once("victory-hit",57.8,function() enqueue("light") end)
    once("victory-force",62,function() if v and v.bossHp>0 then enqueue("boss-hp:0") end end)
    once("retry-victory",65,function() enqueue("retry") end)
    once("heavy-setup",69,function() reset(45.5);enqueue("boss-idle");enqueue("boss-hp:1") end)
    once("heavy-start",70,function() enqueue("heavy") end)
    once("heavy-retry",80,function() enqueue("retry") end)
    once("finish",83,function()
        print("[WK-BOSS-REPLAY] finished "..json.encode(v));bossReplay=nil
    end)
    return 0,0,false,t>=70 and t<73
end
local function replayInput(v,dt)
    replay.age=replay.age+dt
    local t=replay.age
    local function once(key,at,fn)
        if t>=at and not replay.fired[key] then replay.fired[key]=true;fn() end
    end
    local function reset()
        enqueue("test-reset");velocityX=0;velocityZ=0
        actor:Teleport(boss.transform.position+UE.Vector3(0,0.05,-3.3),UE.Quaternion.identity)
        arena.SetLocked(true)
    end
    once("combo-reset",0,reset)
    once("combo-start",0.5,function() enqueue("light") end)
    if t<7 and v and v.kind=="light" and not replay.combo[v.play] then
        local cw=K.active(C.clips[v.clip],v.t,"comboWindow")
        local nextStep=(v.step or 1)+1
        if nextStep<=5 and cw and K.allowed(cw,C.player.lightCombo[nextStep].skill) then
            enqueue("light");replay.combo[v.play]=true
        end
    end
    once("heavy-reset",8,reset)
    once("heavy-start",8.5,function() enqueue("heavy") end)
    once("hit-reset",15,reset)
    once("hit",15.5,function() enqueue("test-strike") end)
    once("heal",17,function() enqueue("gourd") end)
    once("perfect-reset",21,reset)
    once("warning",21.5,function() enqueue("test-strike") end)
    once("perfect",22.05,function() enqueue("dodge") end)
    once("move-reset",26,function()
        reset();arena.SetLocked(false)
        print("[WK-COMBAT-REPLAY] move-origin="..tostring(actor.position))
    end)
    once("move-end",29,function() print("[WK-COMBAT-REPLAY] move-end="..tostring(actor.position)) end)
    once("sprint-light",30.2,function() enqueue("light") end)
    once("finish",34,function()
        print("[WK-COMBAT-REPLAY] finished position="..tostring(actor.position));replay=nil
    end)
    return t>=26.5 and t<28.5 and 1 or 0,t>=30 and t<31 and 1 or 0,
        t>=30 and t<31,t>=8.5 and t<11.5
end
local function skillsReplayInput(v,dt)
    local r=skillsReplay;r.age=r.age+dt;local t=r.age
    local function once(k,at,fn) if t>=at and not r.fired[k] then r.fired[k]=true;fn() end end
    local function reset()
        enqueue("test-reset");enqueue("boss-idle");velocityX=0;velocityZ=0;arena.SetLocked(true)
        actor:Teleport(UE.Vector3(1.226,-6.3,45.5),UE.Quaternion.identity)
    end
    once("suite",0,function() enqueue("skills-suite");enqueue("test-suite");enqueue("boss-suite") end)
    once("pillar",.3,function() reset();enqueue("stance:pillar") end)
    once("pillarCharge",1,function() enqueue("heavy") end)
    once("thrust",16,function() reset();enqueue("stance:thrust") end)
    once("thrustCharge",17,function() enqueue("heavy") end)
    once("spin",24,function() reset();enqueue("spin") end)
    once("ding",29,function() reset();enqueue("immobilize") end)
    once("cloud",33,function() reset();enqueue("cloud") end)
    once("strike",35,function() enqueue("light") end)
    once("transform",39,function() reset();enqueue("transform") end)
    once("formLight",42.5,function() enqueue("light") end)
    once("formHeavy",45,function() enqueue("heavy") end)
    once("return",49,function() enqueue("transform") end)
    once("spirit",54,function() reset();enqueue("spirit") end)
    once("vigorNear",66.5,function()
        actor:Teleport(boss.transform.position+UE.Vector3(0,0.05,-2.65),UE.Quaternion.identity)
        velocityX=0;velocityZ=0
    end)
    once("vigorHit",67,function() enqueue("light") end)
    once("death",70,function() enqueue("player-defeat") end)
    once("retry",73,function() enqueue("retry") end)
    once("finish",77,function()
        print("[WK-SKILLS-REPLAY] finished "..json.encode(v));skillsReplay=nil
    end)
    return 0,0,false,(t>=1 and t<12.5) or (t>=17 and t<21),t>=24 and t<27
end
function Update()
    if DouyinApplication.isServer or not DouyinNetService.isNetworkSettled then return end
    if not actor then
        poll=poll+UE.Time.deltaTime
        if poll<0.5 then return end;poll=0
        local actors=DouyinActorService.GetActors()
        if actors then for i=0,actors.Length-1 do if actors[i].isLocal then initialize(actors[i]) end end end
        if not actor then return end
    end
    local dt=math.min(UE.Time.deltaTime,0.1)
    pointerControls()
    if DouyinApplication.isSimulator and UE.Input.GetMouseButtonDown(0) then
        print("[WK-COMBAT-POINTER] mouse="..tostring(UE.Input.mousePosition))
    end
    local views=state.GetViews()
    local v=views[tostring(actor.actorID)]
    if v then
        if epoch~=v.epoch then
            if epoch~=nil then
                local spawn=WKArenaConfig.spawn
                actor:StopMove();actor:Teleport(UE.Vector3(spawn.x,spawn.y,spawn.z),UE.Quaternion.Euler(0,spawn.yaw,0))
                arena.ResetView();pose=nil;velocityX=0;velocityZ=0
            end
            epoch=v.epoch
        end
        while #pending>0 and pending[1].id<=(v.ack or 0) do table.remove(pending,1) end
        if not pose or pose.play~=v.play or pose.clip~=v.clip then
            pose={clip=v.clip,t=v.t,play=v.play,kind=v.kind,section=1}
        elseif v.time~=pose.serverTime and math.abs(pose.t-v.t)>0.15 then pose.t=v.t end
        pose.serverTime=v.time;pose.kind=v.kind
        pose.form=v.form
        if hud then hud.Apply(v) else updateHUD(v) end
    end
    for key,view in pairs(views) do
        local prev=logCache[key]
        if not prev or prev.play~=view.play or prev.hits~=view.hits or prev.heals~=view.heals or prev.perfect~=view.perfect
            or prev.bossPlay~=(view.boss and view.boss.play) or prev.challenge~=view.challenge or prev.phase~=(view.boss and view.boss.phase)
            or prev.epoch~=view.epoch or prev.resultReady~=view.resultReady
            or prev.hazards~=(view.boss and #view.boss.hazards) or prev.decoys~=(view.boss and #view.boss.decoys)
            or prev.stone~=(view.boss and view.boss.stone) or prev.invisible~=(view.boss and view.boss.invisible)
            or prev.cloud~=(view.cloud~=nil) or prev.immobilized~=((view.immobilized or 0)>0)
            or prev.form~=view.form or prev.vigor~=view.vigor or prev.bossHp~=view.bossHp
            or prev.snakes~=#(view.snakes or {}) or prev.projectiles~=#(view.projectiles or {}) then
            print("[WK-COMBAT-VIEW] "..json.encode(view));logCache[key]={play=view.play,hits=view.hits,heals=view.heals,perfect=view.perfect,
                bossPlay=view.boss and view.boss.play,challenge=view.challenge,phase=view.boss and view.boss.phase,epoch=view.epoch,
                resultReady=view.resultReady,hazards=view.boss and #view.boss.hazards,decoys=view.boss and #view.boss.decoys,
                stone=view.boss and view.boss.stone,invisible=view.boss and view.boss.invisible,
                cloud=view.cloud~=nil,immobilized=(view.immobilized or 0)>0,form=view.form,vigor=view.vigor,
                bossHp=view.bossHp,snakes=#(view.snakes or {}),projectiles=#(view.projectiles or {})}
        end
    end
    local x,z=keyboardDirection()
    local locked=arena.IsLocked()
    if uiPressed.lock then arena.ToggleLock();locked=arena.IsLocked();uiPressed.lock=nil end
    if uiPressed.sprint then sprintToggle=not sprintToggle;uiPressed.sprint=nil end
    local heavy=UE.Input.GetMouseButton(1) or uiHeld.heavy==true
    local spin=UE.Input.GetKey("v") or uiHeld.spin==true
    local stickLength=math.sqrt(stick.x*stick.x+stick.y*stick.y)
    local walk=UE.Input.GetKey(UE.KeyCode.LeftControl) or UE.Input.GetKey(UE.KeyCode.LeftAlt)
        or stickLength>0 and stickLength<0.5
    local sprint=UE.Input.GetKey(UE.KeyCode.LeftShift) or sprintToggle
    local route=arena.IsRouteActive()
    if DouyinApplication.isSimulator and UE.Input.GetKeyDown(UE.KeyCode.F7) then
        replay={age=0,fired={},combo={}}
        print("[WK-COMBAT-REPLAY] start")
    end
    if replay then x,z,sprint,heavy=replayInput(v,dt);locked=arena.IsLocked();walk=false end
    if DouyinApplication.isSimulator and (UE.Input.GetKeyDown(UE.KeyCode.F6)
        or not autoProbeStarted and UE.GameObject.Find("BossDebugAutoRun")~=nil and actor.actorID==2) then
        autoProbeStarted=true;bossReplay={age=0,fired={}};print("[WK-BOSS-REPLAY] start")
    end
    if bossReplay then x,z,sprint,heavy=bossReplayInput(v,dt);locked=arena.IsLocked();walk=false end
    if DouyinApplication.isSimulator and (UE.Input.GetKeyDown(UE.KeyCode.F5)
        or not autoProbeStarted and UE.GameObject.Find("SkillsDebugAutoRun")~=nil and actor.actorID==2) then
        autoProbeStarted=true;skillsReplay={age=0,fired={}};print("[WK-SKILLS-REPLAY] start")
    end
    if skillsReplay then x,z,sprint,heavy,spin=skillsReplayInput(v,dt);locked=arena.IsLocked();walk=false end
    local direction="F"
    if locked then
        if math.abs(x)+math.abs(z)<0.01 then direction="B"
        else
            local rel=math.atan(x,z)-(actor.rotation.eulerAngles.y*math.pi/180)
            rel=(rel+math.pi)%(2*math.pi)-math.pi
            direction=math.abs(rel)<math.pi/4 and "F" or math.abs(rel)>3*math.pi/4 and "B" or rel>0 and "L" or "R"
        end
    end
    -- The platform's full-screen input surface also counts as "over UI".
    -- Our pointer callbacks identify which combat control consumed the press.
    local overUI=hud and hud.IsPointerOver(UE.Input.mousePosition) or false
    for _,held in pairs(uiHeld) do if held then overUI=true end end
    local modal=hud and hud.IsModal()
    if not modal then
    if (not overUI and UE.Input.GetMouseButtonDown(0)) or uiPressed.light then enqueue("light") end
    if (not overUI and UE.Input.GetMouseButtonDown(1)) or uiPressed.heavy then enqueue("heavy") end
    if UE.Input.GetKeyDown(UE.KeyCode.Space) or uiPressed.dodge then enqueue("dodge") end
    if UE.Input.GetKeyDown(UE.KeyCode.R) or uiPressed.gourd then enqueue("gourd") end
    for _,row in ipairs({{"z","stance:smash"},{"x","stance:pillar"},{"c","stance:thrust"},{"v","spin"},{"1","immobilize"},{"2","cloud"},{"4","transform"},{"f","spirit"}}) do
        if UE.Input.GetKeyDown(row[1]) then enqueue(row[2]) end
    end
    for _,name in ipairs({"stanceCycle","spin","immobilize","cloud","transform","spirit"}) do if uiPressed[name] then enqueue(name) end end
    if UE.Input.GetKeyDown(UE.KeyCode.Return) or uiPressed.challenge then
        enqueue(v and (v.challenge=="defeat" or v.challenge=="victory") and "retry" or "start")
    end
    else x,z,sprint,heavy,spin=0,0,false,false,false end
    uiPressed={}
    if DouyinApplication.isSimulator then
        if UE.Input.GetKeyDown(UE.KeyCode.F8) then enqueue("test-suite") end
        if UE.Input.GetKeyDown(UE.KeyCode.F9) then
            enqueue("test-reset")
            actor:Teleport(boss.transform.position+UE.Vector3(0,0.15,-3.3),UE.Quaternion.identity)
            arena.SetLocked(true)
        end
        if UE.Input.GetKeyDown(UE.KeyCode.F10) then enqueue("test-strike") end
    end
    sendAge=sendAge+dt
    if sendAge>=0.05 or #pending>0 then
        sendAge=0;state.Send(json.encode({x=route and 0 or x,z=route and 0 or z,
            sprint=sprint,walk=walk,heavy=heavy,spin=spin,locked=locked,direction=direction,commands=pending,
            cameraYaw=DouyinCameraService.GetYaw() or 0}))
    end
    if route then velocityX=0;velocityZ=0;return end
    local vx,vz=0,0
    if pose and v and v.hp>0 and (v.challenge=="fight" or v.challenge=="ready") then
        local motionDt=dt*(v.slow or 1)
        local old=pose.t;local done=K.advance(pose,motionDt)
        if pose.kind=="free" then
            local movement=v.movement or C.player.movement
            local speed=sprint and v.stamina>0 and v.depleted<=0 and not walk and movement.sprint
                or walk and movement.walk or movement.run
            if v.cloud then speed=speed*(walk and 1.1 or 1.15) end
            vx=x*speed;vz=z*speed
            if locked then
                local yaw=actor.rotation.eulerAngles.y*math.pi/180
                if x*math.sin(yaw)+z*math.cos(yaw)<0 then vx=vx*movement.backwardRate;vz=vz*movement.backwardRate end
            end
            velocityX,velocityZ=K.velocity(velocityX,velocityZ,vx,vz,locked,
                x*x+z*z<0.001 and 0 or sprint and speed==C.player.movement.sprint and 3 or walk and 1 or 2,dt)
            vx=velocityX;vz=velocityZ
            vx=vx*(v.slow or 1);vz=vz*(v.slow or 1)
        elseif not done then
            velocityX=0;velocityZ=0
            local b,p=boss.transform.position,actor.position
            local surface=math.sqrt((b.x-p.x)^2+(b.z-p.z)^2)-C.capsule.radius-C.bossCapsule.radius
            local forward,side=K.rootDelta(pose,old,pose.t,locked and surface or nil)
            local yaw=actor.rotation.eulerAngles.y*math.pi/180
            vx=(forward*math.sin(yaw)+side*math.cos(yaw))/math.max(dt,0.001)
            vz=(forward*math.cos(yaw)-side*math.sin(yaw))/math.max(dt,0.001)
        end
        local target
        if locked and pose.kind~="dodge" and pose.kind~="perfectDodge" then
            local d=boss.transform.position-actor.position;target=UE.Mathf.Atan2(d.x,d.z)*UE.Mathf.Rad2Deg
        elseif x*x+z*z>0.001 and pose.kind=="free" then target=UE.Mathf.Atan2(x,z)*UE.Mathf.Rad2Deg end
        if target then
            local yaw=actor.rotation.eulerAngles.y
            local movement=v.movement or C.player.movement
            local limit=movement.turnSpeed
            if math.abs(UE.Mathf.DeltaAngle(yaw,target))>90 then limit=movement.bigTurnSpeed end
            actor.rotation=UE.Quaternion.Euler(0,UE.Mathf.MoveTowardsAngle(yaw,target,limit*dt),0)
        end
    end
    local speed=math.sqrt(vx*vx+vz*vz)
    if speed>0.01 then actor.speed=speed;actor:MoveContinuously(UE.Vector2(vx/speed,vz/speed))
    else actor:StopMove() end
end
function OnApplicationFocus(value)
    if not value then stick=UE.Vector2.zero;uiHeld={};uiPressed={};sprintToggle=false;if actor then actor:StopMove() end end
end
function OnDestroy()
    if DouyinApplication.isServer then return end
    if moveStart then DouyinInputService.onMoveInputStart:RemoveListener(moveStart) end
    if movePerform then DouyinInputService.onMoveInputPerform:RemoveListener(movePerform) end
    if moveCancel then DouyinInputService.onMoveInputCancel:RemoveListener(moveCancel) end
    if onTouch then DouyinInputService.onTouchEvent:RemoveListener(onTouch) end
    for _,b in ipairs(uiBindings) do
        if b.button and not b.button:IsNull() then b.button.onClick:RemoveListener(b.click) end
    end
    -- World disposal has already invalidated Actor services before this callback.
    -- Actor settings disappear with the Actor; do not access them during teardown.
    actor=nil;uiHeld={};pending={}
end
