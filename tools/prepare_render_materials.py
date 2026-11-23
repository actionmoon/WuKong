"""Export source GLB surfaces to URP Lit maps without changing geometry or animation."""

import hashlib
import io
import json
from pathlib import Path
import struct

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "unity/Assets/WuKong/Art"
OUTPUT = ART / "RenderMaterials"
ASSETS = ("Arena", "Wukong", "Tiger", "Guangzhi", "Guangmou", "SpiritSnake", "StoneDecoy")


def write_changed(path, content):
    if not path.exists() or path.read_bytes() != content:
        path.write_bytes(content)


def export(asset):
    raw = (ART / f"{asset}.glb").read_bytes()
    length = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    binary = memoryview(raw)[28 + length:]
    folder = OUTPUT / asset
    folder.mkdir(parents=True, exist_ok=True)
    images = {}
    textures = {}

    def bitmap(info):
        index = info["index"]
        source = doc["textures"][index]["source"]
        if source not in images:
            entry = doc["images"][source]
            view = doc["bufferViews"][entry["bufferView"]]
            start = view.get("byteOffset", 0)
            images[source] = Image.open(io.BytesIO(binary[start:start + view["byteLength"]])).convert("RGBA")
        return images[source]

    def save_image(image, kind):
        stream = io.BytesIO()
        image.save(stream, format="PNG")
        content = stream.getvalue()
        name = kind + "_" + hashlib.sha256(content).hexdigest()[:20] + ".png"
        write_changed(folder / name, content)
        textures[name] = {"file": name, "kind": kind}
        return name

    result = []
    for index, material in enumerate(doc.get("materials", [])):
        pbr = material.get("pbrMetallicRoughness", {})
        infos = {
            "base": pbr.get("baseColorTexture"),
            "normal": material.get("normalTexture"),
            "metallic": pbr.get("metallicRoughnessTexture"),
            "occlusion": material.get("occlusionTexture"),
            "emission": material.get("emissiveTexture"),
        }
        # URP Lit shares one UV transform across these maps. Reject unsupported contracts
        # instead of silently losing an independently transformed map.
        transforms = []
        for info in infos.values():
            if info:
                transform = info.get("extensions", {}).get("KHR_texture_transform", {})
                value = (tuple(transform.get("scale", [1, 1])), tuple(transform.get("offset", [0, 0])),
                         transform.get("rotation", 0), transform.get("texCoord", info.get("texCoord", 0)))
                transforms.append(value)
        if len(set(transforms)) > 1 or any(t[2] != 0 or t[3] != 0 for t in transforms):
            raise ValueError(f"{asset}/{material['name']}: URP Lit cannot represent the source UVs")
        scale, offset = transforms[0][:2] if transforms else ([1, 1], [0, 0])
        # glTFast flips vertex V into Unity's bottom-origin UV convention.
        # Move the transformed flip axis exactly as MaterialGenerator does.
        unity_offset = [offset[0], 1 - offset[1] - scale[1]]
        paths = {}
        for kind, info in infos.items():
            if info is None:
                paths[kind] = ""
                continue
            image = bitmap(info)
            if kind == "metallic":
                data = np.asarray(image, dtype=np.float32)
                packed = np.full(data.shape, 255, dtype=np.uint8)
                # glTF: B metalness, G roughness; URP: R metalness, A smoothness.
                packed[:, :, 0] = np.rint(data[:, :, 2] * pbr.get("metallicFactor", 1)).clip(0, 255)
                packed[:, :, 3] = np.rint(255 - data[:, :, 1] * pbr.get("roughnessFactor", 1)).clip(0, 255)
                image = Image.fromarray(packed)
            elif kind == "occlusion":
                data = np.asarray(image)
                # URP samples G whereas glTF samples R.
                image = Image.fromarray(np.repeat(data[:, :, :1], 4, axis=2))
            paths[kind] = save_image(image, kind)
        result.append({
            "index": index, "name": material["name"], **paths,
            "baseColor": pbr.get("baseColorFactor", [1, 1, 1, 1]),
            "emissionColor": material.get("emissiveFactor", [0, 0, 0]),
            "metallicFactor": pbr.get("metallicFactor", 1),
            "smoothness": max(0, min(1, 1 - pbr.get("roughnessFactor", 1))),
            "normalScale": material.get("normalTexture", {}).get("scale", 1),
            "occlusionStrength": material.get("occlusionTexture", {}).get("strength", 1),
            "alphaMode": material.get("alphaMode", "OPAQUE"),
            "alphaCutoff": material.get("alphaCutoff", 0.5),
            "doubleSided": material.get("doubleSided", False),
            "scale": scale, "offset": unity_offset,
        })
    manifest = {"asset": asset, "sourceSha256": hashlib.sha256(raw).hexdigest(),
                "textures": list(textures.values()), "materials": result}
    write_changed(folder / "materials.json", (json.dumps(manifest, indent=2) + "\n").encode())
    return {"asset": asset, "materials": len(result), "textures": len(textures)}


if __name__ == "__main__":
    print(json.dumps([export(asset) for asset in ASSETS], indent=2))
