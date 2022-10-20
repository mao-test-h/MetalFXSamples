using System;
using UnityEngine.Rendering.Universal;

namespace MetalFX.SpacingScaling.Runtime
{
    [Serializable]
    public sealed class SpacingScalingFeature : ScriptableRendererFeature
    {
        SpacingScalingRenderPass _scriptablePass;

        public override void Create()
        {
            _scriptablePass = new SpacingScalingRenderPass();
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
