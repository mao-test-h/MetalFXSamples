using System.Collections;
using MetalFXSample.Plugins.LLNPIForMetalFX.Managed;
using UnityEngine;
using UnityEngine.Assertions;

namespace MetalFXSample.Scripts
{
    [RequireComponent(typeof(Camera))]
    internal sealed class Sample : MonoBehaviour
    {
        private Camera _targetCamera;
        private INativeProxy _nativeProxy;

        private void Awake()
        {
            TryGetComponent(out _targetCamera);
            Assert.IsTrue(_targetCamera != null);

#if UNITY_EDITOR
            _nativeProxy = new NativeProxyForEditor();
#elif UNITY_IOS
            _nativeProxy = new NativeProxyForIOS();
#endif
        }

        private void OnPostRender()
        {
            StartCoroutine(OnFrameEnd());
        }

        private IEnumerator OnFrameEnd()
        {
            yield return new WaitForEndOfFrame();
            _nativeProxy.DoSpatialScaling(_targetCamera.targetTexture);
            yield return null;
        }
    }
}