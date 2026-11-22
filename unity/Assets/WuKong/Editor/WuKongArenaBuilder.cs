using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/// <summary>Repeatable step-3 scene assembly; reference coordinates are already converted by glTFast.</summary>
public static class WuKongArenaBuilder
{
    const string Root = "Assets/WuKong";
    [Serializable] public class MaterialList { public MaterialInfo[] materials; }
    [Serializable] public class MaterialInfo
    {
        public string name, packed, alphaMode;
        public float[] baseColor, scale, offset;
        public float normalScale, metallic, alphaCutoff;
        public bool doubleSided;
    }

    static void Remove(string name)
    {
        var go = GameObject.Find(name);
        if (go != null) UnityEngine.Object.DestroyImmediate(go);
    }

    public static string Assemble()
    {
        if (EditorSceneManager.GetActiveScene().path != Root + "/Scenes/WuKongTiger.unity")
            throw new InvalidOperationException("Open WuKongTiger before assembling.");
        var arenaAsset = AssetDatabase.LoadAssetAtPath<GameObject>(Root + "/Art/Arena.glb");
        var tigerAsset = AssetDatabase.LoadAssetAtPath<GameObject>(Root + "/Art/Tiger.glb");
        if (arenaAsset == null || tigerAsset == null) throw new InvalidOperationException("Import Arena and Tiger first.");
        foreach (var folder in new[] {"Materials/Arena", "Art/CollisionMeshes"})
        {
            var parts = folder.Split('/');
            var parent = Root;
            foreach (var part in parts)
            {
                if (!AssetDatabase.IsValidFolder(parent + "/" + part)) AssetDatabase.CreateFolder(parent, part);
                parent += "/" + part;
            }
        }
        foreach (var name in new[] {"WoHuSi", "ArenaCollision", "ArenaCameraOccluders", "ArenaMarkers",
            "ArenaHUD", "ArenaPresentation", "TigerBaseline", "WukongShowcase", "ReferenceCollisionSample",
            "SampleHUD", "SampleSpawnA", "SampleSpawnB", "Plane"})
            Remove(name);
        var arena = (GameObject)PrefabUtility.InstantiatePrefab(arenaAsset);
        PrefabUtility.UnpackPrefabInstance(arena, PrefabUnpackMode.Completely, InteractionMode.AutomatedAction);
        arena.name = "WoHuSi";
        ConvertMaterials(arena);
        var count = BuildCollision();
        var occluders = BuildCameraOccluders(arena);
        BuildMarkers();
        BuildEnvironment();
        BuildHUD();

        var tiger = (GameObject)PrefabUtility.InstantiatePrefab(tigerAsset);
        PrefabUtility.UnpackPrefabInstance(tiger, PrefabUnpackMode.Completely, InteractionMode.AutomatedAction);
        tiger.name = "TigerBaseline";
        tiger.transform.position = new Vector3(1.226f, -6.343f, 48.157f);
        // Source +X becomes model -X; add the model-to-Avatar +90 degree correction.
        tiger.transform.rotation = Quaternion.Euler(0, -1.68932f * Mathf.Rad2Deg, 0);
        var animation = tiger.GetComponent<Animation>();
        if (animation != null)
        {
            var clip = AssetDatabase.LoadAllAssetsAtPath(Root + "/Art/Tiger.glb").OfType<AnimationClip>()
                .FirstOrDefault(c => c.name == "AS_HFM_Hu_Stone_Bstd_01");
            if (clip != null) { animation.clip = clip; animation.wrapMode = WrapMode.Loop; animation.playAutomatically = true; clip.SampleAnimation(tiger, 0); }
        }
        var presentation = new GameObject("ArenaPresentation");
        AddLua(presentation, Root + "/Lua/Client/ArenaPresentation.lua");
        var camera = GameObject.Find("Main Camera").GetComponent<Camera>();
        camera.transform.position = new Vector3(-0.116f, 1.16f, -4.52f);
        camera.transform.LookAt(new Vector3(0, 0.5f, 0));
        camera.fieldOfView = 55;
        camera.farClipPlane = 930;
        AssetDatabase.SaveAssets();
        EditorSceneManager.SaveScene(EditorSceneManager.GetActiveScene());
        return "Arena: " + arena.GetComponentsInChildren<Renderer>().Length + " renderers, " + count
            + " collision chunks, " + occluders + " camera proxies; markers, environment, Tiger and HUD saved.";
    }

