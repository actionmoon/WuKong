"""Capture the reference's public debug baseline in one managed browser lifetime."""

import json
from datetime import datetime
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
SESSION = "wk-arena-" + datetime.now().strftime("%H%M%S")


def browser(*args):
    result = subprocess.run(["agent-browser", "--session", SESSION, *args],
                            capture_output=True, text=True, check=True)
    return result.stdout


def evaluate(script):
    result = subprocess.run(["agent-browser", "--session", SESSION, "eval", "--stdin"],
                            input="(() => {" + script + "})()", capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return json.loads(result.stdout)


if __name__ == "__main__":
    try:
        browser("set", "viewport", "1280", "720")
        browser("open", "http://127.0.0.1:8765/")
        browser("wait", "--fn", "window.__WK_DEBUG__?.state().state === 'ready'")
        browser("press", "Enter")
        browser("wait", "--fn", "window.__WK_DEBUG__?.state().state === 'fight'")
        evaluate("window.__WK_DEBUG__.bossAi(false); window.__WK_DEBUG__.godMode(true); return true;")
        records = []
        for label, position in [("spawn", [0, -1.237, 0]), ("blood-pool", [0, -6.419, 42])]:
            evaluate(
                "const d=window.__WK_DEBUG__;d.teleport('player'," + ",".join(map(str, position))
                + ");d.game.cam.yaw=0;d.game.cam.pitch=-0.18;d.game.cam.first=true;return true;")
            browser("wait", "--fn", "window.__WK_DEBUG__?.state().player?.grounded")
            path = ROOT / f"docs/reference/step3-reference-{label}-{SESSION}.png"
            browser("screenshot", str(path))
            data = evaluate("const d=window.__WK_DEBUG__;return {state:d.state(),camera:d.game.r.camera.position.toArray(),"
                            "target:d.game.cam.smoothTarget.toArray(),fov:d.game.r.camera.fov};")
            records.append({"view": label, "path": str(path.relative_to(ROOT)), **data})
        output = ROOT / "docs/reference/step3-reference-views.json"
        output.write_text(json.dumps(records, indent=2, ensure_ascii=False))
        print(json.dumps(records, ensure_ascii=False))
    finally:
        browser("close")
