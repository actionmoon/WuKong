#!/usr/bin/env python3
"""抖音模拟器启动器（Python 3.9+，仅使用标准库）。

在 Unity 项目或其仓库目录运行：
    python3 .trae/skills/hamlet-debugging/scripts/simulator.py --dry-run
    python3 .trae/skills/hamlet-debugging/scripts/simulator.py --mode single
    python3 .trae/skills/hamlet-debugging/scripts/simulator.py --mode shared
    python3 .trae/skills/hamlet-debugging/scripts/simulator.py --mode ds

自动读取 EditorPrefs、当前场景、SDK 配置及本项目最近的 SDK 启动记录。
资源由 SDK 在 Editor 中构建；本脚本校验并安装已有缓存，不自行构建 Unity。
可用 --config 指定 JSON 对象覆盖公共参数（名称不带前导 -，值未经 URL 编码）。
实例身份、工作目录和日志由启动器管理，昵称和关系通过对应命令行选项设置。
accessToken/device_id 也可由 HAMLET_ACCESS_TOKEN/HAMLET_DEVICE_ID 提供。
新网络先查询配置，再建房或校验已有房间；旧网络的 --room 必须是最终房间 ID。
脚本身份由项目路径、服务端/客户端角色和昵称确定，可跨重启/房间复用存储；
此身份与 SDK 窗口的 .NET 哈希身份不同，测试存档不会与 SDK 窗口互通。
--dry-run 仅检查本地资料，不联网、不复制资源、不启动进程、不写日志。

启动只表示进程创建成功。请按调试手册继续验证场景、输入、同步和存储。
原始 Player 日志可能包含账号信息，仅保存在本机临时目录；对外分享前需脱敏。
"""

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import time
from urllib import error, parse, request
import uuid


ENCODED = {
    "nickName", "relationName", "worldAddressableBundle",
    "worldAddressableSceneName", "worldAssetBundle", "worldAssetName",
    "worldScriptBundle", "workingDir",
}
RUNTIME_KEYS = ENCODED | {
    "roomName", "serverId", "openId", "netHostAddr", "isCreateRoom",
    "isNewNetModule", "worldId", "dataStoreEnabled", "environment",
    "accessToken", "device_id", "isSinglePlayer", "isDsMode", "isDsServer",
    "isWindowless", "pawnActorType", "avatarId", "avatarPrefab",
    "avatarPrefabBundleURL", "worldBundleUrl", "screen-width", "screen-height",
    "monitor", "screen-fullscreen",
    "app_id", "unique_id", "sdk_version", "logFile", "hdbLogFile",
}
BOOL_KEYS = {
    "isCreateRoom", "isNewNetModule", "dataStoreEnabled", "isSinglePlayer",
    "isDsMode", "isDsServer", "isWindowless",
}
MANAGED_KEYS = {"openId", "nickName", "relationName", "workingDir",
                "logFile", "hdbLogFile", "isDsServer", "isWindowless"}


class SimulatorError(Exception):
    """可直接展示且不含秘密的操作错误。"""


def read_json(path):
    try:
        with Path(path).open(encoding="utf-8-sig") as stream:
            value = json.load(stream)
    except (OSError, ValueError) as exc:
        raise SimulatorError(f"无法读取 JSON 文件：{path}") from exc
    if not isinstance(value, dict):
        raise SimulatorError(f"JSON 顶层必须为对象：{path}")
    return value


def boolean(value):
    if isinstance(value, bool):
        return value
    if str(value).lower() in ("true", "1"):
        return True
    if str(value).lower() in ("false", "0"):
        return False
    raise SimulatorError("布尔配置必须是 true 或 false")


def text(value):
    return str(value).lower() if isinstance(value, bool) else str(value)


def pawn_actor_type(value):
    mapping = {"pet": "0", "avatar": "1"}
    try:
        return mapping[value.lower()]
    except (AttributeError, KeyError):
        raise argparse.ArgumentTypeError("必须是 pet 或 avatar") from None


