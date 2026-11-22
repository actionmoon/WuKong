"""Record final asset integrity, source syntax, lifecycle and cross-client evidence."""
import argparse
import hashlib
import json
import re
import subprocess
from datetime import datetime
from pathlib import Path

from lupa.lua53 import LuaRuntime

ROOT = Path(__file__).resolve().parent.parent


def digest(path):
    with path.open("rb") as stream:
        result = hashlib.sha256()
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
        return result.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("session", type=Path)
    parser.add_argument("--runtime", default="step8-runtime-evidence.json")
    args = parser.parse_args()
    rows = json.loads(args.session.read_text())
    runtime = json.loads((ROOT / "docs/reference" / args.runtime).read_text())
    inventory = json.loads((ROOT / "docs/reference/wukong/inventory.json").read_text())
    checked, mismatches = [], []
    for item in inventory["files"]:
        if item.get("status") != 200:
            continue
        path = ROOT / "docs/reference/wukong" / item["path"]
        valid = path.is_file() and path.stat().st_size == item["bytes"] and digest(path) == item["sha256"]
        checked.append({"path": item["path"], "pass": valid})
        if not valid:
            mismatches.append(item["path"])

    lua = LuaRuntime(unpack_returned_tuples=True)
    compile_lua = lua.eval("function(source,name) local f,e=load(source,name); return f~=nil,e end")
    syntax = []
    for path in sorted((ROOT / "unity/Assets/WuKong/Lua").rglob("*.lua")):
        passed, error = compile_lua(path.read_text(), str(path.relative_to(ROOT)))
        syntax.append({"path": str(path.relative_to(ROOT)), "pass": passed, "error": error})

    sources = []
    asset_root = ROOT / "unity/Assets/WuKong"
    for path in sorted(asset_root.rglob("*")):
        if path.is_file() and path.suffix in {".lua", ".cs", ".shader", ".unity", ".json"}:
            sources.append({"path": str(path.relative_to(ROOT)), "bytes": path.stat().st_size,
                            "sha256": digest(path)})
    scene = asset_root / "Scenes/WuKongTiger.unity"
    catalogs = [
        ROOT / "unity/Library/com.unity.addressables/aa/OSX/catalog.json",
        ROOT / "unity/AddressableAssetsData/StandaloneOSX/WuKongTiger/OSX/addrsettingcache/catalog.json",
    ]
    builds = [{"path": str(p.relative_to(ROOT)), "bytes": p.stat().st_size,
               "sha256": digest(p), "modifiedAt": datetime.fromtimestamp(p.stat().st_mtime).astimezone().isoformat()}
              for p in catalogs if p.is_file()]
    bundle_root = ROOT / "unity/AddressableAssetsData/StandaloneOSX/WuKongTiger"
    bundles = [{"path": str(p.relative_to(ROOT)), "bytes": p.stat().st_size, "sha256": digest(p)}
               for p in sorted(bundle_root.rglob("*.bundle"))]

    lifecycle, processes, log_findings = [], [], []
    for row in rows:
        status = subprocess.run(["ps", "-p", str(row["pid"]), "-o", "stat="],
                                capture_output=True, text=True)
        state = status.stdout.strip()
        processes.append({k: row[k] for k in ("role", "pid", "identityTag", "roomTag")})
        processes[-1]["exited"] = status.returncode != 0 or state.startswith("Z")
        for field in ("logFile", "consoleLog"):
            path = Path(row[field])
            lines = path.read_text(errors="replace").splitlines() if path.is_file() else []
            for line in lines:
                if "ugc_onplayerleft" in line:
                    actor = re.search(r'"player_id":(\d+)', line)
                    event = re.search(r'"left_event":"([^"]+)"', line)
                    if actor and event:
                        lifecycle.append({"role": row["role"], "actorID": int(actor[1]),
                                          "event": event[1], "log": str(path)})
            counts = {pattern: sum(bool(re.search(pattern, line)) for line in lines)
                      for pattern in ("LuaException|LuaScriptException", "NullReferenceException",
                                      "CreateDirectory .*failed", r"\[hdb\].*disconnected",
                                      "GetPrefab failed")}
            log_findings.append({"role": row["role"], "path": str(path), "counts": counts})

    a = runtime["views"].get("client-1", [])
    b = runtime["views"].get("client-2-rejoin", [])
    a_states = {json.dumps(v, sort_keys=True, ensure_ascii=False) for v in a}
    b_states = {json.dumps(v, sort_keys=True, ensure_ascii=False) for v in b}
    shared = a_states & b_states
    events = runtime["events"]
    heavy = next((e for e in reversed(events) if e.get("ev") == "bossHit"
                  and e.get("skill") == 10831 and e.get("hp") == 0), None)
    result = {
        "recordedAt": datetime.now().astimezone().isoformat(),
        "session": str(args.session), "scene": str(scene.relative_to(ROOT)),
        "sceneSavedAt": datetime.fromtimestamp(scene.stat().st_mtime).astimezone().isoformat(),
        "sceneSHA256": digest(scene), "catalogs": builds,
        "bundles": bundles,
        "referenceFilesChecked": len(checked), "referenceMismatches": mismatches,
        "luaSyntax": syntax, "sources": sources, "processes": processes,
        "lifecycleEvents": lifecycle, "logFindings": log_findings,
        "fixedTests": runtime["testCount"],
        "fixedTestsPassed": sum(bool(t.get("pass")) for t in runtime["tests"]),
        "projectLuaExceptionCount": sum(f["counts"]["LuaException|LuaScriptException"] for f in log_findings),
        "rawRuntimeErrorCount": sum(p["errorCount"] for p in runtime["processes"]),
        "crossClientIdenticalSnapshots": len(shared),
        "lateClientActors": sorted({v["actorID"] for v in b}),
        "lateClientPhases": sorted({v["boss"]["phase"] for v in b if v.get("boss")}),
        "heavyFatalHit": heavy,
        "finalClientStates": {
            role: {str(actor): next(v for v in reversed(views) if v["actorID"] == actor)
                   for actor in sorted({v["actorID"] for v in views})}
            for role, views in (("client-1", a), ("client-2-rejoin", b))
        },
        "scope": "Fixed suites and replay evidence; not a claim of natural full completion or mobile acceptance.",
    }
    output = ROOT / "docs/reference/step8-delivery-evidence.json"
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({k: result[k] for k in ("referenceFilesChecked", "referenceMismatches",
                     "fixedTests", "fixedTestsPassed", "crossClientIdenticalSnapshots",
                     "lateClientActors", "lateClientPhases", "heavyFatalHit")}, ensure_ascii=False, indent=2))
    print("Lua syntax:", len(syntax), "passed:", sum(t["pass"] for t in syntax))
    print("All test processes exited:", all(p["exited"] for p in processes))
    passed = (not mismatches and all(t["pass"] for t in syntax)
              and all(p["exited"] for p in processes)
              and bool(runtime["tests"]) and all(t.get("pass") for t in runtime["tests"])
              and bool(shared) and heavy is not None and result["projectLuaExceptionCount"] == 0)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
