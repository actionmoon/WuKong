local template = nil
local visuals = {}
local actorPoll = 0
local initialProbe = false
local combat = nil
local templates={}
local effects={}
local function bones(go)
    local out={}
    local ts=go:GetComponentsInChildren(typeof(UnityEngine.Transform),true)
    for i=0,ts.Length-1 do out[ts[i].name]=ts[i] end
    return out
end
local function clone(source,name)
    local go=UnityEngine.Object.Instantiate(source);go.name=name;go:SetActive(true)
    return {model=go,animation=go:GetComponent(typeof(UnityEngine.Animation)),bones=bones(go)}
end
local function poseModel(v,clip,t)
    if not v.animation then return end
    if v.clip~=clip then v.animation:Play(clip);v.clip=clip end
    local state=v.animation:get_Item(clip)
    if state then state.speed=0;state.time=t;v.animation:Sample() end
end

function GetTemplate() return template end
function GetVisual(actorID)
    local v=visuals[actorID]
    return v and (v.active or v)
end

function Start()
    template = UnityEngine.GameObject.Find("WukongVisualTemplate")
    if template then template:SetActive(false) end
    local input = UnityEngine.GameObject.Find("CombatInput")
    if input then combat = input:GetComponent(typeof(DouyinScript)).script end
    local holder=UnityEngine.GameObject.Find("SkillsTemplates")
    if holder then
        for _,row in ipairs({{"lang","GuangzhiVisualTemplate"},{"she","GuangmouVisualTemplate"},{"snake","SpiritSnakeVisualTemplate"}}) do
            local t=holder.transform:Find(row[2]);if t then templates[row[1]]=t.gameObject end
        end
    end
    print("[WK-SAMPLE] visuals-start server=" .. tostring(DouyinApplication.isServer))
end

function Update()
    if DouyinApplication.isServer or template == nil or not DouyinNetService.isNetworkSettled then return end
    actorPoll = actorPoll + UnityEngine.Time.deltaTime
    if actorPoll < 0.5 then return end
    actorPoll = 0
    local actors = DouyinActorService.GetActors()
    if actors == nil then return end
    for i = 0, actors.Length - 1 do
        local actor = actors[i]
        local key = actor.actorID
        if visuals[key] == nil then
            -- Only the local rendering proxy is cloned; the platform retains its Avatar.
            local model = UnityEngine.Object.Instantiate(template)
            model.name = "WukongAvatarVisual_" .. tostring(key)
            model:SetActive(true)
            local animation = model:GetComponent(typeof(UnityEngine.Animation))
            if animation then
                animation.wrapMode = UnityEngine.WrapMode.Loop
                animation:Play(WKSampleConfig.idleClip)
            end
            actor:SetVisible(false)
            visuals[key] = { actor = actor, model = model, animation = animation,
                age = 0, samples = 0, origin = actor.position, moved = false, forms={},bones=bones(model) }
            print("[WK-SAMPLE] avatar-bound actor=" .. tostring(key)
                .. " local=" .. tostring(actor.isLocal) .. " animation=" .. WKSampleConfig.idleClip)
        end
        if actor.isLocal and not initialProbe then
            local state = UnityEngine.GameObject.Find("SampleState"):GetComponent(typeof(DouyinScript))
            state.script.RequestProbe()
            initialProbe = true
        end
    end
end

