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
            _nativeProxy.DoExtraDrawCall();
            StartCoroutine(OnFrameEnd());
        }

        private IEnumerator OnFrameEnd()
        {
            yield return new WaitForEndOfFrame();

            // こちらのイベントはUnityが実行する全てのレンダリングが完了した後に呼び出す必要がある。
            // (AAが関係している場合には特に重要であり、ネイティブ側でエンコーダーを終了することによってAAの解決が行われる)
            _nativeProxy.DoCopyRT(_targetCamera.targetTexture, null);
            yield return null;
        }
    }
}