using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/// <summary>Restore source surfaces and lighting without rebuilding gameplay or HUD.</summary>
public static class WuKongRenderBuilder
{
    const string Root = "Assets/WuKong";
    [Serializable] public class TextureInfo { public string file, kind; }
    [Serializable] public class Surface
    {
        public int index;
        public string name, @base, normal, metallic, occlusion, emission, alphaMode;
        public float[] baseColor, emissionColor, scale, offset;
        public float metallicFactor, smoothness, normalScale, occlusionStrength, alphaCutoff;
        public bool doubleSided;
    }
    [Serializable] public class Manifest
    {
        public string asset, sourceSha256;
        public TextureInfo[] textures;
        public Surface[] materials;
    }
    static readonly Dictionary<string, string> Models = new Dictionary<string, string> {
        {"WoHuSi", "Arena"}, {"WukongVisualTemplate", "Wukong"}, {"TigerBaseline", "Tiger"},
        {"GuangzhiVisualTemplate", "Guangzhi"}, {"GuangmouVisualTemplate", "Guangmou"},
        {"SpiritSnakeVisualTemplate", "SpiritSnake"}, {"StoneDecoyTemplate", "StoneDecoy"}
    };

    [MenuItem("Tools/WuKong/Restore Rendering")]
    public static void MenuApply() { Debug.Log(Apply()); }

    public static string Apply()
    {
        if (EditorApplication.isPlaying || EditorSceneManager.GetActiveScene().path != Root + "/Scenes/WuKongTiger.unity")
            throw new InvalidOperationException("Open the saved WuKongTiger scene outside Play mode.");
        var renderers = 0;
        foreach (var pair in Models)
        {
            var go = Resources.FindObjectsOfTypeAll<GameObject>()
                .Single(g => g.scene.IsValid() && g.name == pair.Key);
            renderers += RestoreModel(go, pair.Value);
        }
        RestoreEnvironment();
        ConfigurePipeline("Assets/Settings/URP-HighFidelity.asset", 2048, 50, 2, 4);
        ConfigurePipeline("Assets/Settings/URP-Balanced.asset", 1024, 35, 2, 2);
        AssetDatabase.SaveAssets();
        EditorSceneManager.SaveScene(EditorSceneManager.GetActiveScene());
        return "Restored source surfaces on " + renderers + " renderers; ACES, sky reflection and desktop/mobile shadows saved.";
    }

    public static int RestoreModel(GameObject go, string asset)
    {
        var folder = Root + "/Art/RenderMaterials/" + asset;
        var manifest = JsonUtility.FromJson<Manifest>(File.ReadAllText(folder + "/materials.json"));
        foreach (var texture in manifest.textures)
        {
            var importer = AssetImporter.GetAtPath(folder + "/" + texture.file) as TextureImporter;
            if (importer == null) throw new InvalidOperationException("Import exported texture: " + texture.file);
            var normal = texture.kind == "normal";
            var type = normal ? TextureImporterType.NormalMap : TextureImporterType.Default;
            var srgb = texture.kind == "base" || texture.kind == "emission";
            if (importer.textureType == type && importer.sRGBTexture == srgb &&
                importer.mipmapEnabled && importer.wrapMode == TextureWrapMode.Repeat && importer.anisoLevel == 4 &&
                !importer.alphaIsTransparency) continue;
            importer.textureType = type;
            importer.sRGBTexture = srgb;
            importer.mipmapEnabled = true;
            importer.wrapMode = TextureWrapMode.Repeat;
            importer.anisoLevel = 4;
            importer.alphaSource = TextureImporterAlphaSource.FromInput;
            importer.alphaIsTransparency = false; // glTF RGB remains meaningful even where alpha is zero.
            importer.SaveAndReimport();
        }
        var materials = manifest.materials.ToDictionary(s => s.name, s => CreateSurface(folder, s));
        var source = AssetDatabase.LoadAssetAtPath<GameObject>(Root + "/Art/" + asset + ".glb");
        var sourceRenderers = source.GetComponentsInChildren<Renderer>(true)
            .ToDictionary(r => AnimationUtility.CalculateTransformPath(r.transform, source.transform));
        var count = 0;
        foreach (var renderer in go.GetComponentsInChildren<Renderer>(true))
        {
            var path = AnimationUtility.CalculateTransformPath(renderer.transform, go.transform);
            Renderer original;
            if (!sourceRenderers.TryGetValue(path, out original))
                throw new InvalidOperationException(asset + ": missing source renderer " + path);
            renderer.sharedMaterials = original.sharedMaterials.Select(m => materials[m.name]).ToArray();
            renderer.receiveShadows = true;
            // Preserve the arena's existing distant-caster budget.
            if (asset != "Arena") renderer.shadowCastingMode = ShadowCastingMode.On;
            EditorUtility.SetDirty(renderer);
            count++;
        }
        return count;
    }

