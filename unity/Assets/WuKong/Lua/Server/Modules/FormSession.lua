local M={}
local D,K,S=WKSkillsConfig.bianhua,WKCombatClock,WKCombatSession
local T,F,P=D.transform,D.form,D.spirit
local function copy(v) local out={};for k,x in pairs(v) do out[k]=x end;return out end
local function inForm(s)
    s.saved={hp=s.hp,stamina=s.stamina,focus=s.focus,lastFocus=s.lastFocus,noRegen=s.noRegen,depleted=s.depleted}
    s.form="lang";s.formPhase="born"
    local data=copy(F);data.stats=copy(WKCombatConfig.player.stats)
    local q=F.statsFromDestinedOne
    for _,v in ipairs({{"hpMax","hp"},{"attack","atk"},{"defense","def"},{"critRate","critRate"},{"critMultiplier","critMultiplier"},{"dmgAddition","dmgAddition"},{"dmgDef","dmgDef"},{"tenacity","tenacity"}}) do
        data.stats[v[1]]=data.stats[v[1]]*(q[v[2].."Mul"] or 1)+(q[v[2].."Base"] or 0)
    end
    data.stats.trueDamageRatio=q.trueDamageRatio
    s.playerData=data;s.actions=WKSkillsConfig.forms.lang.actions
    s.hp=data.stats.hpMax;s.stamina=F.stamina.max;s.focus=0;s.lastFocus=s.time;s.noRegen=0;s.depleted=0
    S.play(s,"form:born",T.born.clip,T.born.spec)
    S.event(s,"bianhuaIn",{hp=s.hp,energy=s.transEnergy})
end
local function outForm(s,reason)
    if not s.saved then return end
    for k,v in pairs(s.saved) do s[k]=v end
    s.saved=nil;s.playerData=nil;s.actions=nil;s.form="wukong";s.formPhase="return"
    s.transEnergy=math.min(T.energy.capAfterReturn,s.transEnergy)+T.energy.max*0.02
    S.play(s,"form:return",T.wukongReturn.clip,{skill=T.wukongReturn.skill})
    S.event(s,"bianhuaOut",{reason=reason,hp=s.hp,energy=s.transEnergy})
end
function M.back(s,reason)
    if s.form~="lang" or s.formPhase=="back" then return false end
    s.formPhase="back";s.backReason=reason;s.invuln=s.time+T.back.swapAt
    S.play(s,"form:back",T.back.clip,{skill=T.back.skill});return true
end
function M.cast(s)
    if s.form=="lang" then return M.back(s,"manual") end
    if s.formPhase~="none" or s.spiritPhase~="none" or s.transEnergy<T.energy.max then
        S.event(s,"rejected",{reason="transform-energy-or-busy"});return false
    end
    s.formPhase="enter";s.invuln=s.time+T.cast.swapAt
    S.play(s,"form:enter",T.cast.clip,{skill=T.cast.skill});return true
end
function M.spirit(s)
    if s.form~="wukong" or s.formPhase~="none" or s.spiritPhase~="none" or s.vigor<P.energy.max then
        S.event(s,"rejected",{reason="spirit-energy-or-busy"});return false
    end
    s.vigor=0;s.spiritPhase="enter";s.cantGainVigor=true
    S.play(s,"spirit:enter",P.enter.clip,{skill=P.enter.skill});S.event(s,"spiritCast");return true
end
local function recover(s)
    s.form="wukong";s.spiritPhase="leave";s.cantGainVigor=false
    S.play(s,"spirit:leave",P.leave.clip,{skill=P.leave.skill});S.event(s,"spiritRecover")
end
function M.abort(s,reason)
    if s.spiritPhase~="none" then
        s.form="wukong";s.spiritPhase="none";s.cantGainVigor=false
        S.event(s,"spiritAbort",{reason=reason})
    end
end
function M.cleanup(s)
    if s.saved then
        for k,v in pairs(s.saved) do s[k]=v end
        s.saved=nil;s.playerData=nil;s.actions=nil
    end
    s.form="wukong";s.formPhase="none";s.spiritPhase="none";s.cantGainVigor=false
