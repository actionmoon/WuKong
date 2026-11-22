"""Run the DS fixed-input suite under Lua 5.3 (python -m pip install lupa)."""
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
            directory = "Server" if name == "CombatSession" else "Shared"
            modules[name] = runtime.execute((scripts / directory / "Modules" / (name + ".lua")).read_text())
        return modules[name]

    runtime.globals().require = require
    runtime.globals().WKCombatConfig = require("CombatConfig")
    runtime.globals().WKCombatClock = require("CombatClock")
    runtime.globals().WKCombatSession = require("CombatSession")
    reports = []
    runtime.globals().report = lambda value: reports.append(dict(value.items()))
    runtime.globals().print = lambda _: None
    runtime.globals().UnityEngine = runtime.table()
    runtime.execute("""
        requireOriginal=require
        require=function(n)
            if n=="dkjson" then return {encode=function(e) report(e);return "test" end} end
            return requireOriginal(n)
        end
    """)
    runtime.globals().WKJson = runtime.eval('require("dkjson")')
    runtime.execute((scripts / "Shared/CombatState.lua").read_text())
    runtime.globals().RunFixedSuite(runtime.table(actorID=1))
    print(json.dumps({"lua": "5.3", "tests": reports}, ensure_ascii=False, indent=2))
    return 0 if reports and all(result["pass"] for result in reports) else 1


if __name__ == "__main__":
    raise SystemExit(main())
