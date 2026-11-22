"""Extract one real instanced arena mesh to verify the import pipeline."""

import copy
import json
from pathlib import Path
import struct
import tempfile

from prepare_model import prepare


ROOT = Path(__file__).resolve().parent.parent


def main():
    source = ROOT / "docs/reference/wukong/assets/arena/arena.glb"
    raw = source.read_bytes()
    size = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + size])
    binary = raw[28 + size:]
    node = copy.deepcopy(next(n for n in doc["nodes"]
                              if "EXT_mesh_gpu_instancing" in n.get("extensions", {})))
    mesh = copy.deepcopy(doc["meshes"][node["mesh"]])
    accessor_ids = set(node["extensions"]["EXT_mesh_gpu_instancing"]["attributes"].values())
    material_ids = set()
    for primitive in mesh["primitives"]:
        accessor_ids.update(primitive["attributes"].values())
        if "indices" in primitive:
            accessor_ids.add(primitive["indices"])
        if "material" in primitive:
            material_ids.add(primitive["material"])
    texture_ids = set()

    def scan(value):
        if isinstance(value, dict):
            for key, child in value.items():
                if key.endswith("Texture") and isinstance(child, dict) and "index" in child:
                    texture_ids.add(child["index"])
                scan(child)
        elif isinstance(value, list):
            for child in value:
                scan(child)

    materials = [copy.deepcopy(doc["materials"][i]) for i in sorted(material_ids)]
    scan(materials)
    textures = [copy.deepcopy(doc["textures"][i]) for i in sorted(texture_ids)]
    image_ids = set()
    for texture in textures:
        if "source" in texture:
            image_ids.add(texture["source"])
        for extension in texture.get("extensions", {}).values():
            if "source" in extension:
                image_ids.add(extension["source"])
    accessors = [copy.deepcopy(doc["accessors"][i]) for i in sorted(accessor_ids)]
    images = [copy.deepcopy(doc["images"][i]) for i in sorted(image_ids)]
    view_ids = {a["bufferView"] for a in accessors} | {i["bufferView"] for i in images}
    mappings = {key: {old: new for new, old in enumerate(sorted(ids))}
                for key, ids in [("accessor", accessor_ids), ("material", material_ids),
                                 ("texture", texture_ids), ("image", image_ids), ("view", view_ids)]}
    for primitive in mesh["primitives"]:
        primitive["attributes"] = {k: mappings["accessor"][v] for k, v in primitive["attributes"].items()}
        if "indices" in primitive:
            primitive["indices"] = mappings["accessor"][primitive["indices"]]
        if "material" in primitive:
            primitive["material"] = mappings["material"][primitive["material"]]
    node["mesh"] = 0
    node.pop("children", None)
    attrs = node["extensions"]["EXT_mesh_gpu_instancing"]["attributes"]
    node["extensions"]["EXT_mesh_gpu_instancing"]["attributes"] = {k: mappings["accessor"][v] for k, v in attrs.items()}
    for entry in accessors + images:
        entry["bufferView"] = mappings["view"][entry["bufferView"]]

    def remap_textures(value):
        if isinstance(value, dict):
            for key, child in value.items():
                if key.endswith("Texture") and isinstance(child, dict) and "index" in child:
                    child["index"] = mappings["texture"][child["index"]]
                remap_textures(child)
        elif isinstance(value, list):
            for child in value:
                remap_textures(child)

    remap_textures(materials)
    for texture in textures:
        if "source" in texture:
            texture["source"] = mappings["image"][texture["source"]]
        for extension in texture.get("extensions", {}).values():
            if "source" in extension:
                extension["source"] = mappings["image"][extension["source"]]
    sample = {"asset": doc["asset"], "scene": 0, "scenes": [{"nodes": [0]}],
              "nodes": [node], "meshes": [mesh], "accessors": accessors,
              "materials": materials, "textures": textures, "images": images,
              "samplers": doc.get("samplers", []),
              "bufferViews": [doc["bufferViews"][i] for i in sorted(view_ids)],
              "buffers": doc["buffers"], "extensionsUsed": doc.get("extensionsUsed", []),
              "extensionsRequired": doc.get("extensionsRequired", [])}
    metadata = json.dumps(sample, separators=(",", ":")).encode()
    metadata += b" " * (-len(metadata) % 4)
    result = (struct.pack("<5I", 0x46546C67, 2, 28 + len(metadata) + len(binary),
                          len(metadata), 0x4E4F534A) + metadata
              + struct.pack("<2I", len(binary), 0x004E4942) + binary)
    with tempfile.TemporaryDirectory(prefix="wukong-instance-") as scratch:
        selected = Path(scratch) / "selected.glb"
        selected.write_bytes(result)
        prepare(selected, ROOT / "unity/Assets/WuKong/Art/ArenaInstancingSample.glb")
    print("Preserved one original arena mesh and its 42 instance transforms.")


if __name__ == "__main__":
    main()
