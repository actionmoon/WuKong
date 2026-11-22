using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.UI;

/// <summary>Editor-only assembly of the step-2 import and networking sample.</summary>
public static class WuKongSampleBuilder
{
    const string Root = "Assets/WuKong";
    const string ScenePath = Root + "/Scenes/WuKongTiger.unity";

    public static string Assemble()
    {
        if (EditorSceneManager.GetActiveScene().path != ScenePath)
            throw new InvalidOperationException("Open the clone scene before assembling its sample.");
        foreach (var folder in new[] { "Prefabs", "Materials", "Evidence" })
            if (!AssetDatabase.IsValidFolder(Root + "/" + folder))
                AssetDatabase.CreateFolder(Root, folder);

        var model = GameObject.Find("WukongImportSample");
        if (model == null) throw new InvalidOperationException("Missing imported model sample.");
        PrefabUtility.UnpackPrefabInstance(model, PrefabUnpackMode.Completely, InteractionMode.AutomatedAction);
        var converted = new Dictionary<Material, Material>();
        foreach (var renderer in model.GetComponentsInChildren<Renderer>())
        {
            renderer.sharedMaterials = renderer.sharedMaterials.Select(source =>
            {
                if (converted.ContainsKey(source)) return converted[source];
                var material = new Material(Shader.Find("Douyin/World/ENV/World_Lit"));
                material.name = source.name;
                var texture = source.HasProperty("baseColorTexture") ? source.GetTexture("baseColorTexture") : source.mainTexture;
                material.SetTexture("_BasecoloTex_AMeta", texture);
                material.SetColor("_BaseColor", source.HasProperty("baseColorFactor") ? source.GetColor("baseColorFactor") : Color.white);
                // Packed map: R/G tangent normal, B smoothness, A ambient occlusion.
                var packed = new Texture2D(1, 1, TextureFormat.RGBA32, false, true);
                packed.SetPixel(0, 0, new Color(0.5f, 0.5f, 0.35f, 1));
                packed.Apply();
                AssetDatabase.CreateAsset(packed, Root + "/Materials/" + source.name + "_NeutralPacked.asset");
                material.SetTexture("_RGNormalBSmoothAAO", packed);
                material.SetFloat("_Metallic", 0);
                material.SetFloat("_Smoothness", 1);
                material.SetFloat("_CullMode", 0);
                AssetDatabase.CreateAsset(material, Root + "/Materials/" + source.name + ".mat");
                converted[source] = material;
                return material;
            }).ToArray();
        }
        model.name = "WukongVisualTemplate";
        var animation = model.GetComponent<Animation>();
        animation.clip = AssetDatabase.LoadAllAssetsAtPath(Root + "/Art/Wukong.glb")
            .OfType<AnimationClip>().Single(c => c.name == "AS_Wukong_idle_stand_1");
        animation.wrapMode = WrapMode.Loop;
        animation.playAutomatically = true;
        animation.clip.SampleAnimation(model, 0);
        PrefabUtility.SaveAsPrefabAsset(model, Root + "/Prefabs/WukongVisual.prefab");
        var showcase = UnityEngine.Object.Instantiate(model);
        showcase.name = "WukongShowcase";
        showcase.transform.position = new Vector3(0, 0, 2);

        var shared = new GameObject("SampleState");
        var state = AddLua(shared, Root + "/Lua/Shared/SampleState.lua");
        state.ParaLuaBindingData = new DouyinLuaDataVar[] {
            new DouyinLuaDataNetInt { varName = "revision", Data = 0 },
            new DouyinLuaDataNetInt { varName = "contextCount", Data = 0 }
        };
        var visualDriver = new GameObject("AvatarVisualSample");
        AddLua(visualDriver, Root + "/Lua/Client/AvatarVisualSample.lua");
        var serverRoot = GameObject.Find("DouyinServerRoot");
        var serverLoader = serverRoot.GetComponent<DouyinServerScriptLoader>();
        if (serverLoader == null) serverLoader = serverRoot.AddComponent<DouyinServerScriptLoader>();
        serverLoader.CustomScripts = AssetDatabase.LoadAssetAtPath<UnityEngine.Object>(Root + "/Lua/Server/Modules");
        serverLoader.CustomScriptsPath = Root + "/Lua/Server/Modules";
        AddLua(serverRoot, Root + "/Lua/Server/ServerBoot.lua");
        var world = GameObject.Find("DouyinWorldRoot").GetComponent<DouyinWorldRoot>();
        var loader = world.GetComponent<DouyinScriptLoader>();
        loader.CustomScripts = AssetDatabase.LoadAssetAtPath<UnityEngine.Object>(Root + "/Lua/Shared/Modules");
        loader.CustomScriptsPath = Root + "/Lua/Shared/Modules";
        var spawn1 = new GameObject("SampleSpawnA").transform;
        spawn1.position = new Vector3(-1.5f, 0.1f, -2);
        var spawn2 = new GameObject("SampleSpawnB").transform;
        spawn2.position = new Vector3(1.5f, 0.1f, -2);
        world.Spawns = new[] { spawn1, spawn2 };
        world.GuestSpawn = spawn1;
        world.RespawnHeightY = -8;

        BuildCollisionSample();
        BuildStatus();
        var camera = GameObject.Find("Main Camera").GetComponent<Camera>();
        camera.transform.position = new Vector3(7, 5, -9);
        camera.transform.LookAt(new Vector3(2, 1, 1));
        camera.farClipPlane = 100;
        AssetDatabase.SaveAssets();
        EditorSceneManager.SaveScene(EditorSceneManager.GetActiveScene());
        return "Assembled model, SDK materials, Lua loaders, DS boot, state probe, collision sample, and two Avatar spawns.";
    }

