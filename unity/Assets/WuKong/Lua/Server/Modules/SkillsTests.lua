local M={}
function M.run(actorID,report)
    local S,Q,B,K=WKCombatSession,WKChallengeSession,WKBossSession,WKCombatClock
    local St,Sp,F=WKStanceSession,WKSpellSession,WKFormSession
    local C=WKSkillsConfig
    local function test(name,fn)
        local ok,v=pcall(fn);report({ev="skillsFixedTest",name=name,pass=ok and v==true,detail=not ok and tostring(v) or nil,actor=actorID})
    end
    local function fresh()
        local s=Q.new(actorID);Q.start(s);s.boss.aiEnabled=false;s.rng=function() return 0.5 end
        s.position={x=s.boss.pos.x,y=s.boss.pos.y,z=s.boss.pos.z-3};s.boss.target=s.position
        return s
    end
    local function advance(s,sec)
        for _=1,math.ceil(sec*120) do S.update(s,1/120);Q.update(s,1/120,s.position) end
    end
    local function cast(s,name) S.press(s,name);advance(s,1/120) end
    local function window(s)
        local meta=WKCombatConfig.clips[s.clip]
        for _,e in ipairs(meta.events) do
            if e.type=="comboWindow" then s.action.t=e.start+0.001;s.t=s.action.t;return e end
        end
    end
    test("contracts-have-116-clips",function()
        local count=0
        for name,clip in pairs(C.clips) do count=count+1;if not WKCombatConfig.clips[name] or clip.duration<=0 then return false end end
        return count==116
    end)
    test("stance-switch-and-independent-context",function()
        local s,t=fresh(),fresh();S.press(s,"stance:pillar");S.press(s,"stanceCycle")
        return s.stance=="thrust" and t.stance=="smash"
    end)
    test("pillar-grow-to-three-and-release",function()
        local s=fresh();s.stance="pillar";s.heavyHeld=true;cast(s,"heavy");advance(s,10)
        local grown=s.action.kind=="stance:charge" and s.action.level==3
        s.heavyHeld=false;advance(s,1)
        return grown and s.action and s.action.mode=="pillar" and s.action.level==3 and s.focus==0
    end)
    test("pillar-depleted-falls-thrust-depleted-releases",function()
        local s=fresh();s.stance="pillar";s.stamina=1;s.heavyHeld=true;cast(s,"heavy");advance(s,.2)
        local fall=s.action and s.action.kind=="stance:fall"
        local t=fresh();t.stance="thrust";t.stamina=1;t.heavyHeld=true;cast(t,"heavy");advance(t,.2)
        return fall and t.action and t.action.kind=="stance:attack"
    end)
    test("thrust-release-uses-current-focus",function()
        local s=fresh();s.stance="thrust";s.heavyHeld=true;cast(s,"heavy");advance(s,1.5)
        s.focus=480;s.heavyHeld=false;advance(s,.3)
        return s.action and s.action.level==4 and s.action.spec.skill==C.stances.thrust[5].attack.skill
    end)
    test("spin-loop-cost-repeat-and-release",function()
        local s=fresh();s.spinHeld=true;cast(s,"spin");advance(s,1.8)
        local before=s.stamina;advance(s,1.5);local paid=s.stamina<before
        s.spinHeld=false;advance(s,.1)
        return paid and s.action and s.action.kind=="stance:attack"
    end)
    test("spin-intercepts-swept-projectile",function()
        local s=fresh();s.spinHeld=true;cast(s,"spin");advance(s,1)
        s.bone=function() return {x=0,y=1,z=0} end
        return St.blockBullet(s,{key="test",pos={x=2,y=1,z=0}},{x=-2,y=1,z=0})==true
    end)
    test("pillar-body-raised-staff-costs-no-hp",function()
        local s=fresh();s.stance="pillar";s.heavyHeld=true;cast(s,"heavy");advance(s,.1)
        s.bone=function(n)
            if n=="pelvis" then return {x=0,y=4,z=0} elseif n=="head" then return {x=0,y=5,z=0}
            elseif n=="weapon_tou_1" then return {x=0,y=0,z=0} else return {x=0,y=4,z=0} end
        end
        local hp,st=s.hp,s.stamina;local low=St.hurtSegment(s)
        local hit=St.staffContact(s,{x=-1,y=1,z=0},{x=1,y=1,z=0},.3,{damageMult=1})
        return low.y==4 and hit and s.hp==hp and s.stamina<st
    end)
    test("shipo-parry-guansuo-q3-and-hit-followup",function()
        local s=fresh();s.focus=230;cast(s,"light");window(s);cast(s,"heavy")
        if not s.action or s.action.spec.skill~=10705 then return false end
        local hp=s.hp;S.receive(s,{damageMult=1,hitWeight=1})
        local parry=s.hp==hp and s.gpUntil>s.time
        local expiry=s.gpUntil;s.time=s.time+.01;S.receive(s,{damageMult=1,hitWeight=1})
        parry=parry and s.gpUntil==expiry
        St.hit(s,s.action);window(s);cast(s,"light")
        return parry and s.action.step==3
    end)
    test("shipo-expired-receives-hit",function()
        local s=fresh();St.heavy(s);s.focus=100
        S.play(s,"stance:attack",C.stances.followUps.smash.shipo.clip,C.stances.followUps.smash.shipo)
        s.action.t=.5;local hp=s.hp;S.receive(s,{damageMult=1,hitWeight=1})
        return s.hp<hp and not s.gpUntil
    end)
    test("zhangun-requires-hit-mark-and-focus",function()
        local s=fresh();s.focus=230;S.play(s,"stance:attack",C.stances.followUps.smash.shipo.clip,C.stances.followUps.smash.shipo)
        local cw=window(s);local absent=St.follow(s,s.action,cw)==nil
        St.hit(s,s.action);local e=St.follow(s,s.action,cw)
        return absent and e and e.skill==10707
    end)
    test("pillar-fengyunzhuan-and-thrust-followup",function()
        local s=fresh();s.stance="pillar";s.focus=200;s.heavyHeld=true;cast(s,"light");window(s);cast(s,"heavy")
        local fyz=s.action and s.action.kind=="stance:fyz"
        advance(s,2);s.heavyHeld=false;advance(s,.1)
        local t=fresh();t.stance="thrust";t.focus=200;cast(t,"light");window(t);cast(t,"heavy")
        local tuicun=t.action and t.action.spec.skill==10713
        window(t);cast(t,"heavy")
        return fyz and tuicun and t.action.spec.skill==10714
    end)
    test("cast-resource-cooldown-and-input-window",function()
        local s=fresh();s.mp=49;cast(s,"immobilize");local rejected=not s.action
        s.mp=220;cast(s,"light");S.press(s,"immobilize");advance(s,.1)
        return rejected and s.action.kind=="light" and not s.cooldowns.immobilize
    end)
    test("normal-immobilize-cost-freeze-and-timer",function()
        local s=fresh();B.cast(s.boss,202201);cast(s,"immobilize");advance(s,.5)
        local t=s.boss.t;local froze=s.boss.immobilized and s.mp==170
        advance(s,.2);local paused=s.boss.t==t
        advance(s,5)
        return froze and paused and not s.boss.immobilized and s.cooldowns.immobilize>0
    end)
    test("precise-immobilize-cooldown-and-vulnerability",function()
        local s=fresh();s.warningUntil=s.time+.1;cast(s,"immobilize");advance(s,.2)
        return s.mp==170 and s.boss.immobilized>=3.9 and s.cooldowns.immobilize<20 and s.boss.immobilizeDef==-4000
    end)
    test("immobilize-repeated-min-and-damage-break",function()
        local s=fresh();s.boss.immobilizeCount=99;cast(s,"immobilize");advance(s,.5)
        local minimum=s.boss.immobilized and s.boss.immobilized<=1
        B.receive(s.boss,{flatDamage=600,hitWeight=1},s.position,10801)
        return minimum and not s.boss.immobilized
    end)
    test("immobilize-immune-still-pays-and-precast-interrupt",function()
        local s=fresh();B.addBuff(s.boss,205,10);cast(s,"immobilize");advance(s,.6)
        local immune=s.mp==170 and not s.boss.immobilized
        local t=fresh();cast(t,"immobilize");S.receive(t,{damageMult=1,hitWeight=10,armorBreak=10000});advance(t,.6)
        return immune and t.mp==220 and not t.boss.immobilized
    end)
    test("cloud-taunt-cost-strike-and-exit",function()
        local s=fresh();cast(s,"cloud");advance(s,1)
        local enter=s.cloud~=nil and s.mp==190 and s.boss.target==s.cloud.decoy
        local hp=s.hp;s.boss.damage({damageMult=1},"test")
        local decoy=s.hp==hp and s.cloud.decoy.hp<585
        S.free(s);cast(s,"light")
        return enter and decoy and not s.cloud and s.action.kind=="cloudStrike"
    end)
    test("cloud-timer-and-no-magic-protection",function()
        local s=fresh();cast(s,"cloud");advance(s,1);s.mp=0;advance(s,.5)
        local protect=s.cloud~=nil;advance(s,.6)
        local drained=not s.cloud
        local t=fresh();cast(t,"cloud");advance(t,11)
        return protect and drained and not t.cloud and t.mp==160
    end)
    test("transform-separate-resources-manual-return",function()
        local s=fresh();s.hp=123;s.stamina=87;s.focus=200;cast(s,"transform");advance(s,3)
        local form=s.form=="lang" and s.hp==468 and s.stamina==200 and s.focus==0 and s.playerData.stats.dmgDef==WKCombatConfig.player.stats.dmgDef+2000
        cast(s,"transform");advance(s,.6)
        return form and s.form=="wukong" and s.hp==123 and s.focus==200 and s.transEnergy<65
    end)
    test("transform-hp-zero-reverts-without-defeat",function()
        local s=fresh();s.hp=123;cast(s,"transform");advance(s,2)
        S.receive(s,{flatDamage=10000,hitWeight=10});advance(s,2)
        return s.form=="wukong" and s.hp==123 and s.challenge=="fight"
    end)
    test("transform-energy-exhaustion-and-not-full-rejected",function()
        local s=fresh();s.transEnergy=149;cast(s,"transform");local rejected=s.form=="wukong"
        s.transEnergy=150;cast(s,"transform");advance(s,2);s.transEnergy=.01;advance(s,2)
        return rejected and s.form=="wukong" and s.transEnergy<5
    end)
    test("transform-light-hit-effects-and-heavy-trigger-cost",function()
        local s=fresh();cast(s,"transform");advance(s,3);cast(s,"light")
        F.hit(s,s.action,{effects={}});local gain=s.focus==16
        S.free(s);local before=s.transEnergy;cast(s,"heavy");advance(s,.3)
        return gain and s.transEnergy<before-32 and s.action.spec.skill==12031
    end)
    test("transform-fire-direction-heavy-and-r2-hit-follow",function()
        local s=fresh();cast(s,"transform");advance(s,3);s.focus=100;s.lastDodge="B";s.dodgeUntil=s.time+1
        local directional=F.heavySpec(s).skill==12044
        s.dodgeUntil=0;cast(s,"heavy");F.effect(s,1203103);local follow=F.heavySpec(s).skill==12042
        return directional and follow
    end)
    test("transform-perfect-dodge-full-focus-and-gourd-block",function()
        local s=fresh();cast(s,"transform");advance(s,3);s.warningUntil=s.time+.2;s.warningID=1
        cast(s,"dodge");local full=s.focus==100
        S.free(s);cast(s,"gourd")
        return full and not s.action and s.gourd==6
    end)
    test("spirit-mutual-exclusion-energy-and-recover",function()
        local s=fresh();cast(s,"spirit");advance(s,.6)
        local form=s.form=="she" and s.vigor==0 and s.cantGainVigor
        S.press(s,"transform");advance(s,2.5)
        return form and s.form=="wukong" and not s.cantGainVigor and s.formPhase=="none"
    end)
    test("spirit-summons-two-ground-points-bullets-hit-and-expire",function()
        local s=fresh();s.ground=function(p) return p end
        s.snakeSocket=function(n) return {x=n.pos.x,y=n.pos.y+1,z=n.pos.z} end
        s.boss.bone=function() return {x=s.boss.pos.x,y=s.boss.pos.y+1,z=s.boss.pos.z} end
        cast(s,"spirit");advance(s,2)
        local two=#s.snakes==2;local hp=s.bossHp;advance(s,7)
        local hit=s.bossHp<hp;advance(s,8)
        return two and hit and #s.snakes==0
    end)
    test("spirit-break-armor-restores-and-energy-gain-table",function()
        local s=fresh();cast(s,"spirit");advance(s,.7)
        S.receive(s,{damageMult=0,hitWeight=10,armorBreak=10000});advance(s,.1)
        local restored=s.form=="wukong" and not s.cantGainVigor
        F.hit(s,{kind="light",spec={}},{effects={1061492}})
        return restored and s.vigor==10
    end)
    test("landed-base-light-hit-recovers-vigor-once",function()
        local s=fresh();s.vigor=0;cast(s,"light")
        local p=s.boss.pos
        local bone=function() return {x=p.x,y=p.y+1,z=p.z} end
        for _=1,60 do S.update(s,1/120);S.resolve(s,bone,p) end
        return s.hits==1 and s.vigor==1.5
    end)
    test("victory-in-form-restores-player-and-clears-summons",function()
        local s=fresh();s.hp=123;cast(s,"transform");advance(s,3)
        s.bossHp=0;Q.update(s,0,s.position)
        return s.challenge=="victory" and s.form=="wukong" and s.hp==123 and not s.saved and #s.snakes==0
    end)
    test("death-retry-clears-skills-and-full-energy",function()
        local s=fresh();cast(s,"cloud");advance(s,1)
        s.snakes={{key="test"}};s.projectiles={};S.receive(s,{flatDamage=10000,hitWeight=10});advance(s,3)
        local t=Q.retry(s)
        return t and not t.cloud and #t.snakes==0 and #t.projectiles==0 and t.form=="wukong" and t.vigor==C.bianhua.spirit.energy.max and t.transEnergy==150
    end)
end
return M
