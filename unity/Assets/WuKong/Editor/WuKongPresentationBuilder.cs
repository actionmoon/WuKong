using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.UI;
using UnityEditor;
using UnityEditor.SceneManagement;

public static class WuKongPresentationBuilder
{
    const string Root = "Assets/WuKong";
    static readonly Color Gold = new Color(.91f,.82f,.63f);
    static JObject data;
    static GameObject Object(string name, Transform parent, params Type[] components)
    {
        var go = parent.Find(name);
        var result = go ? go.gameObject : new GameObject(name, components);
        result.transform.SetParent(parent, false);
        return result;
    }
    static RectTransform Rect(string name, Transform parent, Vector2 anchor, Vector2 pos, Vector2 size)
    {
        var go = Object(name,parent,typeof(RectTransform));
        var rect=go.GetComponent<RectTransform>();
        rect.anchorMin=rect.anchorMax=rect.pivot=anchor;rect.anchoredPosition=pos;rect.sizeDelta=size;
        return rect;
    }
    static Text Label(string name, Transform parent, Vector2 anchor, Vector2 pos, Vector2 size, string text, int font=18)
    {
        var r=Rect(name,parent,anchor,pos,size);var t=r.GetComponent<Text>()??r.gameObject.AddComponent<Text>();
        t.font=Resources.GetBuiltinResource<Font>("Arial.ttf");t.fontSize=font;t.color=Gold;
        t.alignment=TextAnchor.MiddleCenter;t.text=text;t.raycastTarget=false;return t;
    }
    static void Button(string name, Transform parent, Vector2 anchor, Vector2 pos, Vector2 size, string text)
    {
        var r=Rect("CombatButton_"+name,parent,anchor,pos,size);
        var image=r.GetComponent<Image>()??r.gameObject.AddComponent<Image>();image.color=new Color(.09f,.065f,.04f,.82f);
        if(!r.GetComponent<Button>()) r.gameObject.AddComponent<Button>();
        var label=r.GetComponentInChildren<Text>();
        if(label) UnityEngine.Object.DestroyImmediate(label.gameObject);
        Label(name=="challenge"?"ChallengeButtonLabel":"ActionLabel_"+name,r,Vector2.one*.5f,Vector2.zero,size,text);
    }
    static DouyinScript Script(string name)
    {
        var go=GameObject.Find(name)??new GameObject(name);
        var s=go.GetComponent<DouyinScript>()??go.AddComponent<DouyinScript>();
        s.ScriptAsset=AssetDatabase.LoadAssetAtPath<DouyinScriptAsset>(Root+"/Lua/Client/"+name+".lua");
        if(!s.ScriptAsset) throw new InvalidOperationException("Missing script "+name);
        s.ParaLuaBindingData=new DouyinLuaDataVar[] {
            new DouyinLuaDataUObject {varName="presentationData",varType="UnityEngine.TextAsset",
                Data=AssetDatabase.LoadAssetAtPath<TextAsset>(Root+"/VFX/PresentationData.json")}
        };
        EditorUtility.SetDirty(s);return s;
    }
    static void HUD()
    {
        var canvas=GameObject.Find("ArenaHUD").GetComponent<Canvas>();
        canvas.renderMode=RenderMode.ScreenSpaceOverlay;canvas.sortingOrder=20;
        var scaler=canvas.GetComponent<CanvasScaler>();scaler.referenceResolution=new Vector2(1280,720);
        scaler.matchWidthOrHeight=1; // Fixed height preserves the touch target size across landscape aspects.
        var root=Rect("HUDSafeArea",canvas.transform,Vector2.one*.5f,Vector2.zero,Vector2.zero);
        root.anchorMin=Vector2.zero;root.anchorMax=Vector2.one;root.offsetMin=root.offsetMax=Vector2.zero;
        foreach(var child in canvas.transform.Cast<Transform>().ToArray())
            if(child!=root) child.SetParent(root,false);
        var bars=new[]{"PlayerHP","PlayerMP","PlayerStamina","BossHP"};
        foreach(var name in bars)
        {
            var bar=root.Find(name);var fill=bar.Find(name+"Fill").GetComponent<RectTransform>();
            if(name!="BossHP")
            {
                var r=bar.GetComponent<RectTransform>();r.anchorMin=r.anchorMax=r.pivot=new Vector2(0,1);
                r.anchoredPosition=new Vector2(32,name=="PlayerHP"?-68:name=="PlayerMP"?-90:-106);
            }
            fill.pivot=new Vector2(0,.5f);fill.anchorMin=fill.anchorMax=new Vector2(0,.5f);
            fill.anchoredPosition=new Vector2(2,0);
            var ghost=Object(name+"Damage",bar,typeof(RectTransform),typeof(Image)).GetComponent<RectTransform>();
            ghost.anchorMin=fill.anchorMin;ghost.anchorMax=fill.anchorMax;ghost.pivot=fill.pivot;
            ghost.anchoredPosition=fill.anchoredPosition;ghost.sizeDelta=fill.sizeDelta;
            ghost.GetComponent<Image>().color=new Color(.9f,.46f,.22f,.75f);
            ghost.GetComponent<Image>().raycastTarget=false;ghost.SetSiblingIndex(1);fill.SetAsLastSibling();
        }
        Label("BossName",root,new Vector2(.5f,1),new Vector2(0,-24),new Vector2(500,28),"虎先锋",22);
        Label("SkillBaseline",root,new Vector2(0,1),new Vector2(32,-174),new Vector2(310,58),"",16);
        Label("PlayerResources",root,new Vector2(0,1),new Vector2(32,-132),new Vector2(310,30),"",16);
        Label("StanceBaseline",root,new Vector2(0,1),new Vector2(32,-210),new Vector2(310,28),"",18);
        Label("CameraHint",root,new Vector2(.5f,0),new Vector2(0,48),new Vector2(340,24),"",15);
        string[] names={"light","heavy","dodge","gourd","lock","sprint","stanceCycle","spin","immobilize","cloud","transform","spirit"};
        string[] labels={"轻棍","重棍·按住","闪避","葫芦","锁定","疾跑","棍势","棍花·按住","定身","散气","赤潮","广谋"};
        var controls=Rect("CombatControls",root,new Vector2(1,0),Vector2.zero,new Vector2(408,408));
        string[][] layers={new[]{"dodge"},new[]{"light","heavy"},new[]{"immobilize","cloud","transform","spirit"},new[]{"gourd","sprint","stanceCycle","spin","lock"}};
        float[] radii={44,156,260,356},diameters={92,84,76,68},starts={45,20,8,8},ends={45,70,82,82};
        // A persisted round sprite keeps visuals circular while the rectangular
        // raycast target retains the full touch area.
        const string circlePath=Root+"/Presentation/ControlCircle.png";
        Directory.CreateDirectory(Path.GetDirectoryName(circlePath));
        var texture=new Texture2D(128,128,TextureFormat.RGBA32,false);
        for(int y=0;y<128;y++)for(int x=0;x<128;x++)
            texture.SetPixel(x,y,new Color(1,1,1,Mathf.Clamp01(64-Vector2.Distance(new Vector2(x+.5f,y+.5f),new Vector2(64,64)))));
        texture.Apply();File.WriteAllBytes(circlePath,texture.EncodeToPNG());UnityEngine.Object.DestroyImmediate(texture);
        AssetDatabase.ImportAsset(circlePath);
        var importer=(TextureImporter)AssetImporter.GetAtPath(circlePath);
        importer.textureType=TextureImporterType.Sprite;importer.mipmapEnabled=false;importer.SaveAndReimport();
        var circle=AssetDatabase.LoadAssetAtPath<Sprite>(circlePath);
        for(int layer=0;layer<layers.Length;layer++)for(int i=0;i<layers[layer].Length;i++)
        {
            var name=layers[layer][i];var old=root.Find("CombatButton_"+name);
            if(old)UnityEngine.Object.DestroyImmediate(old.gameObject);
            var angle=Mathf.Lerp(starts[layer],ends[layer],layers[layer].Length==1?0:(float)i/(layers[layer].Length-1))*Mathf.Deg2Rad;
            var pos=new Vector2(-20-radii[layer]*Mathf.Cos(angle),20+radii[layer]*Mathf.Sin(angle));
            var size=Vector2.one*diameters[layer];
            Button(name,controls,new Vector2(1,0),pos,size,labels[Array.IndexOf(names,name)]);
            var r=controls.Find("CombatButton_"+name).GetComponent<RectTransform>();r.pivot=Vector2.one*.5f;
            r.GetComponent<Image>().sprite=circle;
            var progress=Rect("ActionProgress_"+name,r,Vector2.one*.5f,Vector2.zero,size-Vector2.one*6);
            var fill=progress.gameObject.GetComponent<Image>()??progress.gameObject.AddComponent<Image>();
            fill.sprite=circle;fill.type=Image.Type.Filled;fill.fillMethod=Image.FillMethod.Radial360;
            fill.fillOrigin=2;fill.fillClockwise=true;fill.fillAmount=0;fill.color=new Color(.82f,.64f,.28f,.3f);fill.raycastTarget=false;
            progress.SetAsFirstSibling();
            r.GetComponentInChildren<Text>().fontSize=layer<2?19:16;
        }
        Label("CombatToast",controls,new Vector2(.5f,1),new Vector2(0,-8),new Vector2(180,24),"",16);
        Button("mute",root,new Vector2(0,1),new Vector2(124,-246),new Vector2(78,36),"声音");
        Button("help",root,new Vector2(0,1),new Vector2(32,-246),new Vector2(78,36),"帮助");
        var result=Rect("ChallengeResultPanel",root,Vector2.one*.5f,Vector2.zero,new Vector2(510,220));
        var image=result.GetComponent<Image>()??result.gameObject.AddComponent<Image>();
        image.color=new Color(.025f,.018f,.012f,.92f);image.raycastTarget=false;
        Label("ChallengeResultTitle",result,Vector2.one*.5f,new Vector2(0,45),new Vector2(480,60),"卧虎寺",36);
        Label("ChallengeResultHint",result,Vector2.one*.5f,new Vector2(0,0),new Vector2(460,30),"",18);
        Button("challenge",root,Vector2.one*.5f,new Vector2(0,-72),new Vector2(190,48),"开始挑战");
        root.Find("CombatButton_challenge").SetAsLastSibling();
        var help=Rect("HelpPanel",root,Vector2.one*.5f,new Vector2(0,60),new Vector2(740,360));
        var back=help.GetComponent<Image>()??help.gameObject.AddComponent<Image>();back.color=new Color(.025f,.018f,.012f,.97f);back.raycastTarget=false;
        Label("HelpText",help,Vector2.one*.5f,Vector2.zero,new Vector2(710,320),
            "触屏操作\n\n左侧摇杆移动；右侧四层按钮直接操作\n闪避 → 轻棍 / 按住重棍蓄力 → 定身 / 聚形散气 / 赤潮 / 广谋\n外层：葫芦、疾跑切换、棍势切换、按住棍花、锁定\n移动时可同时蓄力；松开或滑出结束按住\n空白处拖动视角；点击帮助关闭；中央按钮开始 / 重新挑战\n\n键鼠兼容\nWASD 移动 · Shift 疾跑 · Ctrl / Alt 慢走\n左键轻棍 · 右键蓄力 · Space 闪避 · V 棍花\nZ / X / C 棍势 · 1 定身 · 2 散气 · 4 赤潮 · F 广谋\nR 葫芦 · Q / 中键锁定 · H 帮助 · M 声音 · Enter 挑战",20);
        // Runtime caches these objects before hiding them.
        help.gameObject.SetActive(true);result.gameObject.SetActive(true);
        Script("PresentationHUD");
    }
    static float Number(JToken token,float fallback=0)
    {
        if(token==null)return fallback;
        var range=token as JArray;
        return range==null?(float)token:range.Count==0?fallback:range.Select(v=>Number(v,fallback)).Average();
    }
    static ParticleSystem.MinMaxCurve Range(JToken token,float fallback)
    {
        var a=token as JArray;
        return a==null?new ParticleSystem.MinMaxCurve(Number(token,fallback)):
            new ParticleSystem.MinMaxCurve(Number(a[0],fallback),Number(a[1],fallback));
    }
    static Material Material(string texture,bool additive)
    {
        var path=Root+"/VFX/"+texture+(additive?"_Add":"_Alpha")+".mat";
        var material=AssetDatabase.LoadAssetAtPath<Material>(path);
        if(!material) {material=new Material(Shader.Find("Universal Render Pipeline/Particles/Unlit"));AssetDatabase.CreateAsset(material,path);}
        material.SetTexture("_BaseMap",AssetDatabase.LoadAssetAtPath<Texture2D>(Root+"/VFX/Textures/"+texture+".png"));
        material.SetColor("_BaseColor",Color.white);material.SetFloat("_Surface",1);material.SetFloat("_Blend",additive?2:0);
        material.SetFloat("_SrcBlend",(float)UnityEngine.Rendering.BlendMode.SrcAlpha);
        material.SetFloat("_DstBlend",(float)(additive?UnityEngine.Rendering.BlendMode.One:UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha));
        material.SetFloat("_ZWrite",0);material.SetFloat("_Cull",0);material.EnableKeyword("_SURFACE_TYPE_TRANSPARENT");material.renderQueue=3000;
        EditorUtility.SetDirty(material);return material;
    }
    static void FX()
    {
        var holder=GameObject.Find("PresentationTemplates")??new GameObject("PresentationTemplates");
        foreach(var child in holder.transform.Cast<Transform>().ToArray()) UnityEngine.Object.DestroyImmediate(child.gameObject);
        var vfx=(JObject)data["vfx"];var layers=(JObject)vfx["layers"];
        foreach(var property in ((JObject)vfx["systems"]).Properties())
        {
            var spec=property.Value;var go=new GameObject(property.Name);go.transform.SetParent(holder.transform,false);
            int n=0;
            foreach(var emitter in (JArray)spec["emitters"])
            {
                var layer=layers[(string)emitter["layer"]];if(layer==null)continue;
                var child=new GameObject("Emitter_"+n++);child.transform.SetParent(go.transform,false);
                var ps=child.AddComponent<ParticleSystem>();ps.Stop(true,ParticleSystemStopBehavior.StopEmittingAndClear);
                var main=ps.main;main.playOnAwake=false;main.loop=false;
                main.duration=Mathf.Max(.1f,Number(emitter["dur"],.6f));
                main.startLifetime=Range(emitter["life"],.8f);main.startSpeed=Range(emitter["speed"],.5f);
                var size=emitter["size"] as JArray;main.startSize=size==null?.4f:Number(size[0],.4f);
                main.simulationSpace=ParticleSystemSimulationSpace.World;main.maxParticles=128;
                main.gravityModifier=Number(emitter["gravity"])/9.81f;
                var color=emitter["color"] as JArray;
                main.startColor=new Color(color==null?1:Number(color[0]),color==null?.75f:Number(color[1]),
                    color==null?.4f:Number(color[2]),Number(emitter["alpha"],.8f));
                var emission=ps.emission;emission.rateOverTime=Mathf.Min(80,Number(emitter["rate"]));
                int count=Mathf.Clamp((int)Number(emitter["count"]),0,96);
                if(count>0) emission.SetBursts(new[]{new ParticleSystem.Burst(0,(short)count)});
                var shape=ps.shape;shape.shapeType=ParticleSystemShapeType.Sphere;shape.radius=Number(emitter["radius"],.2f);
                if((string)emitter["shape"]=="body") {shape.shapeType=ParticleSystemShapeType.Box;shape.scale=new Vector3(1,2,1);}
                var alpha=ps.colorOverLifetime;alpha.enabled=true;
                var gradient=new Gradient();gradient.SetKeys(new[]{new GradientColorKey(Color.white,0),new GradientColorKey(Color.white,1)},
                    new[]{new GradientAlphaKey(1,0),new GradientAlphaKey(0,1)});alpha.color=gradient;
                var scale=ps.sizeOverLifetime;scale.enabled=true;scale.size=new ParticleSystem.MinMaxCurve(1,new AnimationCurve(new Keyframe(0,1),
                    new Keyframe(1,size!=null?Number(size[1],.1f)/Mathf.Max(.01f,Number(size[0],.4f)):.2f)));
                var renderer=child.GetComponent<ParticleSystemRenderer>();renderer.sharedMaterial=Material((string)layer["texture"],(string)layer["blend"]=="additive");
                renderer.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;renderer.receiveShadows=false;
                var tex=data["textures"][(string)layer["texture"]];var grid=tex==null?null:tex["flipbook"] as JArray;
                if(grid!=null)
                {
                    var sheet=ps.textureSheetAnimation;sheet.enabled=true;sheet.numTilesX=(int)grid[0];sheet.numTilesY=(int)grid[1];
                    sheet.frameOverTime=new ParticleSystem.MinMaxCurve(1,AnimationCurve.Linear(0,0,1,1));
                }
            }
            go.SetActive(false);
        }
        var trail=new GameObject("WeaponTrail");trail.transform.SetParent(holder.transform,false);
        var t=trail.AddComponent<TrailRenderer>();t.time=.36f;t.minVertexDistance=.045f;t.widthMultiplier=.2f;
        t.sharedMaterial=Material("T_Streak_Soft_Trail_03",true);t.emitting=false;t.autodestruct=false;
        t.startColor=new Color(1,.75f,.3f,.8f);t.endColor=new Color(1,.4f,.1f,0);trail.SetActive(false);
        var script=Script("PresentationFX");
        var ghostPath=Root+"/VFX/GhostMaterial.mat";
        var ghost=AssetDatabase.LoadAssetAtPath<Material>(ghostPath);
        if(!ghost)
        {
            ghost=new Material(Shader.Find("Universal Render Pipeline/Unlit"));
            ghost.SetFloat("_Surface",1);ghost.SetFloat("_SrcBlend",5);ghost.SetFloat("_DstBlend",10);ghost.SetFloat("_ZWrite",0);
            ghost.EnableKeyword("_SURFACE_TYPE_TRANSPARENT");ghost.renderQueue=3000;AssetDatabase.CreateAsset(ghost,ghostPath);
        }
        script.ParaLuaBindingData=script.ParaLuaBindingData.Concat(new DouyinLuaDataVar[]{
            new DouyinLuaDataUObject {varName="stoneTexture",varType="UnityEngine.Texture2D",
                Data=AssetDatabase.LoadAssetAtPath<Texture2D>(Root+"/VFX/Textures/T_HFM_HuStone_D.png")},
            new DouyinLuaDataUObject {varName="ghostMaterial",varType="UnityEngine.Material",Data=ghost}
        }).ToArray();
        EditorUtility.SetDirty(script);
    }
    static void Audio()
    {
        var script=Script("PresentationAudio");
        var files=((JArray)data["audioFiles"]).Select(f=>AssetDatabase.LoadAssetAtPath<AudioClip>(Root+"/Audio/"+(string)f)).ToArray();
        if(files.Any(f=>!f))throw new InvalidOperationException("Missing converted AudioClip");
        script.ParaLuaBindingData=script.ParaLuaBindingData.Concat(new DouyinLuaDataVar[]{
            new DouyinLuaDataUObjectArr {varName="audioClips",varType="UnityEngine.AudioClip",Data=files.Cast<UnityEngine.Object>().ToArray()}
        }).ToArray();
        EditorUtility.SetDirty(script);
    }
    public static string Assemble()
    {
        if(EditorSceneManager.GetActiveScene().path!=Root+"/Scenes/WuKongTiger.unity")throw new InvalidOperationException("Open WuKongTiger.");
        data=JObject.Parse(File.ReadAllText(Root+"/VFX/PresentationData.json"));
        foreach(var path in AssetDatabase.FindAssets("t:AudioClip",new[]{Root+"/Audio"}).Select(AssetDatabase.GUIDToAssetPath))
        {
            var importer=(AudioImporter)AssetImporter.GetAtPath(path);var setting=importer.defaultSampleSettings;
            var load=path.Contains("bgm_")?AudioClipLoadType.Streaming:AudioClipLoadType.CompressedInMemory;
            if(setting.loadType==load&&setting.compressionFormat==AudioCompressionFormat.Vorbis&&Mathf.Approximately(setting.quality,.75f))continue;
            setting.loadType=load;
            setting.compressionFormat=AudioCompressionFormat.Vorbis;setting.quality=.75f;
            importer.defaultSampleSettings=setting;importer.preloadAudioData=!path.Contains("bgm_");importer.SaveAndReimport();
        }
        foreach(var path in AssetDatabase.FindAssets("t:Texture2D",new[]{Root+"/VFX/Textures"}).Select(AssetDatabase.GUIDToAssetPath))
        {
            var importer=(TextureImporter)AssetImporter.GetAtPath(path);importer.alphaIsTransparency=true;
            if(!importer.mipmapEnabled&&importer.maxTextureSize==512)continue;
            importer.mipmapEnabled=false;importer.maxTextureSize=512;importer.SaveAndReimport();
        }
        HUD();FX();Audio();Script("PresentationMetrics");
        AssetDatabase.SaveAssets();EditorSceneManager.SaveScene(EditorSceneManager.GetActiveScene());
        return "HUD, 623 audio clips, 80 effect templates and original textures assembled.";
    }
    public static string UpdateHUD()
    {
        HUD();AssetDatabase.SaveAssets();EditorSceneManager.SaveScene(EditorSceneManager.GetActiveScene());
        return "HUD layout updated.";
    }
}
