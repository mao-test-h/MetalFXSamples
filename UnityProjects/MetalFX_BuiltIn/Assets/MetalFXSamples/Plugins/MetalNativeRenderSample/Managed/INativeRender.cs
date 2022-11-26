using UnityEngine;

namespace MetalFXSamples.Plugins.MetalNativeRenderSample.Managed
{
    public interface INativeRender
    {
        void DoExtraDrawCall();
        void DoCopyRT(RenderTexture srcRT, RenderTexture dstRT);
    }
}