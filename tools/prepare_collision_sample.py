"""Crop decoded reference collision around the player spawn, with Unity handedness."""

from pathlib import Path
import struct
import numpy as np


def prepare(source, destination):
    raw = Path(source).read_bytes()
    vertex_count, triangle_count = struct.unpack_from("<2I", raw)
    vertices = np.frombuffer(raw, "<f4", vertex_count * 3, 8).reshape(-1, 3)
    triangles = np.frombuffer(raw, "<u4", triangle_count * 3, 8 + vertex_count * 12).reshape(-1, 3)
    centers = vertices[triangles].mean(axis=1)
    selected = triangles[
        (np.abs(centers[:, 0]) < 4)
        & (np.abs(centers[:, 2]) < 4)
        & (centers[:, 1] > -3)
        & (centers[:, 1] < 1)
    ]
    if not len(selected):
        raise ValueError("No collision triangles near the reference spawn")
    used, indices = np.unique(selected, return_inverse=True)
    points = vertices[used].copy()
    points[:, 0] *= -1
    indices = indices.reshape(-1, 3)[:, [0, 2, 1]].astype("<u4")
    output = Path(destination)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(struct.pack("<2I", len(points), len(indices)) + points.astype("<f4").tobytes() + indices.tobytes())
    print({"vertices": len(points), "triangles": len(indices), "bounds": [points.min(axis=0).tolist(), points.max(axis=0).tolist()], "destination": str(output)})


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source")
    parser.add_argument("destination")
    options = parser.parse_args()
    prepare(options.source, options.destination)
