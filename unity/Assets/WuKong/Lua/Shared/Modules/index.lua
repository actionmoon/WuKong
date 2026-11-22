WKSampleConfig = require "SampleConfig"
WKArenaConfig = require "ArenaConfig"
WKCombatConfig = require "CombatConfig"
WKSkillsConfig = require "SkillsConfig"
for name,clip in pairs(WKSkillsConfig.clips) do WKCombatConfig.clips[name]=clip end
WKCombatClock = require "CombatClock"
WKBossConfig = require "BossConfig"
WKJson = require "dkjson"
