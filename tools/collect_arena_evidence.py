"""Export only WuKong business markers and numeric camera probes from a simulator session."""

import argparse
from datetime import datetime
import json
from pathlib import Path
import re


def collect(directory):
    session = json.loads((directory / "session.json").read_text())
    if not isinstance(session, list):
        raise ValueError("Expected the simulator's list of instance records")
    instances = []
    sample_pattern = re.compile(
        r"sample actor=(\d+) position=\(([^)]+)\).*?floor=(\S+)"
        r" camera=\(([^)]+)\).*?distance=(\S+) locked=(true|false)"
    )
    for entry in session:
        role = entry["role"]
        log = Path(entry["logFile"])
        lines = log.read_text(errors="replace").splitlines()
        business = []
        samples = []
        for line in lines:
            if "[WK-ARENA]" in line or "[WK-SAMPLE]" in line:
                match = re.search(r"\[(WK-ARENA|WK-SAMPLE)\]", line)
                business.append(line[match.start():])
            match = sample_pattern.search(line)
            if match:
                samples.append({
                    "actor": int(match[1]),
                    "position": [float(n) for n in match[2].split(",")],
                    "floor": None if match[3] == "nil" else float(match[3]),
                    "camera": [float(n) for n in match[4].split(",")],
                    "requestedDistance": float(match[5]),
                    "locked": match[6] == "true",
                })
        instances.append({
            "role": role, "pid": entry["pid"],
            "startedAt": datetime.fromtimestamp(entry["startedAt"]).isoformat(),
            "businessEvents": business, "cameraSamples": samples,
            # SDK appends "stack traceback:" to ordinary Lua print messages too.
            "exceptionLineCount": sum(bool(re.search(r"\b\w*Exception\b", line))
                                      for line in lines),
        })
    return {"sessionDirectory": str(directory), "instances": instances,
            "note": "Recorded events are evidence; pass/fail decisions are documented in plan.md."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("session", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = collect(args.session)
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    print(f"Saved {args.output}: {len(result['instances'])} instances")
