using UnityEngine;

namespace MetalFXSample.Plugins.LLNPIForMetalFX.Managed
{
    public sealed class NativeProxyForEditor : INativeProxy
    {
        void INativeProxy.DoSpatialScaling(RenderTexture renderTexture)
        {
            // do nothing
        }
    }
}