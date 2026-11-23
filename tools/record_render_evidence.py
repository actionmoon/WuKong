"""Record render build hashes and comparable simulator replay measurements."""

import argparse
import collections
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def replay_metrics(path, marker):
    active = False
    complete = False
    metrics = []
    for line in path.read_text(errors="replace").splitlines():
        if marker + " start" in line:
            active = True
        elif active and marker + " finished" in line:
            complete = True
            break
        elif active and "[WK-PRESENTATION-METRICS] " in line:
            metrics.append(json.loads(line.split("[WK-PRESENTATION-METRICS] ", 1)[1]))
    selected = [m for m in metrics if m.get("challenge") == "fight"
                and (m.get("width"), m.get("height")) == (1140, 700)]
    return {
        "complete": complete, "resolution": [1140, 700], "samples": len(selected),
        "fpsMean": sum(m["fps"] for m in selected) / len(selected) if selected else None,
        "fpsMin": min((m["fps"] for m in selected), default=None),
        "p95FrameMsMax": max((m["p95ms"] for m in selected), default=None),
        "allocatedBytesMax": max((m.get("allocatedBytes", 0) for m in selected), default=0),
        "metrics": selected,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("session", type=Path)
    args = parser.parse_args()
    rows = json.loads(args.session.read_text())
    runtime = json.loads((ROOT / "docs/reference/render-final-runtime-evidence.json").read_text())
    baseline = json.loads((ROOT / "docs/reference/render-baseline-runtime-evidence.json").read_text())
    previous = next(p for p in baseline["processes"] if p["role"] == "client-1")
    current = next(p for p in rows if p["role"] == "client-1")
    cache = ROOT / "unity/AddressableAssetsData/StandaloneOSX/WuKongTiger"
    artifacts = []
    for p in sorted(cache.rglob("*")):
        if p.is_file() and (p.suffix == ".bundle" or p.name in {"catalog.json", "settings.json"}):
            artifacts.append({
                "path": str(p.relative_to(ROOT)), "bytes": p.stat().st_size,
                "sha256": digest(p),
                "modifiedAt": datetime.fromtimestamp(p.stat().st_mtime).astimezone().isoformat(),
            })
    snapshots = {}
    for role in ("client-1", "client-2"):
        snapshots[role] = collections.Counter(
            json.dumps(v, sort_keys=True, separators=(",", ":"))
            for v in runtime["views"].get(role, [])
        )
    matching = sum((snapshots["client-1"] & snapshots["client-2"]).values())
    logs = runtime["presentationLogs"]
    completion = {
        "skills": any("[WK-SKILLS-REPLAY] finished" in s for s in logs["client-1"]),
        "boss": any("[WK-BOSS-REPLAY] finished" in s for s in logs["client-2"]),
        "route": any("[WK-ARENA] route-stop reason=completed" in s for s in logs["client-1"]),
    }
    # The full process error list includes SDK shutdown errors; classify them separately.
    errors = [{
        "role": p["role"],
        "projectLua": [e for e in p["errors"] if any(k in e for k in
                        ("LuaException", "LuaScriptException", "attempt to "))],
        "sdkOrNative": [e for e in p["errors"] if not any(k in e for k in
                         ("LuaException", "LuaScriptException", "attempt to "))],
    } for p in runtime["processes"]]
    exited = []
    for row in rows:
        try:
            os.kill(row["pid"], 0)
            running = True
        except ProcessLookupError:
            running = False
        exited.append({"role": row["role"], "pid": row["pid"], "exited": not running})
    server = next(row for row in rows if row["role"] == "server")
    exit_count = sum('"left_event":"ExitRoom"' in line
                     for line in Path(server["logFile"]).read_text(errors="replace").splitlines())
    output = {
        "session": str(args.session), "artifacts": artifacts,
        "bundleBytes": sum(a["bytes"] for a in artifacts if a["path"].endswith(".bundle")),
        "replays": completion, "identicalSnapshotCount": matching,
        "fixedTests": {"count": runtime["testCount"], "passed": sum(t.get("pass", False) for t in runtime["tests"])},
        "errors": errors,
        "processes": exited, "normalExitRoomCount": exit_count,
        "comparison": {
            "baseline": replay_metrics(Path(previous["logFile"]), "[WK-SKILLS-REPLAY]"),
            "final": replay_metrics(Path(current["logFile"]), "[WK-SKILLS-REPLAY]"),
            "conditions": "Same A window 1140x700 and F5 replay; final session also exercises B F6 with different scheduling. Five-second fight samples only.",
            "baselineCatalogNote": "Baseline collector ran after a later build; its catalogBuiltAt is not the baseline build timestamp.",
        },
        "limitations": ["macOS simulator only; no mobile device measurements.",
                        "Replay uses controlled reset, HP and forced skills; it is not unaided gameplay.",
                        "Snapshot equality proves delivered contents, not rendered appearance equality."],
    }
    target = ROOT / "docs/reference/render-restoration-evidence.json"
    target.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({k: output[k] for k in ("replays", "fixedTests", "identicalSnapshotCount", "errors", "bundleBytes")}, ensure_ascii=False, indent=2))
    for name, data in output["comparison"].items():
        if isinstance(data, dict):
            print(name, json.dumps({k: v for k, v in data.items() if k != "metrics"}))


if __name__ == "__main__":
    main()