end
local function summon(s)
    local cfg=P.summon;local p=s.position or WKArenaConfig.spawn;local candidates={}
    local b=s.boss and s.boss.pos or {x=p.x,y=p.y,z=p.z+10}
    local dx,dz=b.x-p.x,b.z-p.z;local len=math.sqrt(dx*dx+dz*dz)
    for i=0,cfg.eqs.points-1 do
        local a=2*math.pi*i/cfg.eqs.points
        local pos={x=p.x+math.sin(a)*cfg.eqs.circleRadius,y=p.y,z=p.z+math.cos(a)*cfg.eqs.circleRadius}
        pos=s.ground and s.ground(pos) or pos
        if pos then candidates[#candidates+1]={pos=pos,score=(math.sin(a)*dx+math.cos(a)*dz)/math.max(len,0.001)} end
    end
    table.sort(candidates,function(a,b) return a.score>b.score end)
    s.snakes={}
    for i=1,math.min(cfg.count,#candidates) do
        local p=candidates[i].pos
        s.snakes[i]={key=s.play..":"..i,pos=p,yaw=math.atan(b.x-p.x,b.z-p.z),age=0,t=0,
            clip=cfg.bornClip,phase="delay",fired=false,stats=copy(WKCombatConfig.player.stats)}
        s.snakes[i].stats.attack=s.snakes[i].stats.attack*cfg.atkRatio
    end
    S.event(s,"spiritSummon",{count=#s.snakes})
end
local function projectile(s,n)
    local p=s.snakeSocket and s.snakeSocket(n,P.bullet.socket) or {x=n.pos.x,y=n.pos.y+1,z=n.pos.z}
    local target=s.boss and s.boss.bone and s.boss.bone(P.bullet.target) or s.boss and s.boss.pos
    if not p or not target then return end
    local dx,dy,dz=target.x-p.x,target.y-p.y,target.z-p.z;local len=math.sqrt(dx*dx+dy*dy+dz*dz)
    if len<0.001 then return end
    s.projectiles[#s.projectiles+1]={key=n.key..":"..n.age,pos=p,dx=dx/len,dy=dy/len,dz=dz/len,age=0,stats=n.stats}
    S.event(s,"spiritBullet",{socket=P.bullet.socket})
end
local function summonsTick(s,dt)
    local cfg=P.summon
    for i=#s.snakes,1,-1 do
        local n=s.snakes[i];n.age=n.age+dt
        if n.phase=="delay" then
            if n.age>=cfg.bornDelay then n.phase="born";n.t=0 end
        else
            if n.age>=cfg.aliveTime and n.phase~="die" then n.phase="die";n.clip=cfg.dieClip;n.t=0 end
            local old=n.t;n.t=n.t+dt
            if n.phase=="attack" then
                if old<P.bullet.at and n.t>=P.bullet.at then projectile(s,n) end
            end
            if n.t>=WKCombatConfig.clips[n.clip].duration then
                if n.phase=="die" then table.remove(s.snakes,i)
                elseif n.phase=="born" or n.phase=="attack" then
                    n.phase="idle";n.clip=cfg.idleClip;n.t=0
                    n.wait=cfg.attack.gap[1]+(s.rng or math.random)()*(cfg.attack.gap[2]-cfg.attack.gap[1])
                else n.t=0 end
            end
            if n.phase=="idle" then
                n.wait=(n.wait or 1)-dt
                if n.wait<=0 then
                    n.phase="attack";n.clip=cfg.attack.clip;n.t=0
                    if s.boss then n.yaw=math.atan(s.boss.pos.x-n.pos.x,s.boss.pos.z-n.pos.z) end
                end
            end
        end
    end
    for i=#s.projectiles,1,-1 do
        local h=s.projectiles[i];local old=copy(h.pos);h.age=h.age+dt
        local v=P.bullet.speed[1]+(P.bullet.speed[2]-P.bullet.speed[1])*math.min(1,h.age/P.bullet.accelTime)
        h.pos={x=old.x+h.dx*v*dt,y=old.y+h.dy*v*dt,z=old.z+h.dz*v*dt}
        local b=s.boss;local hit=false
        if b and s.bossHp>0 then
            local cap=WKCombatConfig.bossCapsule
            local low={x=b.pos.x,y=b.pos.y+cap.radius,z=b.pos.z}
            local high={x=b.pos.x,y=b.pos.y+2*cap.halfHeight-cap.radius,z=b.pos.z}
            hit=K.segmentDistance2(old,h.pos,low,high)<=(cap.radius+P.bullet.radius)^2
            if hit then
                local damage,_,bounce=s.bossReceive(P.bullet.damage,103801,h.stats)
                S.event(s,"spiritBulletHit",{damage=damage,bounced=bounce})
            end
        end
        if hit or h.age>=P.bullet.life then table.remove(s.projectiles,i) end
    end
end
function M.tick(s,dt)
    if s.form=="lang" then
        s.transEnergy=math.max(0,s.transEnergy-(T.energy.drainPerSec+(s.sprinting and T.energy.sprintDrainPerSec or 0))*dt)
        if s.transEnergy<=0 then M.back(s,"energy") end
    elseif s.formPhase=="none" then s.transEnergy=math.min(T.energy.max,s.transEnergy+T.energy.regenPerSec*dt) end
    if not s.challenge or s.challenge=="fight" then summonsTick(s,dt) end
end
function M.events(s,a)
    if a.kind=="form:enter" and a.t>=T.cast.swapAt then inForm(s);return
    elseif a.kind=="form:back" and a.t>=T.back.swapAt then outForm(s,s.backReason);return
    elseif a.kind=="spirit:enter" and a.t>=P.enter.changeAt then
        s.form="she";s.spiritPhase="form";S.play(s,"spirit:form",P.form.clip,{skill=P.form.skill});S.event(s,"spiritChange");return
    elseif a.kind=="spirit:form" then
        if a.t>=P.form.destroyOldAt and not a.destroyed then s.snakes={};a.destroyed=true end
        if a.t>=P.form.summonAt and not a.summoned then a.summoned=true;summon(s) end
        if a.t>=P.form.recoverAt then recover(s);return end
    end
    if s.form=="lang" and a.spec then
        for i,e in ipairs(a.spec.triggers or {}) do
            if a.t>=e.time and not a.fired["trans"..i] then
                a.fired["trans"..i]=true;M.effect(s,e.effect)
            end
        end
    end
end
function M.effect(s,id)
    id=tostring(id)
    if T.energyEffects[id] then s.transEnergy=math.max(0,s.transEnergy-T.energyEffects[id]) end
    if T.peEffects[id] then S.gain(s,T.peEffects[id]) end
    if T.buffEffects[id]==12030 then s.r2HitUntil=s.time+1 end
    if T.healEffects[id] then s.hp=S.player(s).stats.hpMax end
end
function M.hit(s,a,e)
    if s.form=="lang" then for _,id in ipairs(a.spec.hitEffects or {}) do M.effect(s,id) end
    elseif not s.cantGainVigor then
        local seen={};local gained=0
        for _,id in ipairs(e.effects or {e.id}) do
            id=tostring(id);local v=P.energy.gainByEffect[id]
            if v and not seen[id] then gained=gained+v;seen[id]=true end
        end
        if gained==0 then gained=WKSkillsConfig.vigorBySkill[tostring(a.spec and a.spec.skill)] or 0 end
        s.vigor=math.min(P.energy.max,s.vigor+gained)
    end
end
function M.heavySpec(s)
    local a=s.action;local h=F.heavy;local full=S.pips(s)>=1
    if a and a.spec and s.time<(s.r2HitUntil or 0) then
        if a.spec.skill==h.r2.skill then return h.r2Follow end
        if a.spec.skill==h.r2Fire.skill then return h.r2FireFollow end
    end
    if full and s.time<(s.dodgeUntil or 0) then
        return h.dodgeFire[s.lastDodge=="F" and "F" or s.lastDodge=="B" and "B" or "S"]
    end
    return full and h.r2Fire or h.r2
end
function M.finished(s,a)
    if a.kind=="form:enter" then inForm(s);return true end
    if a.kind=="form:back" then outForm(s,s.backReason);return true end
    if a.kind=="form:return" or a.kind=="form:born" then s.formPhase="none" end
    if a.kind=="spirit:enter" then s.form="she";s.spiritPhase="form";S.play(s,"spirit:form",P.form.clip,{skill=P.form.skill});return true end
    if a.kind=="spirit:form" then recover(s);return true end
    if a.kind=="spirit:leave" then s.spiritPhase="none" end
    return false
end
return M
