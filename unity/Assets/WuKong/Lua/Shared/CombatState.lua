---@varSync snapshot:string
---@end
local UE = UnityEngine
local json = WKJson
local request, ready, elapsed = nil, false, 0
local sessions, models, players = {}, {}, {}
local localViews = {}
local Session = nil
local Challenge, Boss = nil,nil
local template, boss = nil, nil
local formTemplates={}
local traffic={inputBytes=0,inputMessages=0,snapshotBytes=0,snapshotMessages=0}
function GetTraffic() return traffic end
local function log(e) print("[WK-COMBAT] "..json.encode(e)) end

function Start()
    request=DouyinRemoteEvent("WKCombatInput")
    if DouyinApplication.isServer then request.onServerEvent:AddListener(OnRequest) end
    if DouyinApplication.isServer then
        local root=UE.GameObject.Find("DouyinServerRoot"):GetComponent(typeof(DouyinScript))
        Session=root.script.GetCombatModule()
        Challenge=root.script.GetChallengeModule();Boss=root.script.GetBossModule()
        print("[WK-COMBAT] session-module="..tostring(Session~=nil))
    end
    template=UE.GameObject.Find("WukongVisualTemplate")
    if not template then
        template=UE.GameObject.Find("AvatarVisualSample"):GetComponent(typeof(DouyinScript)).script.GetTemplate()
    end
    boss=UE.GameObject.Find("TigerBaseline")
    local holder=UE.GameObject.Find("SkillsTemplates")
    if holder then
        for _,row in ipairs({{"lang","GuangzhiVisualTemplate"},{"she","GuangmouVisualTemplate"},{"snake","SpiritSnakeVisualTemplate"}}) do
            local child=holder.transform:Find(row[2]);if child then formTemplates[row[1]]=child.gameObject end
        end
    end
end
function OnNetSpawned()
    ready=true
    snapshot:OnValueChange(function(value)
        if not ready or DouyinApplication.isServer then return end
        local decoded=json.decode(value or "")
        traffic.snapshotBytes=traffic.snapshotBytes+#(value or "")
        traffic.snapshotMessages=traffic.snapshotMessages+1
        if decoded then
            localViews=decoded
        end
    end)
end
function GetViews() return localViews end
function Send(value)
    if ready and DouyinNetService.isNetworkSettled and not DouyinApplication.isServer then
        traffic.inputBytes=traffic.inputBytes+#value;traffic.inputMessages=traffic.inputMessages+1
        request:FireServer(value)
    end
end
local function sample(model,clip,t)
    if model.clip~=clip then model.animation:Play(clip);model.clip=clip end
    local state=model.animation:get_Item(clip)
    if state then state.speed=0;state.time=t;model.animation:Sample() end
end
local function bones(go)
    local result={}
    local transforms=go:GetComponentsInChildren(typeof(UE.Transform),true)
    for i=0,transforms.Length-1 do result[transforms[i].name]=transforms[i] end
    return result
end
local function hiddenClone(template,name)
    local go=UE.Object.Instantiate(template);go.name=name;go:SetActive(true)
    local renderers=go:GetComponentsInChildren(typeof(UE.Renderer),true)
    for i=0,renderers.Length-1 do renderers[i].enabled=false end
    return {go=go,animation=go:GetComponent(typeof(UE.Animation)),bones=bones(go)}
end
local function destroyModel(model)
    UE.Object.Destroy(model.go);UE.Object.Destroy(model.boss.go)
    for _,m in pairs(model.forms or {}) do UE.Object.Destroy(m.go) end
    for _,m in pairs(model.snakes or {}) do UE.Object.Destroy(m.go) end
end
local function ground(p)
    local hits=UE.Physics.RaycastAll(UE.Vector3(p.x,p.y+6,p.z),UE.Vector3.down,20,1,UE.QueryTriggerInteraction.Ignore)
    local best=nil
    if hits then for i=0,hits.Length-1 do
        local h=hits[i]
        if h.normal.y>0.4 and (not best or h.point.y>best.y) then best={x=p.x,y=h.point.y,z=p.z} end
    end end
    return best
