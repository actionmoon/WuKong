---@var presentationData:UnityEngine.TextAsset
---@var stoneTexture:UnityEngine.Texture2D
---@var ghostMaterial:UnityEngine.Material
---@end
local UE=UnityEngine
local data,input,visuals,arena=nil,nil,nil,nil
local holder,boss=nil,nil
local bossBones={}
local pools,live,tracks,trails={},{},{},{}
local epoch=nil
local count=0
local stats={bursts=0,missed=0,peak=0,trails=0,stone=0,immobilize=0,cloud=0,transform=0,snake=0}
local materialStates={}
local function bones(go)
    local out={};local ts=go:GetComponentsInChildren(typeof(UE.Transform),true)
    for i=0,ts.Length-1 do out[ts[i].name]=ts[i] end
    return out
end
local function recycle(item)
    for i=0,item.particles.Length-1 do item.particles[i]:Stop(true,UE.ParticleSystemStopBehavior.StopEmittingAndClear) end
    item.go:SetActive(false);item.follow=nil;item.key=nil;item.active=false
end
local function resolve(name)
    if data.vfx.systems[name] then return name end
    if name=="NG_wukong_chenggun_baofa" then return "NG_WuKong_XuLiGun_BaoFa_01_burst" end
    if name=="HS_In" or name=="HS_InBurst" then return "transform" end
    if string.find(name,"comboC") then return "groundHit" end
    if string.find(name,"DingShen") then return "immobilize" end
    if string.find(name,"JXSQ") then return "cloud" end
    if string.find(name,"Lang") or string.find(name,"Daolang") then return "transform" end
    if string.find(name,"She") or string.find(name,"she") then return "snake" end
    return nil
