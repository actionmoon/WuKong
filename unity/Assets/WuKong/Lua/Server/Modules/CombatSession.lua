-- DS owns action legality, resources and hit settlement. No client damage input.
local M = {}
local C, K = WKCombatConfig, WKCombatClock
local D, A = C.player, C.actions
local function player(s) return s.playerData or D end
local function actions(s) return s.actions or A end
local function event(s, name, values)
    values = values or {}; values.ev = name; values.time = s.time; values.play = s.play
    values.actor = s.actorID
    if s.emit then s.emit(values) end
end
function M.new(actorID, emit)
    local s={actorID=actorID, hp=D.stats.hpMax,mp=D.stats.mpMax,stamina=D.stamina.max,
        focus=0,gourd=D.gourd.charges,bossHp=C.bossStats.hp,time=0,play=0,
        noRegen=0,depleted=0,lastFocus=0,invuln=0,clip=A.idle,t=0,
        vx=0,vz=0,moveX=0,moveZ=0,yaw=0,emit=emit,hits=0,heals=0,perfect=0}
    if WKSkillsSession then WKSkillsSession.init(s) end
    return s
end
function M.pips(s)
    local D=player(s)
    local level=0
    for _, e in ipairs(D.focus.configs[tostring(D.focus.activeConfig)]) do
        if s.focus >= e.threshold then level=e.level end
    end
    return level
end
local function gain(s,v)
    s.focus=math.max(0,math.min(s.form=="lang" and 100 or 480,s.focus+v));s.lastFocus=s.time
end
local function spend(s,n)
    local D=player(s)
    if not n or n<=0 then return end
    s.stamina=math.max(0,s.stamina-n)
    if s.stamina==0 then
        s.noRegen=D.stamina.depletion.noRegenSec;s.depleted=D.stamina.depletion.staminaDepletedStateSec
        event(s,"depleted")
    end
end
local function play(s,kind,clip,spec,step)
    if WKSkillsSession then WKSkillsSession.beforePlay(s,kind,spec) end
    s.play=s.play+1;s.action={kind=kind,clip=clip,t=0,prev=0,spec=spec,step=step,
        hitKeys={},previousBones={},fired={},armor={}}
    s.clip=clip;s.t=0;s.sprinting=false
    -- Casting while depleted removes the initial regen-block buff, as in BUS_StaminaComp.
    if s.depleted>0 then s.noRegen=0 end
    event(s,"action",{kind=kind,clip=clip,skill=spec and spec.skill,step=step})
end
local function free(s)
    s.action=nil;s.clip=actions(s).idle;s.t=0
end
local function attack(s,kind,spec,step)
    if s.stamina < (spec.minStaminaToStart or 0) then event(s,"rejected",{reason="stamina"});return false end
    spend(s,spec.staminaCost);play(s,kind,spec.clip,spec,step);return true
end
local function dodge(s,chain)
    local D=player(s)
    if s.stamina<=0 then return false end
    local key=s.dodgeDirection or (s.locked and "B" or "F")
    if s.warningUntil and s.time<=s.warningUntil and s.warningAward~=s.warningID then
        s.warningAward=s.warningID;s.invuln=s.time+D.dodge.perfect.rewards.invulnerableSec
        gain(s,D.dodge.perfect.rewards.focusGain);s.perfect=s.perfect+1
        s.bossSlowUntil=s.time+0.3
        play(s,"perfectDodge",D.dodge.perfect.clips[key]);event(s,"perfectDodge",{warning=s.warningID})
    else
        local spec=D.dodge.chain[chain]
        spend(s,spec.staminaCost);play(s,"dodge",spec.clips[key],nil,chain)
    end
    if WKSkillsSession then WKSkillsSession.dodged(s,key) end
    return true
end
local function charge(s)
    local spec=D.heavy.levels[M.pips(s)+1]
    if s.stamina<(spec.minStaminaToStart or 0) then return false end
    spend(s,spec.chargeStartCost);s.chargeTime=0;s.loopTime=0
    play(s,"heavyStart",spec.chargeStartClip);return true