    static Material CreateSurface(string folder, Surface s)
    {
        var path = folder + "/Surface_" + s.index.ToString("D3") + ".mat";
        var material = AssetDatabase.LoadAssetAtPath<Material>(path);
        var shader = Shader.Find("WuKong/Source Lit");
        if (shader == null) throw new InvalidOperationException("Source Lit shader unavailable.");
        if (material == null) { material = new Material(shader); AssetDatabase.CreateAsset(material, path); }
        material.shader = shader;
        material.name = s.name;
        material.shaderKeywords = new string[0];
        material.enableInstancing = true;
        material.SetFloat("_WorkflowMode", 1);
        // ShaderLab Color properties are converted from sRGB when uploaded in Linear mode.
        material.SetColor("_BaseColor", new Color(s.baseColor[0], s.baseColor[1], s.baseColor[2], s.baseColor[3]).gamma);
        SetMap(material, folder, "_BaseMap", s.@base);
        SetMap(material, folder, "_BumpMap", s.normal);
        SetMap(material, folder, "_MetallicGlossMap", s.metallic);
        SetMap(material, folder, "_OcclusionMap", s.occlusion);
        SetMap(material, folder, "_EmissionMap", s.emission);
        material.SetTextureScale("_BaseMap", new Vector2(s.scale[0], s.scale[1]));
        material.SetTextureOffset("_BaseMap", new Vector2(s.offset[0], s.offset[1]));
        material.SetFloat("_BumpScale", s.normalScale);
        material.SetFloat("_Metallic", s.metallicFactor);
        material.SetFloat("_Smoothness", string.IsNullOrEmpty(s.metallic) ? s.smoothness : 1);
        material.SetFloat("_SmoothnessTextureChannel", 0);
        material.SetFloat("_OcclusionStrength", s.occlusionStrength);
        material.SetColor("_EmissionColor", new Color(s.emissionColor[0], s.emissionColor[1], s.emissionColor[2]).gamma);
        var blend = s.alphaMode == "BLEND";
        var cutout = s.alphaMode == "MASK";
        material.SetFloat("_Surface", blend ? 1 : 0);
        material.SetFloat("_Blend", 0);
        material.SetFloat("_AlphaClip", cutout ? 1 : 0);
        material.SetFloat("_Cutoff", s.alphaCutoff);
        material.SetFloat("_Cull", s.doubleSided ? 0 : 2);
        material.SetFloat("_SrcBlend", blend ? 5 : 1);
        material.SetFloat("_DstBlend", blend ? 10 : 0);
        material.SetFloat("_ZWrite", blend ? 0 : 1);
        material.SetFloat("_ReceiveShadows", 1);
        material.SetOverrideTag("RenderType", blend ? "Transparent" : cutout ? "TransparentCutout" : "Opaque");
        material.renderQueue = blend ? 3000 : cutout ? 2450 : 2000;
        material.SetShaderPassEnabled("ShadowCaster", !blend);
        Keyword(material, "_NORMALMAP", !string.IsNullOrEmpty(s.normal));
        Keyword(material, "_METALLICSPECGLOSSMAP", !string.IsNullOrEmpty(s.metallic));
        Keyword(material, "_OCCLUSIONMAP", !string.IsNullOrEmpty(s.occlusion));
        Keyword(material, "_EMISSION", !string.IsNullOrEmpty(s.emission) || s.emissionColor.Any(x => x > 0));
        Keyword(material, "_ALPHATEST_ON", cutout);
        Keyword(material, "_SURFACE_TYPE_TRANSPARENT", blend);
        EditorUtility.SetDirty(material);
        return material;
    }

