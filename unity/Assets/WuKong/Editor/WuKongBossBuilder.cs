using System;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.UI;

public static class WuKongBossBuilder
{
    const string Root="Assets/WuKong";
    public static string Assemble()
    {
        if (EditorSceneManager.GetActiveScene().path != Root+"/Scenes/WuKongTiger.unity")
            throw new InvalidOperationException("Open WuKongTiger.");
        if(!AssetDatabase.IsValidFolder(Root+"/Art/Materials"))
            AssetDatabase.CreateFolder(Root+"/Art","Materials");
        var tiger=GameObject.Find("TigerBaseline");
        var animation=tiger.GetComponent<Animation>();
        var clips=AssetDatabase.LoadAllAssetsAtPath(Root+"/Art/Tiger.glb").OfType<AnimationClip>().ToArray();
        foreach(var clip in clips)
        {
            if(!clip.legacy) throw new InvalidOperationException("Non legacy tiger clip "+clip.name);
            animation.AddClip(clip,clip.name);
        }
        animation.playAutomatically=false;
        var go=GameObject.Find("BossPresentation")??new GameObject("BossPresentation");
        var script=go.GetComponent<DouyinScript>()??go.AddComponent<DouyinScript>();
        script.ScriptAsset=AssetDatabase.LoadAssetAtPath<DouyinScriptAsset>(Root+"/Lua/Client/BossPresentation.lua");
        var decoy=GameObject.Find("StoneDecoyTemplate");
        if(decoy==null)
        {
            var asset=AssetDatabase.LoadAssetAtPath<GameObject>(Root+"/Art/StoneDecoy.glb");
            if(asset==null) throw new InvalidOperationException("Import StoneDecoy.glb.");
            decoy=(GameObject)PrefabUtility.InstantiatePrefab(asset);
            PrefabUtility.UnpackPrefabInstance(decoy,PrefabUnpackMode.Completely,InteractionMode.AutomatedAction);
            decoy.name="StoneDecoyTemplate";
        }
        var rockPath=Root+"/Art/Materials/StoneDecoy.mat";
        var rock=AssetDatabase.LoadAssetAtPath<Material>(rockPath);
        if(rock==null)
        {
            rock=new Material(Shader.Find("Douyin/World/ENV/World_Lit"));
            AssetDatabase.CreateAsset(rock,rockPath);
        }
        rock.SetColor("_BaseColor",new Color(.78f,.72f,.6f));
        rock.SetTexture("_BaseMap",AssetDatabase.LoadAssetAtPath<Texture2D>(Root+"/Art/StoneRock.png"));
        foreach(var r in decoy.GetComponentsInChildren<Renderer>(true))
        {
            r.sharedMaterials=r.sharedMaterials.Select(x=>rock).ToArray();r.enabled=false;
        }
        var wind=GameObject.Find("WindHazardMaterial");
        if(wind==null) {wind=GameObject.CreatePrimitive(PrimitiveType.Cube);wind.name="WindHazardMaterial";}
        UnityEngine.Object.DestroyImmediate(wind.GetComponent<Collider>());
        var materialPath=Root+"/Art/Materials/WindHazard.mat";
        var material=AssetDatabase.LoadAssetAtPath<Material>(materialPath);
        if(material==null)
        {
            material=new Material(Shader.Find("Universal Render Pipeline/Unlit"));
            AssetDatabase.CreateAsset(material,materialPath);
        }
        material.SetFloat("_Surface",1);material.SetFloat("_Blend",0);
        material.SetFloat("_SrcBlend",(float)UnityEngine.Rendering.BlendMode.SrcAlpha);
        material.SetFloat("_DstBlend",(float)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
        material.SetFloat("_ZWrite",0);material.SetColor("_BaseColor",new Color(.7f,.85f,.9f,.25f));
        material.EnableKeyword("_SURFACE_TYPE_TRANSPARENT");material.renderQueue=3000;
        wind.GetComponent<Renderer>().sharedMaterial=material;wind.GetComponent<Renderer>().enabled=false;
        var canvas=GameObject.Find("ArenaHUD").transform;
        var button=GameObject.Find("CombatButton_challenge");
        if(button==null) button=new GameObject("CombatButton_challenge",typeof(RectTransform),typeof(Image),typeof(Button));
        var rect=button.GetComponent<RectTransform>();rect.SetParent(canvas,false);
        rect.anchorMin=rect.anchorMax=rect.pivot=new Vector2(.5f,0);rect.anchoredPosition=new Vector2(0,60);rect.sizeDelta=new Vector2(200,50);
        button.GetComponent<Image>().color=new Color(.16f,.11f,.07f,.9f);
        var label=GameObject.Find("ChallengeButtonLabel");
        if(label==null) label=new GameObject("ChallengeButtonLabel",typeof(RectTransform),typeof(Text));
        label.transform.SetParent(button.transform,false);
        var lr=label.GetComponent<RectTransform>();lr.anchorMin=Vector2.zero;lr.anchorMax=Vector2.one;lr.offsetMin=lr.offsetMax=Vector2.zero;
        var text=label.GetComponent<Text>();text.font=Resources.GetBuiltinResource<Font>("Arial.ttf");
        text.text="开始挑战";text.fontSize=22;text.color=new Color(.95f,.85f,.65f);text.alignment=TextAnchor.MiddleCenter;text.raycastTarget=false;
        EditorUtility.SetDirty(script);EditorUtility.SetDirty(animation);
        AssetDatabase.SaveAssets();EditorSceneManager.SaveScene(EditorSceneManager.GetActiveScene());
        return "Boss presentation, "+clips.Length+" legacy clips, stone decoy, wind volumes and challenge button saved.";
    }
}
