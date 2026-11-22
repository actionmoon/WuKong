"""Execute the production boss/challenge fixed suite in Lua 5.3."""
import json
from pathlib import Path
from lupa.lua53 import LuaRuntime

ROOT = Path(__file__).resolve().parent.parent


def main():
    runtime = LuaRuntime(unpack_returned_tuples=True)
    scripts = ROOT / "unity/Assets/WuKong/Lua"
    modules = {}

    def require(name):
        if name not in modules:
            side = "Server" if name in {"CombatSession", "BossSession", "ChallengeSession", "BossTests"} else "Shared"
            modules[name] = runtime.execute((scripts / side / "Modules" / (name + ".lua")).read_text())
        return modules[name]

    runtime.globals().require = require
    for prefix, name in [("WKCombatConfig", "CombatConfig"), ("WKCombatClock", "CombatClock"),
                         ("WKBossConfig", "BossConfig"), ("WKArenaConfig", "ArenaConfig"),
                         ("WKCombatSession", "CombatSession"), ("WKBossSession", "BossSession"),
                         ("WKChallengeSession", "ChallengeSession")]:
        runtime.globals()[prefix] = require(name)
    reports = []
    require("BossTests").run(1, lambda row: reports.append(dict(row.items())))
    result = {"lua": "5.3", "tests": reports}
    path = ROOT / "docs/reference/step5-fixed-evidence.json"
    path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if reports and all(t["pass"] for t in reports) else 1


if __name__ == "__main__":
    raise SystemExit(main())
