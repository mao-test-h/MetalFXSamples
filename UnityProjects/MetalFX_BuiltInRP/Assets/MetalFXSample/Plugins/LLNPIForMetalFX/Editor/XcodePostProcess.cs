#if UNITY_IOS
using System.IO;
using UnityEditor;
using UnityEditor.Callbacks;
using UnityEditor.iOS.Xcode;
using UnityEngine;

namespace MetalFXSample.Plugins.LLNPIForMetalFX.Editor
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

            AddFramework(ref pbxProject);
            ReplaceNativeSources(xcodeprojPath);
            SetPublicHeader(ref pbxProject);

            File.WriteAllText(pbxProjectPath, pbxProject.WriteToString());
        }

        private static void AddFramework(ref PBXProject pbxProject)
        {
            var frameworkGuid = pbxProject.GetUnityFrameworkTargetGuid();
            pbxProject.AddFrameworkToProject(frameworkGuid, "MetalFX.framework", false);
        }

        private static void ReplaceNativeSources(string xcodeprojPath)
        {
            // iOSビルド結果にある`UnityFramework.h`を改造済みのソースに差し替える
            const string headerFile = "UnityFramework.h";
            const string replaceHeaderPath = "/LLNPISample/Plugins/LLNPIWithMetal/Native/.ReplaceSources/" + headerFile;
            const string nativePath = "/UnityFramework/" + headerFile;

            var srcPath = Application.dataPath + replaceHeaderPath;
            var dstPath = xcodeprojPath + nativePath;
            File.Copy(srcPath, dstPath, true);
        }

        private static void SetPublicHeader(ref PBXProject pbxProject)
        {
            // iOSビルド結果にある以下のヘッダーはpublicとして設定し直す
            const string sourcesDirectory = "Classes/Unity/";
            var sources = new[]
            {
                "IUnityInterface.h",
                "IUnityGraphicsMetal.h",
                "IUnityGraphics.h",
            };

            var frameworkGuid = pbxProject.GetUnityFrameworkTargetGuid();
            foreach (var source in sources)
            {
                var sourceGuid = pbxProject.FindFileGuidByProjectPath(sourcesDirectory + source);
                pbxProject.AddPublicHeaderToBuild(frameworkGuid, sourceGuid);
            }
        }
    }
}

#endif