    static void SetMap(Material material, string folder, string property, string file)
    {
        material.SetTexture(property, string.IsNullOrEmpty(file) ? null : AssetDatabase.LoadAssetAtPath<Texture2D>(folder + "/" + file));
    }
    static void Keyword(Material material, string keyword, bool enabled)
    {
        if (enabled) material.EnableKeyword(keyword); else material.DisableKeyword(keyword);
    }
    public static string CaptureViews()
    {
        var camera = GameObject.Find("Main Camera").GetComponent<Camera>();
        var position = camera.transform.position;
        var rotation = camera.transform.rotation;
        var target = camera.targetTexture;
        var active = RenderTexture.active;
        var fov = camera.fieldOfView;
        var texture = new RenderTexture(1280, 720, 24, RenderTextureFormat.ARGB32);
        var pixels = new Texture2D(1280, 720, TextureFormat.RGB24, false);
        var positions = new[] {new Vector3(0,1.16f,-4.52f), new Vector3(0,-4,37.5f),
            new Vector3(1.7f,1.1f,-2.5f), new Vector3(4.5f,-1.8f,40.5f)};
        var rotations = new[] {new Vector3(10.31324f,0,0), new Vector3(10.31324f,0,0),
            new Vector3(5,-32,0), new Vector3(10,-27,0)};
        var names = new[] {"spawn", "pool", "wukong", "tiger"};
        try
        {
            camera.targetTexture = texture;
            camera.fieldOfView = 55;
            for (var i = 0; i < names.Length; i++)
            {
                camera.transform.SetPositionAndRotation(positions[i], Quaternion.Euler(rotations[i]));
                camera.Render();
                RenderTexture.active = texture;
                pixels.ReadPixels(new Rect(0, 0, 1280, 720), 0, 0);
                pixels.Apply();
                File.WriteAllBytes(Root + "/Evidence/render-final-" + names[i] + ".png", pixels.EncodeToPNG());
            }
        }
        finally
        {
            camera.targetTexture = target;
            camera.fieldOfView = fov;
            camera.transform.SetPositionAndRotation(position, rotation);
            RenderTexture.active = active;
            UnityEngine.Object.DestroyImmediate(pixels);
            UnityEngine.Object.DestroyImmediate(texture);
        }
        return "Four 1280x720 views captured using the actual camera, FOV 55 and its URP post processing.";
    }
    static void ConfigurePipeline(string path, int resolution, float distance, int cascades, int msaa)
    {
        var pipeline = AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(path);
        pipeline.shadowDistance = distance;
        pipeline.shadowCascadeCount = cascades;
        pipeline.shadowDepthBias = .35f;
        pipeline.shadowNormalBias = .25f;
        pipeline.msaaSampleCount = msaa;
        pipeline.supportsHDR = true;
        var serialized = new SerializedObject(pipeline);
        serialized.FindProperty("m_MainLightShadowmapResolution").intValue = resolution;
        serialized.FindProperty("m_Cascade2Split").floatValue = .3f;
        serialized.FindProperty("m_ColorGradingMode").intValue = 1;
        serialized.FindProperty("m_ColorGradingLutSize").intValue = 32;
        serialized.ApplyModifiedPropertiesWithoutUndo();
        EditorUtility.SetDirty(pipeline);
    }

