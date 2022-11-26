#if UNITY_IOS
using System.IO;
using UnityEditor;
using UnityEditor.Callbacks;
using UnityEditor.iOS.Xcode;

namespace MetalFXSamples.Editor
{
    static class XcodePostProcess
    {
        [PostProcessBuild]
        static void OnPostProcessBuild(BuildTarget target, string path)
        {
            if (target != BuildTarget.iOS) return;

            var projectPath = PBXProject.GetPBXProjectPath(path);
            var project = new PBXProject();
            project.ReadFromString(File.ReadAllText(projectPath));

            var frameworkGuid = project.GetUnityFrameworkTargetGuid();
            project.AddFrameworkToProject(frameworkGuid, "MetalFX.framework", false);
            File.WriteAllText(projectPath, project.WriteToString());

            // 検証用に常に有効にしておく
            var schemePath = $"{path}/Unity-iPhone.xcodeproj/xcshareddata/xcschemes/Unity-iPhone.xcscheme";
            var xcScheme = new XcScheme();
            xcScheme.ReadFromFile(schemePath);
            xcScheme.SetFrameCaptureModeOnRun(XcScheme.FrameCaptureMode.Metal);
            xcScheme.SetDebugExecutable(true);
            xcScheme.WriteToFile(schemePath);
        }
    }
}

#endif