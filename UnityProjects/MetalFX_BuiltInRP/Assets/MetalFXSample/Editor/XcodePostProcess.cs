#if UNITY_IOS
using System.IO;
using UnityEditor;
using UnityEditor.Callbacks;
using UnityEditor.iOS.Xcode;

namespace MetalFXSample.Editor
{
    internal static class XcodePostProcess
    {
        [PostProcessBuild]
        private static void OnPostProcessBuild(BuildTarget target, string xcodeprojPath)
        {
            if (target != BuildTarget.iOS) return;

            var pbxProjectPath = PBXProject.GetPBXProjectPath(xcodeprojPath);
            var pbxProject = new PBXProject();
            pbxProject.ReadFromString(File.ReadAllText(pbxProjectPath));

            // 検証用に常に有効にしておく
            var schemePath = $"{xcodeprojPath}/Unity-iPhone.xcodeproj/xcshareddata/xcschemes/Unity-iPhone.xcscheme";
            var xcScheme = new XcScheme();
            xcScheme.ReadFromFile(schemePath);
            xcScheme.SetFrameCaptureModeOnRun(XcScheme.FrameCaptureMode.Metal);
            xcScheme.SetDebugExecutable(true);
            xcScheme.WriteToFile(schemePath);
        }
    }
}

#endif