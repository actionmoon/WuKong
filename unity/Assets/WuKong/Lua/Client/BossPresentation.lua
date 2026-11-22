local UE=UnityEngine
local state,boss,animation,localActor,template=nil,nil,nil,nil,nil
local renderers,objects={},{}
local observed=nil
local lastClip=nil
local arena,windMaterial=nil,nil
local function collect(go)
    return go:GetComponentsInChildren(typeof(UE.Renderer),true)
end
function Start()
    if DouyinApplication.isServer then return end
    state=UE.GameObject.Find("CombatState"):GetComponent(typeof(DouyinScript)).script
    boss=UE.GameObject.Find("TigerBaseline");animation=boss:GetComponent(typeof(UE.Animation))
    renderers=collect(boss);template=UE.GameObject.Find("StoneDecoyTemplate")
    arena=UE.GameObject.Find("ArenaPresentation"):GetComponent(typeof(DouyinScript)).script
    windMaterial=UE.GameObject.Find("WindHazardMaterial"):GetComponent(typeof(UE.Renderer)).sharedMaterial
    if template then
        local rs=collect(template);for i=0,rs.Length-1 do rs[i].enabled=false end
    end
end
function Observe(actorID) observed=actorID end
local function presentation(key,spec,isDecoy)
    local item=objects[key]
    if not item then
        local go
        if isDecoy then go=UE.Object.Instantiate(template)
        else
            local shape=WKBossConfig.bullets[spec.id].shape
            go=UE.GameObject.CreatePrimitive(shape.box and UE.PrimitiveType.Cube or shape.capsule and UE.PrimitiveType.Cylinder or UE.PrimitiveType.Sphere)
            local collider=go:GetComponent(typeof(UE.Collider));if collider then UE.Object.Destroy(collider) end
            local renderer=go:GetComponent(typeof(UE.Renderer))
            renderer.sharedMaterial=windMaterial
            if shape.box then go.transform.localScale=UE.Vector3(shape.box[2]*2,shape.box[3]*2,shape.box[1]*2)
            elseif shape.capsule then go.transform.localScale=UE.Vector3(shape.capsule.radius*2,shape.capsule.halfHeight,shape.capsule.radius*2)
            else go.transform.localScale=UE.Vector3.one*(shape.sphere*2) end
        end
        go.name="ChallengeFx_"..key
        local rs=collect(go);for i=0,rs.Length-1 do rs[i].enabled=true end
        item={go=go};objects[key]=item
    end
    item.seen=true
    local p=spec.pos;local height=not isDecoy and WKBossConfig.bullets[spec.id].shape.capsule
    item.go.transform.position=UE.Vector3(p.x,p.y+(height and height.halfHeight or 0),p.z)
    item.go.transform.rotation=UE.Quaternion.Euler(0,spec.yaw*180/math.pi+(isDecoy and 90 or 0),0)
end
function Update()
    if DouyinApplication.isServer or not state then return end
    if not localActor then
        local actors=DouyinActorService.GetActors()
        if actors then for i=0,actors.Length-1 do if actors[i].isLocal then localActor=actors[i] end end end
    end
    if not localActor then return end
    local views=state.GetViews();local v=views[tostring(observed or localActor.actorID)]
    if not v or not v.boss then return end
    local b=v.boss;local p=b.pos
    boss.transform.position=UE.Vector3(p.x,p.y,p.z)
    boss.transform.rotation=UE.Quaternion.Euler(0,b.yaw*180/math.pi+90,0)
    if lastClip~=b.clip then animation:Play(b.clip);lastClip=b.clip end
    local clip=animation:get_Item(b.clip)
    if clip then clip.speed=0;clip.time=b.t;animation:Sample() end
    for i=0,renderers.Length-1 do
        renderers[i].enabled=not b.invisible
    end
    for _,item in pairs(objects) do item.seen=false end
    for _,h in ipairs(b.hazards or {}) do
        -- Empty bullet has no visible wind/damage, matching the reference.
        if h.id~="20010103" then presentation(tostring(v.epoch)..":h:"..h.key,h,false) end
    end
    if template then for _,d in ipairs(b.decoys or {}) do presentation(tostring(v.epoch)..":d:"..d.key,d,true) end end
    for key,item in pairs(objects) do if not item.seen then UE.Object.Destroy(item.go);objects[key]=nil end end
    if not b.canLock and arena.IsLocked() then arena.SetLocked(false) end
end
function OnDestroy()
    for _,item in pairs(objects) do UE.Object.Destroy(item.go) end;objects={}
end
