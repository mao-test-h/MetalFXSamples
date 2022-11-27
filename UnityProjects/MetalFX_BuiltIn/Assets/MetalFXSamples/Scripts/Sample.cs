using System.Collections;
using MetalFXSamples.Plugins.MetalNativeRenderSample.Managed;
using UnityEngine;

namespace MetalFXSamples.Scripts
{
    [RequireComponent(typeof(Camera))]
    public sealed class Sample : MonoBehaviour
    {
        Camera _targetCamera;
        INativeRender _nativeRender;

        private void Awake()
        {
            TryGetComponent(out _targetCamera);

#if UNITY_EDITOR
            _nativeRender = new NativeRenderForEditor();
            return;
#endif
            _nativeRender = new NativeProxyForIOS();
        }

        private void OnPostRender()
        {
            _nativeRender.DoExtraDrawCall();
            StartCoroutine(OnFrameEnd());
        }

        private IEnumerator OnFrameEnd()
        {
            yield return new WaitForEndOfFrame();

            // note that we do that AFTER all unity rendering is done.
            // it is especially important if AA is involved, as we will end encoder (resulting in AA resolve)
            _nativeRender.DoCopyRT(_targetCamera.targetTexture, null);
            yield return null;
        }
    }
}