using UnityEngine;

namespace MetalFXSample.Plugins.LLNPIForMetalFX.Managed
{
    public interface INativeProxy
    {
        void DoExtraDrawCall();
        void DoCopyRT(RenderTexture srcRT, RenderTexture dstRT);
    }
}