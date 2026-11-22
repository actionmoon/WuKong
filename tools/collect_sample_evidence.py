"""Save only the sample's business events and observed measurements."""

import argparse
import json
from pathlib import Path
import shutil


ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("session", type=Path)
    args = parser.parse_args()
    session = args.session.resolve()
    entries = json.loads((session / "session.json").read_text())
    events = {}
    for entry in entries:
        path = session / (entry["role"] + "-hdb.log")
        events[entry["role"]] = [
            line for line in path.read_text(errors="replace").splitlines()
            if "[WK-SAMPLE]" in line
        ]
    server = "\n".join(events["server"])
    clients = ["\n".join(events["client-1"]), "\n".join(events["client-2"])]
    checks = {
        "ds_initialization": "ds-boot context-mode=independent-single-player" in server,
        "two_independent_contexts": all("contexts 1 -> 2" in s for s in [server, *clients]),
        "both_clients_bound_two_actors": all("actor=2" in s and "actor=3" in s for s in clients),
        "manual_client_a_request_to_ds": "request-processed context=1 revision=3" in server,
        "revision_three_on_both_clients": all("revision 2 -> 3" in s for s in clients),
        "animation_advances": all(s.count("animation-sample") >= 4 and "playing=true" in s for s in clients),
        "movement_visible_on_both_clients": all("visual-follow actor=2" in s and "error=0.0" in s for s in clients),
    }
    if not all(checks.values()):
        raise SystemExit("Evidence incomplete: " + json.dumps(checks))
    output = ROOT / "docs/reference/step2-runtime-evidence.json"
    output.write_text(json.dumps({
        "session": str(session), "scene": "Assets/WuKong/Scenes/WuKongTiger.unity",
        "mode": "ds", "network": "new", "pawnActorType": "avatar", "dataStore": False,
        "resourceCatalogModified": "2026-11-22 10:55:34",
        "checks": checks, "events": events,
        "editorMeasurements": {
            "collisionRay": {"origin": [7, 10, 0], "direction": [0, -1, 0],
                             "hit": [7, 0, 0], "normal": [0, 1, 0]},
            "idleClipLength": 14.53333, "spinePoseAngleAtOneSecond": 0.3582736,
            "gpuInstancing": {"meshCount": 1, "rendererCount": 42, "distinctPositions": 42,
                             "firstSourcePosition": [-364.703125, -167.796875, 481.375],
                             "firstUnityPosition": [364.703125, -167.796875, 481.375]},
        },
        "remaining": [
            "Client B manual input unverified after desktop tool timeout; its automatic request passed.",
            "Reference collision route walking unverified; isolated collider ray passed.",
            "SDK AvatarData null / missing pawn_avatar_bundle_uri / id type errors remain at startup.",
            "Fine normal, transparency and PBR calibration remain for later asset work.",
            "GPU extension instances became separate Renderers; batching and performance unverified.",
        ],
    }, ensure_ascii=False, indent=2) + "\n")
    screenshots = {
        "step2-client-a.jpg": "sdk-6b0259d42e85ab0.jpg",
        "step2-client-b.jpg": "sdk-6b025a1e38286378.jpg",
    }
    screenshot_root = Path("/var/folders/t5/cx_l90z95vx72xgc8ps0j8n80000gn/T/trae/computer-use/20261122/screenshots")
    for name, original in screenshots.items():
        shutil.copyfile(screenshot_root / original, output.parent / name)
    print(output)
    print(json.dumps(checks, ensure_ascii=False))


if __name__ == "__main__":
    main()