function LateUpdate()
    if DouyinApplication.isServer then return end
    for _, visual in pairs(visuals) do
        local pose = combat and combat.GetPose(visual.actor.actorID)
        local kind=pose and pose.form or "wukong"
        local active=visual
        if templates[kind] then
            if not visual.forms[kind] then visual.forms[kind]=clone(templates[kind],"AvatarForm_"..kind.."_"..visual.actor.actorID) end
            active=visual.forms[kind]
        end
        visual.active=active
        visual.model:SetActive(active==visual)
        for _,v in pairs(visual.forms) do v.model:SetActive(v==active) end
        active.model.transform.position=visual.actor.position
        active.model.transform.rotation=visual.actor.rotation*UnityEngine.Quaternion.Euler(0,90,0)
        if pose then poseModel(active,pose.clip,pose.t) end
        visual.model.transform.position = visual.actor.position
        -- glTFast mirrors source +X into -X; align that model axis with Avatar +Z.
        visual.model.transform.rotation = visual.actor.rotation * UnityEngine.Quaternion.Euler(0, 90, 0)
        visual.age = visual.age + UnityEngine.Time.deltaTime
        if visual.samples < 2 and visual.age >= (visual.samples + 1) * 2 then
            visual.samples = visual.samples + 1
            local state = visual.animation and visual.animation:get_Item(WKSampleConfig.idleClip)
            print("[WK-SAMPLE] animation-sample actor=" .. tostring(visual.actor.actorID)
                .. " time=" .. tostring(state and state.time)
                .. " playing=" .. tostring(visual.animation and visual.animation.isPlaying)
                .. " position=" .. tostring(visual.model.transform.position))
        end
        if not visual.moved and UnityEngine.Vector3.Distance(visual.origin, visual.actor.position) > 0.5 then
            visual.moved = true
            print("[WK-SAMPLE] visual-follow actor=" .. tostring(visual.actor.actorID)
                .. " position=" .. tostring(visual.model.transform.position)
                .. " error=" .. tostring(UnityEngine.Vector3.Distance(visual.model.transform.position, visual.actor.position)))
        end
    end
    -- A player's summons belong to the same challenge as that player's tiger.
    local owner=nil
    for _,v in pairs(visuals) do if v.actor.isLocal then owner=v;break end end
    local view=owner and combat and combat.GetView(owner.actor.actorID)
    for _,v in pairs(effects) do v.seen=false end
    local function object(key,source)
        local v=effects[key]
        if not v then v=clone(source,"SkillVisual_"..key);effects[key]=v end
        v.seen=true;return v
    end
    if view then
        local prefix=tostring(view.epoch)..":"
        if view.cloud then
            local d=view.cloud.decoy;local v=object(prefix.."cloud",template)
            v.model.transform.position=UnityEngine.Vector3(d.x,d.y,d.z)
            v.model.transform.rotation=UnityEngine.Quaternion.Euler(0,d.yaw*180/math.pi+90,0)
            poseModel(v,d.clip,d.t)
        end
        for _,n in ipairs(view.snakes or {}) do
            if templates.snake then
                local v=object(prefix.."snake:"..n.key,templates.snake)
                local cfg=WKSkillsConfig.bianhua.spirit.summon.mesh
                v.model.transform.position=UnityEngine.Vector3(n.pos.x,n.pos.y+cfg.offsetY,n.pos.z)
                v.model.transform.rotation=UnityEngine.Quaternion.Euler(0,n.yaw*180/math.pi+90,0)
                v.model.transform.localScale=UnityEngine.Vector3.one*cfg.scale
                v.model:SetActive(n.phase~="delay");poseModel(v,n.clip,n.t)
            end
        end
        for _,h in ipairs(view.projectiles or {}) do
            local key=prefix.."bullet:"..h.key;local v=effects[key]
            if not v then
                local go=UnityEngine.GameObject.CreatePrimitive(UnityEngine.PrimitiveType.Sphere)
                local collider=go:GetComponent(typeof(UnityEngine.Collider));if collider then UnityEngine.Object.Destroy(collider) end
                local material=UnityEngine.GameObject.Find("WindHazardMaterial")
                if material then go:GetComponent(typeof(UnityEngine.Renderer)).sharedMaterial=material:GetComponent(typeof(UnityEngine.Renderer)).sharedMaterial end
                go.name="SpiritBullet_"..key;go.transform.localScale=UnityEngine.Vector3.one*WKSkillsConfig.bianhua.spirit.bullet.radius*2
                v={model=go};effects[key]=v
            end
            v.seen=true;v.model.transform.position=UnityEngine.Vector3(h.pos.x,h.pos.y,h.pos.z)
        end
    end
    for key,v in pairs(effects) do if not v.seen then UnityEngine.Object.Destroy(v.model);effects[key]=nil end end
end

function OnActorDespawned(actor)
    local visual = visuals[actor.actorID]
    if visual then
        UnityEngine.Object.Destroy(visual.model)
        for _,v in pairs(visual.forms) do UnityEngine.Object.Destroy(v.model) end
        visuals[actor.actorID] = nil
    end
end

function OnDestroy()
    for _, visual in pairs(visuals) do
        UnityEngine.Object.Destroy(visual.model)
        for _,v in pairs(visual.forms) do UnityEngine.Object.Destroy(v.model) end
    end
    visuals = {}
    for _,v in pairs(effects) do UnityEngine.Object.Destroy(v.model) end
    effects={}
end
