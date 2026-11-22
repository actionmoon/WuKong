using System;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.EventSystems;
using UnityEditor;
using UnityEditor.SceneManagement;

public static class WuKongCombatBuilder
{
    const string Root = "Assets/WuKong";
    static DouyinScript Attach(string name, string path)
    {
        var go = GameObject.Find(name) ?? new GameObject(name);
        var script = go.GetComponent<DouyinScript>() ?? go.AddComponent<DouyinScript>();
        script.ScriptAsset = AssetDatabase.LoadAssetAtPath<DouyinScriptAsset>(Root + path);
        if (script.ScriptAsset == null) throw new InvalidOperationException("Missing " + path);
        EditorUtility.SetDirty(script);
        return script;
    }
    public static string Assemble()
    {
        if (EditorSceneManager.GetActiveScene().path != Root + "/Scenes/WuKongTiger.unity")
            throw new InvalidOperationException("Open WuKongTiger.");
        var state = Attach("CombatState", "/Lua/Shared/CombatState.lua");
        state.ParaLuaBindingData = new DouyinLuaDataVar[] {
            new DouyinLuaDataNetString { varName="snapshot", Data="{}" }
        };
        Attach("CombatInput", "/Lua/Client/CombatInput.lua");
        var canvas = GameObject.Find("ArenaHUD").GetComponent<Canvas>();
        if (canvas.GetComponent<GraphicRaycaster>() == null) canvas.gameObject.AddComponent<GraphicRaycaster>();
        var names = new[] { "light", "heavy", "dodge", "gourd", "lock", "sprint" };
        var labels = new[] { "轻棍", "重棍", "闪避", "葫芦", "锁定", "疾跑" };
        for (int i=0; i<names.Length; i++)
        {
            var go = GameObject.Find("CombatButton_" + names[i]);
            if (go == null)
                go = new GameObject("CombatButton_" + names[i], typeof(RectTransform), typeof(Image), typeof(Button), typeof(EventTrigger));
            var r = go.GetComponent<RectTransform>();
            r.SetParent(canvas.transform, false);
            r.anchorMin=r.anchorMax=r.pivot=new Vector2(1,0);
            r.anchoredPosition=new Vector2(-35-(i%3)*88,180+(i/3)*65);
            r.sizeDelta=new Vector2(80,55);
            go.GetComponent<Image>().color=new Color(0.15f,0.1f,0.07f,0.85f);
            var text = go.GetComponentInChildren<Text>();
            if (text == null)
            {
                var label = new GameObject("Label",typeof(RectTransform),typeof(Text));
                label.transform.SetParent(go.transform,false);
                var rect=label.GetComponent<RectTransform>();rect.anchorMin=Vector2.zero;rect.anchorMax=Vector2.one;
                rect.offsetMin=rect.offsetMax=Vector2.zero;text=label.GetComponent<Text>();
            }
            text.font=Resources.GetBuiltinResource<Font>("Arial.ttf");text.fontSize=18;
            text.alignment=TextAnchor.MiddleCenter;text.color=new Color(0.95f,0.85f,0.65f);
            text.text=labels[i];text.raycastTarget=false;
        }
        var hint=GameObject.Find("CameraHint").GetComponent<Text>();
        hint.text="左键轻棍  右键蓄力  Space闪避  R葫芦";
        GameObject.Find("BossName").GetComponent<RectTransform>().sizeDelta=new Vector2(500,40);
        EditorUtility.SetDirty(state);
        AssetDatabase.SaveAssets();
        EditorSceneManager.SaveScene(EditorSceneManager.GetActiveScene());
        return "Step-4 action state, input and six touch buttons assembled.";
    }
}
