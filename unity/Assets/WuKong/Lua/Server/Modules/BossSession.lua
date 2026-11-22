-- Authority-only tiger AI. Data and decision rules follow reference boss.js.
local M = {}
local B,K,C = WKBossConfig,WKCombatClock,WKCombatConfig
local rad=math.pi/180
local function wrap(a) return (a+math.pi)%(2*math.pi)-math.pi end
local function rand(b) return (b.owner.rng or math.random)() end
local function range(b,v) return v[1]+rand(b)*(v[2]-v[1]) end
local function integer(b,v) return v[1]+math.min(v[2]-v[1],math.floor(rand(b)*(v[2]-v[1]+1))) end
local function emit(b,name,data)
    data=data or {};data.ev=name;data.actor=b.owner.actorID;data.time=b.owner.time
    data.bossPlay=b.play;data.phase=b.phase
    if b.owner.emit then b.owner.emit(data) end
end
function M.new(owner,position,yaw)
    return {owner=owner,pos={x=position.x,y=position.y,z=position.z},yaw=yaw,play=0,
        clip=B.idle,t=0,state="idle",fsm="BATTLE_ATTACK",budget=0,
        watch=range({owner=owner},B.ai.initialWatchTime or {0,0}),watchTick=0,watchNext=1,
        cooldowns={},lastCast={},buffs={},cbgCD={},hazards={},decoys={},serial=0,battleTime=0}
end
function M.hasBuff(b,id)
    id=tostring(id)
    if b.buffs[id] then return true end
    local a=b.action
    for _,e in ipairs(a and B.clips[a.clip].events or {}) do
        if e.type=="buff" and tostring(e.buffId)==id and a.t>=e.start and a.t<e["end"] then return true end
    end
    return false
end
function M.addBuff(b,id,seconds)
    id=tostring(id);b.buffs[id]=seconds or (B.buffs[id] and B.buffs[id].duration) or math.huge
end
function M.relation(b,p)
    p=p or b.target or b.pos
    local dx,dz=p.x-b.pos.x,p.z-b.pos.z
    local yaw=math.atan(dx,dz)
    return math.sqrt(dx*dx+dz*dz),-wrap(yaw-b.yaw)/rad,yaw,p.y-b.pos.y
end
local function turn(b,yaw,speed,dt) b.yaw=b.yaw+K.clamp(wrap(yaw-b.yaw),-speed*rad*dt,speed*rad*dt) end
function M.phase(b)
    local hp=100*b.owner.bossHp/B.stats.hp;local current
    for _,p in ipairs(B.phases) do
        if p.hpPctAbove and hp>p.hpPctAbove or p.hpPctAtMost and hp<=p.hpPctAtMost then current=p end
    end
    if current and current.id~=b.phase then b.phase=current.id;emit(b,"phase",{hp=b.owner.bossHp}) end
    return current
end
function M.aware(b,why)
    if not b.awake then b.awake=true;b.battleTime=0;emit(b,"aware",{why=why}) end
end
local function play(b,clip,id,section,reaction)
    local meta=B.clips[clip];if not meta then return false end
    b.play=b.play+1
    local index=1
    for i,s in ipairs(meta.sections or {}) do if s.name==section then index=i end end
    local start=meta.sections and meta.sections[index].start or 0
    b.action={clip=clip,id=tostring(id),t=start,prev=start-0.00001,section=index,
        fired={},hitKeys={},previousBones={},armor={},reaction=reaction,spec=B.skills[tostring(id)]}
    b.clip=clip;b.t=start;b.state="skill"
    return true
end
function M.cast(b,id,section,source)
    id=tostring(id);local spec=B.skills[id]
    if not spec or not play(b,spec.clip,id,section) then emit(b,"castMissing",{id=id});return false end
    b.cooldowns[id]=spec.cooldown or 0;b.lastCast[id]=b.battleTime
    for _,sid in ipairs(spec.sharedCooldown or {}) do
        local key=tostring(sid);b.cooldowns[key]=B.skills[key] and B.skills[key].cooldown or 0
    end
    emit(b,"bossSkill",{id=id,clip=spec.clip,section=section,source=source or "BT"})
    return true
end
local function idle(b)
    b.state="idle";b.action=nil;b.clip=B.idle;b.t=0;b.vx=0;b.vz=0
end
local function exitTask(b,aborted)
    local task=b.task
    if task and task.n.type=="combo" and (not aborted or task.n.interruptReducesBudget~=false) then b.budget=b.budget-1 end
    b.task=nil
end
local function abort(b)
    if b.task then emit(b,"btAbort",{node=b.task.n.id});exitTask(b,true);b.path=nil end
end
local function selectedClip(b,config,p)
    local _,angle,yaw=M.relation(b,p);local key="F";local a=math.abs(angle)*rad
    if config.sectors=="FourDir" then key=a<=math.pi/4 and "F" or a>=3*math.pi/4 and "B" or angle<0 and "L" or "R"
    elseif config.sectors=="ForwardAndBackward" then key=a<=math.pi/2 and "F" or "B" end
    if config.rotateToAttacker then b.yaw=yaw end
    return config.clips[key] or config.clips.F