    static void ConvertMaterials(GameObject arena)
    {
        var entries = JsonUtility.FromJson<MaterialList>(File.ReadAllText(Root + "/Art/ArenaPacked/materials.json")).materials;
        var byName = entries.ToDictionary(e => e.name);
        var converted = new Dictionary<Material, Material>();
        foreach (var renderer in arena.GetComponentsInChildren<Renderer>())
        {
            renderer.sharedMaterials = renderer.sharedMaterials.Select(source =>
            {
                Material cached;
                if (converted.TryGetValue(source, out cached)) return cached;
                MaterialInfo info;
                if (!byName.TryGetValue(source.name, out info)) throw new InvalidOperationException("Material mapping missing: " + source.name);
                // SDK's opaque shader has no alpha test or two-sided pass. Preserve glTF's supported
                // URP material for those surfaces so leaves and blood overlays keep their real silhouette.
                if (info.alphaMode != "OPAQUE" || info.doubleSided)
                {
                    var preserved = new Material(source) { name = source.name, enableInstancing = true };
                    preserved = Save(preserved, Root + "/Materials/Arena/" + info.packed.Replace(".png", "_Surface.mat"));
                    converted[source] = preserved;
                    return preserved;
                }
                var material = new Material(Shader.Find("Douyin/World/ENV/World_Lit")) { name = source.name, enableInstancing = true };
                material.SetTexture("_BasecoloTex_AMeta", source.GetTexture("baseColorTexture"));
                material.SetTextureScale("_BasecoloTex_AMeta", source.GetTextureScale("baseColorTexture"));
                material.SetTextureOffset("_BasecoloTex_AMeta", source.GetTextureOffset("baseColorTexture"));
                material.SetColor("_BaseColor", source.GetColor("baseColorFactor"));
                var path = Root + "/Art/ArenaPacked/" + info.packed;
                var importer = AssetImporter.GetAtPath(path) as TextureImporter;
                if (importer != null && (importer.sRGBTexture || !importer.mipmapEnabled))
                {
                    importer.sRGBTexture = false;
                    importer.mipmapEnabled = true;
                    importer.wrapMode = TextureWrapMode.Repeat;
                    importer.SaveAndReimport();
                }
                material.SetTexture("_RGNormalBSmoothAAO", AssetDatabase.LoadAssetAtPath<Texture2D>(path));
                material.SetTextureScale("_RGNormalBSmoothAAO", source.GetTextureScale("normalTexture"));
                material.SetTextureOffset("_RGNormalBSmoothAAO", source.GetTextureOffset("normalTexture"));
                material.SetFloat("_NormalScale", info.normalScale);
                material.SetFloat("_Metallic", info.metallic);
                material.SetFloat("_Smoothness", 1);
                material.SetTexture("_Emission", source.GetTexture("emissiveTexture"));
                material.SetColor("_EmissionColor", source.GetColor("emissiveFactor"));
                material = Save(material, Root + "/Materials/Arena/" + info.packed.Replace(".png", ".mat"));
                converted[source] = material;
                return material;
            }).ToArray();
            renderer.receiveShadows = true;
            var center = new Vector3(-0.274f, -6.419f, 38.657f);
            renderer.shadowCastingMode = Vector3.Distance(renderer.bounds.ClosestPoint(center), center) < 56
                ? ShadowCastingMode.On : ShadowCastingMode.Off;
        }
    }

    static T Save<T>(T asset, string path) where T : UnityEngine.Object
    {
        var existing = AssetDatabase.LoadAssetAtPath<UnityEngine.Object>(path);
        if (existing == null) AssetDatabase.CreateAsset(asset, path);
        else { EditorUtility.CopySerialized(asset, existing); UnityEngine.Object.DestroyImmediate(asset); }
        return AssetDatabase.LoadAssetAtPath<T>(path);
    }

