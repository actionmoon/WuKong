using System.Collections;
using System.Collections.Generic;
using UnityEditor;

public static class ScenePackage
{
    [MenuItem("Tools/ScenePackage")]
    public static void BuildActiveDebugScene()
    {
        SimulatorUtils.BuildActiveDebugScene();
    }
}
