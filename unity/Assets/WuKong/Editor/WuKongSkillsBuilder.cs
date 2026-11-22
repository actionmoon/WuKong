using System;
using System.Linq;
using UnityEngine;
using UnityEngine.UI;
using UnityEditor;
using UnityEditor.SceneManagement;

public static class WuKongSkillsBuilder
{
    const string Root="Assets/WuKong";
    static readonly string[] Assets={"Stances","Spells","FormTransition","Guangzhi","Guangmou","SpiritSnake"};
    public static string Import()
    {
        foreach(var name in Assets)
        {
            var importer=AssetImporter.GetAtPath(Root+"/Art/"+name+".glb");
            if(importer==null) throw new InvalidOperationException("Missing "+name);
            var settings=new SerializedObject(importer);
            var property=settings.FindProperty("importSettings.animationMethod");
            if(property==null) throw new InvalidOperationException("No glTF animation setting");
            property.intValue=(int)GLTFast.AnimationMethod.Legacy;
            settings.ApplyModifiedPropertiesWithoutUndo();importer.SaveAndReimport();
        }
        return "Six skill GLBs imported as legacy animations.";
    }
    static GameObject Template(string asset,string name)
    {
        var go=Resources.FindObjectsOfTypeAll<GameObject>().FirstOrDefault(g=>g.scene.IsValid()&&g.name==name);
        if(go==null)
        {
            go=(GameObject)PrefabUtility.InstantiatePrefab(AssetDatabase.LoadAssetAtPath<GameObject>(Root+"/Art/"+asset+".glb"));
            PrefabUtility.UnpackPrefabInstance(go,PrefabUnpackMode.Completely,InteractionMode.AutomatedAction);
            go.name=name;
        }
        go.transform.position=Vector3.zero;go.transform.rotation=Quaternion.identity;
        var anim=go.GetComponent<Animation>()??go.AddComponent<Animation>();
        AddClips(anim,asset);anim.playAutomatically=false;
        foreach(var renderer in go.GetComponentsInChildren<Renderer>(true))
        {
            renderer.sharedMaterials=renderer.sharedMaterials.Select(source=>
            {
                var path=Root+"/Art/Materials/Skill_"+asset+"_"+source.name.Replace("/","_")+".mat";
                var material=AssetDatabase.LoadAssetAtPath<Material>(path);
                if(material==null)
                {
                    material=new Material(Shader.Find("Douyin/World/ENV/World_Lit"));
                    if(source.HasProperty("_BaseColor")) material.SetColor("_BaseColor",source.GetColor("_BaseColor"));
                    if(source.HasProperty("_BaseMap")) material.SetTexture("_BaseMap",source.GetTexture("_BaseMap"));
                    material.SetFloat("_Metallic",0);material.SetFloat("_CullMode",0);
                    AssetDatabase.CreateAsset(material,path);
                }
                return material;
            }).ToArray();
        }
        go.SetActive(false);return go;
    }
    static void AddClips(Animation animation,string asset)
    {
        foreach(var clip in AssetDatabase.LoadAllAssetsAtPath(Root+"/Art/"+asset+".glb").OfType<AnimationClip>())
        {
            if(!clip.legacy) throw new InvalidOperationException("Non legacy clip "+clip.name);
            animation.AddClip(clip,clip.name);
        }
        EditorUtility.SetDirty(animation);
    }
    public static string Assemble()
    {
        if(EditorSceneManager.GetActiveScene().path!=Root+"/Scenes/WuKongTiger.unity")
            throw new InvalidOperationException("Open WuKongTiger.");
        var wukong=Resources.FindObjectsOfTypeAll<GameObject>().First(g=>g.scene.IsValid()&&g.name=="WukongVisualTemplate");
        foreach(var asset in Assets.Take(3)) AddClips(wukong.GetComponent<Animation>(),asset);
        var lang=Template("Guangzhi","GuangzhiVisualTemplate");
        // Source sockets are already in metres; glTF handedness mirrors local X.
        string[] names={"Hit_Weapon_5","Hit_Weapon_1","Hit_Weapon_2","Hit_Weapon_3","Hit_Weapon_4","FX_Trail_Fire_01","FX_Trail_Fire_02","Touch_01"};
        Vector3[] positions={new Vector3(0,2,.1f),new Vector3(0,-1.04f,-.1f),new Vector3(0,-.32f,0),
            new Vector3(0,.48f,0),new Vector3(0,1.28f,0),new Vector3(0,1.8f,.01f),new Vector3(0,-.8f,-.01f),new Vector3(0,.63f,0)};
        var weapon=lang.GetComponentsInChildren<Transform>(true).First(t=>t.name=="weapon_r");
        for(int i=0;i<names.Length;i++)
        {
            var t=weapon.Find(names[i]);
            if(t==null) { t=new GameObject(names[i]).transform;t.SetParent(weapon,false); }
            t.localPosition=positions[i];t.localRotation=Quaternion.identity;
        }
        var holder=GameObject.Find("SkillsTemplates")??new GameObject("SkillsTemplates");
        lang.transform.SetParent(holder.transform,false);
        Template("Guangmou","GuangmouVisualTemplate").transform.SetParent(holder.transform,false);
        Template("SpiritSnake","SpiritSnakeVisualTemplate").transform.SetParent(holder.transform,false);
        var canvas=GameObject.Find("ArenaHUD").transform;
        string[] buttons={"stanceCycle","spin","immobilize","cloud","transform","spirit"};
        string[] labels={"棍势","棍花","定身","散气","赤潮","广谋"};
        for(int i=0;i<buttons.Length;i++)
        {
            var go=GameObject.Find("CombatButton_"+buttons[i])??new GameObject("CombatButton_"+buttons[i],typeof(RectTransform),typeof(Image),typeof(Button));
            var rect=go.GetComponent<RectTransform>();rect.SetParent(canvas,false);
            rect.anchorMin=rect.anchorMax=rect.pivot=new Vector2(1,0);
            rect.anchoredPosition=new Vector2(-35-(i%3)*88,320+(i/3)*65);rect.sizeDelta=new Vector2(80,55);
            go.GetComponent<Image>().color=new Color(.15f,.1f,.07f,.85f);
            var text=go.GetComponentInChildren<Text>();
            if(text==null)
            {
                var label=new GameObject("Label",typeof(RectTransform),typeof(Text));label.transform.SetParent(go.transform,false);
                var r=label.GetComponent<RectTransform>();r.anchorMin=Vector2.zero;r.anchorMax=Vector2.one;r.offsetMin=r.offsetMax=Vector2.zero;
                text=label.GetComponent<Text>();
            }
            text.font=Resources.GetBuiltinResource<Font>("Arial.ttf");text.fontSize=18;text.alignment=TextAnchor.MiddleCenter;
            text.color=new Color(.95f,.85f,.65f);text.text=labels[i];text.raycastTarget=false;
        }
        AssetDatabase.SaveAssets();EditorSceneManager.SaveScene(EditorSceneManager.GetActiveScene());
        return "56 Wukong skill clips, three form templates, weapon sockets and six touch controls saved.";
    }
}
