"""Verify persisted render settings through the active Unity MCP Editor."""
import json
from pathlib import Path
from unity_mcp import UnityMcp

client = UnityMcp()
client.select("unity@fff213c1fca70370")
code = """
var root = "Assets/WuKong";
var profile = AssetDatabase.LoadAssetAtPath<UnityEngine.Rendering.VolumeProfile>(root + "/Materials/ArenaPost.asset");
UnityEngine.Rendering.Universal.Tonemapping tone;
var valid = profile.TryGet(out tone);
var materialPaths = AssetDatabase.FindAssets("t:Material",new[]{root+"/Art/RenderMaterials"});
var shader = Shader.Find("WuKong/Source Lit");
var messages = ShaderUtil.GetShaderMessages(shader);
var pipelines = new[]{"Assets/Settings/URP-HighFidelity.asset","Assets/Settings/URP-Balanced.asset"}.Select(path=>{
    var p=AssetDatabase.LoadAssetAtPath<UnityEngine.Rendering.Universal.UniversalRenderPipelineAsset>(path);
    return new {path, p.shadowDistance,p.shadowCascadeCount,p.msaaSampleCount,p.mainLightShadowmapResolution,p.supportsHDR};
}).ToArray();
var sh=RenderSettings.ambientProbe;
var factorChecks=0;
var factorFailures=new System.Collections.Generic.List<string>();
foreach(var manifestPath in System.IO.Directory.GetFiles(root+"/Art/RenderMaterials","materials.json",System.IO.SearchOption.AllDirectories)){
    var manifest=JsonUtility.FromJson<WuKongRenderBuilder.Manifest>(System.IO.File.ReadAllText(manifestPath));
    foreach(var surface in manifest.materials){
        var mat=AssetDatabase.LoadAssetAtPath<Material>(System.IO.Path.GetDirectoryName(manifestPath)+"/Surface_"+surface.index.ToString("D3")+".mat");
        var color=mat.GetColor("_BaseColor").linear;
        var expected=new Color(surface.baseColor[0],surface.baseColor[1],surface.baseColor[2],surface.baseColor[3]);
        if(Mathf.Max(Mathf.Abs(color.r-expected.r),Mathf.Abs(color.g-expected.g),Mathf.Abs(color.b-expected.b),Mathf.Abs(color.a-expected.a))>.002f)factorFailures.Add(manifest.asset+"/"+surface.name);
        factorChecks++;
    }
}
return new {
    scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,
    dirty=UnityEngine.SceneManagement.SceneManager.GetActiveScene().isDirty,
    activePipeline=UnityEngine.Rendering.GraphicsSettings.currentRenderPipeline.name,
    materialCount=materialPaths.Length,
    sourceShaderCount=materialPaths.Count(g=>AssetDatabase.LoadAssetAtPath<Material>(AssetDatabase.GUIDToAssetPath(g)).shader==shader),
    shaderMessages=messages.Select(m=>new {m.message, severity=m.severity.ToString()}).ToArray(),
    aces=valid && tone.mode.value==UnityEngine.Rendering.Universal.TonemappingMode.ACES && AssetDatabase.Contains(tone),
    ambientMode=RenderSettings.ambientMode.ToString(),
    ambientL0=new[]{sh[0,0],sh[1,0],sh[2,0]},
    sunIntensity=GameObject.Find("Directional Light").GetComponent<Light>().intensity,
    reflectionIntensity=RenderSettings.reflectionIntensity,
    skyMipCount=AssetDatabase.LoadAssetAtPath<Cubemap>(root+"/Materials/RenderSky.asset").mipmapCount,
    factorChecks,factorFailures=factorFailures.ToArray(),
    pipelines
};
"""
result = client.call("execute_code", {"action": "execute", "code": code})
target = Path(__file__).resolve().parent.parent / "docs/reference/render-editor-evidence.json"
target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(result, ensure_ascii=False, indent=2))