end
function Burst(name,position,follow,key,life)
    name=resolve(name)
    if not name then stats.missed=stats.missed+1;return end
    local pool=pools[name]
    if not pool then
        local source=holder:Find(name)
        if not source then return end
        pool={};pools[name]=pool
    end
    local item=nil
    for _,candidate in ipairs(pool) do if not candidate.active then item=candidate;break end end
    if not item and #pool<3 and count<64 then
        local go=UE.Object.Instantiate(holder:Find(name).gameObject)
        go.name="PresentationFX_"..name
        item={go=go,particles=go:GetComponentsInChildren(typeof(UE.ParticleSystem),true)}
        pool[#pool+1]=item;live[#live+1]=item;count=count+1
    end
    if not item then return end
    item.go.transform.position=position;item.go:SetActive(true);item.active=true
    item.age=0;item.life=life or 3;item.follow=follow;item.key=key
    for i=0,item.particles.Length-1 do item.particles[i]:Play(true) end
    stats.bursts=stats.bursts+1
    if stats[name] then stats[name]=stats[name]+1 end
end
local function reset()
    for _,item in ipairs(live) do recycle(item) end
    for _,trail in pairs(trails) do trail.renderer.emitting=false;trail.renderer:Clear() end
    tracks={}
    arena.Shake(0)
end
local function poll(key,pose,model,transforms)
    local contract=pose and data.clips[pose.clip]
    if not contract then return end
    local previous=tracks[key]
    local changed=not previous or previous.play~=pose.play or previous.clip~=pose.clip
    local last=changed and math.max(-.001,pose.t-.15) or previous.t
    if not changed and pose.t<last-.02 then last=-.001 end
    local trailing=false
    for _,cue in ipairs(contract.cues) do
        if cue.type=="vfx" then
            local active=cue.time<=pose.t and (cue["end"] or cue.time)>=pose.t
            if string.find(string.lower(cue.name),"trail") and active then trailing=true end
            if cue.time>last and cue.time<=pose.t and not string.find(string.lower(cue.name),"trail") then
                local bone=transforms[cue.socket]
                Burst(cue.name,bone and bone.position or model.transform.position,
                    cue.attached and bone or nil,nil,math.max(2,(cue["end"] or 0)-cue.time+1))
            end
        elseif cue.type=="cameraShake" and cue.time>last and cue.time<=pose.t then
            local strength=string.find(cue.name,"lv3") and .6 or string.find(cue.name,"lv2") and .4 or .25
            arena.Shake(strength)
        end
    end
    local trail=trails[key]
    if not trail then
        local go=UE.Object.Instantiate(holder:Find("WeaponTrail").gameObject);go:SetActive(true)
        trail={go=go,renderer=go:GetComponent(typeof(UE.TrailRenderer))};trails[key]=trail
    end
    local tip=transforms[pose.form=="lang" and "FX_Trail_Fire_01" or "FX_Weapon_Trail_01"]
        or transforms["FX_weapon_trail_01"] or transforms.weapon_r
    local switched=changed or trail.model~=model
    if switched then trail.renderer:Clear();trail.model=model end
    if tip then trail.go.transform.position=tip.position end
    if trailing and not trail.renderer.emitting then stats.trails=stats.trails+1 end
    trail.renderer.emitting=trailing and tip~=nil
    tracks[key]={play=pose.play,clip=pose.clip,t=pose.t}
end
local function tint(go,rock,cloud,death)
    local cached=materialStates[go]
    if not cached and not rock and not cloud and not death then return end
    if not cached then
        cached={};materialStates[go]=cached
        local rs=go:GetComponentsInChildren(typeof(UE.Renderer),true)
        for i=0,rs.Length-1 do
            local renderer=rs[i]
            local original=renderer.sharedMaterials
            cached[#cached+1]={renderer=renderer,original=original,block=UE.MaterialPropertyBlock()}
        end
    end
    for _,entry in ipairs(cached) do
        local value=cloud and .14 or death and death or 1
        local mode=cloud and "cloud" or death and "death" or rock and "rock" or "normal"
        if mode~=entry.mode or mode=="death" and math.abs(value-(entry.value or 1))>.02 then
        if cloud or death then
            if not entry.ghost then
                entry.ghost=entry.renderer.sharedMaterials
                for j=0,entry.ghost.Length-1 do
                    local material=UE.Material(ghostMaterial)
                    if entry.original[j]:HasProperty("_BaseMap") then material:SetTexture("_BaseMap",entry.original[j]:GetTexture("_BaseMap")) end
                    material:SetFloat("_Surface",1);material:SetFloat("_SrcBlend",5);material:SetFloat("_DstBlend",10)
                    material:SetFloat("_ZWrite",0);material:EnableKeyword("_SURFACE_TYPE_TRANSPARENT");material.renderQueue=3000
                    entry.ghost[j]=material
                end
            end
            entry.renderer.sharedMaterials=entry.ghost
            entry.renderer:SetPropertyBlock(nil)
            for j=0,entry.ghost.Length-1 do entry.ghost[j]:SetColor("_BaseColor",UE.Color(.75,.8,.85,value)) end
        else
            entry.renderer.sharedMaterials=entry.original
            entry.block:Clear()
            if rock then
                entry.block:SetColor("_BaseColor",UE.Color(.78,.72,.6,1))
                if stoneTexture then entry.block:SetTexture("_BaseMap",stoneTexture) end
                entry.block:SetVector("_BaseMap_ST",UE.Vector4(20,20,0,0))
            end
            entry.renderer:SetPropertyBlock(entry.block)
        end
        entry.mode=mode;entry.value=value
        end
    end
end
function GetStats()
    local particles=0
    for _,item in ipairs(live) do if item.active then
        for i=0,item.particles.Length-1 do particles=particles+item.particles[i].particleCount end
    end end
    stats.particles=particles;stats.peakParticles=math.max(stats.peakParticles or 0,particles)
    return stats
end
function Start()
    if DouyinApplication.isServer then return end
    data=WKJson.decode(presentationData.text);holder=UE.GameObject.Find("PresentationTemplates").transform
    input=UE.GameObject.Find("CombatInput"):GetComponent(typeof(DouyinScript)).script
    visuals=UE.GameObject.Find("AvatarVisualSample"):GetComponent(typeof(DouyinScript)).script
    arena=UE.GameObject.Find("ArenaPresentation"):GetComponent(typeof(DouyinScript)).script
    boss=UE.GameObject.Find("TigerBaseline");bossBones=bones(boss)
end
function LateUpdate()
    if DouyinApplication.isServer or not data then return end
    local v=input.GetLocalView()
    local visual=visuals.GetVisual(input.GetLocalActorID())
    if not v or not visual then return end
    if epoch~=v.epoch then reset();epoch=v.epoch end
    local dt=UE.Time.deltaTime
    poll("player",input.GetPose(v.actorID) or v,visual.model,visual.bones)
    poll("tiger",v.boss,boss,bossBones)
    local previous=tracks.state
    if previous then
        if v.bossHp<previous.bossHp then Burst(v.boss.stone and "hit_stone" or "hit_staff",
            boss.transform.position+UE.Vector3(0,1.8,0));arena.Shake(.28) end
        if v.hp<previous.hp then Burst("hit_tiger",visual.model.transform.position+UE.Vector3(0,1,0));arena.Shake(.3) end
        if v.boss.stone and not previous.stone then Burst("NG_HYM_HuStone_Stone_InPut",boss.transform.position);stats.stone=stats.stone+1 end
        if not v.boss.stone and previous.stone then Burst("NG_HYM_HuStone_Stone_OutPut",boss.transform.position) end
        if v.form~=previous.form then Burst("transform",visual.model.transform.position) end
        if (v.cloud~=nil)~=previous.cloud then Burst("cloud",visual.model.transform.position) end
    end
    local immobile=(v.immobilized or 0)>0
    local hasGlyph=false
    for _,item in ipairs(live) do if item.active and item.key=="glyph" then
        hasGlyph=true;if not immobile then recycle(item) else item.age=0 end
    end end
    if immobile and not hasGlyph then Burst("immobilize",boss.transform.position+UE.Vector3(0,3,0),bossBones.head,"glyph",1.2) end
    tint(boss,v.boss.stone,false,v.challenge=="victory" and math.max(0,1-(v.boss.t-4)*.2) or nil)
    tint(visual.model,false,v.cloud~=nil,v.hp<=0 and math.max(0,1-(v.t-4.1)/5) or nil)
    local snakes={}
    for _,snake in ipairs(v.snakes or {}) do
        snakes[snake.key]=true
        if not previous or not previous.snakes[snake.key] then Burst("snake",UE.Vector3(snake.pos.x,snake.pos.y,snake.pos.z)) end
    end
    for _,p in ipairs(v.projectiles or {}) do
        local key="poison:"..p.key;local item=nil
        for _,candidate in ipairs(live) do if candidate.key==key and candidate.active then item=candidate;break end end
        if not item then Burst("poisonBullet",UE.Vector3(p.pos.x,p.pos.y,p.pos.z),nil,key,.3)
        else item.go.transform.position=UE.Vector3(p.pos.x,p.pos.y,p.pos.z) end
    end
    tracks.state={bossHp=v.bossHp,hp=v.hp,stone=v.boss.stone,form=v.form,cloud=v.cloud~=nil,snakes=snakes}
    local active=0
    for _,item in ipairs(live) do
        if item.active then
            item.age=item.age+dt
            if item.follow then item.go.transform.position=item.follow.position end
            if item.age>=item.life then recycle(item) else active=active+1 end
        end
    end
    stats.peak=math.max(stats.peak,active)
end
function OnDestroy()
    for _,item in ipairs(live) do UE.Object.Destroy(item.go) end
    for _,trail in pairs(trails) do UE.Object.Destroy(trail.go) end
    for _,entries in pairs(materialStates) do
        for _,entry in ipairs(entries) do
            if entry.renderer and not entry.renderer:IsNull() then entry.renderer.sharedMaterials=entry.original end
            if entry.ghost then for i=0,entry.ghost.Length-1 do UE.Object.Destroy(entry.ghost[i]) end end
        end
    end
end
