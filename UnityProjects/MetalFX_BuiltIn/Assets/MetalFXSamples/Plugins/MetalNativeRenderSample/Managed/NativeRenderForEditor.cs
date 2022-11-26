using UnityEngine;

namespace MetalFXSamples.Plugins.MetalNativeRenderSample.Managed
{
    public sealed class NativeRenderForEditor : INativeRender
    {
        public void DoExtraDrawCall()
        {
            // do nothing
        }

        public void DoCopyRT(RenderTexture srcRT, RenderTexture dstRT)
        {
            // do nothing
        }
    }
}