def split_arguments(command):
    """解析 SDK QuoteCommandLineArgument 使用的双引号/反斜杠约定。

    不使用 POSIX shlex：它会损坏 Windows 路径和 SDK 转义的 JSON。
    """
    result, index = [], 0
    while index < len(command):
        while index < len(command) and command[index].isspace():
            index += 1
        if index == len(command):
            break
        word, quoted = [], False
        while index < len(command) and (quoted or not command[index].isspace()):
            slashes = 0
            while index < len(command) and command[index] == "\\":
                slashes += 1
                index += 1
            if index < len(command) and command[index] == '"':
                word.extend("\\" * (slashes // 2))
                if slashes % 2:
                    word.append('"')
                else:
                    quoted = not quoted
                index += 1
            else:
                word.extend("\\" * slashes)
                if index < len(command) and (quoted or not command[index].isspace()):
                    word.append(command[index])
                    index += 1
        if quoted:
            raise SimulatorError("SDK 启动记录中的引号不完整")
        result.append("".join(word))
    return result


def parse_arguments(command):
    parts = split_arguments(command)
    if len(parts) % 2:
        raise SimulatorError("SDK 启动记录不是成对参数")
    values = {}
    for key, value in zip(parts[::2], parts[1::2]):
        name = key.removeprefix("-")
        if name in RUNTIME_KEYS:
            values.setdefault(name, parse.unquote_plus(value) if name in ENCODED else value)
    return values


def to_argv(values):
    result = []
    for key, value in values.items():
        if key not in RUNTIME_KEYS:
            continue
        value = text(value)
        if key in ENCODED:
            value = parse.quote(value, safe="")
        result.extend(["-" + key, value])
    return result


def discover_project(start):
    start = Path(start).expanduser().resolve()
    for parent in (start, *start.parents):
        if (parent / "ProjectSettings/ProjectVersion.txt").is_file():
            return parent
    candidates = [
        p.parent.parent for p in start.glob("*/ProjectSettings/ProjectVersion.txt")
    ]
    if len(candidates) == 1:
        return candidates[0]
    raise SimulatorError("无法唯一定位 Unity 项目，请用 --project 指定项目根目录")


def editor_prefs():
    if sys.platform == "darwin":
        path = Path.home() / "Library/Preferences/com.unity3d.UnityEditor5.x.plist"
        if path.exists():
            try:
                return plistlib.loads(path.read_bytes())
            except (OSError, plistlib.InvalidFileException, ValueError) as exc:
                raise SimulatorError("无法读取 Unity EditorPrefs") from exc
    elif sys.platform == "win32":
        import winreg
        result = {}
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER,
                               r"Software\Unity Technologies\Unity Editor 5.x") as key:
                for index in range(winreg.QueryInfoKey(key)[1]):
                    name, value, _ = winreg.EnumValue(key, index)
                    if isinstance(value, bytes):
                        value = value.rstrip(b"\0").decode("utf-8", errors="replace")
                    result[re.sub(r"_h\d+$", "", name)] = value
        except FileNotFoundError:
            pass
        return result
    return {}


def default_logs():
    if sys.platform == "win32":
        directory = Path(os.environ.get("LOCALAPPDATA", "")) / "Unity/Editor"
    else:
        directory = Path.home() / "Library/Logs/Unity"
    return [directory / "Editor.log", directory / "Editor-prev.log"]


def read_launch_record(project, logs):
    """只接受 workingDir 与目标项目一致的记录，忽略截断记录。"""
    project = project.resolve()
    candidates = []
    for log in logs:
        if not log.is_file():
            continue
        latest = None
        # 限制内存和旧记录范围；跳过截断的第一行。
        with log.open("rb") as stream:
            size = stream.seek(0, os.SEEK_END)
            stream.seek(max(0, size - 16 * 1024 * 1024))
            if stream.tell():
                stream.readline()
            for line in stream:
                line = line.decode("utf-8", errors="replace")
                marker = "StartSimulatorProcess arguments:"
                if marker not in line:
                    continue
                try:
                    values = parse_arguments(line.split(marker, 1)[1].strip())
                    if values.get("workingDir") and Path(values["workingDir"]).resolve() == project:
                        latest = values
                except (SimulatorError, OSError, ValueError):
                    continue
        if latest:
            candidates.append((log.stat().st_mtime, latest))
    return max(candidates, key=lambda item: item[0])[1] if candidates else {}


def executable_path(project, prefs, explicit=None):
    suffix = ("DouyinWorldDebugger.app/Contents/MacOS/DouyinWorldDebugger"
              if sys.platform == "darwin" else "DouyinWorldDebugger.exe")
    configured = explicit or prefs.get("HamletSimulator")
    path = Path(configured).expanduser() if configured else (
        project / "DouyinWorldDebuggerEditor" / suffix)
    if not path.is_absolute():
        path = project / path
    if path.suffix == ".app":
        path = path / "Contents/MacOS" / path.stem
    if not path.is_file():
        raise SimulatorError(f"未找到调试器可执行程序：{path}。"
                             "请确认安装位置，或先安装调试器并配置路径。")
    if sys.platform != "win32" and not os.access(path, os.X_OK):
        raise SimulatorError(f"调试器没有执行权限：{path}")
    return path.resolve()


def active_scene(project):
    path = project / "Library/LastSceneManagerSetup.txt"
    if path.is_file():
        for block in path.read_text(encoding="utf-8").split("- path:")[1:]:
            if re.search(r"isActive:\s*1", block):
                return block.splitlines()[0].strip().strip('"')
    return ""


def load_settings(project, prefs, overrides, logs):
    values = read_launch_record(project, logs)
    config_path = project / "Packages/com.douyin.world/Config/simulator.json"
    config = read_json(config_path) if config_path.exists() else {}
    values["netHostAddr"] = config.get("hostAddr", "hamlet-debugger.douyin.com:8900")
    values["serverId"] = text(config.get("serverId", 0))
    sdk_path = project / "Packages/com.douyin.common/Config/SdkConfig.json"
    sdk = read_json(sdk_path) if sdk_path.exists() else {}
    # 发布版 SDKOnlineConfig 的默认环境；开发版优先读取 SdkConfig。
    recorded_env = values.get("environment")
    env = overrides.get("environment") or sdk.get("Env") or recorded_env or "online"
    env_info = next((x for x in sdk.get("SdkEnvValue", []) if x.get("Env") == env), {})
    values["environment"] = env
    values["app_id"] = text(env_info.get("SdkAppId", values.get("app_id", 618015)))
    values["accessToken"] = (prefs.get(f"{env}_AccessToken") or
                             (values.get("accessToken", "") if recorded_env == env else ""))
    values["dataStoreEnabled"] = text(prefs.get(
        "HamletIsOpenDataStorge", values.get("dataStoreEnabled", False)))
    values["worldId"] = text(prefs.get(
        "HamletDataStorge_worldId", values.get("worldId", "")))
    preferences = Path(__file__).resolve().parents[2] / "hamlet-skill/hamlet-preferences.md"
    content = preferences.read_text(encoding="utf-8") if preferences.exists() else ""
    values.setdefault("pawnActorType", "0" if re.search(
        r"\*\*AvatarOrPet\*\*:\s*Pet\b", content) else "1")
    values.setdefault("isNewNetModule", "false")
    values["workingDir"] = str(project)
    scene = active_scene(project)
    if scene:
        values["worldAddressableSceneName"] = scene
    for key, env_key in (("accessToken", "HAMLET_ACCESS_TOKEN"),
                         ("device_id", "HAMLET_DEVICE_ID")):
        if os.environ.get(env_key):
            values[key] = os.environ[env_key]
    values.update({key: text(value) for key, value in overrides.items() if key in RUNTIME_KEYS})
    values["workingDir"] = str(project)
    for key in BOOL_KEYS & values.keys():
        values[key] = text(boolean(values[key]))
    if values.get("pawnActorType") not in ("0", "1"):
        raise SimulatorError("pawnActorType 必须是 Pet=0 或 Avatar=1")
    api = {
        "url": overrides.get("resourceUrl") or env_info.get("ResourceUrl") or
               ("https://vassets-backend.douyin.com" if env == "online" else ""),
        "envMark": overrides.get("envMark") or env_info.get("EvnMarkHeader", ""),
    }
    return values, api, config


def local_path(project, value):
    path = Path(value).expanduser()
    if sys.platform != "win32":
        path = Path(str(path).replace("\\", "/"))
    return (path if path.is_absolute() else project / path).resolve()


def prepare_resources(project, executable, values, dry_run):
    """返回缓存复制源和目标；所有本地校验通过后才安装缓存。"""
    bundle, asset = values.get("worldAssetBundle"), values.get("worldAssetName")
    cache_pair = None
    if bundle or asset:
        if not bundle or not asset:
            raise SimulatorError("AssetBundle 路径和场景资源名必须同时提供")
        path = local_path(project, bundle)
        if not path.is_file():
            raise SimulatorError(f"未找到 AssetBundle：{path}")
        values["worldAssetBundle"] = str(path)
        values.pop("worldAddressableBundle", None)
        values.pop("worldAddressableSceneName", None)
    else:
        scene = values.get("worldAddressableSceneName", "")
        if not scene:
            raise SimulatorError("未找到活动场景，请先在 Unity Editor 打开目标场景")
        platform = "OSX" if sys.platform == "darwin" else "Windows"
        target = "StandaloneOSX" if sys.platform == "darwin" else "StandaloneWindows64"
        configured_root = local_path(project, values.get(
            "worldAddressableBundle", str(project / "AddressableAssetsData" / target)))
        scene_root = configured_root
        cache = scene_root / platform / "addrsettingcache"
        if not (cache / "settings.json").is_file():
            scene_root = configured_root / Path(scene).stem
            cache = scene_root / platform / "addrsettingcache"
        for name in ("settings.json", "catalog.json"):
            if not (cache / name).is_file():
                raise SimulatorError(f"缺少模拟器资源：{cache / name}。"
                                     "请先在 SDK 模拟器窗口构建当前场景资源。")
            read_json(cache / name)
        if sys.platform == "darwin":
            destination = executable.parents[1] / "Resources/Data/StreamingAssets/aa"
        else:
            destination = executable.parent / "DouyinWorldDebugger_Data/StreamingAssets/aa"
        values["worldAddressableBundle"] = str(scene_root)
        cache_pair = (cache, destination)
    if values.get("worldScriptBundle"):
        path = local_path(project, values["worldScriptBundle"])
        if not path.is_file():
            raise SimulatorError(f"未找到 C# 脚本包：{path}。请用 SDK 重新构建。")
        values["worldScriptBundle"] = str(path)
    if cache_pair and not dry_run:
        # 不删除共享目录；SDK settings/catalog 使用固定名称，覆盖同名缓存即可。
        shutil.copytree(*cache_pair, dirs_exist_ok=True)
    return cache_pair


def response_data(payload):
    if not isinstance(payload, dict):
        raise SimulatorError("房间接口返回格式无效")
    data = payload.get("data", payload)
    for layer in (payload, data):
        if not isinstance(layer, dict):
            raise SimulatorError("房间接口返回格式无效")
        base = layer.get("base_resp") or {}
        if not isinstance(base, dict):
            raise SimulatorError("SDK 接口状态格式无效")
        try:
            code = int(base.get("status_code", layer.get("error_code", 0)))
        except (TypeError, ValueError):
            raise SimulatorError("SDK 接口状态格式无效") from None
        if code != 0:
            # 服务端 message 可能回显 token 或请求，不对外展示。
            raise SimulatorError(f"SDK 接口失败（错误码 {code}），请在 Editor 检查登录或房间")
    return data


class NoRedirect(request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # 不把鉴权头转发给重定向目的地址。
        return None


def sdk_request(values, api, endpoint, body=None):
    base_url = api["url"]
    if parse.urlsplit(base_url).scheme != "https":
        raise SimulatorError("SDK ResourceUrl 必须是已配置的 HTTPS 地址")
    if not values.get("accessToken") or not values.get("device_id"):
        raise SimulatorError("缺少有效 SDK 登录或设备记录，请先在 Editor 登录并启动一次模拟器")
    if values["environment"] != "online" and not api["envMark"]:
        raise SimulatorError("缺少当前 SDK 环境配置，请检查 SdkConfig.json")
    serialized = "" if body is None else json.dumps(body, ensure_ascii=False, separators=(",", ":"))
    headers = {
        "X-Hamlet-Dy-Scene": "3",
        "X-Hamlet-Dy-Access-Token": values["accessToken"],
        "X-Hamlet-Dy-Device-Id": values["device_id"],
    }
    # 与 SDK EditorUtil.GenerateSignature(headers, body, "SDK") 保持一致。
    signature = "&".join(f"{key}={headers[key]}" for key in sorted(headers))
    digest = hashlib.md5((signature + serialized + "SDK").encode()).digest()
    headers.update({
        "x-hamlet-dy-signature": base64.b64encode(digest).decode(),
        "agw-js-conv": "str",
        "hamlet-sdk-timestamp": str(int(time.time())),
        "Content-Type": "application/json",
    })
    if values["environment"] != "online":
        headers.update({"x-use-ppe": "1", "x-tt-env": api["envMark"]})
    req = request.Request(base_url.rstrip("/") + endpoint, headers=headers,
                          data=None if body is None else serialized.encode())
    try:
        with request.build_opener(NoRedirect()).open(req, timeout=30) as response:
            return response_data(json.load(response))
    except error.HTTPError as exc:
        raise SimulatorError(f"SDK 接口 HTTP {exc.code}，请在 Editor 检查登录和环境") from None
    except (error.URLError, OSError, ValueError) as exc:
        raise SimulatorError("SDK 接口请求失败，请检查网络和 SDK 环境") from None


def resolve_room(values, mode, send, dry_run=False):
    room = values.get("roomName", "").strip()
    new_net = boolean(values.get("isNewNetModule", False))
    if not new_net:
        if not room or room == "0":
            if mode != "single":
                raise SimulatorError("缺少旧网络最终房间 ID，请先在 SDK 启动一次或使用 --room")
            room = "local-" + uuid.uuid4().hex
        values.update(roomName=room, isCreateRoom="true")
        return
    create = not room or room == "0"
    if not create and (not room.isascii() or not room.isdecimal() or int(room) <= 0):
        raise SimulatorError("新网络房间 ID 必须是正整数")
    values["isCreateRoom"] = text(create)
    if dry_run:
        return
    body = {"room_id": 0 if create else int(room)}
    if create:
        body.update({
            "world_id": values["worldId"],
            "world_type": 2 if values["pawnActorType"] == "1" else 1,
            "world_version": 0,
            "room_mode": 1 if mode == "ds" else 0,
            "delay_create_spirit": True,
            "data_store_enabled": boolean(values["dataStoreEnabled"]),
        })
    data = send("/room/user/create_local" if create else "/room/user/get_local", body)
    result = data.get("room")
    final_id = str(result.get("room_id", "")) if isinstance(result, dict) else ""
    if not final_id.isascii() or not final_id.isdecimal() or int(final_id) <= 0:
        raise SimulatorError("房间接口未返回有效 room_id")
    values["roomName"] = final_id


def make_instances(common, mode, names, log_dir, relation, windowless):
    names = [name.strip() or "Anonymous" for name in names]
    if (mode == "single" and len(names) != 1) or (mode != "single" and len(names) < 2):
        raise SimulatorError("单机需要一个玩家；SharedMode/DS 至少需要两个玩家")
    if len(set(names)) != len(names):
        raise SimulatorError("玩家名称必须互不相同")
    players = [(False, name, f"client-{index + 1}") for index, name in enumerate(names)]
    if mode == "ds":
        players.insert(0, (True, "服务端", "server"))
    instances = []
    for server, name, label in players:
        values = dict(common)
        # 固定身份让存储用例能跨重启验证；角色参与哈希，避免同名服务端与玩家冲突。
        identity = hashlib.sha256(json.dumps(
            [common.get("workingDir", ""), server, name], ensure_ascii=False
        ).encode()).hexdigest()[:32]
        values.update({
            "openId": "SimOpenId__" + identity,
            "nickName": name,
            "relationName": relation,
            "isSinglePlayer": text(mode == "single"),
            "isDsMode": text(mode == "ds"),
            "isDsServer": text(server),
            "isWindowless": text(server and windowless),
            "logFile": str(log_dir / (label + ".log")),
            "hdbLogFile": str(log_dir / (label + "-hdb.log")),
        })
        instances.append(values)
    return instances


def wait_processes(processes, seconds):
    deadline = time.monotonic() + seconds
    while True:
        for process in processes:
            if process.poll() is not None:
                raise SimulatorError(f"模拟器进程 {process.pid} 已退出，请检查独立日志")
        if time.monotonic() >= deadline:
            return
        time.sleep(min(0.2, max(0, deadline - time.monotonic())))


def launch(executable, project, instances, run_dir, ready_pattern=None, timeout=60, hold=False,
           instance_executables=None):
    processes, records = [], []
    manifest = run_dir / "session.json"
    try:
        for index, values in enumerate(instances):
            label = Path(values["logFile"]).stem
            console = run_dir / f"{label}-console.log"
            with console.open("wb") as stream:
                process = subprocess.Popen(
                    [str((instance_executables or {}).get(label, executable)), *to_argv(values)], cwd=str(project),
                    stdin=subprocess.DEVNULL, stdout=stream, stderr=subprocess.STDOUT,
                    start_new_session=(sys.platform != "win32"),
                )
            processes.append(process)
            records.append({
                "role": label, "pid": process.pid, "startedAt": time.time(),
                "logFile": values["logFile"], "consoleLog": str(console),
                "identityTag": hashlib.sha256(values["openId"].encode()).hexdigest()[:12],
                "roomTag": hashlib.sha256(values["roomName"].encode()).hexdigest()[:12],
                "state": "started; gameplay unverified",
            })
            manifest.write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"{label}: PID {process.pid}，日志 {values['logFile']}", flush=True)
            if values["isDsServer"] == "true" and ready_pattern:
                deadline = time.monotonic() + timeout
                while True:
                    wait_processes(processes, 0)
                    log = Path(values["logFile"])
                    content = log.read_text(encoding="utf-8", errors="replace") if log.exists() else ""
                    if ready_pattern.search(content):
                        break
                    if time.monotonic() >= deadline:
                        raise SimulatorError("等待 DS 指定日志标记超时，请检查 server.log")
                    time.sleep(0.2)
            elif index < len(instances) - 1:
                # 与 SDK 的调度间隔一致；间隔结束不代表服务端/客户端已经就绪。
                wait_processes(processes, 3 if values["isDsServer"] == "true" else 2)
        wait_processes(processes, 1)
        if hold:
            print(f"实例保持运行，记录：{manifest}", flush=True)
            for process in processes:
                process.wait()
    except BaseException:
        # 只清理由本次 Popen 持有的进程，绝不按名称或历史 PID 杀进程。
        for process in reversed(processes):
            if process.poll() is None:
                process.terminate()
        for process in processes:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        for record in records:
            record["state"] = "launch aborted"
        manifest.write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")
        raise


def parser():
    cli = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    cli.add_argument("--project", type=Path, default=Path.cwd(), help="Unity 项目或包含它的目录")
    cli.add_argument("--mode", choices=("single", "shared", "ds"), help="默认使用最近 SDK 模式或项目偏好")
    cli.add_argument("--players", nargs="+", help="客户端昵称，默认单机一个、多人两个")
    cli.add_argument("--scene", help="项目中的场景路径")
    cli.add_argument("--room", help="最终房间 ID；新网络填 0 创建房间")
    cli.add_argument("--network", choices=("auto", "legacy", "new"), default="auto")
    cli.add_argument("--data-store", choices=("on", "off"), help="默认沿用 SDK 设置")
    cli.add_argument("--pawn-actor-type", type=pawn_actor_type, metavar="{pet,avatar}",
                     help="玩家角色类型，Pet=0、Avatar=1；默认沿用 SDK 设置或项目偏好")
    cli.add_argument("--config", type=Path, help="可选 JSON 参数覆盖文件，不在输出中回显")
    cli.add_argument("--executable", help="覆盖 SDK 配置的调试器路径，也接受 .app")
    cli.add_argument("--instance-executable", action="append", default=[], metavar="ROLE=PATH",
                     help="为 server / client-N 指定本地调试器副本，分别定位桌面窗口")
    cli.add_argument("--editor-log", type=Path, action="append", help="额外的 SDK Editor 日志")
    cli.add_argument("--relation", default="模拟器合养关系", help="Pet 客户端共享关系名")
    cli.add_argument("--windowless", action="store_true", help="仅用于 DS 服务端窗口选项")
    cli.add_argument("--server-ready-pattern", help="等待服务端日志中的项目就绪标记（正则）")
    cli.add_argument("--timeout", type=float, default=60, help="等待 DS 标记的超时秒数")
    cli.add_argument("--dry-run", action="store_true", help="仅本地校验，不联网或启动")
    cli.add_argument("--hold", action="store_true", help="保持启动器运行，供受管终端会话验证")
    return cli


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        if sys.platform not in ("darwin", "win32"):
            raise SimulatorError("调试器仅支持 macOS 和 Windows")
        project = discover_project(args.project)
        prefs = editor_prefs()
        executable = executable_path(project, prefs, args.executable)
        instance_executables = {}
        for entry in args.instance_executable:
            role, separator, path = entry.partition("=")
            if not separator or not re.fullmatch(r"server|client-[1-9][0-9]*", role):
                raise SimulatorError("--instance-executable 格式应为 server=PATH 或 client-N=PATH")
            if role in instance_executables:
                raise SimulatorError("同一实例不能重复指定调试器")
            instance_executables[role] = executable_path(project, prefs, path)
        overrides = read_json(args.config) if args.config else {}
        if args.pawn_actor_type is not None:
            overrides["pawnActorType"] = args.pawn_actor_type
        unknown = set(overrides) - RUNTIME_KEYS - {"resourceUrl", "envMark"}
        if unknown:
            raise SimulatorError("配置包含未知参数，请使用手册中的参数名（不带前导 -）")
        if MANAGED_KEYS & overrides.keys():
            raise SimulatorError("实例身份、工作目录和日志参数由启动器管理，请使用对应命令行选项")
        values, api, config = load_settings(
            project, prefs, overrides, (args.editor_log or []) + default_logs())
        mode = args.mode
        if mode is None:
            if boolean(values.get("isSinglePlayer", prefs.get("HamletSimulatorIsSinglePlayer", False))):
                mode = "single"
            elif "isDsMode" in values:
                mode = "ds" if boolean(values["isDsMode"]) else "shared"
            else:
                preferences = Path(__file__).resolve().parents[2] / "hamlet-skill/hamlet-preferences.md"
                content = preferences.read_text(encoding="utf-8") if preferences.exists() else ""
                match = re.search(r"\*\*Network\*\*:\s*(\w+)", content)
                mode = {"SinglePlayer": "single", "SharedMode": "shared",
                        "DedicatedServer": "ds"}.get(match[1] if match else "")
                if not mode:
                    raise SimulatorError("无法确定项目网络模式，请指定 --mode")
        if args.scene:
            values["worldAddressableSceneName"] = args.scene
        if args.room is not None:
            values["roomName"] = args.room.strip()
        if args.data_store:
            values["dataStoreEnabled"] = text(args.data_store == "on")
        names = args.players or [f"玩家{i + 1}" for i in range(1 if mode == "single" else 2)]
        roles = {f"client-{i + 1}" for i in range(len(names))}
        if mode == "ds":
            roles.add("server")
        if set(instance_executables) - roles:
            raise SimulatorError("指定的调试器实例不在本次启动范围")
        pattern = re.compile(args.server_ready_pattern) if args.server_ready_pattern else None
        if not 0 < args.timeout < float("inf"):
            raise SimulatorError("--timeout 必须是有限正数")
        # 先验证全部本地前提，不能在失败的启动中创建房间。
        make_instances(values, mode, names, Path(tempfile.gettempdir()), args.relation, args.windowless)
        prepare_resources(project, executable, values, True)
        for instance_executable in set(instance_executables.values()):
            prepare_resources(project, instance_executable, values, True)
        if config.get("enableCSharp") and not values.get("worldScriptBundle"):
            raise SimulatorError("C# 项目缺少脚本包，请先用 SDK 构建并启动一次")
        send = lambda endpoint, body=None: sdk_request(values, api, endpoint, body)
        if args.network != "auto":
            values["isNewNetModule"] = text(args.network == "new")
        elif "isNewNetModule" not in overrides and not args.dry_run:
            remote = send("/resource/editor/get_config")
            module = remote.get("net_module", remote.get("NetModule", {}))
            if not isinstance(module, dict):
                raise SimulatorError("SDK 网络配置格式无效")
            values["isNewNetModule"] = text(boolean(
                module.get("pure_tcp", module.get("PureTcp", False))))
        new_net = boolean(values["isNewNetModule"])
        if boolean(values["dataStoreEnabled"]):
            world = values.get("worldId", "")
            if not world.isascii() or not world.isdecimal() or int(world) <= 0:
                raise SimulatorError("存储已开启，请在 SDK 选择已启用存储的测试世界")
        else:
            values["worldId"] = "1" if new_net else "0"
        # 新网络房间输入可由 EditorPrefs 恢复；旧网络不能再次拼接设备前缀。
        if new_net and not values.get("roomName"):
            values["roomName"] = text(prefs.get("HamletSimulatorRoomID", "0"))
        resolve_room(values, mode, send, dry_run=args.dry_run)
        if args.dry_run:
            print(f"本地校验通过：{project.name}，模式 {mode}，客户端 {len(names)} 个。")
            print("未联网、未构建、未启动；网络配置与房间有效性将在实际启动时确认。")
            return 0
        prepare_resources(project, executable, values, False)
        for instance_executable in set(instance_executables.values()):
            prepare_resources(project, instance_executable, values, False)
        run_dir = Path(tempfile.mkdtemp(prefix="hamlet-simulator-"))
        os.chmod(run_dir, 0o700)
        instances = make_instances(values, mode, names, run_dir, args.relation, args.windowless)
        launch(executable, project, instances, run_dir, pattern, args.timeout, args.hold,
               instance_executables)
        print(f"已启动，记录：{run_dir / 'session.json'}")
        print("场景、角色、输入及跨端同步仍需按调试手册验证。")
        return 0
    except (SimulatorError, re.error) as exc:
        print(f"错误：{exc}", file=sys.stderr)
        return 2
    except OSError:
        print("错误：本地文件或进程操作失败，请检查路径、权限及独立日志。", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        print("已取消启动。", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
