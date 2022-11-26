using System.Collections;
using MetalFXSamples.Plugins.MetalNativeRenderSample.Managed;
using UnityEngine;

namespace MetalFXSamples.Scripts
{
    public sealed class Sample : MonoBehaviour
    {
        INativeRender _nativeRender;

        private void Awake()
        {
#if UNITY_EDITOR
            _nativeRender = new NativeRenderForEditor();
#elif UNITY_IOS
            _nativeRender = new NativeProxyForIOS();
#endif
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
            _nativeRender.DoCopyRT(GetComponent<Camera>().targetTexture, null);
            yield return null;
        }
    }
}