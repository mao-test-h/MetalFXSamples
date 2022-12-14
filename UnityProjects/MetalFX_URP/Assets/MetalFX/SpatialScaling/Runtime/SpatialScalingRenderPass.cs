#if UNITY_IOS && !UNITY_EDITOR
#define IOS_ONLY
using System.Runtime.InteropServices;
#endif

using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MetalFX.SpatialScaling.Runtime
{
    sealed class SpatialScalingRenderPass : ScriptableRenderPass, IDisposable
    {
        const string RenderPassName = "MetalFX_SpatialScaling";
        readonly ProfilingSampler _profilingSampler;
        readonly SpatialScalingVolume _volume;

        RenderTexture _srcRT = null;
        RenderTexture _dstRT = null;

        bool isActive => (_volume != null && _volume.IsActive);

        public SpatialScalingRenderPass()
        {
            renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
            _profilingSampler = new ProfilingSampler(RenderPassName);

            var volumeStack = VolumeManager.instance.stack;
            _volume = volumeStack.GetComponent<SpatialScalingVolume>();
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

            var cmd = CommandBufferPool.Get(RenderPassName);
            cmd.Clear();
            using (new ProfilingScope(cmd, _profilingSampler))
            {
                var source = renderingData.cameraData.renderer.cameraColorTarget;
                var cameraTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
                cameraTargetDescriptor.depthBufferBits = 0;

                // NOTE: `RenderTexture.GetTemporary`を使うとネイティブ側で怒られたので`RenderTexture`を作ってる
                if (_srcRT == null || _dstRT == null)
                {
                    _srcRT = new RenderTexture(cameraTargetDescriptor);

                    // NOTE: RenderScaleが0.5であることを期待して等倍に戻している
                    var dstDescriptor = new RenderTextureDescriptor(
                        cameraTargetDescriptor.width * 2,
                        cameraTargetDescriptor.height * 2);
                    _dstRT = new RenderTexture(dstDescriptor);
                }

                // NOTE: `dst`側にもBlitしないとnullの状態でnativeに渡される？
                cmd.Blit(source, _srcRT);
                cmd.Blit(source, _dstRT);

#if IOS_ONLY
                if (_volume.IsActive)
                {
                    [DllImport("__Internal", EntryPoint = "callMetalFX_SpatialScaling")]
                    static extern void CallNativeMethod(IntPtr srcTexture, IntPtr dstTexture);

                    // ネイティブ側にてscalingした結果を`dst`に書き込む
                    CallNativeMethod(_srcRT.GetNativeTexturePtr(), _dstRT.GetNativeTexturePtr());
                }
#endif
                cmd.Blit(_dstRT, source);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}