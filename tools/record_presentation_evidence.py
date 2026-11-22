"""Collect presentation and gameplay evidence from actual simulator logs."""
import argparse
import collections
import json
from pathlib import Path
from datetime import datetime

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("session", type=Path)
    parser.add_argument("--output", default="step7-runtime-evidence.json")
    args = parser.parse_args()
    rows = json.loads(args.session.read_text())
    output = {"session": str(args.session), "processes": [], "tests": [], "layouts": {},
              "events": [], "metrics": {}, "views": {}, "presentationLogs": {}}
    for row in rows:
        role = row["role"]
        lines = Path(row["logFile"]).read_text(errors="replace").splitlines()
        errors = [line for line in lines if any(key in line for key in (
            "LuaException", "LuaScriptException", "attempt to ", "NullReferenceException"))]
        output["processes"].append({"role": role, "pid": row["pid"], "logFile": row["logFile"],
                                    "errors": sorted(set(errors)), "errorCount": len(errors)})
        output["metrics"][role], output["views"][role], output["presentationLogs"][role] = [], [], []
        output["layouts"][role] = []
        for line in lines:
            if "[WK-PRESENTATION-METRICS] " in line:
                output["metrics"][role].append(json.loads(line.split("[WK-PRESENTATION-METRICS] ", 1)[1]))
            elif "[WK-LAYOUT] " in line:
                output["layouts"][role].append(json.loads(line.split("[WK-LAYOUT] ", 1)[1]))
            elif "[WK-COMBAT-VIEW] " in line:
                output["views"][role].append(json.loads(line.split("[WK-COMBAT-VIEW] ", 1)[1]))
            elif "[WK-COMBAT] {" in line:
                event = json.loads(line.split("[WK-COMBAT] ", 1)[1])
                output["events"].append(event)
                if event.get("ev") in {"fixedTest", "bossFixedTest", "skillsFixedTest"}:
                    output["tests"].append(event)
            if any(key in line for key in ("[WK-AUDIO]", "[WK-HUD]", "[WK-SKILLS-REPLAY]",
                                           "[WK-BOSS-REPLAY]", "[WK-ARENA] route",
                                           "[WK-ARENA] camera-reset", "[WK-COMBAT-POINTER]")):
                output["presentationLogs"][role].append(line)
    output["eventCounts"] = dict(collections.Counter(e.get("ev") for e in output["events"]))
    output["summaries"] = {}
    for role, metrics in output["metrics"].items():
        if not metrics:
            continue
        battle = [m for m in metrics if m.get("challenge") == "fight"]
        output["summaries"][role] = {
            "samples": len(metrics), "battleSamples": len(battle),
            "battleFpsMean": sum(m["fps"] for m in battle) / len(battle) if battle else None,
            "battleFpsMin": min((m["fps"] for m in battle), default=None),
            "p95FrameMsMax": max(m["p95ms"] for m in metrics),
            "allocatedBytesMax": max((m.get("allocatedBytes", 0) for m in metrics), default=0),
            "inputPayloadBytesPerSecMean": sum(m["inputBytesPerSec"] for m in metrics) / len(metrics),
            "snapshotPayloadBytesPerSecMean": sum(m["snapshotBytesPerSec"] for m in metrics) / len(metrics),
            "audio": metrics[-1]["audio"], "fx": metrics[-1]["fx"],
            "resolutions": sorted({(m["width"], m["height"]) for m in metrics}),
            "visibleRenderersRange": [
                min(m["rendering"]["visibleRenderers"] for m in metrics if m.get("rendering")),
                max(m["rendering"]["visibleRenderers"] for m in metrics if m.get("rendering")),
            ] if any(m.get("rendering") for m in metrics) else None,
            "visibleMeshTrianglesRange": [
                min(m["rendering"]["visibleMeshTriangles"] for m in metrics if m.get("rendering")),
                max(m["rendering"]["visibleMeshTriangles"] for m in metrics if m.get("rendering")),
            ] if any(m.get("rendering") for m in metrics) else None,
        }
    tests = output["tests"]
    output["testCount"] = len(tests)
    output["pass"] = bool(tests) and all(t.get("pass") for t in tests) and not any(
        p["errors"] for p in output["processes"])
    catalog = ROOT / "unity/Library/com.unity.addressables/aa/OSX/catalog.json"
    output["catalogBuiltAt"] = datetime.fromtimestamp(catalog.stat().st_mtime).astimezone().isoformat()
    output["limitations"] = [
        "Frame times describe the actual macOS simulator windows, not a target mobile device.",
        "Traffic counters measure UTF-8 JSON payloads and exclude SDK transport overhead.",
        "Visual and listening checks are recorded separately from playback and particle API evidence.",
    ]
    target = ROOT / "docs/reference" / args.output
    target.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({k: output[k] for k in ("pass", "testCount", "summaries")}, ensure_ascii=False, indent=2))
    return 0 if output["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