end
local function moveBoss(p,dx,dz,b)
    local length=math.sqrt(dx*dx+dz*dz)
    if length>0.00001 then
        local direction=UE.Vector3(dx/length,0,dz/length)
        local hits=UE.Physics.SphereCastAll(UE.Vector3(p.x,p.y+0.9,p.z),0.65,direction,length+0.05,1,UE.QueryTriggerInteraction.Ignore)
        if hits then for i=0,hits.Length-1 do
            local h=hits[i]
            if h.normal.y<0.4 and h.distance>0.001 then length=math.min(length,math.max(0,h.distance-0.05)) end
        end end
        dx=direction.x*length;dz=direction.z*length
        local target=b.target
        if target and not Boss.hasBuff(b,202212) and not WKCombatClock.active(WKBossConfig.clips[b.clip],b.t,"noHitMove")
            and not WKCombatClock.active(WKBossConfig.clips[b.clip],b.t,"collision") then
            local ox,oz=p.x-target.x,p.z-target.z;local radius=WKBossConfig.capsule.radius+WKCombatConfig.capsule.radius
            if (ox+dx)^2+(oz+dz)^2<radius^2 then
                local dist=math.sqrt(ox*ox+oz*oz)
                if dist>0.001 then local dot=dx*ox/dist+dz*oz/dist
                    if dot<0 then dx=dx-dot*ox/dist;dz=dz-dot*oz/dist end
                end
            end
        end
    end
    local q={x=p.x+dx,y=p.y,z=p.z+dz};local floor=ground(q)
    return floor or p
