"""Convert a reference GLB into a Unity-importable GLB, preserving its source data."""

import argparse
import io
import json
from pathlib import Path
import struct
import subprocess
import tempfile

from PIL import Image


def prepare(source, destination):
    tools = Path(__file__).resolve().parent
    with tempfile.TemporaryDirectory(prefix="wukong-model-") as scratch:
        decoded = Path(scratch) / "decoded.glb"
        subprocess.run(
            ["node", str(tools / "decode_assets.mjs"), "glb", str(source), str(decoded)],
            check=True,
        )
        raw = decoded.read_bytes()
    json_length = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20 : 20 + json_length])
    bin_start = 20 + json_length
    bin_length = struct.unpack_from("<I", raw, bin_start)[0]
    binary = bytearray(raw[bin_start + 8 : bin_start + 8 + bin_length])
    converted = 0
    for image in doc.get("images", []):
        if image.get("mimeType") != "image/webp":
            continue
        view = doc["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        webp = binary[start : start + view["byteLength"]]
        with Image.open(io.BytesIO(webp)) as bitmap:
            output = io.BytesIO()
            bitmap.save(output, format="PNG")
        png = output.getvalue()
        binary.extend(b"\0" * ((-len(binary)) % 4))
        image["bufferView"] = len(doc["bufferViews"])
        image["mimeType"] = "image/png"
        doc["bufferViews"].append(
            {"buffer": 0, "byteOffset": len(binary), "byteLength": len(png)}
        )
        binary.extend(png)
        converted += 1
    for texture in doc.get("textures", []):
        extension = texture.get("extensions", {}).pop("EXT_texture_webp", None)
        if extension is not None:
            texture["source"] = extension["source"]
        if "extensions" in texture and not texture["extensions"]:
            del texture["extensions"]
    for field in ("extensionsUsed", "extensionsRequired"):
        if field in doc:
            doc[field] = [name for name in doc[field] if name != "EXT_texture_webp"]
    doc["buffers"] = [{"byteLength": len(binary)}]
    binary.extend(b"\0" * ((-len(binary)) % 4))
    metadata = json.dumps(doc, separators=(",", ":")).encode()
    metadata += b" " * ((-len(metadata)) % 4)
    result = (
        struct.pack("<5I", 0x46546C67, 2, 28 + len(metadata) + len(binary), len(metadata), 0x4E4F534A)
        + metadata
        + struct.pack("<2I", len(binary), 0x004E4942)
        + binary
    )
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(result)
    print(json.dumps({
        "source": str(source), "destination": str(destination),
        "converted_textures": converted, "animations": len(doc.get("animations", [])),
        "extensions_required": doc.get("extensionsRequired", []), "bytes": len(result),
    }))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    options = parser.parse_args()
    prepare(options.source.resolve(), options.destination.resolve())
