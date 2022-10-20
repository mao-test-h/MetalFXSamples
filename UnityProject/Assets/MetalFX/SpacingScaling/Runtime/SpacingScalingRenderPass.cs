using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MetalFX.SpacingScaling.Runtime
{
    sealed class SpacingScalingRenderPass : ScriptableRenderPass, IDisposable
    {
        const string RenderPassName = "MetalFX_SpacingScaling";
        readonly ProfilingSampler _profilingSampler;
        readonly SpacingScalingVolume _volume;

        bool isActive => (_volume != null && _volume.IsActive);

        public SpacingScalingRenderPass()
        {
            renderPassEvent = RenderPassEvent.AfterRendering;
            _profilingSampler = new ProfilingSampler(RenderPassName);

            var volumeStack = VolumeManager.instance.stack;
            _volume = volumeStack.GetComponent<SpacingScalingVolume>();
        }

        public void Dispose()
        {
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var isPostProcessEnabled = renderingData.cameraData.postProcessEnabled;
            var isSceneViewCamera = renderingData.cameraData.isSceneViewCamera;
            if (!isActive || !isPostProcessEnabled || isSceneViewCamera)
            {
                return;
            }

            // TODO: Swap Bufferの検証
            var cmd = CommandBufferPool.Get(RenderPassName);
            cmd.Clear();
            using (new ProfilingScope(cmd, _profilingSampler))
            {
                var source = renderingData.cameraData.renderer.cameraColorTarget;
                var cameraTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
                cameraTargetDescriptor.depthBufferBits = 0;

                // MTLTextureに変換したいので`RenderTexture`で取得を行う
                var mainRT = RenderTexture.GetTemporary(cameraTargetDescriptor);
                cmd.Blit(source, mainRT);

                // TODO: ネイティブで頑張る
                if (_volume.IsActive)
                {
                }

                // 書き戻す
                cmd.Blit(mainRT, source);
                RenderTexture.ReleaseTemporary(mainRT);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}
