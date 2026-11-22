local M={}
local D,K,S=WKSkillsConfig.spells,WKCombatClock,WKCombatSession
function M.cast(s,name)
    local spec=name=="immobilize" and D.immobilize.skills[tostring(s.warningUntil and s.time<=s.warningUntil and 10519 or 10518)] or D.cloud.enter
    if (s.cooldowns[name] or 0)>0 or s.mp<spec.mpRequired then
        S.event(s,"rejected",{reason=(s.cooldowns[name] or 0)>0 and "cooldown" or "mp",name=name});return false
    end
    s.cooldowns[name]=spec.cooldown
    local clip=name=="cloud" and D.cloud.enterClips[s.dodgeDirection or "B"] or spec.clip
    S.play(s,"spell:"..name,clip,{skill=spec.id})
    return true
end
function M.exitCloud(s,reason)
    if not s.cloud then return end
    s.cloud=nil;s.buffs={}
    S.event(s,"cloudExit",{reason=reason})
end
local function enterCloud(s,a)
    local p=s.position or WKArenaConfig.spawn
    s.cloud={remaining=D.cloud.config.duration,tick=0,noMagic=0,
        decoy={x=p.x,y=p.y,z=p.z,yaw=s.yaw,clip=a.clip,t=a.t,hp=WKCombatConfig.player.stats.hpMax*D.cloud.decoy.hpRatio}}
    s.buffs={};for _,id in ipairs(D.cloud.config.beginBuffs) do s.buffs[tostring(id)]=true end
    S.event(s,"cloudEnter",{remaining=s.cloud.remaining})
end
function M.breakFreeze(s,reason)
    local b=s.boss
    if not b or not b.immobilized then return end
    b.immobilized=nil;b.immobilizeHp=nil;b.immobilizeDef=nil
    S.event(s,"immobilizeEnd",{reason=reason})
end
local function freeze(s,e)
    local b=s.boss;if not b or s.bossHp<=0 then return end
    local p=s.position or WKArenaConfig.spawn
    local cfg=D.immobilize.configs[tostring(e.config or 10)]
    if (p.x-b.pos.x)^2+(p.z-b.pos.z)^2>cfg.rangeRadius^2 then S.event(s,"immobilizeMiss");return end
    for id,def in pairs(WKBossConfig.buffs) do
        for _,state in ipairs(def.simpleStates or {}) do
            if state=="ImmueImmobilizing" and WKBossSession.hasBuff(b,id) then S.event(s,"immobilizeImmune");return end
        end
    end
    local factor=1
    if b.action and b.action.reaction then
        factor=D.immobilize.victim.beImmobilized.factorForBeAttacked[tostring(b.lastStiff or 1)] or 1
    end
    b.immobilizeCount=b.immobilizeCount or 0
    b.immobilized=math.max(cfg.minDurationMs/1000,cfg.durationMs/1000*D.immobilize.victim.dingShenDef*factor*(1-cfg.repeatedDef*b.immobilizeCount)/100)
    b.immobilizeCount=b.immobilizeCount+1;b.immobilizeHp=D.immobilize.victim.immobilizeHp
    b.immobilizeDef=e.config==1 and -4000 or -1000
    S.event(s,"immobilize",{duration=b.immobilized,precise=e.config==1,hp=b.immobilizeHp})
end
function M.events(s,a)
    if string.sub(a.kind,1,6)~="spell:" then return end
    for i,e in ipairs(WKCombatConfig.clips[a.clip].events) do
        local at=e.time or e.start
        if at and a.t>=at and not a.fired["spell"..i] then
            a.fired["spell"..i]=true
            if e.type=="cost" then
                s.mp=math.max(0,s.mp-(e.effect==1051851 and 50 or e.effect==1009501 and 30 or 0))
                S.event(s,"spellCost",{mp=s.mp})
            elseif e.type=="castDingShen" then freeze(s,e)
            elseif e.type=="effect" and e.effectId==1051691 and a.spec.skill==10519 then
                s.cooldowns.immobilize=math.max(0,s.cooldowns.immobilize-30)
            elseif e.type=="effect" and e.effectId==1099934 then enterCloud(s,a) end
        end
    end
end
function M.tick(s,dt)
    for k,v in pairs(s.cooldowns) do s.cooldowns[k]=math.max(0,v-dt) end
    local b=s.boss
    if b and b.immobilized then
        b.immobilized=b.immobilized-dt
        if b.immobilized<=0 then M.breakFreeze(s,"timer") end
    end
    local c=s.cloud
    if c then
        c.remaining=c.remaining-dt;c.tick=c.tick+dt
        while c.tick>=1-0.000001 do c.tick=math.max(0,c.tick-1);s.mp=math.max(0,s.mp-3) end
        if s.mp<=0 then c.noMagic=c.noMagic+dt else c.noMagic=0 end
        if c.remaining<=0 or c.noMagic>=D.cloud.config.noMagicProtect or s.hp<=0 then M.exitCloud(s,c.remaining<=0 and "timer" or s.hp<=0 and "death" or "mp") end
    end
end
function M.strike(s)
    local e=D.cloud.strike
    M.exitCloud(s,"strike");S.play(s,"cloudStrike",e.clip,{skill=e.id,damage=e.damage,focusGain={}})
end
function M.beforePlay(s,kind,spec)
    if not s.cloud then return end
    for _,id in ipairs(D.cloud.config.exitOnSkills) do
        if spec and spec.skill==id then M.exitCloud(s,"skill");return end
    end
    if string.sub(kind,1,5)=="form:" or string.sub(kind,1,7)=="spirit:" then M.exitCloud(s,"form") end
end
function M.decoyDamage(s,e)
    if not s.cloud then return 0 end
    local d=s.cloud.decoy
    local damage=K.damage(WKCombatConfig.bossStats,WKCombatConfig.player.stats,e,true,WKCombatConfig.player.stats.hpMax*D.cloud.decoy.hpRatio,s.rng)
    d.hp=math.max(0,d.hp-damage);S.event(s,"cloudDecoyHit",{damage=damage,hp=d.hp})
    if d.hp<=0 then M.exitCloud(s,"decoy") end
    return damage
end
return M
