"""Extract step-4 gameplay evidence without copying SDK credentials."""
import argparse
import datetime
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def events(path, marker):
    out = []
    for number, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        if marker not in line:
            continue
        payload = line.split(marker, 1)[1].strip()
        try:
            value = json.loads(payload)
        except json.JSONDecodeError:
            value = {"text": payload}
        out.append({"line": number, "value": value})
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("session", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/reference/step4-runtime-evidence.json")
    args = parser.parse_args()
    session = args.session
    server = events(session / "server.log", "[WK-COMBAT]")
    views = {
        name: events(session / (name + ".log"), "[WK-COMBAT-VIEW]")
        for name in ("client-1", "client-2")
    }
    values = [e["value"] for e in server]
    hits = [v for v in values if v.get("ev") == "hit"]
    # Multiple hit events can settle in one 20 Hz snapshot; verify the final
    # result of each montage playback instead of requiring transient HP values.
    final_hits = {}
    for hit in hits:
        final_hits[(hit["actor"], hit["play"])] = hit
    synced = []
    for hit in final_hits.values():
        matched = {}
        for name, stream in views.items():
            matched[name] = any(
                v["value"].get("actorID") == hit["actor"]
                and v["value"].get("play") == hit["play"]
                and v["value"].get("bossHp") == hit["bossHp"]
                for v in stream
            )
        synced.append({"hit": hit, "observed": matched})
    errors = {}
    for name in ("server", "client-1", "client-2"):
        text = (session / (name + ".log")).read_text(errors="replace")
        errors[name] = [
            {"line": number, "message": line}
            for number, line in enumerate(text.splitlines(), 1)
            if "LuaException" in line or "c# exception:" in line
        ]
    replay = events(session / "client-2.log", "[WK-COMBAT-REPLAY]")
    catalog = ROOT / "unity/Library/com.unity.addressables/aa/OSX/catalog.json"
    result = {
        "session": str(session),
        "mode": "DedicatedServer",
        "players": 2,
        "scene": "Assets/WuKong/Scenes/WuKongTiger.unity",
        "catalogBuiltAt": datetime.datetime.fromtimestamp(catalog.stat().st_mtime).isoformat(),
        "fixedTests": [v for v in values if v.get("ev") == "fixedTest"],
        "serverEvents": server,
        "clientViews": views,
        "hitReplication": synced,
        "luaErrors": errors,
        "replay": replay,
        "dedupUnique": len({(h["actor"], h["play"], h["group"]) for h in hits}) == len(hits),
    }
    target = args.output
    target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({
        "target": str(target),
        "fixedPass": sum(v.get("pass") is True for v in result["fixedTests"]),
        "hits": len(hits),
        "dedupUnique": result["dedupUnique"],
        "replicationPass": all(all(e["observed"].values()) for e in synced) if synced else False,
        "luaErrors": {k: len(v) for k, v in errors.items()},
        "replay": replay,
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
