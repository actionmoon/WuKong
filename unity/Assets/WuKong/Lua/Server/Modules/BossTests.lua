local M={}
function M.run(actorID,report)
    local Q,B,S,K=WKChallengeSession,WKBossSession,WKCombatSession,WKCombatClock
    local C=WKBossConfig
    local function test(name,fn)
        local ok,value=pcall(fn)
        report({ev="bossFixedTest",name=name,pass=ok and value==true,detail=not ok and tostring(value) or nil,actor=actorID})
    end
    local function fresh()
        local s=Q.new(actorID);s.rng=function() return 0.5 end;s.position={x=1.226,y=-6.419,z=45}
        s.boss.target=s.position
        return s,s.boss
    end
    local function advance(s,time,point)
        for _=1,math.ceil(time*120) do S.update(s,1/120);Q.update(s,1/120,point or s.position) end
    end
    local nodes={}
    local function visit(n)
        nodes[n.id]=n;for _,c in ipairs(n.children or {}) do visit(c) end
    end
    visit(C.ai.behaviorTree)
    test("51-skill-clips-and-bullet-rows",function()
        local count=0
        for _,spec in pairs(C.skills) do
            count=count+1
            if not C.clips[spec.clip] then return false end
            for _,e in ipairs(C.clips[spec.clip].events) do
                if e.type=="bullet" and not C.bullets[tostring(e.bulletId)] then return false end
            end
        end
        return count==51
    end)
    test("ready-force-box-perception",function()
        local s,b=fresh();advance(s,.1,{x=0,y=-1.237,z=0})
        local ready=s.challenge=="ready" and not b.awake
        advance(s,.1,{x=0,y=-5,z=33.6})
        return ready and s.challenge=="fight" and b.awake
    end)
    test("sight-cone-hearing",function()
        local s,b=fresh();Q.start(s);b.yaw=0
        advance(s,.01,{x=b.pos.x,y=b.pos.y,z=b.pos.z-20})
        local hidden=not b.awake
        advance(s,.01,{x=b.pos.x,y=b.pos.y,z=b.pos.z+20})
        local sight=b.awake
        local s2,b2=fresh();Q.start(s2);b2.yaw=0
        advance(s2,.01,{x=b2.pos.x,y=b2.pos.y,z=b2.pos.z-5})
        return hidden and sight and b2.awake
    end)
    test("five-hp-phases",function()
        local s,b=fresh()
        for i,hp in ipairs({6480,5508,3888,3240,2592}) do
            s.bossHp=hp;B.phase(b)
            if b.phase~=C.phases[i].id then return false end
        end
        return true
    end)
    test("near-far-candidate-range-and-cooldown",function()
        local s,b=fresh();B.phase(b);b.battleTime=100
        local node=nodes[C.phases[1].combo]
        for _,dist in ipairs({3,14,25,45}) do
            b.target={x=b.pos.x,y=b.pos.y,z=b.pos.z+dist};b.yaw=0
            local candidates=B.candidates(b,node,1)
            for _,c in ipairs(candidates) do
                local ai=C.skills[c.id].ai
                if dist<ai.rangeMin or dist>ai.rangeMax then return false end
                b.cooldowns[c.id]=100
            end
            if #B.candidates(b,node,1)>0 then return false end
            b.cooldowns={}
        end
        return true
    end)
    test("source-section-and-rate-timeline",function()
        local s,b=fresh();B.cast(b,202201,"ing")
        local meta=C.clips[b.clip];local start=b.action.t
        B.update(b,1/120,s.position,false)
        return start==meta.sections[2].start and b.t>start and b.t-start<.1
    end)
    test("armor-breaking-hit-continues-next-hit-reacts",function()
        local s,b=fresh();B.cast(b,202201)
        local e={damageMult=1,hitWeight=2,armorBreak=10000}
        local n=B.receive(b,e,s.position,10805);local running=b.action.id=="202201"
        B.receive(b,e,s.position,10805)
        return n>0 and running and b.action and b.action.reaction==true
    end)
    test("stone-immune-rebound-and-counter",function()
        local s,b=fresh();B.cast(b,202240);B.addBuff(b,202202,1)
        local hp=s.bossHp
        local damage,_,bounce=B.receive(b,{damageMult=1,hitWeight=1,armorBreak=1},s.position,10801)
        return damage==0 and bounce and s.bossHp==hp and b.action.reaction and string.find(b.clip,"dep02_sl0",1,true)~=nil
    end)
    test("melee-sweep-once-per-window",function()
        local s,b=fresh();Q.start(s);b.aiEnabled=false;B.cast(b,202201)
        local contacts=0
        b.bone=function() return {x=s.position.x,y=s.position.y+1.5,z=s.position.z} end
        b.damage=function() contacts=contacts+1;return 1 end
        for _=1,480 do B.update(b,1/120,s.position,true) end
        local expected=0
        for _,e in ipairs(C.clips[C.skills["202201"].clip].events) do
            if e.type=="hit" and e.start<4 then
                for _,id in ipairs(e.effectIds or {e.id}) do if C.effects[tostring(id)] and C.effects[tostring(id)].type=="damage" then expected=expected+1 end end
            end
        end
        return contacts==expected and contacts>0
    end)
    test("projectile-spawn-lifetime-and-repeat-interval",function()
        local s,b=fresh();Q.start(s);b.aiEnabled=false;B.cast(b,202207)
        b.bone=function() return {x=s.position.x,y=s.position.y,z=s.position.z} end
        local count,spawned=0,false
        b.damage=function() count=count+1;return 1 end
        for _=1,1440 do B.update(b,1/120,s.position,true);if #b.hazards>0 then spawned=true end end
        return spawned and #b.hazards==0 and count>0
    end)
    test("switch-projectile-removes-missing-destination",function()
        local s,b=fresh()
        b.hazards={{key=1,id="20220703",pos=b.pos,yaw=0,speed=0,age=0,nextSweep=0}}
        B.triggerEffect(b,20229904);B.update(b,.01,s.position,true)
        return #b.hazards==0
    end)
    test("stone-decoy-expiry",function()
        local s,b=fresh();B.triggerEffect(b,20229999)
        local spawned=#b.decoys==1
        B.update(b,2.4,s.position,true);local alive=#b.decoys==1
        B.update(b,.11,s.position,true)
        return spawned and alive and #b.decoys==0
    end)
    test("stone-decoy-player-rebound-and-buff",function()
        local s,b=fresh();Q.start(s);B.triggerEffect(b,20229999)
        S.press(s,"light");S.update(s,.01)
        local meta=WKCombatConfig.clips[s.clip];local hit
        for _,e in ipairs(meta.events) do if e.type=="hit" then hit=e;break end end
        s.action.t=hit.start+.01;s.action.prev=hit.start
        local d=b.decoys[1];local h=C.stone.decoy.hurt.a
        local p={x=d.pos.x+h[1]*math.sin(d.yaw),y=d.pos.y+h[2],z=d.pos.z+h[1]*math.cos(d.yaw)}
        B.resolveDecoys(b,s,function() return p end)
        return s.action.kind=="rebound" and B.hasBuff(b,202205)
    end)
    test("teleport-inside-arena-facing-player",function()
        local s,b=fresh();s.position={x=-.274,y=-6.419,z=38.657};b.target=s.position;s.cameraYaw=0
        B.triggerEffect(b,20229890)
        local dist,angle=B.relation(b)
        return math.abs(dist-15)<.01 and math.abs(angle)<.01
    end)
    test("victory-delay-retry-clears-all-resources",function()
        local s,b=fresh();Q.start(s);B.triggerEffect(b,20229999);s.bossHp=0
        Q.update(s,.01,s.position)
        local before=s.challenge=="victory" and Q.retry(s)==nil and #b.decoys==0
        advance(s,2.6);local next=Q.retry(s)
        return before and next and next.challenge=="ready" and next.epoch==2 and next.hp==390
            and next.bossHp==6480 and next.mp==220 and next.stamina==250 and next.gourd==6
            and next.focus==0 and #next.boss.hazards==0 and #next.boss.decoys==0 and next.action==nil
    end)
    test("defeat-delay-retry-and-context-isolation",function()
        local s,b=fresh();local other=fresh();Q.start(s);s.hp=0;Q.update(s,.01,s.position)
        local before=s.challenge=="defeat" and Q.retry(s)==nil
        advance(s,2.3);local next=Q.retry(s)
        return before and next and next.epoch==2 and other.hp==390 and other.bossHp==6480 and other.epoch==1
    end)
    test("retry-waits-for-observed-player-spawn",function()
        local s,b=fresh();Q.start(s);s.hp=0;Q.update(s,.01,s.position);advance(s,2.3)
        local next=Q.retry(s)
        Q.update(next,.01,{x=0,y=-5,z=33.6})
        local waiting=next.challenge=="ready" and next.awaitSpawn==true
        Q.update(next,.01,{x=0,y=-1.237,z=0})
        Q.update(next,.01,{x=0,y=-5,z=33.6})
        return waiting and next.challenge=="fight" and not next.awaitSpawn
    end)
    test("all-skill-timelines-execute",function()
        for id,spec in pairs(C.skills) do
            local s,b=fresh();Q.start(s);b.aiEnabled=false;s.hp=100000
            b.bone=function() return {x=100,y=100,z=100} end
            if not B.cast(b,id) then return false end
            for _=1,math.ceil((C.clips[spec.clip].duration*3+2)*30) do B.update(b,1/30,s.position,true) end
        end
        return true
    end)
end
return M
