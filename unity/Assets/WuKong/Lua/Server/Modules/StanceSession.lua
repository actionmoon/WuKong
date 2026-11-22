-- Source stance graph, with montage costs and server sampled staff/body geometry.
local M={}
local D,K,S=WKSkillsConfig.stances,WKCombatClock,WKCombatSession
local function chargeRow(s,a) return D[a and a.mode or s.stance][(a and a.level or S.pips(s))+1] end
local function begin(s,kind,entry,extra)
    if s.stamina<(entry.minStaminaToStart or 0) or s.stamina<=0 then return false end
    S.play(s,kind,entry.clip,entry)
    local a=s.action
    for k,v in pairs(extra or {}) do a[k]=v end
    for _,b in ipairs(entry.buffs or {}) do
        if b.buff==116 and b.start<=0.01 then S.gain(s,-100) end
    end
    return true
end
function M.follow(s,a,cw)
    if not a or not cw then return nil end
    local f=D.followUps
    if a.kind=="light" or a.kind=="sprintLight" then
        if s.stance=="smash" and S.pips(s)>0 then return f.smash.shipo end
        if s.stance=="thrust" then return f.thrust.tuicun end
        if s.stance=="pillar" and S.pips(s)>0 then return f.pillar.fengyunzhuan.start,"stance:fyz" end
    elseif a.kind=="stance:attack" then
        if a.spec.skill==f.smash.shipo.skill and s.time<(s.shHitUntil or 0) and S.pips(s)>0 then return f.smash.zhangunshi end
        if a.spec.skill==f.thrust.tuicun.skill and S.pips(s)>0 then return f.thrust.tuicunThrust end
    end
end
function M.heavy(s)
    local a=s.action;local cw=a and K.active(WKCombatConfig.clips[a.clip],a.t,"comboWindow")
    local e,kind=M.follow(s,a,cw)
    if e and K.allowed(cw,e.skill) then return begin(s,kind or "stance:attack",e,{stage=kind and "begin" or nil}) end
    if s.stance=="smash" then return false end
    local l=chargeRow(s)
    return begin(s,"stance:charge",l.start,{mode=s.stance,level=S.pips(s),stage="begin",age=0,
        gainAt=math.max(0,l.focusGain.begin<0 and l.start.length+l.focusGain.begin or l.focusGain.begin),
        gainRate=l.focusGain.perSec,released=not s.heavyHeld})
end
function M.spin(s) return begin(s,"stance:spin",D.spin.start,{stage="begin",released=not s.spinHeld}) end
local function release(s,a)
    local lv=a.mode=="pillar" and a.level or S.pips(s)
    local e=D[a.mode][lv+1].attack
    S.play(s,"stance:attack",e.clip,e);s.action.level=lv;s.action.mode=a.mode
    s.focus=0;S.event(s,"stanceHeavy",{stance=a.mode,level=lv})
end
local function loop(s,a)
    local clip,spec
    if a.kind=="stance:charge" then clip=chargeRow(s,a).charge.loopClip
    elseif a.kind=="stance:spin" then clip=D.spin.loopClip;spec=D.spin.loop
    else clip=D.followUps.pillar.fengyunzhuan.charge.loopClip;spec=D.followUps.pillar.fengyunzhuan.loop end
    S.play(s,a.kind,clip,spec)
    for _,k in ipairs({"mode","level","age","gainAt","gainRate","released"}) do s.action[k]=a[k] end
    s.action.stage="loop"