    static DouyinScript AddLua(GameObject go, string path)
    {
        var component = go.AddComponent<DouyinScript>();
        component.ScriptAsset = AssetDatabase.LoadAssetAtPath<DouyinScriptAsset>(path);
        if (component.ScriptAsset == null) throw new InvalidOperationException("Lua asset missing: " + path);
        EditorUtility.SetDirty(component);
        return component;
    }

    static void BuildCollisionSample()
    {
        using (var reader = new BinaryReader(File.OpenRead(Root + "/Art/CollisionSample.bytes")))
        {
            var vertexCount = reader.ReadInt32();
            var triangleCount = reader.ReadInt32();
            var vertices = new Vector3[vertexCount];
            for (var i = 0; i < vertexCount; i++)
                vertices[i] = new Vector3(reader.ReadSingle(), reader.ReadSingle(), reader.ReadSingle());
            var indices = new int[triangleCount * 3];
            for (var i = 0; i < indices.Length; i++) indices[i] = reader.ReadInt32();
            var mesh = new Mesh { name = "ReferenceSpawnCollision", indexFormat = UnityEngine.Rendering.IndexFormat.UInt32 };
            mesh.vertices = vertices;
            mesh.triangles = indices;
            mesh.RecalculateNormals();
            mesh.RecalculateBounds();
            AssetDatabase.CreateAsset(mesh, Root + "/Art/CollisionSample.asset");
            var go = new GameObject("ReferenceCollisionSample");
            go.transform.position = new Vector3(7, 1.237f, 0);
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            var material = new Material(Shader.Find("Douyin/World/ENV/World_Lit"));
            material.SetColor("_BaseColor", new Color(0.55f, 0.45f, 0.3f, 1));
            material.SetFloat("_Metallic", 0);
            AssetDatabase.CreateAsset(material, Root + "/Materials/CollisionSample.mat");
            go.AddComponent<MeshRenderer>().sharedMaterial = material;
            go.AddComponent<MeshCollider>().sharedMesh = mesh;
        }
    }

    static void BuildStatus()
    {
        var go = new GameObject("SampleHUD", typeof(Canvas), typeof(CanvasScaler));
        go.GetComponent<Canvas>().renderMode = RenderMode.ScreenSpaceOverlay;
        go.GetComponent<Canvas>().sortingOrder = 100;
        var scaler = go.GetComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(1280, 720);
        var label = new GameObject("SampleStatus", typeof(RectTransform), typeof(Text));
        label.transform.SetParent(go.transform, false);
        var rect = label.GetComponent<RectTransform>();
        rect.anchorMin = rect.anchorMax = new Vector2(0, 1);
        rect.pivot = new Vector2(0, 1);
        rect.anchoredPosition = new Vector2(24, -24);
        rect.sizeDelta = new Vector2(950, 150);
        var text = label.GetComponent<Text>();
        text.font = Resources.GetBuiltinResource<Font>("Arial.ttf");
        text.fontSize = 24;
        text.color = Color.white;
        text.text = "悟空 · 资源与联机样例\n等待 DS 与 Avatar 初始化";
    }
}
