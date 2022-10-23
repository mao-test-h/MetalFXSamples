using System;
using UnityEngine.Rendering.Universal;

namespace MetalFX.SpatialScaling.Runtime
{
    [Serializable]
    public sealed class SpatialScalingFeature : ScriptableRendererFeature
    {
        SpatialScalingRenderPass _scriptablePass;

        public override void Create()
        {
            _scriptablePass = new SpatialScalingRenderPass();
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            renderer.EnqueuePass(_scriptablePass);
        }

        protected override void Dispose(bool disposing)
        {
            _scriptablePass.Dispose();
        }
    }
}