    static int BuildCollision()
    {
        var root = new GameObject("ArenaCollision");
        var files = Directory.GetFiles(Root + "/Art/Collision", "*.bytes").OrderBy(p => p).ToArray();
        foreach (var file in files)
        {
            using (var reader = new BinaryReader(File.OpenRead(file)))
            {
                var nv = reader.ReadInt32(); var nt = reader.ReadInt32();
                var vertices = new Vector3[nv];
                for (var i = 0; i < nv; i++) vertices[i] = new Vector3(reader.ReadSingle(), reader.ReadSingle(), reader.ReadSingle());
                // The source BVH tests DoubleSide. Its floor proxies have mixed winding.
                // Give PhysX both faces, including capsule support, instead of relying on
                // a global ray-only backface query switch.
                var indices = new int[nt * 6];
                for (var i = 0; i < nt * 3; i++) indices[i] = reader.ReadInt32();
                for (var i = 0; i < nt * 3; i += 3)
                {
                    indices[nt * 3 + i] = indices[i];
                    indices[nt * 3 + i + 1] = indices[i + 2];
                    indices[nt * 3 + i + 2] = indices[i + 1];
                }
                var name = Path.GetFileNameWithoutExtension(file);
                var mesh = new Mesh {name = name, indexFormat = IndexFormat.UInt32};
                mesh.vertices = vertices; mesh.triangles = indices; mesh.RecalculateBounds();
                var path = Root + "/Art/CollisionMeshes/" + name + ".asset";
                Save(mesh, path);
                var go = new GameObject(name);
                go.transform.SetParent(root.transform, false);
                go.layer = 0;
                var collider = go.AddComponent<MeshCollider>();
                collider.cookingOptions = MeshColliderCookingOptions.CookForFasterSimulation | MeshColliderCookingOptions.UseFastMidphase;
                collider.sharedMesh = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            }
        }
        return files.Length;
    }

    public static string RebuildCollision()
    {
        Remove("ArenaCollision");
        var count = BuildCollision();
        Physics.queriesHitBackfaces = false;
        Physics.SyncTransforms();
        AssetDatabase.SaveAssets();
        EditorSceneManager.SaveScene(EditorSceneManager.GetActiveScene());
        return "Rebuilt " + count + " double-sided collision chunks.";
    }

    static int BuildCameraOccluders(GameObject arena)
    {
        var root = new GameObject("ArenaCameraOccluders");
        var center = new Vector3(-0.274f, -6.419f, 38.657f);
        var count = 0;
        foreach (var r in arena.GetComponentsInChildren<Renderer>())
        {
            var b = r.bounds;
            var dims = new[] {b.size.x, b.size.y, b.size.z};
            // Conservative boxes for thin, large walls/columns near the route. Trigger geometry
            // is queried only by the camera; it never changes the player's walkable collision.
            if (Vector3.Distance(b.ClosestPoint(center), center) > 45 || dims.Min() > 2
                || dims.Max() < 3 || b.size.y < 1.8f
                || r.sharedMaterials.Any(m => m.renderQueue > 2450)) continue;
            var go = new GameObject("CameraWall_" + count++);
            go.transform.SetParent(root.transform, false); go.transform.position = b.center; go.layer = 9;
            var box = go.AddComponent<BoxCollider>(); box.size = b.size; box.isTrigger = true;
        }
        return count;
    }

    static void BuildMarkers()
    {
        var root = new GameObject("ArenaMarkers");
        var spawn = new GameObject("PlayerSpawn").transform;
        spawn.SetParent(root.transform, false); spawn.position = new Vector3(0, -1.197f, 0);
        spawn.rotation = Quaternion.Euler(0, -(-1.59626f + Mathf.PI / 2) * Mathf.Rad2Deg, 0);
        var world = GameObject.Find("DouyinWorldRoot").GetComponent<DouyinWorldRoot>();
        world.Spawns = new[] {spawn}; world.GuestSpawn = spawn; world.RespawnHeightY = -25;
        var area = new GameObject("FightArea").transform;
        area.SetParent(root.transform, false); area.position = new Vector3(-0.274f, -6.419f, 38.657f);
        area.localScale = new Vector3(16.26f, 1, 16.26f);
        var trigger = new GameObject("ForceFightBox");
        trigger.transform.SetParent(root.transform, false);
        trigger.transform.position = new Vector3(1.039f, -0.398f, 33.654f);
        var box = trigger.AddComponent<BoxCollider>(); box.isTrigger = true;
        box.size = new Vector3(62.524f, 10.876f, 11.28f);
        AddLua(trigger, Root + "/Lua/Shared/ArenaTrigger.lua");
    }

