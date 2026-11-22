"""Run step-6 production modules and affected suites under Lua 5.3."""
import json
from pathlib import Path
from lupa.lua53 import LuaRuntime

ROOT = Path(__file__).resolve().parent.parent


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    scripts = ROOT / "unity/Assets/WuKong/Lua"
    modules = {}
    server = {"CombatSession", "StanceSession", "SpellSession", "FormSession", "SkillsSession",
              "BossSession", "ChallengeSession", "BossTests", "SkillsTests"}

    def require(name):
        if name not in modules:
            side = "Server" if name in server else "Shared"
            modules[name] = lua.execute((scripts / side / "Modules" / f"{name}.lua").read_text())
        return modules[name]

    lua.globals().require = require
    for name in ("CombatConfig", "SkillsConfig"):
        lua.globals()["WK" + name] = require(name)
    lua.execute("for k,v in pairs(WKSkillsConfig.clips) do WKCombatConfig.clips[k]=v end")
    for name in ("CombatClock", "BossConfig", "ArenaConfig", "CombatSession", "StanceSession",
                 "SpellSession", "FormSession", "SkillsSession", "BossSession", "ChallengeSession"):
        lua.globals()["WK" + name] = require(name)
    reports = []
    report = lambda row: reports.append(dict(row.items()))
    require("SkillsTests").run(1, report)
    require("BossTests").run(1, report)
    lua.globals().UnityEngine = lua.table()
    lua.globals().print = lambda _: None
    lua.globals().WKJson = lua.table(encode=lambda row: report(row) or "test")
    lua.execute((scripts / "Shared/CombatState.lua").read_text())
    lua.globals().RunFixedSuite(lua.table(actorID=1))
    result = {"lua": "5.3", "tests": reports}
    path = ROOT / "docs/reference/step6-fixed-evidence.json"
    path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if reports and all(t["pass"] for t in reports) else 1


if __name__ == "__main__":
    raise SystemExit(main())
