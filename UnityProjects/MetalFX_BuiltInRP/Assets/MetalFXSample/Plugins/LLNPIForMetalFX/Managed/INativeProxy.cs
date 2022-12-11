using UnityEngine;

namespace MetalFXSample.Plugins.LLNPIForMetalFX.Managed
{
    public interface INativeProxy
    {
        void DoSpatialScaling(RenderTexture renderTexture);
    }
}