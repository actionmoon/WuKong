function Start()
    if not DouyinApplication.isServer then return end
    print("[WK-SAMPLE] ds-boot context-mode=" .. WKServerSample.contextMode)
end

function GetCombatModule()
    return WKCombatSession
end

function GetChallengeModule() return WKChallengeSession end
function GetBossModule() return WKBossSession end
function RunBossSuite(actorID)
    WKBossTests.run(actorID,function(e) print("[WK-COMBAT] "..WKJson.encode(e)) end)
end
function RunSkillsSuite(actorID)
    WKSkillsTests.run(actorID,function(e) print("[WK-COMBAT] "..WKJson.encode(e)) end)
end

function OnPlayerJoined(player, evt)
    if not DouyinApplication.isServer or player == nil or player.isServer then return end
    print("[WK-SAMPLE] real-player-joined")
end
