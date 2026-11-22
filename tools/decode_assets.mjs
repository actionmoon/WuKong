// Decode the reference's Meshopt buffers without changing its coordinates or animation data.
import fs from "node:fs";
import { MeshoptDecoder } from "../docs/reference/wukong/vendor/three/examples/jsm/libs/meshopt_decoder.module.js";

const [kind, source, destination] = process.argv.slice(2);
if (!["glb", "collision"].includes(kind) || !source || !destination) {
  throw new Error("Usage: node tools/decode_assets.mjs glb|collision INPUT OUTPUT");
}
await MeshoptDecoder.ready;
const input = fs.readFileSync(source);
if (kind === "collision") {
  if (input.readUInt32LE(0) !== 0x31434b57) throw new Error("Expected WKC1 collision data");
  const vertices = input.readUInt32LE(4), triangles = input.readUInt32LE(8);
  const vertexBytes = input.readUInt32LE(12), indexBytes = input.readUInt32LE(16);
  if (input.length !== 20 + vertexBytes + indexBytes) throw new Error("Invalid WKC1 length");
  const positions = Buffer.alloc(vertices * 12);
  const indices = Buffer.alloc(triangles * 12);
  MeshoptDecoder.decodeVertexBuffer(positions, vertices, 12, input.subarray(20, 20 + vertexBytes));
  MeshoptDecoder.decodeIndexBuffer(indices, triangles * 3, 4, input.subarray(20 + vertexBytes));
  const header = Buffer.alloc(8);
  header.writeUInt32LE(vertices, 0); header.writeUInt32LE(triangles, 4);
  fs.writeFileSync(destination, Buffer.concat([header, positions, indices]));
  console.log(JSON.stringify({ vertices, triangles, bytes: 8 + positions.length + indices.length }));
} else {
  if (input.readUInt32LE(0) !== 0x46546c67 || input.readUInt32LE(4) !== 2
      || input.readUInt32LE(8) !== input.length) throw new Error("Invalid GLB header");
  const jsonLength = input.readUInt32LE(12);
  if (input.readUInt32LE(16) !== 0x4e4f534a) throw new Error("Missing GLB JSON chunk");
  const doc = JSON.parse(input.subarray(20, 20 + jsonLength).toString());
  const binStart = 20 + jsonLength;
  if (input.readUInt32LE(binStart + 4) !== 0x004e4942) throw new Error("Missing GLB BIN chunk");
  const binary = input.subarray(binStart + 8, binStart + 8 + input.readUInt32LE(binStart));
  const chunks = []; let offset = 0, decodedViews = 0;
  for (const view of doc.bufferViews || []) {
    const compression = view.extensions?.KHR_meshopt_compression || view.extensions?.EXT_meshopt_compression;
    let data;
    if (compression) {
      if (compression.buffer !== 0) throw new Error("External compressed buffers are unsupported");
      data = Buffer.alloc(compression.count * compression.byteStride);
      const start = compression.byteOffset || 0;
      MeshoptDecoder.decodeGltfBuffer(data, compression.count, compression.byteStride,
        binary.subarray(start, start + compression.byteLength), compression.mode, compression.filter);
      if (data.length !== view.byteLength) throw new Error("Decoded bufferView length mismatch");
      decodedViews++;
      delete view.extensions.KHR_meshopt_compression;
      delete view.extensions.EXT_meshopt_compression;
      if (!Object.keys(view.extensions).length) delete view.extensions;
    } else {
      if (view.buffer !== 0) throw new Error("Unexpected uncompressed external buffer");
      data = binary.subarray(view.byteOffset || 0, (view.byteOffset || 0) + view.byteLength);
      if (data.length !== view.byteLength) throw new Error("Truncated bufferView");
    }
    const padding = (4 - offset % 4) % 4;
    if (padding) { chunks.push(Buffer.alloc(padding)); offset += padding; }
    view.buffer = 0; view.byteOffset = offset;
    chunks.push(data); offset += data.length;
  }
  doc.buffers = [{ byteLength: offset }];
  for (const field of ["extensionsUsed", "extensionsRequired"]) {
    if (doc[field]) doc[field] = doc[field].filter(e => !["KHR_meshopt_compression", "EXT_meshopt_compression"].includes(e));
  }
  const rawJson = Buffer.from(JSON.stringify(doc));
  const json = Buffer.concat([rawJson, Buffer.alloc((4 - rawJson.length % 4) % 4, 0x20)]);
  const bin = Buffer.concat([...chunks, Buffer.alloc((4 - offset % 4) % 4)]);
  const header = Buffer.alloc(20);
  header.writeUInt32LE(0x46546c67, 0); header.writeUInt32LE(2, 4);
  header.writeUInt32LE(28 + json.length + bin.length, 8);
  header.writeUInt32LE(json.length, 12); header.writeUInt32LE(0x4e4f534a, 16);
  const binHeader = Buffer.alloc(8);
  binHeader.writeUInt32LE(bin.length, 0); binHeader.writeUInt32LE(0x004e4942, 4);
  fs.writeFileSync(destination, Buffer.concat([header, json, binHeader, bin]));
  console.log(JSON.stringify({ decodedViews, animations: doc.animations?.length || 0, bytes: 28 + json.length + bin.length }));
}
