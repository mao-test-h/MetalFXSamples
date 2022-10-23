#if UNITY_IOS
using System.IO;
using UnityEditor;
using UnityEditor.Callbacks;
using UnityEditor.iOS.Xcode;

namespace MinimumExample.Editor
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
        }
    }
}

#endif