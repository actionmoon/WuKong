local M={}
local S,K=WKCombatSession,WKCombatClock
local St,Sp,F=WKStanceSession,WKSpellSession,WKFormSession
function M.init(s)
    s.stance="smash";s.form="wukong";s.formPhase="none";s.spiritPhase="none"
    s.transEnergy=WKSkillsConfig.bianhua.transform.energy.max;s.vigor=WKSkillsConfig.bianhua.spirit.energy.max
    s.cooldowns={};s.snakes={};s.projectiles={};s.buffs={}
end
function M.isCast(q) return q=="immobilize" or q=="cloud" or q=="transform" or q=="spirit" end
function M.accepts(s,q)
    if s.formPhase~="none" or s.spiritPhase~="none" then
        return s.form=="lang" and s.formPhase=="born" and (q=="transform" or q=="light" or q=="heavy" or q=="dodge")
    end
    if s.form=="lang" and (q=="gourd" or q=="spin" or q=="cloud" or q=="immobilize" or q=="spirit") then return false end
    return true
end
function M.immediate(s,q)
    if q=="stanceCycle" or string.sub(q,1,7)=="stance:" then
        if s.form=="wukong" and s.formPhase=="none" and s.spiritPhase=="none" then
            local nextStance=q=="stanceCycle" and (s.stance=="smash" and "pillar" or s.stance=="pillar" and "thrust" or "smash") or string.sub(q,8)
            if nextStance=="smash" or nextStance=="pillar" or nextStance=="thrust" then s.stance=nextStance;S.event(s,"stance",{stance=s.stance}) end
        end
        return true
    end
    return false
end
function M.permitted(s,q,a,meta)
    local cw=a and K.active(meta,a.t,"comboWindow")
    if M.isCast(q) then
        if q=="transform" or q=="spirit" then return true,not a or cw~=nil or K.active(meta,a.t,"dodgeWindow")~=nil or K.active(meta,a.t,"moveWindow")~=nil end
        return true,not a or K.active(meta,a.t,"magicWindow")~=nil
    end
    if s.form=="lang" and (q=="heavy" or q=="light") then
        local spec
        if q=="heavy" then spec=F.heavySpec(s)
        else
            local step=a and a.kind=="light" and ((a.step or 1)%4+1) or 1
            spec=(S.pips(s)>=1 and WKSkillsConfig.bianhua.form.lightComboFire or WKSkillsConfig.bianhua.form.lightCombo)[step]
        end
        return true,not a or cw and K.allowed(cw,spec.skill)
    end
    if q=="spin" then return true,not a or cw~=nil end
    if q=="light" and s.cloud then return true,not a or cw and K.allowed(cw,10096) end
    if q=="light" and a and a.kind=="stance:attack" and a.spec.skill==10705 and s.time<(s.gpUntil or 0) then
        return true,cw and K.allowed(cw,WKCombatConfig.player.lightCombo[3].skill)
    end
    if q=="heavy" then
        if a and (a.kind=="stance:charge" or a.kind=="stance:fyz" or a.kind=="stance:spin") then return true,false end
        local e=St.follow(s,a,cw)
        if e then return true,cw and K.allowed(cw,e.skill) end
        if s.stance~="smash" then
            local e=WKSkillsConfig.stances[s.stance][S.pips(s)+1].start
            return true,not a or cw and K.allowed(cw,e.skill)
        end
    end
    return false
end
function M.execute(s,q)
    if q=="immobilize" or q=="cloud" then Sp.cast(s,q)
    elseif q=="transform" then F.cast(s)
    elseif q=="spirit" then F.spirit(s)
    elseif q=="spin" then St.spin(s)
    elseif q=="heavy" and s.form=="lang" then S.attack(s,"form:heavy",F.heavySpec(s))
    elseif q=="heavy" then St.heavy(s)
    elseif q=="light" and s.cloud then Sp.strike(s)
    elseif q=="light" and s.form=="lang" then
        local a=s.action;local step=a and a.kind=="light" and ((a.step or 1)%4+1) or 1
        local list=S.pips(s)>=1 and WKSkillsConfig.bianhua.form.lightComboFire or WKSkillsConfig.bianhua.form.lightCombo
        S.attack(s,"light",list[step],step)
    elseif q=="light" then S.attack(s,"light",WKCombatConfig.player.lightCombo[3],3) end
end
function M.tick(s,dt) Sp.tick(s,dt);F.tick(s,dt) end
function M.actionTick(s,dt) St.tick(s,dt) end
function M.events(s,a) St.events(s,a);Sp.events(s,a);if s.action==a then F.events(s,a) end end
function M.finished(s,a) return St.finished(s,a) or F.finished(s,a) end
function M.beforePlay(s,kind,spec)
    Sp.beforePlay(s,kind,spec)
    if s.formPhase=="born" and kind~="form:born" and kind~="form:back" then s.formPhase="none" end
end
function M.hit(s,a,e,id,damage) St.hit(s,a);F.hit(s,a,e) end
function M.parry(s,e) return St.parry(s,e) end
function M.zeroHP(s)
    if s.form=="lang" then F.back(s,"hp");return true end
    return false
end
function M.interrupted(s,reason)
    F.abort(s,reason)
    if reason=="death" then Sp.exitCloud(s,reason);s.snakes={};s.projectiles={} end
end
function M.dodged(s,key)
    if s.form=="lang" then
        s.lastDodge=key;s.dodgeUntil=s.time+0.5
        s.transEnergy=math.max(0,s.transEnergy-WKSkillsConfig.bianhua.form.dodge.chain[1].energyCost)
    end
end
function M.cleanup(s)
    Sp.exitCloud(s,"challenge");Sp.breakFreeze(s,"challenge")
    F.abort(s,"challenge");F.cleanup(s);s.snakes={};s.projectiles={};s.queued=nil
    if s.hp>0 then S.free(s) end
end
function M.snapshot(s,v)
    local d=S.player(s)
    v.stance=s.stance;v.form=s.form;v.formPhase=s.formPhase;v.spiritPhase=s.spiritPhase
    v.transEnergy=s.transEnergy;v.vigor=s.vigor;v.cooldowns=s.cooldowns
    v.hpMax=d.stats.hpMax;v.staminaMax=d.stamina.max;v.movement=d.movement
    v.cloud=s.cloud;v.snakes={}
    for _,n in ipairs(s.snakes) do
        v.snakes[#v.snakes+1]={key=n.key,pos=n.pos,yaw=n.yaw,clip=n.clip,t=n.t,phase=n.phase}
    end
    v.projectiles={}
    for _,h in ipairs(s.projectiles) do v.projectiles[#v.projectiles+1]={key=h.key,pos=h.pos} end
    v.immobilized=s.boss and s.boss.immobilized or 0
end
return M
