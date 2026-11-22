---@var presentationData:UnityEngine.TextAsset
---@var audioClips:UnityEngine.AudioClip[]
---@end
local UE=UnityEngine
local data,input,hud=nil,nil,nil
local voices,tracks,variants={},{},{}
local music={}
local muted=false
local epoch=nil
local bgmState="off"
local bgmPiece=nil
local bgmAge=0
local musicIndex=1
local stats={played=0,missing=0,footstep=0,mapped=0,montage=0,hit=0}
local function source(name)
    local go=UE.GameObject(name);go.transform:SetParent(self.transform,false)
    local value=go:AddComponent(typeof(UE.AudioSource));value.playOnAwake=false;value.spatialBlend=0
    return value
end
function ToggleMute()
    muted=not muted
    if hud then hud.SetMuted(muted) end
    print("[WK-AUDIO] mute="..tostring(muted))
end
function IsMuted() return muted end
function GetStats()
    local active,progress=0,0
    for _,voice in ipairs(voices) do
        if voice.source.isPlaying then active=active+1;progress=progress+voice.source.timeSamples end
    end
    stats.activeVoices=active;stats.timeSamples=progress;stats.peakVoices=math.max(stats.peakVoices or 0,active)
    return stats
end
local function clear()
    for _,voice in ipairs(voices) do voice.source:Stop();voice.name=nil end
    for _,s in ipairs(music) do s:Stop() end
    tracks={};bgmState="off";bgmPiece=nil
