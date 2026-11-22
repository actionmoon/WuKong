"""Export only WuKong gameplay events from a specific debugger session."""
import argparse
from collections import Counter
from datetime import datetime
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent


def read(path):
    records, errors = [], []
    for line in path.read_text(errors="replace").splitlines():
        match = re.search(r"\[WK-(COMBAT|COMBAT-VIEW|BOSS-REPLAY)\] (.*)", line)
        if match:
            payload = match[2]
            start = payload.find("{")
            if start >= 0:
                try:
                    value = json.loads(payload[start:])
                except json.JSONDecodeError:
                    continue
                stamp = re.search(r"\[([0-9T:.Z-]+) log\]", line)
                records.append({"timestamp": stamp[1] if stamp else None, "channel": match[1], "value": value})
            elif match[1] == "BOSS-REPLAY":
                records.append({"channel": match[1], "message": payload})
        if any(word in line for word in ["LuaException", "attempt to ", "Lua runtime error", "not allowed in Lua", "XLua.LuaException"]):
            # Export the error line only; raw startup/SDK account fields stay in temp.
            errors.append(line[:1200])
    return records, errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("session", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/reference/step5-runtime-evidence.json")
    args = parser.parse_args()
    session = json.loads((args.session / "session.json").read_text())
    roles = {}
    for item in session:
        hdb = args.session / (item["role"] + "-hdb.log")
        path = hdb if hdb.exists() else Path(item["logFile"])
        events, errors = read(path)
        roles[item["role"]] = {"pid": item["pid"], "logFile": str(path), "events": events, "luaErrors": errors}
    server = [r["value"] for r in roles["server"]["events"] if "value" in r]
    counts = Counter(r.get("ev", "view") for r in server)
    latest = {}
    for role, content in roles.items():
        views = {}
        for record in content["events"]:
            if record.get("channel") == "COMBAT-VIEW":
                v = record["value"]
                views[str(v["actorID"])] = {k: v.get(k) for k in
                    ("challenge", "epoch", "hp", "bossHp", "mp", "stamina", "focus", "gourd", "resultReady", "hits")}
        if views:
            latest[role] = views
    result = {
        "session": str(args.session),
        "exportedAt": datetime.now().isoformat(),
        "buildCatalogMtime": datetime.fromtimestamp((ROOT / "unity/Library/com.unity.addressables/aa/OSX/catalog.json").stat().st_mtime).isoformat(),
        "runtime": "DedicatedServer + two actual clients; simulator F6 replay",
        "events": roles,
        "summary": {"serverEventCounts": dict(counts),
                    "bossSkillsObserved": sorted({e["id"] for e in server if e.get("ev") == "bossSkill"}),
                    "fixedSuite": [e for e in server if e.get("ev") == "bossFixedTest"],
                    "challenges": [e for e in server if e.get("ev") == "challenge"],
                    "latestClientStates": latest,
                    "luaErrorCount": sum(len(x["luaErrors"]) for x in roles.values())},
        "limits": ["Simulator-only skill/HP/death commands supply coverage; actual damage contacts still use production geometry.",
                   "Desktop remained locked; manual controls and screenshots were not observed.",
                   "51 skill definitions execute in the fixed suite; live skill coverage is the observed list above."],
    }
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"path": str(args.output), "summary": result["summary"]}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