end
function M.tick(s,dt)
    local a=s.action
    if not a then return end
    if a.kind=="stance:charge" then
        a.age=(a.age or 0)+dt;a.released=a.released or not s.heavyHeld
        if a.age>=(a.gainAt or 0) and s.focus<330 then S.gain(s,math.min(330-s.focus,(a.gainRate or 0)*dt)) end
        s.lastFocus=s.time
        local l=chargeRow(s,a)
        if a.mode=="pillar" then
            if s.stamina<=0 then
                S.play(s,"stance:fall",l.fallClip);S.event(s,"pillarFall",{level=a.level});return
            end
            if l.growUp and S.pips(s)>a.level then
                local g=l.growUp
                begin(s,"stance:charge",g,{mode="pillar",level=g.toLevel,stage="begin",age=0,
                    gainAt=math.max(0,g.length+g.focusGain.begin),gainRate=g.focusGain.perSec,released=a.released})
                S.event(s,"pillarGrow",{level=g.toLevel});return
            end
        elseif s.stamina<=0 then release(s,a);return end
        if a.released and a.stage=="loop" then release(s,a) end
    elseif a.kind=="stance:spin" or a.kind=="stance:fyz" then
        a.released=a.released or not (a.kind=="stance:spin" and s.spinHeld or a.kind=="stance:fyz" and s.heavyHeld)
        if a.stage=="loop" and (a.released or s.stamina<=0 or a.kind=="stance:spin" and (s.queued=="heavy" or math.abs(s.moveX)+math.abs(s.moveZ)>0.01)) then
            local left=false
            for _,b in ipairs(D.spin.loop.buffs or {}) do if b.buff==D.spin.sideBuffs.left and a.t>=b.start and a.t<b["end"] then left=true end end
            local e=a.kind=="stance:spin" and D.spin["end"][left and "left" or "right"] or D.followUps.pillar.fengyunzhuan["end"]
            if a.kind=="stance:spin" then s.queued=nil end
            -- End montages are legal even after stamina depletion.
            S.play(s,"stance:attack",e.clip,e)
        end
    end
end
function M.events(s,a)
    if string.sub(a.kind,1,7)~="stance:" then return end
    for i,e in ipairs(WKCombatConfig.clips[a.clip].events) do
        if e.type=="cost" and a.t>=e.start and not a.fired["cost"..i] then
            a.fired["cost"..i]=true;S.spend(s,WKSkillsConfig.stanceCosts[tostring(e.effect)] or 0)
        end
    end
end
function M.finished(s,a)
    if (a.kind=="stance:charge" or a.kind=="stance:spin" or a.kind=="stance:fyz") and a.stage=="begin" then loop(s,a);return true end
    return false
end
function M.parry(s,effect)
    if (effect.damageImmuneLevel or 0)>=1 then return false end
    local a=s.action
    if a and a.kind=="stance:attack" and a.spec.skill==D.followUps.smash.shipo.skill and a.t<D.followUps.smash.shipo.gpBuff.duration then
        if not a.gp then
            a.gp=true;s.gpUntil=s.time+D.followUps.smash.guansuo.buffDuration
            S.event(s,"shipo",{untilTime=s.gpUntil})
        end
        return true
    end
    return false
end
function M.hit(s,a)
    if a.spec and a.spec.skill==D.followUps.smash.shipo.skill then s.shHitUntil=s.time+3 end
end
function M.hurtSegment(s)
    local a=s.action
    if a and a.kind=="stance:charge" and a.mode=="pillar" and s.bone then
        local low,high=s.bone("pelvis"),s.bone("head")
        if low and high then return low,high,0.32 end
    end
end
function M.staffContact(s,p,q,r,effect)
    local a=s.action
    if not a or a.kind~="stance:charge" or a.mode~="pillar" or not s.bone then return false end
    local low,high=s.bone("weapon_tou_1"),s.bone("weapon_wei_1")
    if low and high and K.segmentDistance2(p,q,low,high)<=(r+0.12)^2 then
        local damage=K.damage(WKCombatConfig.bossStats,WKCombatConfig.player.stats,effect,true,WKCombatConfig.player.stats.hpMax,s.rng)
        S.spend(s,damage*0.8);S.event(s,"pillarStaffHit",{stamina=s.stamina,cost=damage*0.8});return true
    end
    return false
end
function M.blockBullet(s,h,old)
    local a=s.action
    if not a or a.kind~="stance:spin" or a.stage~="loop" or not s.bone then return false end
    local p=s.bone(D.spin.projectileSweep.socket)
    local shape=WKBossConfig.bullets[h.id] and WKBossConfig.bullets[h.id].shape or {}
    local radius=D.spin.projectileSweep.radius+(shape.sphere or shape.capsule and shape.capsule.radius or shape.box and math.min(shape.box[1],shape.box[2]) or 0)
    if p and K.segmentDistance2(old,h.pos,p,p)<=radius^2 then
        S.event(s,"spinBlock",{key=h.key});return true
    end
    return false
end
return M