    static void BuildEnvironment()
    {
        var light = GameObject.Find("Directional Light").GetComponent<Light>();
        light.transform.rotation = Quaternion.LookRotation(new Vector3(-0.77028f, -0.63631f, -0.0421f));
        light.color = Color.white; light.intensity = 3; light.shadows = LightShadows.Soft;
        RenderSettings.ambientMode = AmbientMode.Trilight;
        RenderSettings.ambientSkyColor = new Color(0.7451f, 0.851f, 1);
        RenderSettings.ambientEquatorColor = new Color(0.3608f, 0.3255f, 0.2863f);
        RenderSettings.ambientGroundColor = RenderSettings.ambientEquatorColor * 0.35f;
        RenderSettings.ambientIntensity = 0.6f;
        RenderSettings.fog = true; RenderSettings.fogMode = FogMode.ExponentialSquared;
        RenderSettings.fogDensity = 0.005813f; RenderSettings.fogColor = new Color(0.3608f, 0.3255f, 0.2863f);
        var cubemap = new Cubemap(32, TextureFormat.RGBAHalf, false);
        foreach (CubemapFace face in Enum.GetValues(typeof(CubemapFace)))
        {
            if ((int)face < 0 || (int)face > 5) continue;
            var pixels = new Color[32 * 32];
            for (var y = 0; y < 32; y++) for (var x = 0; x < 32; x++)
            {
                var u = 2f * (x + 0.5f) / 32 - 1; var v = 2f * (y + 0.5f) / 32 - 1;
                Vector3 d;
                switch (face) {
                    case CubemapFace.PositiveX: d = new Vector3(1, -v, -u); break;
                    case CubemapFace.NegativeX: d = new Vector3(-1, -v, u); break;
                    case CubemapFace.PositiveY: d = new Vector3(u, 1, v); break;
                    case CubemapFace.NegativeY: d = new Vector3(u, -1, -v); break;
                    case CubemapFace.PositiveZ: d = new Vector3(u, -v, 1); break;
                    default: d = new Vector3(-u, -v, -1); break;
                }
                var h = d.normalized.y;
                pixels[y * 32 + x] = Color.Lerp(RenderSettings.ambientEquatorColor.linear,
                    h >= 0 ? RenderSettings.ambientSkyColor : RenderSettings.ambientGroundColor.linear,
                    Mathf.Pow(Mathf.Abs(h), h >= 0 ? 0.6f : 0.5f));
            }
            cubemap.SetPixels(pixels, face);
        }
        cubemap.Apply(); Save(cubemap, Root + "/Materials/ArenaSky.asset");
        var sky = new Material(Shader.Find("Douyin/World/ENV/World_Skybox"));
        sky.SetTexture("_Tex", AssetDatabase.LoadAssetAtPath<Cubemap>(Root + "/Materials/ArenaSky.asset"));
        sky.SetColor("_Tint", Color.gray); Save(sky, Root + "/Materials/ArenaSky.mat");
        RenderSettings.skybox = AssetDatabase.LoadAssetAtPath<Material>(Root + "/Materials/ArenaSky.mat");
        var volume = GameObject.Find("Global Volume").GetComponent<Volume>();
        var profile = AssetDatabase.LoadAssetAtPath<VolumeProfile>(Root + "/Materials/ArenaPost.asset");
        if (profile == null) profile = Save(new VolumeProfile(), Root + "/Materials/ArenaPost.asset");
        Tonemapping tone;
        if (!profile.TryGet(out tone))
        {
            tone = profile.Add<Tonemapping>();
            AssetDatabase.AddObjectToAsset(tone, profile);
        }
        tone.mode.Override(TonemappingMode.ACES);
        EditorUtility.SetDirty(tone); EditorUtility.SetDirty(profile);
        volume.sharedProfile = profile;
        DynamicGI.UpdateEnvironment();
    }