end
local function release(s)
    local level=M.pips(s);local spec=D.heavy.levels[level+1]
    spend(s,spec.staminaCost);play(s,"heavy",spec.clip,spec)
    s.action.level=level
    local hasClear=false
    for _,e in ipairs(C.clips[spec.clip].events) do if e.type=="focus" and e.value==-99 then hasClear=true end end
    if not hasClear then s.focus=0 end
    event(s,"heavyRelease",{level=level})
end
local function gourd(s)
    if s.gourd<=0 then event(s,"rejected",{reason="gourd-empty"});return false end
    play(s,"gourd",D.gourd.clip);return true
end
function M.press(s,name)
    if s.hp<=0 then return end
    if s.challenge and s.challenge~="fight" then return end
    if WKSkillsSession and WKSkillsSession.immediate(s,name) then return end
    if WKSkillsSession and not WKSkillsSession.accepts(s,name) then return end
    local a=s.action
    if a then
        local meta=C.clips[a.clip]
        local ok
        if name=="dodge" then ok=K.active(meta,a.t,"dodgeInputBuffer") or K.active(meta,a.t,"dodgeWindow") or K.active(meta,a.t,"hitCancel")
        elseif name=="gourd" then ok=K.active(meta,a.t,"itemWindow") or K.active(meta,a.t,"inputBuffer")
        elseif name=="transform" or name=="spirit" then ok=K.active(meta,a.t,"comboWindow") or K.active(meta,a.t,"dodgeWindow") or K.active(meta,a.t,"inputBuffer")
        elseif WKSkillsSession and WKSkillsSession.isCast(name) then ok=K.active(meta,a.t,"magicWindow") or K.active(meta,a.t,"magicBuffer") or K.active(meta,a.t,"inputBuffer")
        else ok=K.active(meta,a.t,"inputBuffer") or K.active(meta,a.t,"comboWindow") end
        if not ok then event(s,"inputIgnored",{name=name,t=a.t});return end
    end
    s.queued=name;s.queuedAt=s.time