    public static void RestoreEnvironment()
    {
        var light = GameObject.Find("Directional Light").GetComponent<Light>();
        light.transform.rotation = Quaternion.LookRotation(new Vector3(-.77028f, -.63631f, -.0421f));
        light.color = Color.white;
        // URP's direct diffuse omits Three.js' 1/pi Lambert factor.
        light.intensity = 10 / Mathf.PI;
        light.shadows = LightShadows.Soft;
        light.shadowBias = .035f;
        light.shadowNormalBias = .03f;
        RenderSettings.ambientMode = AmbientMode.Trilight;
        RenderSettings.ambientIntensity = 1;
        RenderSettings.reflectionIntensity = .6f;
        RenderSettings.fog = true;
        RenderSettings.fogMode = FogMode.ExponentialSquared;
        RenderSettings.fogDensity = .005813f;
        var top = new Color(.7451f, .851f, 1); // source explicitly linear
        var mid = new Color(.3608f, .3255f, .2863f).linear; // source explicitly sRGB
        var bottom = mid * .35f;
        // Match source hemisphere light plus diffuse environment. Keep this explicit:
        // the SDK must not depend on Editor-only asynchronous sky SH generation.
        // RenderSettings' ambient colour inputs are converted from sRGB by Unity.
        RenderSettings.ambientSkyColor = (top * .95f).gamma;
        RenderSettings.ambientEquatorColor = (Color.Lerp(mid, top, .4f) * .95f).gamma;
        RenderSettings.ambientGroundColor = (bottom * .95f).gamma;
        RenderSettings.fogColor = new Color(.3608f, .3255f, .2863f);
        const int size = 128;
        var cubePath = Root + "/Materials/RenderSky.asset";
        var cube = AssetDatabase.LoadAssetAtPath<Cubemap>(cubePath);
        if (cube == null) { cube = new Cubemap(size, TextureFormat.RGBAHalf, true); AssetDatabase.CreateAsset(cube, cubePath); }
        foreach (CubemapFace face in Enum.GetValues(typeof(CubemapFace)))
        {
            if ((int)face < 0 || (int)face > 5) continue;
            var pixels = new Color[size * size];
            for (var y = 0; y < size; y++) for (var x = 0; x < size; x++)
            {
                var u = 2f * (x + .5f) / size - 1;
                var v = 2f * (y + .5f) / size - 1;
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
                pixels[y * size + x] = Color.Lerp(mid, h >= 0 ? top : bottom, Mathf.Pow(Mathf.Abs(h), h >= 0 ? .6f : .5f));
            }
            cube.SetPixels(pixels, face);
        }
        cube.Apply(true, false);
        EditorUtility.SetDirty(cube);
        // Unity's sky reflection generation convolves this HDR gradient; the visible source
        // background is a solid sky colour, so keep the game's camera on SolidColor.
        var skyPath = Root + "/Materials/RenderSky.mat";
        var sky = AssetDatabase.LoadAssetAtPath<Material>(skyPath);
        if (sky == null) { sky = new Material(Shader.Find("Skybox/Cubemap")); AssetDatabase.CreateAsset(sky, skyPath); }
        sky.SetTexture("_Tex", cube);
        sky.SetColor("_Tint", Color.gray);
        sky.SetFloat("_Exposure", 1);
        EditorUtility.SetDirty(sky);
        RenderSettings.skybox = sky;
        RenderSettings.defaultReflectionMode = DefaultReflectionMode.Skybox;
        RenderSettings.defaultReflectionResolution = size;
        var camera = GameObject.Find("Main Camera").GetComponent<Camera>();
        camera.clearFlags = CameraClearFlags.SolidColor;
        camera.backgroundColor = top.gamma;
        camera.allowHDR = true;
        camera.allowMSAA = true;
        var data = camera.GetUniversalAdditionalCameraData();
        data.renderPostProcessing = true;
        data.volumeLayerMask = 1;
        var profile = AssetDatabase.LoadAssetAtPath<VolumeProfile>(Root + "/Materials/ArenaPost.asset");
        if (profile == null) { profile = ScriptableObject.CreateInstance<VolumeProfile>(); AssetDatabase.CreateAsset(profile, Root + "/Materials/ArenaPost.asset"); }
        profile.components.RemoveAll(c => c == null);
        Tonemapping tone;
        if (!profile.TryGet(out tone)) { tone = profile.Add<Tonemapping>(); tone.name = "Tonemapping"; }
        if (!AssetDatabase.Contains(tone)) AssetDatabase.AddObjectToAsset(tone, profile);
        tone.active = true;
        tone.mode.Override(TonemappingMode.ACES);
        EditorUtility.SetDirty(tone);
        EditorUtility.SetDirty(profile);
        var volume = GameObject.Find("Global Volume").GetComponent<Volume>();
        volume.sharedProfile = profile;
        volume.isGlobal = true;
        volume.weight = 1;
        EditorUtility.SetDirty(volume);
        EditorUtility.SetDirty(camera);
        EditorUtility.SetDirty(data);
        EditorUtility.SetDirty(light);
        DynamicGI.UpdateEnvironment();
    }
}
