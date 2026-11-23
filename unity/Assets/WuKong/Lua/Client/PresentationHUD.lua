---@var presentationData:UnityEngine.TextAsset
---@end
local UE=UnityEngine
local texts,bars,buttons,listeners={},{},{},{}
local rects={}
local root,help,result,challenge,portrait=nil,nil,nil,nil,nil
local arena,input=nil,nil
local shownHelp=false
local muted=false
local view=nil
local uiAge=0
local lastEpoch=nil
local width,height=0,0
local hpValues={}
local lastToast=nil
local toastUntil=0
local hiddenSystem={}
local systemAge=0
local controls,canvas=nil,nil
local progress={}
local helpCopy=nil
local B=WKSkillsConfig.bianhua
local D=WKSkillsConfig.spells

local function text(name,value)
    local item=texts[name]
    if item and item.text~=value then item.text=value end
end
function Toast(value)
    lastToast=value;toastUntil=UE.Time.unscaledTime+1.5
end
function ToggleHelp()
    shownHelp=not shownHelp;help:SetActive(shownHelp)
    local go=UE.GameObject.Find("CombatInput")
    if go then go:GetComponent(typeof(DouyinScript)).script.ClearControls() end
    print("[WK-HUD] help="..tostring(shownHelp))
end
function IsModal() return shownHelp or UE.Screen.width<UE.Screen.height end
function CanPress(name,notify)
    if IsModal() then return false end
    local v=view
    if name=="challenge" then return true end
    local reason=nil
    if not v then reason="等待角色就绪"
    elseif v.hp<=0 or v.challenge~="fight" and v.challenge~="ready" then reason="请重新挑战"
    elseif (v.formPhase or "none")~="none" or (v.spiritPhase or "none")~="none" then
        if not (v.form=="lang" and v.formPhase=="born" and
            (name=="transform" or name=="light" or name=="heavy" or name=="dodge")) then reason="形态切换中" end
    end
    if not reason and v then
        if v.form=="lang" and (name=="gourd" or name=="spin" or name=="cloud" or name=="immobilize" or name=="spirit")
            or name=="stanceCycle" and v.form~="wukong" then reason="当前形态不可用"
        elseif name=="immobilize" or name=="cloud" then
            local spec=name=="immobilize" and D.immobilize.skills["10518"] or D.cloud.enter
            if ((v.cooldowns or {})[name] or 0)>0 then reason="冷却中"
            elseif v.mp<spec.mpRequired then reason="法力不足" end
        elseif name=="transform" and v.form~="lang" and (v.transEnergy or 0)<B.transform.energy.max then reason="赤潮能量不足"
        elseif name=="spirit" and (v.vigor or 0)<B.spirit.energy.max then reason="精魄能量不足"
        elseif name=="gourd" and v.gourd<=0 then reason="葫芦已用尽" end
    end
    if reason and notify then Toast(reason) end
    return reason==nil,reason
end
function IsPointerOver(position)
    if IsModal() then return true end
    local point=UE.Vector2(position.x,position.y)
    for name,button in pairs(buttons) do
        if button.gameObject.activeInHierarchy and UE.RectTransformUtility.RectangleContainsScreenPoint(rects[name],point,nil) then return true end
    end
    return false
end
function SetMuted(value)
    muted=value;text("ActionLabel_mute",muted and "已静音" or "声音");Toast(muted and "静音" or "声音开启")
end
local function hideSystemControls()
    for _,kind in ipairs({UIType.Jump,UIType.Fly,UIType.Throw}) do
        local button=DouyinUIService.GetInteractionButton(HandType.Right,kind)
        if button and button.gameObject.activeSelf then
            hiddenSystem[button.gameObject]=true;button.gameObject:SetActive(false)
        end
    end
    local system=UE.GameObject.Find("UISystem")
    local chat=system and system.transform:Find("Canvas/UIRoot/Bottom/MainInputPanel(Clone)/ObserverNotHideLayer")
    if chat and chat.gameObject.activeSelf then
        hiddenSystem[chat.gameObject]=true;chat.gameObject:SetActive(false)
    end
