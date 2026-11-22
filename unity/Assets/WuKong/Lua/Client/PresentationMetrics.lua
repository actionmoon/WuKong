local UE=UnityEngine
local frames,total,age=0,0,0
local samples={}
local input,state,audio,fx=nil,nil,nil,nil
local previous={inputBytes=0,snapshotBytes=0,inputMessages=0,snapshotMessages=0}
local memorySupported=true
local probe=nil
local hud=nil
local resolutions={{960,540},{1280,720},{1600,720},{1024,768}}
local rendererCache={}
local renderAge=10
local function rendering()
    if renderAge>=10 then
        rendererCache={};renderAge=0
        local rs=UE.Object.FindObjectsOfType(typeof(UE.Renderer))
        for i=0,rs.Length-1 do
            local r=rs[i];local mesh=nil
            local skin=r.gameObject:GetComponent(typeof(UE.SkinnedMeshRenderer))
            local filter=r.gameObject:GetComponent(typeof(UE.MeshFilter))
            if skin then mesh=skin.sharedMesh elseif filter then mesh=filter.sharedMesh end
            local indices=0
            if mesh then for j=0,mesh.subMeshCount-1 do indices=indices+mesh:GetIndexCount(j) end end
            rendererCache[#rendererCache+1]={renderer=r,triangles=indices/3}
        end
    end
    local visible,triangles=0,0
    for _,entry in ipairs(rendererCache) do
        local r=entry.renderer
        if r and not r:IsNull() and r.enabled and r.gameObject.activeInHierarchy and r.isVisible then
            visible=visible+1;triangles=triangles+entry.triangles
        end
    end
    return {cachedRenderers=#rendererCache,visibleRenderers=visible,visibleMeshTriangles=triangles,
        cacheIntervalSeconds=10}
end
function Start()
    if DouyinApplication.isServer or not DouyinApplication.isSimulator then return end
    input=UE.GameObject.Find("CombatInput"):GetComponent(typeof(DouyinScript)).script
    state=UE.GameObject.Find("CombatState"):GetComponent(typeof(DouyinScript)).script
    audio=UE.GameObject.Find("PresentationAudio"):GetComponent(typeof(DouyinScript)).script
    fx=UE.GameObject.Find("PresentationFX"):GetComponent(typeof(DouyinScript)).script
    hud=UE.GameObject.Find("PresentationHUD"):GetComponent(typeof(DouyinScript)).script
end
function Update()
    if not input then return end
    if UE.Input.GetKeyDown(UE.KeyCode.F4) and not probe then probe={index=1,age=0} end
    if probe then
        if probe.age==0 then
            local r=resolutions[probe.index];UE.Screen.SetResolution(r[1],r[2],false)
        end
        probe.age=probe.age+UE.Time.unscaledDeltaTime
        if probe.age>=2 then
            print("[WK-LAYOUT] "..WKJson.encode(hud.MeasureLayout()))
            probe.index=probe.index+1;probe.age=0
            if probe.index>#resolutions then probe=nil;UE.Screen.SetResolution(1200,675,false) end
        end
    end
    local dt=UE.Time.unscaledDeltaTime
    if dt<=0 then return end
    total=total+dt;age=age+dt;renderAge=renderAge+dt;frames=frames+1;samples[#samples+1]=dt
    if age<5 then return end
    table.sort(samples)
    local v=input.GetLocalView()
    local traffic=state.GetTraffic()
    local memory=nil
    if memorySupported then
        local ok,value=pcall(function() return UE.Profiling.Profiler.GetTotalAllocatedMemoryLong() end)
        if ok then memory=value else memorySupported=false end
    end
    local report={time=total,actor=v and v.actorID,epoch=v and v.epoch,challenge=v and v.challenge,
        form=v and v.form,clip=v and v.clip,fps=frames/age,p95ms=samples[math.ceil(#samples*.95)]*1000,
        maxms=samples[#samples]*1000,allocatedBytes=memory,width=UE.Screen.width,height=UE.Screen.height,
        inputBytesPerSec=(traffic.inputBytes-previous.inputBytes)/age,
        snapshotBytesPerSec=(traffic.snapshotBytes-previous.snapshotBytes)/age,
        inputMessagesPerSec=(traffic.inputMessages-previous.inputMessages)/age,
        snapshotMessagesPerSec=(traffic.snapshotMessages-previous.snapshotMessages)/age,
        audio=audio.GetStats(),fx=fx.GetStats(),rendering=rendering()}
    print("[WK-PRESENTATION-METRICS] "..WKJson.encode(report))
    for k,value in pairs(traffic) do previous[k]=value end
    age=0;frames=0;samples={}
end