end
function M.react(b,stiff,p,kind)
    local config=B.poise.hitReactions[kind or "normal"].levels[tostring(stiff)]
    if not config then return end
    abort(b);b.lastStiff=stiff;local clip=selectedClip(b,config,p)
    if play(b,clip,"react",nil,true) then emit(b,"bossReact",{clip=clip,stiff=stiff,config=kind or "normal"}) end
end
function M.die(b,p,stiff)
    if b.state=="dead" then return end
    abort(b)
    local cfg=B.poise.death.levels[tostring(stiff or 0)] or B.poise.death.levels["0"]
    local clip=selectedClip(b,cfg,p or b.target or b.pos)
    play(b,clip,"dead");b.state="dead";b.hazards={};b.decoys={};b.buffs={}
    emit(b,"bossDeath",{clip=clip})
end
function M.receive(b,e,p,skill,stats)
    if b.owner.bossHp<=0 then return 0,false end
    M.aware(b,"hit");if B.ai.hitResetsWatchTime then b.watch=0 end
    local stiff=(e.hitWeight or 0)-(B.stats.tenacity or 0)
    if M.hasBuff(b,202202) then
        emit(b,"bounce",{skill=skill});M.react(b,stiff,p,"stone");return 0,false,true
    end
    local victim=B.stats
    if b.immobilized then
        victim={};for k,v in pairs(B.stats) do victim[k]=v end
        victim.dmgDef=(victim.dmgDef or 0)+(b.immobilizeDef or 0)
    end
    local damage,crit=K.damage(stats or C.player.stats,victim,e,false,B.stats.hp,b.owner.rng)
    b.owner.bossHp=math.max(0,b.owner.bossHp-damage)
    emit(b,"bossHit",{damage=damage,hp=b.owner.bossHp,skill=skill})
    if b.owner.bossHp<=0 then M.die(b,p,stiff);return damage,crit end
    if b.immobilized then
        b.immobilizeHp=b.immobilizeHp-damage
        if b.immobilizeHp>0 then return damage,crit end
        WKSpellSession.breakFreeze(b.owner,"damage");M.react(b,stiff,p);return damage,crit
    end
    local a=b.action;local armor,i=K.active(a and B.clips[a.clip],a and a.t or 0,"superArmor")
    if armor then
        a.armor[i]=a.armor[i] or (B.poise.superArmorLevels[tostring(armor.level)] or {}).value or 0
        if a.armor[i]>0 then
            a.armor[i]=a.armor[i]-(e.armorBreak or 0)
            if a.armor[i]<=0 then emit(b,"superArmorBroken",{level=armor.level}) end
            return damage,crit -- Source continues the current skill on the breaking hit.
        end
    end
    M.react(b,stiff,p,(M.hasBuff(b,2022061) or M.hasBuff(b,202220)) and "stone" or "normal")
    return damage,crit
end
local function cooldown(b,id) return (b.cooldowns[tostring(id)] or 0)>0 end
local function compare(op,a,c)
    return op=="<=" and a<=c or op=="<" and a<c or op==">=" and a>=c or op==">" and a>c or op=="==" and a==c
end
local function conditions(b,n)
    local count=0
    for _,c in ipairs(n.conditions or {}) do
        local ok=false
        if c.type=="hasBuff" then
            ok=n.unit=="player" and b.owner.buffs and b.owner.buffs[tostring(c.buff)]~=nil
                or n.unit~="player" and M.hasBuff(b,c.buff)
        elseif c.type=="castingSkill" then
            local id=n.unit=="player" and b.owner.action and b.owner.action.spec and b.owner.action.spec.skill
                or n.unit~="player" and b.action and b.action.id
            for _,sid in ipairs(c.skills) do if tostring(sid)==tostring(id) then ok=true end end
        elseif c.type=="simpleState" then ok=(c.state=="Immobilizing" and b.immobilized~=nil) or (c.state=="Frozen" and b.frozen~=nil)
        elseif c.type=="hpPct" then ok=compare(c.op,100*b.owner.bossHp/B.stats.hp,c.value)
        elseif c.type=="distance" then ok=compare(c.op,M.relation(b),c.value)
        elseif c.type=="skillOnCooldown" then ok=cooldown(b,c.skill) end
        if c["not"] then ok=not ok end
        if ok then count=count+1 elseif n.match~="any" then return false end
    end
    return n.match=="any" and count>0 or n.match~="any"
end
local effect,cbgAction
cbgAction=function(b,a)
    if not a then return end
    if a["do"]=="cast" then M.cast(b,a.skill,a.section,"CBG")
    elseif a["do"]=="if" then cbgAction(b,conditions(b,a) and a["then"] or a["else"])
    elseif a["do"]=="random" then cbgAction(b,rand(b)<a.chance and a["then"] or a["else"])
    elseif a["do"]=="sequence" then for _,x in ipairs(a.steps) do cbgAction(b,x) end
    elseif a["do"]=="addBuff" then M.addBuff(b,a.buff)
    elseif a["do"]=="removeBuff" then b.buffs[tostring(a.buff)]=nil
    elseif a["do"]=="triggerEffect" then effect(b,a.effect)
    elseif a["do"]=="voiceLine" then emit(b,"voiceLine",{ids=a.ids}) end