end
function Apply(v)
    view=v
    if lastEpoch~=v.epoch then
        lastEpoch=v.epoch;hpValues={}
        for name,bar in pairs(bars) do bar.value=nil;bar.damage=nil;bar.wait=0 end
    end
end
function Start()
    if DouyinApplication.isServer then return end
    local canvasObject=UE.GameObject.Find("ArenaHUD")
    canvas=canvasObject:GetComponent(typeof(UE.Canvas))
    root=canvasObject.transform:Find("HUDSafeArea"):GetComponent(typeof(UE.RectTransform))
    controls=root:Find("CombatControls"):GetComponent(typeof(UE.RectTransform))
    local ts=canvasObject:GetComponentsInChildren(typeof(UE.UI.Text),true)
    for i=0,ts.Length-1 do texts[ts[i].gameObject.name]=ts[i] end
    local bs=canvasObject:GetComponentsInChildren(typeof(UE.UI.Button),true)
    for i=0,bs.Length-1 do
        local name=string.sub(bs[i].gameObject.name,14)
        buttons[name]=bs[i];rects[name]=bs[i].gameObject:GetComponent(typeof(UE.RectTransform))
        local fill=bs[i].transform:Find("ActionProgress_"..name)
        if fill then progress[name]=fill:GetComponent(typeof(UE.UI.Image)) end
    end
    for _,name in ipairs({"PlayerHP","PlayerMP","PlayerStamina","BossHP"}) do
        bars[name]={fill=root:Find(name.."/"..name.."Fill"),ghost=root:Find(name.."/"..name.."Damage"),wait=0}
    end
    help=root:Find("HelpPanel").gameObject;help:SetActive(false)
    helpCopy=texts.HelpText.text
    result=root:Find("ChallengeResultPanel").gameObject
    challenge=root:Find("CombatButton_challenge").gameObject
    arena=UE.GameObject.Find("ArenaPresentation"):GetComponent(typeof(DouyinScript)).script
    input=UE.GameObject.Find("CombatInput"):GetComponent(typeof(DouyinScript)).script
    local button=buttons.help
    local callback=function() ToggleHelp() end
    button.onClick:AddListener(callback);listeners[#listeners+1]={button=button,callback=callback}
    button=buttons.mute
    callback=function()
        local audio=UE.GameObject.Find("PresentationAudio"):GetComponent(typeof(DouyinScript)).script
        audio.ToggleMute()
    end
    button.onClick:AddListener(callback);listeners[#listeners+1]={button=button,callback=callback}
end
function MeasureLayout()
    local bounds={}
    local outside,overlap=0,0
    for name,button in pairs(buttons) do
        if button.gameObject.activeInHierarchy then
            local r=rects[name];local box=r.rect
            local a=UE.RectTransformUtility.WorldToScreenPoint(nil,r:TransformPoint(UE.Vector3(box.xMin,box.yMin,0)))
            local b=UE.RectTransformUtility.WorldToScreenPoint(nil,r:TransformPoint(UE.Vector3(box.xMax,box.yMax,0)))
            if a.x<-.5 or a.y<-.5 or b.x>UE.Screen.width+.5 or b.y>UE.Screen.height+.5 then outside=outside+1 end
            bounds[#bounds+1]={name=name,x=a.x,y=a.y,width=b.x-a.x,height=b.y-a.y}
        end
    end
    for i=1,#bounds do for j=i+1,#bounds do
        local a,b=bounds[i],bounds[j]
        if a.x<b.x+b.width and b.x<a.x+a.width and a.y<b.y+b.height and b.y<a.y+a.height then overlap=overlap+1 end
    end end
    local safe=UE.Screen.safeArea
    local violations=0
    for _,b in ipairs(bounds) do
        if progress[b.name] and (b.x<.6*UE.Screen.width-.5 or b.y>.6*UE.Screen.height+.5
            or b.y+b.height>.6*UE.Screen.height+.5 or b.x<safe.x-.5 or b.y<safe.y-.5
            or b.x+b.width>safe.x+safe.width+.5 or b.y+b.height>safe.y+safe.height+.5) then violations=violations+1 end
    end
    local function measure(r)
        local box=r.rect
        local a=UE.RectTransformUtility.WorldToScreenPoint(nil,r:TransformPoint(UE.Vector3(box.xMin,box.yMin,0)))
        local b=UE.RectTransformUtility.WorldToScreenPoint(nil,r:TransformPoint(UE.Vector3(box.xMax,box.yMax,0)))
        if a.x<.6*UE.Screen.width-.5 or a.y<safe.y-.5 or b.x>safe.x+safe.width+.5
            or b.y>.6*UE.Screen.height+.5 or a.x<safe.x-.5 then violations=violations+1 end
        return {x=a.x,y=a.y,width=b.x-a.x,height=b.y-a.y}
    end
    local container=measure(controls)
    local toast=measure(texts.CombatToast:GetComponent(typeof(UE.RectTransform)))
    return {width=UE.Screen.width,height=UE.Screen.height,outside=outside,overlap=overlap,
        controlRegionViolations=violations,controlScale=controls.localScale.x*canvas.scaleFactor,
        container=container,toast=toast,buttons=bounds}
end
local function refresh()
    local v=view
    if not v then return end
    local form=v.form=="lang" and "广智" or v.form=="she" and "广谋" or "天命人"
    local stance=v.stance=="pillar" and "立棍" or v.stance=="thrust" and "戳棍" or "劈棍"
    text("PlayerResources",string.format("%s  %.0f / %.0f   葫芦 %d",form,v.hp,v.hpMax or 390,v.gourd))
    text("StanceBaseline",stance.."   "..string.rep("● ",v.pips or 0)..string.rep("○ ",math.max(0,4-(v.pips or 0))))
    text("BossName",string.format("虎先锋   %.0f / 6480",v.bossHp))
    text("SkillBaseline",string.format("法力 %.0f / 220   体力 %.0f / %.0f\n赤潮 %.0f / 150   精魄 %.0f / 212",
        v.mp,v.stamina,v.staminaMax or 250,v.transEnergy or 150,v.vigor or 212))
    text("ActionLabel_gourd","葫芦\n"..v.gourd)
    text("ActionLabel_stanceCycle",stance)
    text("ActionLabel_sprint",input.IsSprinting() and "疾跑中" or "疾跑")
    text("ActionLabel_heavy",input.IsHeld("heavy") and "蓄力中" or (v.form=="lang" and "广智重击" or "重棍").."\n按住蓄力")
    text("ActionLabel_light",v.form=="lang" and "广智轻击" or "轻棍")
    text("ActionLabel_spin",input.IsHeld("spin") and "棍花中" or "棍花\n按住")
    text("ActionLabel_lock",arena.IsLocked() and "已锁定" or "锁定")
    local cd=v.cooldowns or {}
    for _,name in ipairs({"immobilize","cloud"}) do
        local value=cd[name] or 0
        local _,reason=CanPress(name,false)
        text("ActionLabel_"..name,(name=="immobilize" and "定身" or "散气")..(value>0 and string.format("\n%.0fs",math.ceil(value)) or name=="cloud" and v.cloud and "\n化气中" or reason and "\n"..reason or ""))
        local spec=name=="immobilize" and D.immobilize.skills["10518"] or D.cloud.enter
        progress[name].fillAmount=math.min(1,value/spec.cooldown)
    end
    local trans=math.min(1,(v.transEnergy or 0)/B.transform.energy.max)
    local spirit=math.min(1,(v.vigor or 0)/B.spirit.energy.max)
    text("ActionLabel_transform",v.form=="lang" and "返回" or "赤潮"..(trans<1 and string.format("\n%.0f%%",trans*100) or ""))
    text("ActionLabel_spirit","广谋"..(spirit<1 and string.format("\n%.0f%%",spirit*100) or ""))
    progress.transform.fillAmount=trans;progress.spirit.fillAmount=spirit
    for name,fill in pairs(progress) do
        local available=CanPress(name,false)
        buttons[name].interactable=true
        buttons[name]:GetComponent(typeof(UE.UI.Image)).color=available and UE.Color(.09,.065,.04,.88) or UE.Color(.12,.12,.12,.55)
        if name=="heavy" or name=="spin" then
            fill.fillAmount=input.IsHeld(name) and 1 or 0
        end
    end
    local ready=v.challenge=="ready"
    local ended=v.challenge=="victory" or v.challenge=="defeat"
    local visible=ready or ended and v.resultReady==true
    result:SetActive(visible);challenge:SetActive(visible and not shownHelp)
    text("ChallengeButtonLabel",ready and "开始挑战" or "重新挑战")
    text("ChallengeResultTitle",ready and "卧虎寺" or v.challenge=="victory" and "虎先锋 · 伏诛" or "身死")
    text("ChallengeResultHint",ready and "进入血池，迎战虎先锋" or "按 Enter 或点击重新挑战")
    local status=ready and "卧虎寺" or ended and (v.challenge=="victory" and "虎先锋 · 伏诛" or "身死")
        or "血池 · "..(v.boss and v.boss.phase or "虎先锋")
    text("ArenaStatus",status)
    text("CameraHint","空白处拖动视角")
    text("CombatToast",UE.Time.unscaledTime<toastUntil and lastToast or "")
    for name,button in pairs(buttons) do
        if name~="challenge" and name~="mute" and name~="help" then
            button.gameObject:SetActive(not shownHelp and width>=height and (ready or v.challenge=="fight"))
        end
    end
end
function Update()
    if DouyinApplication.isServer or not root then return end
    if UE.Input.GetKeyDown("h") then ToggleHelp() end
    width,height=UE.Screen.width,UE.Screen.height
    local safe=UE.Screen.safeArea
    root.anchorMin=UE.Vector2(safe.x/width,safe.y/height)
    root.anchorMax=UE.Vector2((safe.x+safe.width)/width,(safe.y+safe.height)/height)
    local right=width-safe.x-safe.width
    local scale=math.max(0,math.min(height/720,math.min(.4*width-right,safe.width)/408,
        math.min(.6*height-safe.y,safe.height)/408))
    local localScale=scale/canvas.scaleFactor
    controls.localScale=UE.Vector3(localScale,localScale,1)
    if width<height then
        help:SetActive(true);text("HelpText","请将设备横屏，使用摇杆和右侧按钮进入挑战。")
    else text("HelpText",helpCopy);help:SetActive(shownHelp) end
    local dt=UE.Time.unscaledDeltaTime
    systemAge=systemAge+dt
    if systemAge>=1 then systemAge=0;hideSystemControls() end
    uiAge=uiAge+dt
    if uiAge>=.1 then uiAge=0;refresh() end
    if not view then return end
    local ratios={PlayerHP=view.hp/(view.hpMax or 390),PlayerMP=view.mp/220,
        PlayerStamina=view.stamina/(view.staminaMax or 250),BossHP=view.bossHp/6480}
    for name,bar in pairs(bars) do
        local target=math.max(0,math.min(1,ratios[name]))
        if bar.value==nil then bar.value=target;bar.damage=target end
        if target<bar.value-.002 then bar.wait=.35 end
        bar.value=bar.value+(target-bar.value)*(1-math.exp(-18*dt))
        bar.wait=math.max(0,bar.wait-dt)
        if target>bar.damage then bar.damage=target
        elseif bar.wait==0 then bar.damage=bar.damage+(target-bar.damage)*(1-math.exp(-4*dt)) end
        bar.fill.localScale=UE.Vector3(bar.value,1,1)
        bar.ghost.localScale=UE.Vector3(bar.damage,1,1)
    end
end
function OnDestroy()
    for _,listener in ipairs(listeners) do
        if listener.button and not listener.button:IsNull() then listener.button.onClick:RemoveListener(listener.callback) end
    end
    listeners={}
    for go in pairs(hiddenSystem) do if go and not go:IsNull() then go:SetActive(true) end end
    hiddenSystem={}
end
