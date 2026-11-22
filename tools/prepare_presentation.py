"""Convert the reference audio pack and presentation contracts for Unity."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import wave

from PIL import Image
import imageio_ffmpeg

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "docs/reference/wukong/assets"
DEST = ROOT / "unity/Assets/WuKong"


def short(value):
    if isinstance(value, dict):
        value = value.get("AssetPathName", value.get("ObjectPath", ""))
    return str(value or "").split("/")[-1].split(".")[0]


def main():
    manifest = json.loads((SOURCE / "audio/audio.json").read_text())
    pack = (SOURCE / "audio" / manifest["pack"]).read_bytes()
    folder = DEST / "Audio"
    folder.mkdir(exist_ok=True)
    clips, indices, checks = [], {}, []
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    with tempfile.TemporaryDirectory(prefix="wukong-audio-") as tmp:
        logpath = Path(tmp) / "conversion.log"
        with logpath.open("w") as log:
            for name, event in manifest["events"].items():
                event["clips"] = []
                for offset, size in event["v"]:
                    if offset not in indices:
                        data = pack[offset:offset + size]
                        assert len(data) == size and data.startswith(b"OggS"), (name, offset)
                        output = folder / f"sfx_{offset}.wav"
                        if not output.exists():
                            source = Path(tmp) / "source.ogg"
                            source.write_bytes(data)
                            result = subprocess.run(
                                [ffmpeg, "-y", "-i", str(source), "-ar", "32000",
                                 "-ac", "1", "-c:a", "pcm_s16le", str(output)],
                                stdout=log, stderr=log,
                            )
                            if result.returncode:
                                raise RuntimeError(logpath.read_text())
                        with wave.open(str(output)) as audio:
                            duration = audio.getnframes() / audio.getframerate()
                            assert duration > 0
                        indices[offset] = len(clips)
                        clips.append(output.name)
                        checks.append({"offset": offset, "bytes": size, "duration": duration,
                                       "sha256": hashlib.sha256(data).hexdigest()})
                    event["clips"].append(indices[offset])
            for piece in manifest["bgm"]["pieces"].values():
                output = folder / piece["file"].replace(".ogg", ".wav")
                if not output.exists():
                    result = subprocess.run(
                        [ffmpeg, "-y", "-i", str(SOURCE / "audio" / piece["file"]),
                         "-c:a", "pcm_s16le", str(output)], stdout=log, stderr=log)
                    if result.returncode:
                        raise RuntimeError(logpath.read_text())
                piece["clip"] = len(clips)
                clips.append(output.name)
    vfx = json.loads((SOURCE / "vfx/vfx.json").read_text())
    textures = dict(vfx["textures"])
    textures.update(json.loads((SOURCE / "data/spells.json").read_text())["textures"])
    for source in (SOURCE / "vfx").glob("*.webp"):
        textures.setdefault(source.stem, {"file": source.name})
    texture_folder = DEST / "VFX/Textures"
    texture_folder.mkdir(parents=True, exist_ok=True)
    for name, spec in textures.items():
        image = Image.open(SOURCE / "vfx" / spec["file"]).convert("RGBA")
        image.save(texture_folder / (name + ".png"))
    cues = {}
    for path in sorted(SOURCE.rglob("*.anims.json")):
        document = json.loads(path.read_text())
        for name, clip in document.get("clips", {}).items():
            out = []
            for i, notify in enumerate(clip.get("notifies", [])):
                props = notify.get("props") or {}
                cls = notify.get("class", notify.get("name", ""))
                event, bone = None, props.get("AttachPointName", props.get("SocketName"))
                if cls == "AnimNotify_GSFootStep":
                    event = manifest["footsteps"].get(document["id"], manifest["footsteps"]["wukong"])
                    bone = "foot_r" if str(props.get("FootStepType", "")).endswith("RightFoot") else "foot_l"
                elif cls == "BAN_GSPlayMappedSoundFX":
                    key = str(props.get("EquipPosition", "")).split("::")[-1] + ":" + str(props.get("ActionTypeID"))
                    event = manifest["mapped"].get(key)
                elif props.get("AkEvent"):
                    event = short(props["AkEvent"])
                if event:
                    out.append({"type": "audio", "time": notify.get("start", 0),
                                "name": event, "bone": bone, "i": i})
            for i, event in enumerate(clip.get("events", [])):
                if event["type"] in {"vfx", "cameraShake"}:
                    row = dict(event)
                    row["name"] = short(event.get("name", event.get("shake")))
                    row["time"] = event.get("time", event.get("start", 0))
                    row["i"] = "v" + str(i)
                    out.append(row)
            cues[name] = {"duration": clip.get("duration", 0), "loop": clip.get("loop", False),
                          "cues": sorted(out, key=lambda c: c["time"])}
    # Unity substitutes sprite particles for Niagara mesh/refractive emitters.
    extra_layers = {
        "ding": {"texture": "spells_ding", "blend": "additive"},
        "magicSmoke": {"texture": "spells_smoke8x8", "blend": "normal"},
        "fire": {"texture": "T_ember_Fire0001", "blend": "additive"},
        "poison": {"texture": "spells_flare04", "blend": "additive"},
    }
    vfx["layers"].update(extra_layers)
    for name, layer, color, count, size in [
        ("immobilize", "ding", [2, 1.4, .35], 1, 1.7),
        ("cloud", "magicSmoke", [.8, .85, .9], 35, 1.2),
        ("transform", "fire", [2, .5, .1], 65, .8),
        ("snake", "poison", [.25, 1.3, .3], 20, .55),
        ("poisonBullet", "poison", [.25, 1.3, .3], 1, .45),
    ]:
        vfx["systems"][name] = {"kind": "fx", "emitters": [
            {"layer": layer, "count": count, "life": [1, 1.5], "size": [size, size * .3],
             "speed": [0, .5], "radius": .15, "color": color, "frames": 64 if layer == "fire" else 1}]}
    recipes = {
        "goldSparks": "spark", "goldGlow": "flare", "hitFlash": "flare",
        "bloodSplash": "liquid", "groundRing": "gring", "debris": "debris",
        "dust": "dust8", "glow": "glow", "impactSplash": "liquid",
        "tornadoSmoke": "smoke", "tornadoDebris": "debris", "bladeWisp": "wisp",
    }
    for name, system in vfx["systems"].items():
        emitters = system.get("emitters")
        if not isinstance(emitters, list):
            # Some exported systems also retain unparsed Niagara metadata.
            emitters = []
        emitters = [e for e in emitters if isinstance(e, dict) and e.get("layer") in vfx["layers"]]
        if not emitters and system.get("layers"):
            emitters = [{"layer": recipes[layer], "count": 20 if layer != "groundRing" else 1,
                         "life": [.3, .8], "size": [.2, .6], "speed": [1, 3],
                         "color": [1, .7, .3] if "gold" in layer or layer == "hitFlash" else [.6, .18, .12]}
                        for layer in system["layers"] if layer in recipes]
        system["emitters"] = emitters
    data = {"audio": manifest, "audioFiles": clips, "clips": cues, "vfx": vfx,
            "textures": textures}
    target = DEST / "VFX/PresentationData.json"
    target.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")))
    evidence = {"events": len(manifest["events"]), "variants": len(checks), "clips": len(cues),
                "audioFiles": len(clips), "textures": len(textures), "systems": len(vfx["systems"]),
                "audioChecks": checks,
                "adaptations": ["Niagara mesh emitters become bounded Unity sprite particles.",
                                "Ribbon refraction is omitted; original trail textures are used.",
                                "Custom skill bursts use the reference spell/transform textures."]}
    (ROOT / "docs/reference/step7-asset-evidence.json").write_text(json.dumps(evidence, indent=2))
    print({k: evidence[k] for k in ("events", "variants", "clips", "textures", "systems")})


if __name__ == "__main__":
    main()
