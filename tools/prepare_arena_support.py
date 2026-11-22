"""Build spatial collision chunks and SDK packed material maps from converted GLB data."""

import io
import json
from pathlib import Path
import struct

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "unity/Assets/WuKong/Art"


def collision():
    raw = (ROOT / "unity/Temp/wukong-step3-collision.bin").read_bytes()
    nv, nt = struct.unpack_from("<2I", raw)
    vertices = np.frombuffer(raw, "<f4", nv * 3, 8).reshape(-1, 3)
    triangles = np.frombuffer(raw, "<u4", nt * 3, 8 + nv * 12).reshape(-1, 3)
    centers = vertices[triangles].mean(axis=1)
    cells = np.floor(centers[:, [0, 2]] / 16).astype(int)
    folder = ART / "Collision"
    folder.mkdir(exist_ok=True)
    chunks = []
    for x, z in np.unique(cells, axis=0):
        chosen = triangles[(cells[:, 0] == x) & (cells[:, 1] == z)]
        used, indices = np.unique(chosen, return_inverse=True)
        points = vertices[used].copy()
        points[:, 0] *= -1
        indices = indices.reshape(-1, 3)[:, [0, 2, 1]].astype("<u4")
        name = f"Collision_{x}_{z}.bytes"
        content = (struct.pack("<2I", len(points), len(indices))
                   + points.astype("<f4").tobytes() + indices.tobytes())
        path = folder / name
        if not path.exists() or path.read_bytes() != content:
            path.write_bytes(content)
        chunks.append({"file": name, "vertices": len(points), "triangles": len(indices)})
    return {"sourceVertices": nv, "triangles": nt, "chunks": chunks}


def materials():
    raw = (ART / "Arena.glb").read_bytes()
    size = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + size])
    binary = memoryview(raw)[28 + size:]
    folder = ART / "ArenaPacked"
    folder.mkdir(exist_ok=True)
    cache = {}

    def image(texture):
        if texture is None:
            return None
        index = texture["index"]
        if index not in cache:
            source = doc["textures"][index]["source"]
            view = doc["bufferViews"][doc["images"][source]["bufferView"]]
            start = view.get("byteOffset", 0)
            cache[index] = Image.open(io.BytesIO(binary[start:start + view["byteLength"]])).convert("RGBA")
        return cache[index]

    result = []
    for i, material in enumerate(doc["materials"]):
        pbr = material.get("pbrMetallicRoughness", {})
        normal = image(material.get("normalTexture"))
        mr = image(pbr.get("metallicRoughnessTexture"))
        ao = image(material.get("occlusionTexture"))
        width, height = max([im.size for im in (normal, mr, ao) if im is not None] or [(1, 1)])
        packed = np.empty((height, width, 4), dtype=np.uint8)
        packed[:, :, :2] = 128
        roughness = pbr.get("roughnessFactor", 1)
        packed[:, :, 2] = round(max(0, min(1, 1 - roughness)) * 255)
        packed[:, :, 3] = 255
        if normal is not None:
            packed[:, :, :2] = np.asarray(normal.resize((width, height)))[:, :, :2]
        if mr is not None:
            values = np.asarray(mr.resize((width, height)))[:, :, 1].astype(float)
            packed[:, :, 2] = np.clip(255 - values * roughness, 0, 255).astype(np.uint8)
        if ao is not None:
            packed[:, :, 3] = np.asarray(ao.resize((width, height)))[:, :, 0]
        name = f"Packed_{i:03}.png"
        output = io.BytesIO()
        Image.fromarray(packed).save(output, format="PNG")
        path = folder / name
        if not path.exists() or path.read_bytes() != output.getvalue():
            path.write_bytes(output.getvalue())
        transform = pbr.get("baseColorTexture", {}).get("extensions", {}).get("KHR_texture_transform", {})
        result.append({
            "name": material["name"], "packed": name,
            "baseColor": pbr.get("baseColorFactor", [1, 1, 1, 1]),
            "scale": transform.get("scale", [1, 1]), "offset": transform.get("offset", [0, 0]),
            "normalScale": material.get("normalTexture", {}).get("scale", 1),
            "metallic": pbr.get("metallicFactor", 1),
            "alphaMode": material.get("alphaMode", "OPAQUE"),
            "alphaCutoff": material.get("alphaCutoff", 0.5),
            "doubleSided": material.get("doubleSided", False),
        })
    # A Unity JsonUtility-friendly schema; this is the material conversion contract.
    (folder / "materials.json").write_text(json.dumps({"materials": result}, indent=2))
    return {"materials": len(result), "alphaModes": sorted(set(m["alphaMode"] for m in result))}


if __name__ == "__main__":
    result = {"collision": collision(), "materials": materials()}
    output = ROOT / "docs/reference/step3-conversion.json"
    output.write_text(json.dumps(result, indent=2))
    print(json.dumps({"collisionChunks": len(result["collision"]["chunks"]),
                      "triangles": result["collision"]["triangles"], **result["materials"]}))
