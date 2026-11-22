"""Save only gameplay evidence from a completed three-process simulator session."""
import argparse
import collections
import hashlib
import json
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("session", type=Path)
    args = parser.parse_args()
    manifest = json.loads(args.session.read_text())
    processes, events, views = [], [], {}
    for row in manifest:
        lines = Path(row["logFile"]).read_text(errors="replace").splitlines()
        errors = [line for line in lines if "LuaException" in line or "LuaScriptException" in line or "attempt to " in line]
        role_views = []
        completed = False
        for line in lines:
            if "[WK-COMBAT] {" in line:
                events.append(json.loads(line.split("[WK-COMBAT] ", 1)[1]))
            elif "[WK-COMBAT-VIEW] {" in line:
                role_views.append(json.loads(line.split("[WK-COMBAT-VIEW] ", 1)[1]))
            elif "[WK-SKILLS-REPLAY] finished " in line:
                completed = True
        processes.append({"role": row["role"], "pid": row["pid"], "log": row["logFile"],
                          "luaErrors": errors, "replayCompleted": completed})
        if role_views:
            views[row["role"]] = role_views
    tests = [e for e in events if e.get("ev") in {"fixedTest", "bossFixedTest", "skillsFixedTest"}]
    counts = collections.Counter(e.get("ev") for e in events)
    milestones = {}
    for role, samples in views.items():
        samples = [v for v in samples if v["actorID"] == 2]
        milestones[role] = {
            "pillarLevel3": any(v["clip"] == "AM_Wukong_Xuli_C_attack_3" for v in samples),
            "thrustAttack": any("xuli_B_attack" in v["clip"] for v in samples),
            "spin": any(v["clip"] == "AM_Wukong_ComboC_q_loop" for v in samples),
            "immobilized": any(v.get("immobilized", 0) > 0 for v in samples),
            "cloud": any(v.get("cloud") for v in samples),
            "guangzhi": any(v.get("form") == "lang" for v in samples),
            "guangmou": any(v.get("form") == "she" for v in samples),
            "twoSnakes": any(len(v.get("snakes", [])) == 2 for v in samples),
            "vigorRecovered": any(v.get("vigor", 0) == 1.5 for v in samples),
            "retryCleared": any(v["epoch"] == 2 and v["challenge"] == "ready"
                                and v.get("form") == "wukong" and not v.get("snakes")
                                and not v.get("projectiles") and v["hp"] == 390 for v in samples),
        }
    catalog = ROOT / "unity/Library/com.unity.addressables/aa/OSX/catalog.json"
    valid = (len(tests) == 59 and all(e["pass"] for e in tests)
             and all(not p["luaErrors"] for p in processes)
             and any(p["replayCompleted"] for p in processes)
             and all(counts[e] > 0 for e in ("stanceHeavy", "immobilize", "cloudEnter", "cloudExit",
                                            "bianhuaIn", "bianhuaOut", "spiritSummon", "spiritBulletHit"))
             and len(milestones) == 2 and all(all(m.values()) for m in milestones.values()))
    result = {
        "pass": valid, "session": str(args.session), "processes": processes,
        "catalogBuiltAt": datetime.fromtimestamp(catalog.stat().st_mtime).astimezone().isoformat(),
        "catalogSha256": hashlib.sha256(catalog.read_bytes()).hexdigest(),
        "testCount": len(tests), "eventCounts": dict(counts), "clientMilestones": milestones,
        "tests": tests, "events": events, "clientViews": views,
        "limitations": ["glTF ShaderGraph BuiltIn Deferred Metal compilation error remains; runtime uses converted World_Lit scene materials.",
                        "Base montage Vigor recovery IDs are omitted by the source export; first energy row for the skill is used as the documented fallback.",
                        "Particle, sound, dissolve and material curve work is scheduled for step 7."],
    }
    target = ROOT / "docs/reference/step6-runtime-evidence.json"
    target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({k: result[k] for k in ("pass", "testCount", "eventCounts", "clientMilestones")}, ensure_ascii=False, indent=2))
    return 0 if valid else 1


if __name__ == "__main__":
    raise SystemExit(main())
