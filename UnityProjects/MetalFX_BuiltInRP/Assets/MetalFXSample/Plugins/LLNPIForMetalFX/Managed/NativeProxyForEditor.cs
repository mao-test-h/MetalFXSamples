using UnityEngine;

namespace MetalFXSample.Plugins.LLNPIForMetalFX.Managed
{
    public sealed class NativeProxyForEditor : INativeProxy
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