end
local function attenuation(curve,distance)
    if not curve or #curve==0 then return 1 end
    if distance<=curve[1][1] then return curve[1][2] end
    for i=2,#curve do
        local a,b=curve[i-1],curve[i]
        if distance<=b[1] then return a[2]+(b[2]-a[2])*(distance-a[1])/math.max(.001,b[1]-a[1]) end
    end
    return curve[#curve][2]
end
function Post(name,position,stamp)
    local spec=data.audio.events[name]
    if not spec then stats.missing=stats.missing+1;return end
    local pick=math.random(#spec.clips)
    if #spec.clips>1 and pick==variants[name] then pick=pick%#spec.clips+1 end
    variants[name]=pick
    local slot=nil
    for _,voice in ipairs(voices) do if not voice.source.isPlaying then slot=voice;break end end
    if not slot then
        for _,voice in ipairs(voices) do if not voice.source.loop and (not slot or voice.age<slot.age) then slot=voice end end
    end
    if not slot then return end
    slot.source:Stop();slot.source.clip=audioClips[spec.clips[pick]]
    slot.source.loop=spec.loop==true;slot.name=name;slot.spec=spec;slot.position=position
    slot.stamp=stamp;slot.age=UE.Time.unscaledTime
    slot.source.volume=muted and 0 or math.min(1,spec.gain*2.5*.8)
    slot.source:Play()
    stats.played=stats.played+1;stats[spec.cat]=(stats[spec.cat] or 0)+1
end
local function poll(key,pose,position)
    if not pose or not pose.clip then return end
    local contract=data.clips[pose.clip]
    if not contract then return end
    local stamp=key..":"..tostring(pose.play or pose.clip)
    local previous=tracks[key]
    local changed=not previous or previous.stamp~=stamp or previous.clip~=pose.clip
    local last=changed and math.max(-.001,pose.t-.2) or previous.t
    if not changed and pose.t<last-.02 then last=-.001 end
    for _,cue in ipairs(contract.cues) do
        if cue.type=="audio" and cue.time>last and cue.time<=pose.t then Post(cue.name,position,stamp) end
    end
    for _,voice in ipairs(voices) do
        if voice.stamp and string.sub(voice.stamp,1,#key+1)==key..":" and voice.source.loop and voice.stamp~=stamp then
            voice.source:Stop();voice.name=nil
        end
    end
    tracks[key]={stamp=stamp,clip=pose.clip,t=pose.t}
end
local function switch(piece,fade)
    musicIndex=musicIndex%2+1
    local next=music[musicIndex];next:Stop()
    next.clip=audioClips[data.audio.bgm.pieces[piece].clip]
    next.loop=data.audio.bgm.pieces[piece].loop==true;next.volume=0;next:Play()
    bgmPiece=piece;bgmAge=0
    print("[WK-AUDIO] bgm="..piece)
end
function Start()
    if DouyinApplication.isServer then return end
    data=WKJson.decode(presentationData.text)
    input=UE.GameObject.Find("CombatInput"):GetComponent(typeof(DouyinScript)).script
    hud=UE.GameObject.Find("PresentationHUD"):GetComponent(typeof(DouyinScript)).script
    for i=1,40 do voices[i]={source=source("AudioVoice_"..i),age=0} end
    music={source("BattleMusic_A"),source("BattleMusic_B")}
    print("[WK-AUDIO] ready clips="..audioClips.Length.." voices=40")
end
function Update()
    if DouyinApplication.isServer or not data then return end
    if UE.Input.GetKeyDown("m") then ToggleMute() end
    local v=input.GetLocalView()
    if not v then return end
    if epoch~=v.epoch then clear();epoch=v.epoch end
    local position=input.GetLocalPosition()
    if not position then return end
    position=position+UE.Vector3(0,1,0)
    poll("player",v,position)
    if v.boss then poll("tiger",v.boss,UE.Vector3(v.boss.pos.x,v.boss.pos.y+1.8,v.boss.pos.z)) end
    for _,snake in ipairs(v.snakes or {}) do poll("snake:"..snake.key,snake,UE.Vector3(snake.pos.x,snake.pos.y,snake.pos.z)) end
    local hp=tracks.hp
    if hp and v.bossHp<hp.boss then
        local pre=data.audio.hits["2:"..tostring(v.hitAudio or 1001)]
        local suffix=v.boss.stone and "_normal_stone" or (v.immobilized or 0)>0 and "_immobilizedhit_all" or "_normal_meat"
        local event=pre and (data.audio.events[pre..suffix] and pre..suffix or pre.."_normal_meat")
        if event then Post(event,UE.Vector3(v.boss.pos.x,v.boss.pos.y+1.6,v.boss.pos.z));stats.hit=stats.hit+1 end
    end
    if hp and v.hp<hp.player then
        local pre=data.audio.hits["0:"..tostring(v.receivedAudio or 1301)]
        if pre then Post(pre.."_normal_meat",position);stats.hit=stats.hit+1 end
    end
    tracks.hp={boss=v.bossHp,player=v.hp}
    local dt=UE.Time.unscaledDeltaTime
    bgmAge=bgmAge+dt
    if bgmState=="off" and v.challenge=="fight" and v.boss.awake then bgmState="lv1";switch("lv1Intro",0)
    elseif bgmState=="lv1" and v.boss.bgm==2 then bgmState="lv2";switch("lv2Loop",.9)
    elseif bgmPiece=="lv1Intro" and bgmAge>=data.audio.bgm.pieces.lv1Intro.dur then switch("lv1Loop",0)
    end
    if (bgmState=="lv1" or bgmState=="lv2") and (v.challenge=="victory" or v.challenge=="defeat") then
        bgmState="stopping";switch("outro",.9)
    end
    local gain=data.audio.bgm.gain*2.5*.8
    local fade=math.min(1,bgmAge/data.audio.bgm.crossfade)
    if bgmState=="stopping" then
        fade=fade*math.max(0,1-math.max(0,bgmAge-data.audio.bgm.stopDelay)/data.audio.bgm.stopFade)
        if bgmAge>=data.audio.bgm.stopDelay+data.audio.bgm.stopFade then clear() end
    end
    for i,s in ipairs(music) do
        s.volume=muted and 0 or gain*(i==musicIndex and fade or 1-fade)
        if i~=musicIndex and fade>=1 then s:Stop() end
    end
    local camera=DouyinCameraService.GetCamera()
    for _,voice in ipairs(voices) do
        if voice.name and voice.source.isPlaying then
            local distance=camera and voice.position and UE.Vector3.Distance(camera.transform.position,voice.position) or 0
            voice.source.volume=muted and 0 or math.min(1,voice.spec.gain*2.5*.8*attenuation(voice.spec.att,distance))
        end
    end
end
function OnDestroy()
    clear()
    for _,voice in ipairs(voices) do UE.Object.Destroy(voice.source.gameObject) end
    for _,s in ipairs(music) do UE.Object.Destroy(s.gameObject) end
end