end
local function create(player, actor, replacement)
    local key=player.playerOpenID
    if models[key] then destroyModel(models[key]) end
    local s=replacement or Challenge.new(actor.actorID,log)
    s.ack=0;s.yaw=actor.rotation.eulerAngles.y*math.pi/180
    sessions[key]=s;players[key]=player
    local model=hiddenClone(template,"CombatPose_"..tostring(actor.actorID))
    model.boss=hiddenClone(boss,"BossPose_"..tostring(actor.actorID));models[key]=model
    model.forms={};model.snakes={}
    for _,kind in ipairs({"lang","she"}) do
        if formTemplates[kind] then model.forms[kind]=hiddenClone(formTemplates[kind],"CombatPose_"..kind.."_"..actor.actorID) end
    end
    s.ground=ground
    s.bone=function(name)
        local m=model.forms[s.form] or model
        local t=m.bones[name];if t then local p=t.position;return {x=p.x,y=p.y,z=p.z} end
    end
    s.snakeSocket=function(n,name)
        if not formTemplates.snake then return nil end
        local m=model.snakes[n.key]
        if not m then m=hiddenClone(formTemplates.snake,"SnakePose_"..n.key);model.snakes[n.key]=m end
        local cfg=WKSkillsConfig.bianhua.spirit.summon.mesh
        m.go.transform.position=UE.Vector3(n.pos.x,n.pos.y+cfg.offsetY,n.pos.z)
        m.go.transform.rotation=UE.Quaternion.Euler(0,n.yaw*180/math.pi+90,0)
        m.go.transform.localScale=UE.Vector3.one*cfg.scale
        sample(m,n.clip,n.t)
        local t=m.bones[name];if t then local p=t.position;return {x=p.x,y=p.y,z=p.z} end
    end
    local bm=model.boss
    s.boss.ground=ground;s.boss.move=moveBoss
    s.boss.sample=function(b)
        bm.go.transform.position=UE.Vector3(b.pos.x,b.pos.y,b.pos.z)
        bm.go.transform.rotation=UE.Quaternion.Euler(0,b.yaw*180/math.pi+90,0)
        sample(bm,b.clip,b.t)
    end
    s.boss.bone=function(name)
        local t=bm.bones[name];if t then local p=t.position;return {x=p.x,y=p.y,z=p.z} end
    end
    s.boss.socketYaw=function(name)
        local t=bm.bones[name]
        if t then local dir=t.rotation*UE.Vector3.left;return math.atan(dir.x,dir.z) end
    end
    s.boss.nearestSocket=function(prefix,from)
        local best,dist=nil,math.huge
        for name,t in pairs(bm.bones) do
            if string.sub(name,1,#prefix)==prefix then
                local p=t.position;local d=(p.x-from.x)^2+(p.y-from.y)^2+(p.z-from.z)^2
                if d<dist then dist=d;best={x=p.x,y=p.y,z=p.z} end
            end
        end
        return best
    end
    s.boss.sample(s.boss)
    log({ev="session",actor=actor.actorID,hp=s.hp,bossHp=s.bossHp})
    return s
end
function OnRequest(player,...)
    if not DouyinApplication.isServer or not ready or not DouyinNetService.isNetworkSettled
        or not self:HasOwnership() or player==nil or player.isServer then return end
    local args={...};local raw=args[1]
    if type(raw)~="string" or #raw>4096 then return end
    local input=json.decode(raw);if type(input)~="table" then return end
    local actor=player:GetActor();if actor==nil then return end
    local key=player.playerOpenID;local s=sessions[key] or create(player,actor)
    local function finite(v) return type(v)=="number" and v==v and math.abs(v)<100000 end
    if not finite(input.x) or not finite(input.z) then return end
    Session.input(s,input.x,input.z,input.sprint==true,input.walk==true,input.heavy==true,input.locked==true)
    s.spinHeld=input.spin==true
    if finite(input.cameraYaw) then s.cameraYaw=input.cameraYaw*math.pi/180 end
    s.dodgeDirection=input.direction=="B" and "B" or input.direction=="L" and "L" or input.direction=="R" and "R" or "F"
    for _,cmd in ipairs(input.commands or {}) do
        if type(cmd)=="table" and finite(cmd.id) and cmd.id>s.ack and cmd.id<=s.ack+32 then
            s.ack=cmd.id
            if cmd.name=="light" or cmd.name=="heavy" or cmd.name=="dodge" or cmd.name=="gourd"
                or cmd.name=="spin" or cmd.name=="stanceCycle" or cmd.name=="stance:smash" or cmd.name=="stance:pillar" or cmd.name=="stance:thrust"
                or cmd.name=="immobilize" or cmd.name=="cloud" or cmd.name=="transform" or cmd.name=="spirit" then
                Session.press(s,cmd.name)
            elseif DouyinApplication.isSimulator and cmd.name=="skills-suite" then
                local root=UE.GameObject.Find("DouyinServerRoot"):GetComponent(typeof(DouyinScript))
                root.script.RunSkillsSuite(s.actorID)
            elseif cmd.name=="start" then Challenge.start(s)
            elseif cmd.name=="retry" then
                local next=Challenge.retry(s)
                if next then s=create(player,actor,next);s.ack=cmd.id end
            elseif DouyinApplication.isSimulator and cmd.name=="test-reset" then
                s=create(player,actor,Challenge.new(actor.actorID,log,s.epoch));s.ack=cmd.id
            elseif DouyinApplication.isSimulator and cmd.name=="test-strike" then
                s.strike={time=s.time+0.7,id=cmd.id};log({ev="testWarning",actor=s.actorID,id=cmd.id})
            elseif DouyinApplication.isSimulator and cmd.name=="test-suite" then
                RunFixedSuite(s)
            elseif DouyinApplication.isSimulator and cmd.name=="boss-suite" then
                local root=UE.GameObject.Find("DouyinServerRoot"):GetComponent(typeof(DouyinScript))
                root.script.RunBossSuite(s.actorID)
            elseif DouyinApplication.isSimulator and string.sub(cmd.name,1,10)=="boss-cast:" then
                Challenge.start(s);s.boss.aiEnabled=false;s.debugBoss=true
                Boss.cast(s.boss,string.sub(cmd.name,11),nil,"simulator")
            elseif DouyinApplication.isSimulator and string.sub(cmd.name,1,8)=="boss-hp:" then
                local hp=tonumber(string.sub(cmd.name,9))
                if hp and hp>=0 and hp<=6480 then s.bossHp=hp end
            elseif DouyinApplication.isSimulator and cmd.name=="player-defeat" then
                Session.receive(s,{flatDamage=10000,hitWeight=5})
            elseif DouyinApplication.isSimulator and cmd.name=="boss-ai" then
                s.debugBoss=false;s.boss.aiEnabled=true;Challenge.start(s,true);Boss.aware(s.boss,"simulator-ai")
            elseif DouyinApplication.isSimulator and cmd.name=="boss-idle" then
                Challenge.start(s);s.boss.aiEnabled=false;s.boss.action=nil
                s.boss.state="idle";s.boss.clip=WKBossConfig.idle;s.boss.t=0
                s.boss.hazards={};s.boss.decoys={}
                log({ev="simulatorBossIdle",actor=s.actorID,time=s.time})
            elseif DouyinApplication.isSimulator and cmd.name=="player-heal" then
                s.hp=Session.player(s).stats.hpMax
                log({ev="simulatorHeal",actor=s.actorID,time=s.time,hp=s.hp})
            end
        end
    end
end
function RunFixedSuite(owner)
    -- This entry exercises the production state machine on isolated DS contexts.
    -- Geometry and live replication are verified separately through actual clients.
    local S,K=Session or WKCombatSession,WKCombatClock
    local function test(name,fn)
        local ok,result=pcall(fn);log({ev="fixedTest",name=name,pass=ok and result==true,detail=not ok and tostring(result) or nil})
    end
    local function fresh() local s=S.new(owner.actorID);s.rng=function() return 0.5 end;return s end
    local function advance(s,sec,callback)
        for i=1,math.ceil(sec*120) do S.update(s,1/120);if callback then callback(s) end end
    end
    test("damage-formula",function() return K.damage(WKCombatConfig.player.stats,WKCombatConfig.bossStats,{damageMult=0.9},false,6480,function() return 0.5 end)==54 end)
    test("five-light-combo",function()
        local s=fresh();S.press(s,"light");S.update(s,1/120)
        for nextStep=2,5 do
            local attempts=0
            while s.action and s.action.step==nextStep-1 and attempts<600 do
                attempts=attempts+1
                local meta=WKCombatConfig.clips[s.clip]
                local cw=K.active(meta,s.t,"comboWindow")
                if cw and K.allowed(cw,WKCombatConfig.player.lightCombo[nextStep].skill) then S.press(s,"light") end
                S.update(s,1/120)
            end
            if not s.action or s.action.step~=nextStep then return false end
        end
        return s.action.step==5
    end)
    test("group-hit-dedup-and-new-play",function()
        local s=fresh();S.press(s,"light")
        local pos=function() return {x=0,y=1,z=0} end;local b={x=0,y=0,z=0}
        advance(s,0.6,function(v) S.resolve(v,pos,b);S.resolve(v,pos,b) end)
        local first=s.hits;advance(s,3);S.press(s,"light")
        advance(s,0.6,function(v) S.resolve(v,pos,b) end)
        return first==1 and s.hits==2 and s.bossHp==6480-108
    end)
    test("dodge-cancel",function()
        local s=fresh();S.press(s,"light");advance(s,0.38);S.press(s,"dodge");advance(s,0.08)
        return s.action and s.action.kind=="dodge" and s.stamina<250
    end)
    test("heavy-charge-level-1",function()
        local s=fresh();s.heavyHeld=true;S.press(s,"heavy");advance(s,2.6)
        s.heavyHeld=false;S.update(s,1/120)
        return s.action and s.action.kind=="heavy" and s.action.level==1
    end)
    test("depletion-and-recovery",function()
        local s=fresh();S.input(s,1,0,true,false,false,false);s.stamina=0.05;advance(s,0.1)
        local depleted=s.depleted>0 and s.stamina==0
        S.input(s,0,0,false,false,false,false);advance(s,2)
        return depleted and s.stamina>0 and s.depleted>0
    end)
    test("iframe-and-after-window",function()
        local s=fresh();S.press(s,"dodge");advance(s,0.1)
        local e={damageMult=1,hitWeight=1};local first=S.receive(s,e)
        advance(s,0.6);return first==0 and S.receive(s,e)>0
    end)
    test("perfect-dodge-once",function()
        local s=fresh();s.warningUntil=0.2;s.warningID=7;S.press(s,"dodge");advance(s,0.05)
        return s.perfect==1 and s.focus==40 and s.stamina==250 and S.receive(s,{damageMult=1})==0
    end)
    test("gourd-time-and-once",function()
        local s=fresh();s.hp=100;S.press(s,"gourd");advance(s,0.9)
        local before=s.hp==100 and s.gourd==6;advance(s,0.5)
        return before and math.abs(s.hp-249.8)<0.001 and s.gourd==5 and s.heals==1
    end)
    test("gourd-interrupted-before-heal",function()
        local s=fresh();s.hp=100;S.press(s,"gourd");advance(s,0.5)
        S.receive(s,{damageMult=0,hitWeight=1});advance(s,1)
        return s.gourd==6 and s.heals==0
    end)
end
function Update()
    if not DouyinApplication.isServer or not ready or not DouyinNetService.isNetworkSettled or not self:HasOwnership() then return end
    local dt=math.min(UE.Time.deltaTime,0.1)
    for key,s in pairs(sessions) do
        local actor=players[key]:GetActor();local model=models[key]
        if actor and model then
            s.yaw=actor.rotation.eulerAngles.y*math.pi/180
            if s.strike and s.time>=s.strike.time-0.25 then
                local dist=UE.Vector3.Distance(actor.position,boss.transform.position)
                if dist<5 then s.warningUntil=s.time+WKCombatConfig.perfect.tolerantTime;s.warningID=s.strike.id end
                if s.time>=s.strike.time then
                    if dist<5 then Session.receive(s,{damageMult=1,hitWeight=1,armorBreak=1},s.strike.id) end
                    s.strike=nil
                end
            end
            local steps=math.max(1,math.ceil(dt*60))
            for i=1,steps do
                s.position={x=actor.position.x,y=actor.position.y,z=actor.position.z}
                Session.update(s,dt/steps)
                local m=model.forms[s.form] or model
                m.go.transform.position=actor.position
                m.go.transform.rotation=actor.rotation*UE.Quaternion.Euler(0,90,0)
                sample(m,s.clip,s.t)
                Challenge.update(s,dt/steps,actor.position)
                local bone=s.bone
                if s.challenge=="fight" then
                    Boss.resolveDecoys(s.boss,s,bone)
                    Session.resolve(s,bone,s.boss.pos)
                end
                local alive={};for _,n in ipairs(s.snakes or {}) do alive[n.key]=true end
                for id,m in pairs(model.snakes) do if not alive[id] then UE.Object.Destroy(m.go);model.snakes[id]=nil end end
            end
        end
    end
    elapsed=elapsed+dt
    if elapsed>=0.05 then
        elapsed=0;local all={}
        for _,s in pairs(sessions) do local v=Challenge.snapshot(s);v.ack=s.ack;all[tostring(s.actorID)]=v end
        snapshot:SetValue(json.encode(all))
    end
end
function OnPlayerLeft(player)
    if player==nil then return end
    local key=player.playerOpenID
    if models[key] then destroyModel(models[key]);models[key]=nil end
    sessions[key]=nil;players[key]=nil
end
function OnNetDestroy() ready=false;localViews={} end
function OnDestroy()
    ready=false
    if request then
        if DouyinApplication.isServer then request.onServerEvent:RemoveListener(OnRequest) end
        request:Dispose();request=nil
    end
    for _,model in pairs(models) do destroyModel(model) end
    models={}
end