end
local function cbg(b,tags)
    for _,r in ipairs(B.ai.cbg.rules) do
        local t=r.trigger
        if t.type=="montageTag" and tags and tags[t.tag] then emit(b,"cbgTag",{tag=t.tag,node=r.node});cbgAction(b,r.action)
        elseif t.type=="poll" and (b.cbgCD[r.node] or 0)<=0 and conditions(b,t) then
            b.cbgCD[r.node]=t.cooldown or 0;cbgAction(b,r.action)
        end
    end
end
function M.killedPlayer(b)
    for _,r in ipairs(B.ai.cbg.rules) do if r.trigger.type=="killedPlayer" then cbgAction(b,r.action) end end
end
local function decorator(b,d)
    local ok=true;local dist=M.relation(b)
    if d.type=="fsmState" then ok=b.fsm==d.state or string.sub(b.fsm,1,#d.state+1)==d.state.."_"
    elseif d.type=="hpPctAtMost" then ok=100*b.owner.bossHp/B.stats.hp<=d.value
    elseif d.type=="distanceAtMost" then ok=dist<=d.value
    elseif d.type=="distanceAtLeast" then ok=dist>=d.value
    elseif d.type=="comboBudgetAtMost" then ok=b.budget<=d.value
    elseif d.type=="watchTimeRemaining" then ok=b.watch>0 end
    if d.invert then ok=not ok end;return ok
end
local function nodePass(b,n)
    for _,d in ipairs(n.decorators or {}) do if not decorator(b,d) then return false end end
    return true
end
local function candidates(b,task)
    local n=task.n;local dist,angle,_,dy=M.relation(b)
    local stage=task.stage;local first=stage==0 or not task.prev
    local prev=task.prev and B.skills[task.prev] and B.skills[task.prev].ai
    local sector=angle>=0 and math.min(3,math.floor(angle/45)) or 4+math.min(3,math.floor((angle+180)/45))
    local out,seen={},{}
    for _,sid in ipairs(n.stages[stage+1] or {}) do
        local id=tostring(sid);local spec=B.skills[id];local ai=spec and spec.ai
        if not seen[id] and ai and not cooldown(b,id) and b.battleTime>=(spec.preCooldown or 0)
            and dist>=ai.rangeMin and dist<=ai.rangeMax and math.abs(dy)<=ai.heightMax
            and (ai.angleScores[sector+1] or 0)~=0 and not task.casted[id] then
            local sc=B.ai.scoreConfig;local score=ai.angleScores[sector+1]
            score=score+(b.lastCast[id] and math.min((b.battleTime-b.lastCast[id])*ai.cooldownScorePerSec,ai.cooldownScoreMax) or ai.cooldownScoreMax)
            if not ai.next or #ai.next==0 then score=score+(stage==task.length-1 and sc.endSkillAddition or sc.endSkillSubtraction) end
            if first then score=score+sc.firstSkillRealComboAddition*(task.length-sc.firstSkillRealComboSkillReduceNum)
            else
                local linked=false
                for _,nextID in ipairs(prev and prev.next or {}) do if tostring(nextID)==id then linked=true end end
                if linked then score=score+sc.realComboAddition*stage
                else
                    local other=false
                    for _,otherSpec in pairs(B.skills) do
                        for _,nextID in ipairs(otherSpec.ai and otherSpec.ai.next or {}) do if tostring(nextID)==id then other=true end end
                    end
                    if other then score=score+sc.otherComboSkillSubtraction*stage end
                end
            end
            if dist>=ai.optimalMin and dist<=ai.optimalMax then score=score+ai.optimalScore end
            out[#out+1]={id=id,score=score}
        end
        seen[id]=true
    end
    table.sort(out,function(a,c) return a.score==c.score and a.id<c.id or a.score>c.score end)
    return out
end
local function pick(b,task)
    local out=candidates(b,task);if #out==0 then return end
    local top=math.max(1,math.floor(#out*task.n.topRandomPercent/100))
    local id=out[math.min(top,math.floor(rand(b)*top)+1)].id
    if task.stage>0 and task.prev then
        local linked=false
        for _,sid in ipairs((B.skills[task.prev] and B.skills[task.prev].ai or {}).next or {}) do if tostring(sid)==id then linked=true end end
        if not linked then return end
    end
    return id
end
function M.candidates(b,node,length,stage,previous)
    return candidates(b,{n=node,length=length,stage=stage or 0,prev=previous,casted={}})
end
local function locomote(b,dx,dz,speed,facing,dt)
    local len=math.sqrt(dx*dx+dz*dz);if len<0.01 then idle(b);return end
    turn(b,facing=="target" and select(3,M.relation(b)) or math.atan(dx,dz),B.stats.turnSpeed,dt)
    b.vx=dx/len*speed;b.vz=dz/len*speed;b.state="move";b.action=nil
    b.clip=facing=="target" and B.lockMove or B.freeMove
end
local function validPoint(b,p,margin)
    local f=WKArenaConfig.fight
    if (p.x-f.x)^2+(p.z-f.z)^2>(f.radius-(margin or B.capsule.radius*2))^2 then return end
    return b.ground and b.ground(p) or p
end
local function eqs(b)
    local g=B.ai.eqs.generator;local points={}
    local lo={dq=math.huge,dp=math.huge,dot=math.huge};local hi={dq=-math.huge,dp=-math.huge,dot=-math.huge}
    for ring=0,g.rings-1 do
        local radius=g.rings>1 and g.innerRadius+(g.outerRadius-g.innerRadius)*ring/(g.rings-1) or g.innerRadius
        for i=0,g.pointsPerRing-1 do
            local angle=i/g.pointsPerRing*2*math.pi
            local p=validPoint(b,{x=b.pos.x+math.cos(angle)*radius,y=b.pos.y,z=b.pos.z+math.sin(angle)*radius})
            if p then
                local x={p=p,dq=radius,dp=math.sqrt((p.x-b.target.x)^2+(p.z-b.target.z)^2),
                    dot=math.sin(b.yaw)*math.cos(angle)+math.cos(b.yaw)*math.sin(angle)}
                points[#points+1]=x
                for _,k in ipairs({"dq","dp","dot"}) do lo[k]=math.min(lo[k],x[k]);hi[k]=math.max(hi[k],x[k]) end
            end
        end
    end
    local best,score=nil,-math.huge
    for _,p in ipairs(points) do
        local n={}
        for _,k in ipairs({"dq","dp","dot"}) do n[k]=hi[k]>lo[k] and (p[k]-lo[k])/(hi[k]-lo[k]) or 1 end
        local s=1-n.dq+n.dp+2*n.dot
        if s>score then best=p.p;score=s end
    end
    return best
end
local execute,children
children=function(b,n,from,path)
    for i=from,#(n.children or {}) do
        path[#path+1]={node=n,index=i}
        local result=execute(b,n.children[i],path)
        if result=="running" then return result end
        table.remove(path)
        if n.type=="selector" and result=="success" or n.type=="sequence" and result=="failure" then return result end
    end
    return n.type=="selector" and "failure" or "success"
end
execute=function(b,n,path)
    if not nodePass(b,n) then return "failure" end
    if n.type=="selector" or n.type=="sequence" then return children(b,n,1,path) end
    if n.type=="enterAttack" then b.budget=integer(b,n.comboBudget);b.fsm="BATTLE_ATTACK";emit(b,"enterAttack",{budget=b.budget});return "success" end
    if n.type=="enterWander" then b.watch=range(b,n.watchTime);b.fsm="BATTLE_WANDER";emit(b,"enterWander",{watch=b.watch});return "success" end
    if n.type=="combo" then
        local total=0;for _,w in ipairs(n.lengthWeights) do total=total+w.weight end
        local value=rand(b)*total;local length=n.lengthWeights[#n.lengthWeights].length
        for _,w in ipairs(n.lengthWeights) do value=value-w.weight;if value<=0 then length=w.length;break end end
        local task={n=n,length=math.min(length,#n.stages),stage=0,casted={},retry=0}
        local all=true
        for _,id in ipairs(n.stages[1]) do if B.skills[tostring(id)] and B.skills[tostring(id)].ai and not cooldown(b,id) then all=false end end
        if b.state=="skill" or all then b.budget=b.budget-1;return "success" end
        b.task=task;emit(b,"combo",{node=n.id,length=task.length})
    elseif n.type=="eqsMove" then
        local goal=eqs(b);if not goal then return "failure" end
        b.task={n=n,goal=goal,age=0};emit(b,"eqsMove",{goal=goal})
    else return "failure" end
    return "running"
end
local function taskTick(b,t,dt)
    if t.n.type=="eqsMove" then
        local dx,dz=t.goal.x-b.pos.x,t.goal.z-b.pos.z
        t.age=t.age+dt
        if dx*dx+dz*dz<=(t.n.acceptRadius+2*B.capsule.radius)^2 or b.state=="skill" then
            if b.state~="skill" then idle(b) end;return "success"
        end
        if t.age>15 then idle(b);return "failure" end
        locomote(b,dx,dz,B.stats.moveSpeed.fast*B.stats.aiRunSpeedRate,"target",dt);return "running"
    end
    if b.state=="skill" then
        if b.action.id~=t.prev and b.action.id~="react" then t.prev=b.action.id;t.casted[t.prev]=true end
        if not t.ending and t.stage<t.length then
            local window,index=K.active(B.clips[b.clip],b.t,"comboWindow")
            local key=tostring(b.play)..":"..tostring(index)
            if window and t.window~=key then
                t.window=key;local id=pick(b,t)
                if id then
                    M.cast(b,id,"ing",t.n.id);t.casted[id]=true;t.prev=id;t.stage=t.stage+1
                elseif t.n.forceComboRelation and #(B.skills[t.prev] and B.skills[t.prev].ai and B.skills[t.prev].ai.next or {})>0 then t.ending=true end
            end
        end
        return "running"
    end
    if t.ending or t.stage>0 and t.stage>=t.length then return "success" end
    local id=pick(b,t)
    if id then M.cast(b,id,nil,t.n.id);t.casted[id]=true;t.prev=id;t.stage=t.stage+1;return "running" end
    if t.stage>0 then return "success" end
    local dist,angle,yaw=M.relation(b)
    if not t.turned and t.n.useTurnSkills and math.abs(angle)>t.n.beginRotateAngle then
        local turnIDs=B.ai.turnSkills;local small=math.abs(angle)<=turnIDs.smallMaxAngle
        local turnID=angle<0 and (small and turnIDs.leftSmall or turnIDs.leftBig) or (small and turnIDs.rightSmall or turnIDs.rightBig)
        t.turned=true
        if not cooldown(b,turnID) and M.cast(b,turnID,nil,t.n.id..":turn") then return "running" end
    end
    local radius=0
    for _,sid in ipairs(t.n.stages[1]) do
        local ai=B.skills[tostring(sid)] and B.skills[tostring(sid)].ai
        if ai and ai.rangeMax<dist then radius=math.max(radius,ai.rangeMax) end
    end
    t.retry=t.retry-dt
    if radius>0 and dist>radius+0.05 then locomote(b,math.sin(yaw),math.cos(yaw),B.stats.moveSpeed.fast*B.stats.aiRunSpeedRate,"move",dt)
    else idle(b);turn(b,yaw,B.stats.turnSpeed,dt) end
    if t.retry<=0 then t.retry=2;t.turned=false end
    return "running"
end
local function bt(b,dt)
    if b.task then
        local aborted=false
        local chain={}
        for _,p in ipairs(b.path or {}) do
            chain[#chain+1]=p.node
            if p.node.type=="selector" then
                for i=1,p.index-1 do
                    local sibling=p.node.children[i]
                    for _,d in ipairs(sibling.decorators or {}) do
                        if (d.abort=="LowerPriority" or d.abort=="Both") and nodePass(b,sibling) then aborted=true end
                    end
                end
            end
        end
        chain[#chain+1]=b.task.n
        for _,n in ipairs(chain) do
            for _,d in ipairs(n.decorators or {}) do if (d.abort=="Self" or d.abort=="Both") and not decorator(b,d) then aborted=true end end
        end
        if aborted then abort(b)
        else
            local result=taskTick(b,b.task,dt)
            if result=="running" then return end
            exitTask(b);local path=b.path or {};b.path=nil
            while #path>0 do
                local p=table.remove(path)
                if p.node.type=="sequence" and result=="success" or p.node.type=="selector" and result=="failure" then
                    result=children(b,p.node,p.index+1,path)
                    if result=="running" then b.path=path;return end
                end
            end
            return
        end
    end
    local path={};if execute(b,B.ai.behaviorTree,path)=="running" then b.path=path end
end
local function point(b,name)
    return b.bone and b.bone(name)
end
local function spawnBullet(b,e)
    local id=tostring(e.bulletId);local def=B.bullets[id]
    if not def then emit(b,"bulletUnknown",{id=id});return end
    local p=point(b,e.socket) or {x=b.pos.x,y=b.pos.y+1.5,z=b.pos.z};local yaw=b.yaw
    if e.direction=="UseSlotDir" and b.socketYaw then yaw=b.socketYaw(e.socket) or yaw
    elseif e.direction~="BaseActorRot" then yaw=math.atan(b.target.x-p.x,b.target.z-p.z) end
    b.serial=b.serial+1
    local h={key=b.serial,id=id,pos={x=p.x,y=p.y,z=p.z},yaw=yaw,speed=e.speed or 0,age=0,
        nextSweep=def.sweepDelay or 0,socket=e.socket,follow=(e.speed or 0)==0 and def.moveMode=="StraightMode"}
    b.hazards[#b.hazards+1]=h;emit(b,"bullet",{id=id,key=h.key,socket=e.socket,speed=h.speed})
end
effect=function(b,id)
    id=tostring(id);local e=B.effects[id]
    if id=="20229990" then b.bgm=2;emit(b,"bgmPhase",{level=2});return end
    if not e then return end
    if e.type=="AddBuff" then M.addBuff(b,e.int[1],e.float and e.float[1] and e.float[1]/1000)
    elseif e.type=="SummonUnit" then
        b.serial=b.serial+1
        local p={x=b.pos.x-math.sin(b.yaw)*0.5,y=b.pos.y,z=b.pos.z-math.cos(b.yaw)*0.5}
        b.decoys[#b.decoys+1]={key=b.serial,pos=p,yaw=b.yaw,age=0,hitKeys={}}
        emit(b,"stoneClone",{stage="spawn",key=b.serial,pos=p})
    elseif e.type=="Teleport" then
        local best,score=nil,-math.huge;local yaw=b.owner.cameraYaw or b.owner.yaw
        for i=0,23 do
            local a=i/24*2*math.pi
            local p=validPoint(b,{x=b.target.x+math.cos(a)*15,y=b.target.y,z=b.target.z+math.sin(a)*15},B.capsule.radius)
            if p then
                local s=math.sin(yaw)*math.cos(a)+math.cos(yaw)*math.sin(a)
                if s>score then best=p;score=s end
            end
        end
        if best then b.pos=best;b.yaw=select(3,M.relation(b));if b.sample then b.sample(b) end;emit(b,"teleport",{pos=best}) end
    elseif e.type=="SwitchBullet" then
        for _,h in ipairs(b.hazards) do
            if h.id==tostring(e.int[4]) then
                if B.bullets[tostring(e.int[1])] then h.id=tostring(e.int[1]);h.age=0 else h.dead=true end
            end
        end
        emit(b,"switchBullet",{from=e.int[4],to=e.int[1]})
    elseif e.type=="SwitchStateLib" then b.buffs["2022061"]=nil;b.buffs["202220"]=nil
    elseif e.type=="ClearAbnormalState" then b.immobilized=nil;b.frozen=nil end
end
function M.triggerEffect(b,id) effect(b,id) end
local function hurt(p,cap)
    return {x=p.x,y=p.y+cap.radius,z=p.z},{x=p.x,y=p.y+2*cap.halfHeight-cap.radius,z=p.z}
end
local function targetHurt(b)
    if WKStanceSession and not b.owner.cloud then
        local low,high,radius=WKStanceSession.hurtSegment(b.owner)
        if low then return low,high,radius end
    end
    local cap=C.capsule
    if WKSkillsConfig and not b.owner.cloud then
        if b.owner.form=="she" then cap=WKSkillsConfig.bianhua.spirit.form.capsule
        elseif b.owner.form=="lang" then cap=WKSkillsConfig.forms.lang.capsule end
    end
    local low,high=hurt(b.target,cap)
    return low,high,cap.radius
end
local function hitPlayer(b,e,key)
    local effectData=B.effects[tostring(e)]
    if effectData and effectData.type=="damage" and b.damage then
        local n=b.damage(effectData,key);emit(b,"bossContact",{effect=tostring(e),damage=n,key=key})
    elseif effectData and effectData.type=="AddBuff" then effect(b,e)
    elseif effectData and effectData.type=="TimeScale" then b.owner.slowUntil=b.owner.time+0.91;emit(b,"playerSlow") end
end
local function resolve(b)
    local a=b.action
    if not a or b.state~="skill" or b.owner.hp<=0 or b.owner.bossHp<=0 then return end
    local low,high,bodyRadius=targetHurt(b);local current={}
    for i,e in ipairs(B.clips[a.clip].events) do
        if e.type=="hit" or e.type=="warning" then
            local active=a.t>=e.start and a.prev<e["end"]
            if active then
                local key=e.group and e.group>=0 and "g"..e.group or "e"..i
                for n,name in ipairs(e.bones or {}) do
                    local p=point(b,name)
                    local sweepRadius=e.radii and e.radii[n] or e.radius or 0.5
                    local r=sweepRadius+bodyRadius
                    if p then current[name]=p end
                    if p and e.type=="hit" and not a.hitKeys[key] and WKStanceSession and not b.owner.cloud then
                        for _,id in ipairs(e.effectIds or e.effects or {e.id}) do
                            local eff=B.effects[tostring(id)]
                            if eff and eff.type=="damage" and WKStanceSession.staffContact(b.owner,a.previousBones[name] or p,p,sweepRadius,eff) then
                                a.hitKeys[key]=true;break
                            end
                        end
                    end
                    if p and K.segmentDistance2(a.previousBones[name] or p,p,low,high)<=r*r then
                        if e.type=="warning" then b.owner.warningID=b.play;b.owner.warningUntil=b.owner.time+C.perfect.tolerantTime
                        elseif not a.hitKeys[key] then
                            a.hitKeys[key]=true
                            for _,id in ipairs(e.effectIds or e.effects or {e.id}) do hitPlayer(b,id,tostring(b.play)..":"..key) end
                        end
                    end
                end
            end
        end
    end
    a.previousBones=current
end
local function hazardOverlap(h,old,b)
    local shape=B.bullets[h.id].shape;local low,high,r=targetHurt(b)
    if shape.sphere then return K.segmentDistance2(old,h.pos,low,high)<=(r+shape.sphere)^2 end
    if shape.capsule then
        local p={x=h.pos.x,y=h.pos.y+shape.capsule.halfHeight*2,z=h.pos.z}
        return K.segmentDistance2(h.pos,p,low,high)<=(r+shape.capsule.radius)^2
    end
    if shape.box then
        for i=0,4 do
            local x=low.x-h.pos.x;local z=low.z-h.pos.z;local y=low.y+(high.y-low.y)*i/4-h.pos.y
            local side=x*math.cos(h.yaw)-z*math.sin(h.yaw)
            local front=x*math.sin(h.yaw)+z*math.cos(h.yaw)
            if math.abs(front)<=shape.box[1]+r and math.abs(side)<=shape.box[2]+r and math.abs(y)<=shape.box[3]+r then return true end
        end
    end
    return false
end
local function hazards(b,dt)
    for i=#b.hazards,1,-1 do
        local h=b.hazards[i];local def=B.bullets[h.id];h.age=h.age+dt
        local old={x=h.pos.x,y=h.pos.y,z=h.pos.z}
        if h.follow then local p=point(b,h.socket);if p then h.pos={x=p.x,y=p.y,z=p.z} end
        elseif def.moveMode=="TraceMode" then
            local target=b.target
            local prefix=def.moveInt[1]==2 and def.moveStr[1]
            if prefix and b.nearestSocket then target=b.nearestSocket(prefix,h.pos) or target end
            local want=math.atan(target.x-h.pos.x,target.z-h.pos.z);local rate=def.moveFloat[1] or 0
            h.yaw=h.yaw+K.clamp(wrap(want-h.yaw),-rate*dt,rate*dt)
            if prefix then
                local k=math.min(1,rate*dt)
                h.pos.x=h.pos.x+(target.x-h.pos.x)*k;h.pos.z=h.pos.z+(target.z-h.pos.z)*k
            else h.pos.x=h.pos.x+math.sin(h.yaw)*h.speed*dt;h.pos.z=h.pos.z+math.cos(h.yaw)*h.speed*dt end
        else h.pos.x=h.pos.x+math.sin(h.yaw)*h.speed*dt;h.pos.z=h.pos.z+math.cos(h.yaw)*h.speed*dt end
        if def.shape.capsule and not h.follow and b.ground then h.pos=b.ground(h.pos) or h.pos end
        if WKStanceSession and not b.owner.cloud and WKStanceSession.blockBullet(b.owner,h,old) then h.dead=true end
        if not h.dead and h.age<def.lifeTime and h.age>=h.nextSweep and WKStanceSession and not b.owner.cloud then
            local radius=def.shape.sphere or def.shape.capsule and def.shape.capsule.radius
            if radius then
                for _,id in ipairs(def.hitEffects) do
                    local eff=B.effects[tostring(id)]
                    if eff and eff.type=="damage" and WKStanceSession.staffContact(b.owner,old,h.pos,radius,eff) then h.nextSweep=h.age+(def.sweepInterval or 99);break end
                end
            end
        end
        if not h.dead and h.age<def.lifeTime and h.age>=h.nextSweep and b.owner.hp>0 and hazardOverlap(h,old,b) then
            h.nextSweep=h.age+(def.sweepInterval or 99)
            for _,id in ipairs(def.hitEffects) do hitPlayer(b,id,"bullet:"..h.key) end
        end
        if h.dead or h.age>=def.lifeTime then emit(b,"bulletExpired",{key=h.key,id=h.id});table.remove(b.hazards,i) end
    end
    for i=#b.decoys,1,-1 do
        local d=b.decoys[i];d.age=d.age+dt
        if d.age>=2.5 then emit(b,"stoneClone",{stage="expire",key=d.key});table.remove(b.decoys,i) end
    end
end
function M.update(b,dt,p,active)
    b.target=p;b.vx=0;b.vz=0
    for _,map in ipairs({b.cooldowns,b.cbgCD,b.buffs}) do
        for k,v in pairs(map) do map[k]=v-dt;if map==b.buffs and map[k]<=0 then map[k]=nil end end
    end
    M.phase(b)
    if b.immobilized then
        -- The source keeps CBG conditions polling while action, AI and sweeps pause.
        if active then cbg(b) end
        if b.sample then b.sample(b) end
        return
    end
    if active and b.owner.bossHp>0 and b.owner.hp>0 then
        if not b.awake and b.aiEnabled~=false then
            local dist,angle=M.relation(b);local perception=B.stats.perception
            if dist<=perception.hear or dist<=perception.sight and math.abs(angle)<=perception.visionAngle then M.aware(b,"perception") end
        end
        if b.awake and b.aiEnabled~=false then
            b.battleTime=b.battleTime+dt;b.watchTick=b.watchTick+dt
            if b.watchTick>=b.watchNext then b.watch=b.watch-b.watchTick;b.watchTick=0;b.watchNext=1+(rand(b)-0.5) end
            cbg(b)
            if not (b.action and b.action.reaction) then bt(b,dt) end
        end
    end
    local a=b.action
    if a and not b.immobilized then
        local meta=B.clips[a.clip]
        local rotation=K.active(meta,a.t,"rotate")
        if rotation and active then turn(b,select(3,M.relation(b)),rotation.speed or 0,dt) end
        for _,e in ipairs(meta.events) do
            if e.type=="jumpSectionIfBuff" and a.t>=e.start and a.t<e["end"] and M.hasBuff(b,e.buffId) then
                for index,section in ipairs(meta.sections or {}) do
                    if section.name==e.section and index~=a.section then a.section=index;a.t=section.start;a.fired={};a.hitKeys={};a.previousBones={} end
                end
            end
        end
        local old=a.t;local done,wrapped=K.advance(a,dt,meta)
        local dist,_,yaw=M.relation(b);local surface=dist*math.cos(wrap(yaw-b.yaw))-B.capsule.radius-C.capsule.radius
        local forward,side,dy=K.rootDelta(a,old,a.t,surface,meta)
        local dx=forward*math.sin(b.yaw)+side*math.cos(b.yaw)
        local dz=forward*math.cos(b.yaw)-side*math.sin(b.yaw)
        if not wrapped then
            if b.move then b.pos=b.move(b.pos,dx,dz,b)
            else b.pos.x=b.pos.x+dx;b.pos.z=b.pos.z+dz end
            b.yaw=b.yaw+dy
        end
        b.clip=a.clip;b.t=a.t;if b.sample then b.sample(b) end
        if active then
            resolve(b)
            local tags={}
            for i,e in ipairs(meta.events) do
                local at=e.time or (e.type=="bullet" and e.start)
                if at and not a.fired[i] and at>=old and at<=a.t then
                    a.fired[i]=true
                    if e.type=="bullet" then spawnBullet(b,e)
                    elseif e.type=="effect" then effect(b,e.effectId)
                    elseif e.type=="behavior" then tags[tostring(e.tag)]=true
                    elseif e.type=="destroyProjectile" then
                        for _,h in ipairs(b.hazards) do for _,id in ipairs(e.ids) do if h.id==tostring(id) then h.dead=true end end end
                    end
                end
            end
            cbg(b,tags)
        end
        if b.action==a then
            if done and b.state~="dead" then b.prevSkill=a.id;idle(b)
            elseif wrapped then a.fired={};a.hitKeys={};a.previousBones={} end
        end
    elseif not a then
        if b.move then b.pos=b.move(b.pos,(b.vx or 0)*dt,(b.vz or 0)*dt,b)
        else b.pos.x=b.pos.x+(b.vx or 0)*dt;b.pos.z=b.pos.z+(b.vz or 0)*dt end
        b.t=(b.t+dt)%B.clips[b.clip].duration
        if b.sample then b.sample(b) end
    end
    if active then hazards(b,dt) end
end
function M.resolveDecoys(b,s,bone)
    local a=s.action
    if not a or not a.spec or not a.spec.damage then return end
    local cfg=B.stone.decoy.hurt
    for _,d in ipairs(b.decoys) do
        local function world(v)
            -- Source mesh forward +X becomes Unity model -X.
            return {x=d.pos.x+v[1]*math.sin(d.yaw)+v[3]*math.cos(d.yaw),y=d.pos.y+v[2],
                z=d.pos.z+v[1]*math.cos(d.yaw)-v[3]*math.sin(d.yaw)}
        end
        local low,high=world(cfg.a),world(cfg.b)
        for index,e in ipairs(C.clips[a.clip].events) do
            if e.type=="hit" and a.t>=e.start and a.prev<e["end"] then
                local group=e.group and e.group>=0 and "g"..e.group or "e"..index
                local key=tostring(s.play)..":"..group
                if not d.hitKeys[key] then
                    for n,name in ipairs(e.bones or {}) do
                        local p=bone(name);local r=(e.radii and e.radii[n] or e.radius or 0.5)+cfg.r
                        if p and K.segmentDistance2(a.previousBones[name] or p,p,low,high)<=r*r then
                            local valid=false
                            for _,id in ipairs(e.effects or {e.id}) do if a.spec.damage[tostring(id)] then valid=true end end
                            if valid then
                                d.hitKeys[key]=true;M.addBuff(b,202205,1)
                                emit(b,"stoneClone",{stage="hit",key=d.key,skill=a.spec.skill})
                                WKCombatSession.rebound(s,a.spec.skill);return
                            end
                        end
                    end
                end
            end
        end
    end
end
function M.snapshot(b)
    local hazardsOut,decoys={},{}
    for _,h in ipairs(b.hazards) do hazardsOut[#hazardsOut+1]={key=h.key,id=h.id,pos=h.pos,yaw=h.yaw,age=h.age} end
    for _,d in ipairs(b.decoys) do decoys[#decoys+1]={key=d.key,pos=d.pos,yaw=d.yaw,age=d.age} end
    return {pos=b.pos,yaw=b.yaw,clip=b.clip,t=b.t,play=b.play,phase=b.phase,state=b.state,
        skill=b.action and b.action.id,awake=b.awake,canLock=b.owner.bossHp>0 and not M.hasBuff(b,202203) and not M.hasBuff(b,202212),
        invisible=M.hasBuff(b,202212),stone=M.hasBuff(b,202202),hazards=hazardsOut,decoys=decoys,bgm=b.bgm or 1}
end
return M
