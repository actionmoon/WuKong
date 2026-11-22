"""Run the Hamlet sample using the Editor's existing SDK login, without storing credentials."""

import os
from pathlib import Path
import subprocess
import sys

from unity_mcp import UnityMcp


ROOT = Path(__file__).resolve().parent.parent


def main():
    client = UnityMcp()
    client.select("unity@fff213c1fca70370")
    result = client.call("execute_code", {
        "action": "execute",
        "code": (
            "return new {token=com.douyin.common.SDKCenter.Instance.Account.GetData().AccessToken,"
            'device=typeof(EditorUtil).GetMethod("GetDeviceId",'
            "System.Reflection.BindingFlags.Static|System.Reflection.BindingFlags.Public|"
            "System.Reflection.BindingFlags.NonPublic).Invoke(null,null)};"
        ),
    })["data"]["result"]
    if not result.get("token") or not result.get("device"):
        raise SystemExit("请先在 Unity Editor 登录 SDK。")
    env = os.environ.copy()
    env["HAMLET_ACCESS_TOKEN"] = result["token"]
    env["HAMLET_DEVICE_ID"] = result["device"]
    command = [
        sys.executable, str(ROOT / ".trae/skills/hamlet-debugging/scripts/simulator.py"),
        "--project", str(ROOT / "unity"), "--mode", "ds",
        "--players", "悟空测试A", "悟空测试B",
        "--scene", "Assets/WuKong/Scenes/WuKongTiger.unity",
        "--room", "0", "--network", "new", "--data-store", "off",
        "--pawn-actor-type", "avatar", "--windowless",
        "--executable", str(ROOT / "unity/DouyinWorldDebuggerEditor/DouyinWorldDebugger.app"),
        "--instance-executable", "client-1=" + str(ROOT / "unity/DouyinWorldDebuggerEditor/ClientA.app/Contents/MacOS/DouyinWorldDebugger"),
        "--instance-executable", "client-2=" + str(ROOT / "unity/DouyinWorldDebuggerEditor/ClientB.app/Contents/MacOS/DouyinWorldDebugger"),
        *sys.argv[1:],
    ]
    raise SystemExit(subprocess.run(command, cwd=ROOT, env=env).returncode)


if __name__ == "__main__":
    main()
