local M = {}
local S,B,K=WKCombatSession,WKBossSession,WKCombatClock
local function emit(s,name,values)
    values=values or {};values.ev=name;values.actor=s.actorID;values.time=s.time;values.epoch=s.epoch
    if s.emit then s.emit(values) end
end
function M.new(actorID,log,epoch)
    local s=S.new(actorID,log);s.challenge="ready";s.epoch=epoch or 1
    s.boss=B.new(s,WKArenaConfig.boss,(-1.68932-math.pi/2)%(2*math.pi))
    s.boss.damage=function(e,key)
        if s.cloud then return WKSpellSession.decoyDamage(s,e) end
        return S.receive(s,e,key)
    end
    s.bossReceive=function(e,skill,stats)
        return B.receive(s.boss,e,s.position or WKArenaConfig.spawn,skill,stats or S.player(s).stats)
    end
    return s
end
function M.start(s,forced)
    if s.challenge~="ready" then return false end
    s.challenge="fight";emit(s,"challenge",{state="fight",forced=forced==true})
    if forced then B.aware(s.boss,"forceFightBox") end
    return true
end
function M.retry(s)
    if (s.challenge~="victory" and s.challenge~="defeat") or s.time<(s.resultAt or math.huge) then return nil end
    local next=M.new(s.actorID,s.emit,s.epoch+1);next.ack=s.ack
    next.awaitSpawn=true
    emit(next,"challenge",{state="ready",reset=true})
    return next
end
function M.update(s,dt,p)
    s.position={x=p.x,y=p.y,z=p.z}
    if s.awaitSpawn then
        local spawn=WKArenaConfig.spawn
        if (p.x-spawn.x)^2+(p.z-spawn.z)^2<9 then s.awaitSpawn=nil end
    end
    if s.challenge=="ready" then
        -- Mirror of source forceFightBox, evaluated on DS's observed Actor.
        if not s.awaitSpawn and math.abs(p.x-1.039)<=31.262 and math.abs(p.y+0.398)<=5.438 and math.abs(p.z-33.654)<=5.64 then M.start(s,true) end
    end
    if s.challenge=="fight" then
        if s.hp<=0 and s.form~="lang" then
            s.challenge="defeat";s.resultAt=s.time+2.2;s.boss.hazards={};s.boss.decoys={}
            B.killedPlayer(s.boss);emit(s,"challenge",{state="defeat",resultAt=s.resultAt})
            if WKSkillsSession then WKSkillsSession.cleanup(s) end
        elseif s.bossHp<=0 then
            s.challenge="victory";s.resultAt=s.time+2.5
            B.die(s.boss,p);emit(s,"challenge",{state="victory",resultAt=s.resultAt})
            if WKSkillsSession then WKSkillsSession.cleanup(s) end
        end
    end
    local active=s.challenge=="fight"
    local scale=s.time<(s.bossSlowUntil or 0) and 0.1 or 1
    B.update(s.boss,dt*scale,s.cloud and s.cloud.decoy or s.position,active)
    if s.challenge=="fight" and (s.hp<=0 and s.form~="lang" or s.bossHp<=0) then M.update(s,0,p) end
end
function M.snapshot(s)
    local v=S.snapshot(s)
    v.challenge=s.challenge;v.epoch=s.epoch;v.resultReady=s.resultAt~=nil and s.time>=s.resultAt
    v.boss=B.snapshot(s.boss)
    v.slow=s.time<(s.slowUntil or 0) and 0.3 or 1
    return v
end
return M
