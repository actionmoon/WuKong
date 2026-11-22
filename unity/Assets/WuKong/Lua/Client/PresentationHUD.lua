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

local function text(name,value)
    local item=texts[name]
    if item and item.text~=value then item.text=value end
end
function Toast(value)
    lastToast=value;toastUntil=UE.Time.unscaledTime+1.5
end
function ToggleHelp()
    shownHelp=not shownHelp;help:SetActive(shownHelp)
    print("[WK-HUD] help="..tostring(shownHelp))
end
function IsModal() return shownHelp or width<height end
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
    local canvas=UE.GameObject.Find("ArenaHUD")
    root=canvas.transform:Find("HUDSafeArea"):GetComponent(typeof(UE.RectTransform))
    local ts=canvas:GetComponentsInChildren(typeof(UE.UI.Text),true)
    for i=0,ts.Length-1 do texts[ts[i].gameObject.name]=ts[i] end
    local bs=canvas:GetComponentsInChildren(typeof(UE.UI.Button),true)
    for i=0,bs.Length-1 do
        local name=string.sub(bs[i].gameObject.name,14)
        buttons[name]=bs[i];rects[name]=bs[i].gameObject:GetComponent(typeof(UE.RectTransform))
    end
    for _,name in ipairs({"PlayerHP","PlayerMP","PlayerStamina","BossHP"}) do
        bars[name]={fill=root:Find(name.."/"..name.."Fill"),ghost=root:Find(name.."/"..name.."Damage"),wait=0}
    end
    help=root:Find("HelpPanel").gameObject;help:SetActive(false)
    result=root:Find("ChallengeResultPanel").gameObject
    challenge=root:Find("CombatButton_challenge").gameObject
    arena=UE.GameObject.Find("ArenaPresentation"):GetComponent(typeof(DouyinScript)).script
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
    return {width=UE.Screen.width,height=UE.Screen.height,outside=outside,overlap=overlap,buttons=bounds}
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
    text("ActionLabel_gourd","葫芦 "..v.gourd)
    text("ActionLabel_lock",arena.IsLocked() and "已锁定" or "锁定")
    local cd=v.cooldowns or {}
    for _,name in ipairs({"immobilize","cloud"}) do
        local value=cd[name] or 0
        text("ActionLabel_"..name,(name=="immobilize" and "定身" or "散气")..(value>0 and string.format("\n%.0fs",math.ceil(value)) or ""))
        buttons[name].interactable=value<=0 and v.mp>=(name=="immobilize" and 50 or 30) and v.form=="wukong"
    end
    text("ActionLabel_transform",v.form=="lang" and "退出赤潮" or "赤潮")
    buttons.transform.interactable=v.form=="lang" or (v.transEnergy or 0)>=150 and v.form=="wukong"
    buttons.spirit.interactable=(v.vigor or 0)>=212 and v.form=="wukong"
    buttons.gourd.interactable=v.gourd>0 and v.hp>0
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
    text("CameraHint",UE.Time.unscaledTime<toastUntil and lastToast or "H 帮助   M 声音")
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
    if width<height then
        help:SetActive(true);text("HelpText","请将设备横屏，使用摇杆和右侧按钮进入挑战。")
    elseif not shownHelp then help:SetActive(false) end
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