    static RectTransform Rect(string name, Transform parent, Vector2 anchor, Vector2 pos, Vector2 size)
    {
        var go = new GameObject(name, typeof(RectTransform));
        var r = go.GetComponent<RectTransform>(); r.SetParent(parent, false);
        r.anchorMin = r.anchorMax = anchor; r.pivot = anchor; r.anchoredPosition = pos; r.sizeDelta = size;
        return r;
    }
    static void Label(string name, Transform parent, Vector2 anchor, Vector2 pos, Vector2 size, string value, int fontSize)
    {
        var text = Rect(name, parent, anchor, pos, size).gameObject.AddComponent<Text>();
        text.font = Resources.GetBuiltinResource<Font>("Arial.ttf"); text.fontSize = fontSize;
        text.color = new Color(0.9f, 0.85f, 0.73f); text.text = value; text.raycastTarget = false;
    }
    static void Bar(string name, Transform parent, Vector2 anchor, Vector2 pos, Vector2 size, Color color)
    {
        var rect = Rect(name, parent, anchor, pos, size);
        var back = rect.gameObject.AddComponent<Image>(); back.color = new Color(0.04f, 0.025f, 0.02f, 0.8f); back.raycastTarget = false;
        var fill = Rect(name + "Fill", rect, Vector2.zero, new Vector2(2, 2), size - new Vector2(4, 4));
        var image = fill.gameObject.AddComponent<Image>(); image.color = color; image.raycastTarget = false;
    }
    static void BuildHUD()
    {
        var go = new GameObject("ArenaHUD", typeof(Canvas), typeof(CanvasScaler));
        go.GetComponent<Canvas>().renderMode = RenderMode.ScreenSpaceOverlay; go.GetComponent<Canvas>().sortingOrder = 20;
        var scaler = go.GetComponent<CanvasScaler>(); scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(1280, 720); scaler.matchWidthOrHeight = 0.5f;
        Label("TempleTitle", go.transform, new Vector2(0, 1), new Vector2(28, -24), new Vector2(300, 40), "卧虎寺", 24);
        Label("BossName", go.transform, new Vector2(0.5f, 1), new Vector2(0, -24), new Vector2(180, 28), "虎先锋", 22);
        Bar("BossHP", go.transform, new Vector2(0.5f, 1), new Vector2(0, -62), new Vector2(500, 12), new Color(0.65f, 0.24f, 0.16f));
        var left = new Vector2(0, 0);
        Label("PlayerResources", go.transform, left, new Vector2(32, 132), new Vector2(330, 30), "390 / 390      葫芦 6", 18);
        Bar("PlayerHP", go.transform, left, new Vector2(32, 115), new Vector2(270, 15), new Color(0.78f, 0.69f, 0.54f));
        Bar("PlayerMP", go.transform, left, new Vector2(32, 96), new Vector2(245, 10), new Color(0.35f, 0.58f, 0.66f));
        Bar("PlayerStamina", go.transform, left, new Vector2(32, 80), new Vector2(270, 10), new Color(0.67f, 0.64f, 0.27f));
        Label("StanceBaseline", go.transform, left, new Vector2(32, 47), new Vector2(290, 24), "劈棍    ○ ○ ○", 18);
        Label("SkillBaseline", go.transform, new Vector2(1, 0), new Vector2(-32, 96), new Vector2(470, 30), "1 定身    2 聚形    4 赤潮    F 广谋", 18);
        Label("CameraHint", go.transform, new Vector2(1, 0), new Vector2(-32, 54), new Vector2(470, 28), "Q / 中键 锁定    拖动视角", 18);
        Label("ArenaStatus", go.transform, new Vector2(0.5f, 0), new Vector2(0, 18), new Vector2(400, 26), "前往血池", 16);
        Label("LockMarker", go.transform, new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(24, 24), "◇", 22);
        GameObject.Find("LockMarker").SetActive(false);
    }
    static void AddLua(GameObject go, string path)
    {
        var component = go.AddComponent<DouyinScript>();
        component.ScriptAsset = AssetDatabase.LoadAssetAtPath<DouyinScriptAsset>(path);
        if (component.ScriptAsset == null) throw new InvalidOperationException("Missing Lua: " + path);
        EditorUtility.SetDirty(component);
    }
}