end
local function consume(s)
    local D=player(s)
    local q=s.queued
    if not q then return end
    local a=s.action
    if s.time-s.queuedAt>(a and 1 or 0.4) then s.queued=nil;return end
    local meta=a and C.clips[a.clip]
    local permitted=not a
    local nextStep=1
    if WKSkillsSession then
        local handled,allowed=WKSkillsSession.permitted(s,q,a,meta)
        if handled then
            if allowed then s.queued=nil;WKSkillsSession.execute(s,q) end
            return
        end
    end
    if a and q=="dodge" then permitted=K.active(meta,a.t,"dodgeWindow") or K.active(meta,a.t,"hitCancel")
    elseif a and q=="gourd" then permitted=K.active(meta,a.t,"itemWindow")
    elseif a then
        local cw=K.active(meta,a.t,"comboWindow")
        if q=="light" then
            nextStep=a.kind=="light" and (a.step%#D.lightCombo+1) or 1
            permitted=cw and K.allowed(cw,D.lightCombo[nextStep].skill)
        elseif q=="heavy" then
            local spec=D.heavy.levels[M.pips(s)+1]
            permitted=cw and K.allowed(cw,spec.chargeStartSkill or spec.skill)
        end
    end
    if not permitted then return end
    s.queued=nil
    if q=="dodge" then dodge(s,a and a.kind=="dodge" and (a.step%#D.dodge.chain+1) or 1)
    elseif q=="light" then
        if not a and s.sprinting then attack(s,"sprintLight",D.sprintLight)
        else attack(s,"light",D.lightCombo[nextStep],nextStep) end
    elseif q=="heavy" then charge(s)
    elseif q=="gourd" then gourd(s) end
end
function M.input(s,x,z,sprint,walk,heavy,locked)
    s.moveX=K.clamp(x or 0,-1,1);s.moveZ=K.clamp(z or 0,-1,1)
    s.wantSprint=sprint;s.walk=walk;s.heavyHeld=heavy;s.locked=locked;s.lastInput=s.time
end
local function heal(s)
    local a=s.action
    if not a or a.kind~="gourd" or a.healed then return end
    a.healed=true;s.gourd=s.gourd-1;s.heals=s.heals+1
    local n=D.stats.hpMax*D.gourd.healPctOfHpMax+D.gourd.healFlat
    s.hp=math.min(D.stats.hpMax,s.hp+n)
    event(s,"heal",{amount=n,hp=s.hp,left=s.gourd})
end
function M.update(s,dt)
    local D,A=player(s),actions(s)
    s.time=s.time+dt;s.noRegen=math.max(0,s.noRegen-dt);s.depleted=math.max(0,s.depleted-dt)
    if s.lastInput and s.time-s.lastInput>0.5 then s.moveX=0;s.moveZ=0;s.wantSprint=false;s.heavyHeld=false;s.spinHeld=false end
    if WKSkillsSession then WKSkillsSession.tick(s,dt);D,A=player(s),actions(s) end
    local a=s.action
    local blocked=s.noRegen>0 or s.sprinting or (a and K.active(C.clips[a.clip],a.t,"cost"))
    if not blocked then s.stamina=math.min(D.stamina.max,s.stamina+D.stamina.regenPerSec*dt) end
    local cfg=D.focus.configs[tostring(D.focus.activeConfig)]
    local level=M.pips(s);local l=cfg[level+1]
    if l and l.decayPerSec>0 and l.protectTime>=0 and s.time-s.lastFocus>=l.protectTime
        and not (a and (string.sub(a.kind,1,5)=="heavy" or a.kind=="stance:charge")) then
        local floor=level==cfg[#cfg].level and cfg[level].threshold or l.threshold
        s.focus=math.max(floor,s.focus-l.decayPerSec*dt)
    end
    consume(s);a=s.action
    if not a then
        local length=math.sqrt(s.moveX*s.moveX+s.moveZ*s.moveZ)
        s.sprinting=length>0.01 and s.wantSprint and not s.walk and s.stamina>0 and s.depleted<=0
        local speed=s.sprinting and D.movement.sprint or s.walk and D.movement.walk or D.movement.run
        if s.cloud then speed=speed*(s.walk and 1.1 or 1.15) end
        if length<0.01 or s.hp<=0 then speed=0 end
        if s.locked and length>0 then
            local dot=s.moveX*math.sin(s.yaw)+s.moveZ*math.cos(s.yaw)
            if dot<0 then speed=speed*D.movement.backwardRate end
        end
        local tx,tz=s.moveX/math.max(length,1)*speed,s.moveZ/math.max(length,1)*speed
        local gait=length<0.01 and 0 or s.sprinting and 3 or s.walk and 1 or 2
        s.vx,s.vz=K.velocity(s.vx,s.vz,tx,tz,s.locked,gait,dt)
        if s.sprinting then spend(s,D.stamina.sprintPerSec*dt) end
        local v=math.sqrt(s.vx*s.vx+s.vz*s.vz)
        s.clip=v<0.1 and A.idle or s.sprinting and A.sprint or v>1.6 and A.run or A.walk
        local base=s.clip==A.sprint and D.movement.sprint or s.clip==A.run and D.movement.run or D.movement.walk
        if v>=0.1 and s.locked and not s.sprinting then
            local forward=s.vx*math.sin(s.yaw)+s.vz*math.cos(s.yaw)
            local right=s.vx*math.cos(s.yaw)-s.vz*math.sin(s.yaw)
            local key=math.abs(right)<=v*0.5 and (forward>=0 and "F" or "B")
                or right>0 and (forward>=0 and "LF" or "LB") or (forward>=0 and "RF" or "RB")
            local set=v>3 and A.lockRun or A.lockWalk
            s.clip=set[key]
            base=v>3 and D.movement.run or D.movement.walk
        end
        s.t=(s.t+dt*math.max(0.5,math.min(1.3,v/base)))%C.clips[s.clip].duration
        return
    end
    s.vx=0;s.vz=0
    if WKSkillsSession then WKSkillsSession.actionTick(s,dt);a=s.action end
    if not a then return end
    if a.kind=="heavyStart" or a.kind=="heavyLoop" then
        s.chargeTime=s.chargeTime+dt
        if s.chargeTime>=D.heavy.charge.focusGainStartsAfter and s.focus<330 then
            s.focus=math.min(330,s.focus+D.heavy.charge.focusGainPerSec*dt);s.lastFocus=s.time
        end
        if a.kind=="heavyLoop" then
            s.loopTime=s.loopTime+dt
            if s.loopTime>=D.heavy.loopLength then s.loopTime=s.loopTime-D.heavy.loopLength;spend(s,D.heavy.loopStaminaCost) end
        end
        if not s.heavyHeld or s.stamina<=0 then release(s);a=s.action end
    end
    local finished,wrapped=K.advance(a,dt)
    if WKSkillsSession then WKSkillsSession.events(s,a) end
    if s.action~=a then return end
    for i,e in ipairs(C.clips[a.clip].events) do
        if e.time and not a.fired[i] and e.time>a.prev and e.time<=a.t then
            a.fired[i]=true
            if e.type=="heal" then heal(s)
            elseif e.type=="focus" then if e.value==-99 then s.focus=0 else gain(s,e.value or 0) end end
        end
    end
    if a.kind=="gourd" and a.t>=D.gourd.healTime then heal(s) end
    s.clip=a.clip;s.t=a.t
    if finished then
        if WKSkillsSession and WKSkillsSession.finished(s,a) then
        elseif a.kind=="heavyStart" then play(s,"heavyLoop",D.heavy.loopClip)
        elseif a.kind~="dead" then free(s) end
    elseif wrapped then a.fired={};a.hitKeys={};a.previousBones={} end
    if s.action then
        local meta=C.clips[s.action.clip]
        local move=K.active(meta,s.action.t,"moveWindow")
        local last=0;local has=false
        for _,e in ipairs(meta.events) do if e.type=="comboWindow" then last=math.max(last,e["end"]);has=true end end
        if (math.abs(s.moveX)+math.abs(s.moveZ)>0.01) and (move or
            (has and s.action.t>=last and s.action.kind~="gourd" and s.action.kind~="hit" and s.action.kind~="dead"
                and not string.find(s.action.kind,":",1,true))) then
            event(s,"moveCancel");free(s)
        end
    end
end
function M.resolve(s, bonePosition, boss)
    local D=player(s)
    local a=s.action
    if not a or not a.spec or not a.spec.damage or s.bossHp<=0 then return end
    local cap=C.bossCapsule
    local low={x=boss.x,y=boss.y+cap.radius,z=boss.z}
    local high={x=boss.x,y=boss.y+math.max(2*cap.halfHeight,2*cap.radius)-cap.radius,z=boss.z}
    local current={}
    for i,e in ipairs(C.clips[a.clip].events) do
        if e.type=="hit" and a.t>=e.start and a.prev<e["end"] then
            local key=e.group and e.group>=0 and "g"..e.group or "e"..i
            for n,name in ipairs(e.bones or {}) do
                local p=bonePosition(name)
                if p then
                    current[name]=p
                    local radius=(e.radii and e.radii[n] or e.radius or 0.5)+cap.radius
                    if not a.hitKeys[key] and K.segmentDistance2(a.previousBones[name] or p,p,low,high)<=radius*radius then
                        local id
                        for _,effect in ipairs(e.effects or {e.id}) do if a.spec.damage[tostring(effect)] then id=tostring(effect);break end end
                        if id then
                            a.hitKeys[key]=true
                            local damage,crit,bounced
                            if s.bossReceive then damage,crit,bounced=s.bossReceive(a.spec.damage[id],a.spec.skill)
                            else
                                damage,crit=K.damage(D.stats,C.bossStats,a.spec.damage[id],false,C.bossStats.hp,s.rng)
                                s.bossHp=math.max(0,s.bossHp-damage)
                            end
                            s.hits=s.hits+1
                            if bounced then
                                M.rebound(s,a.spec.skill)
                                return
                            end
                            local gains=a.spec.focusGain or {}
                            for _,g in ipairs(gains) do
                                if #gains==1 or string.sub(tostring(g.effect),-1)==string.sub(id,-1) then gain(s,g.value);break end
                            end
                            if WKSkillsSession then WKSkillsSession.hit(s,a,e,id,damage) end
                            event(s,"hit",{group=key,effect=id,damage=damage,crit=crit,bossHp=s.bossHp,t=a.t})
                        end
                    end
                end
            end
        end
    end
    a.previousBones=current
end
function M.rebound(s,skill)
    local D=player(s)
    local clip=D.reboundClips and D.reboundClips[tostring(skill)]
    if clip then play(s,"rebound",clip);event(s,"rebound",{clip=clip}) end
end
function M.receive(s,effect,warningID)
    local D,A=player(s),actions(s)
    local a=s.action
    if s.hp<=0 then return 0 end
    if WKSkillsSession and WKSkillsSession.parry(s,effect) then return 0 end
    if (s.time<s.invuln or (a and K.active(C.clips[a.clip],a.t,"iframe"))) and (effect.damageImmuneLevel or 0)<1 then
        event(s,"invulnerable",{warning=warningID});return 0
    end
    local stats=D.stats
    if s.cloud then
        stats={};for k,v in pairs(D.stats) do stats[k]=v end
        stats.dmgDef=(stats.dmgDef or 0)+2000
    end
    local damage=K.damage(C.bossStats,stats,effect,true,D.stats.hpMax,s.rng)
    if a and (a.kind=="heavyStart" or a.kind=="heavyLoop") then damage=math.floor(damage*(1-D.heavy.charge.damageReductionWhileCharging)) end
    s.hp=math.max(0,s.hp-damage);event(s,"playerHit",{damage=damage,hp=s.hp})
    if s.hp<=0 then
        if WKSkillsSession and WKSkillsSession.zeroHP(s) then return damage end
        if WKSkillsSession then WKSkillsSession.interrupted(s,"death") end
        play(s,"dead",A.die.F);return damage
    end
    if a then
        local armor,i=K.active(C.clips[a.clip],a.t,"superArmor")
        if armor then
            a.armor[i]=(a.armor[i] or C.armor[tostring(armor.level)] or 0)-(effect.armorBreak or 0)
            if a.armor[i]>0 then return damage end
        end
    end
    local stiff=(effect.hitWeight or 0)-(D.stats.tenacity or 0)
    if stiff>0 and not s.cloud then
        if WKSkillsSession then WKSkillsSession.interrupted(s,"hit");D,A=player(s),actions(s) end
        local best=1
        for key in pairs(A.hitByStiffLevel) do local lv=tonumber(key);if lv<=stiff and lv>best then best=lv end end
        local pool=A.hitByStiffLevel[tostring(best)]
        local selected=pool[1]
        for _,clip in ipairs(pool) do if string.find(clip,"_df_",1,true) then selected=clip;break end end
        play(s,"hit",selected)
    end
    return damage
end
function M.snapshot(s)
    local v={actorID=s.actorID,hp=s.hp,mp=s.mp,stamina=s.stamina,focus=s.focus,pips=M.pips(s),
        gourd=s.gourd,bossHp=s.bossHp,clip=s.clip,t=s.t,play=s.play,time=s.time,
        kind=s.action and s.action.kind or "free",vx=s.vx,vz=s.vz,locked=s.locked,
        step=s.action and s.action.step,
        hits=s.hits,heals=s.heals,perfect=s.perfect,depleted=s.depleted}
    if WKSkillsSession then WKSkillsSession.snapshot(s,v) end
    return v
end
M.play=play;M.free=free;M.spend=spend;M.gain=gain;M.attack=attack;M.event=event
M.player=player;M.actions=actions
return M
