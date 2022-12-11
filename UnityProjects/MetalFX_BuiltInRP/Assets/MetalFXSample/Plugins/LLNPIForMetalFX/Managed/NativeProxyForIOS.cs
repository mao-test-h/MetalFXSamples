using System;
using System.Runtime.InteropServices;
using UnityEngine;

namespace MetalFXSample.Plugins.LLNPIForMetalFX.Managed
{
    public sealed class NativeProxyForIOS : INativeProxy
    {
        public void DoExtraDrawCall()
        {
            CallRenderEventFunc(EventType.ExtraDrawCall);
        }

        public void DoCopyRT(RenderTexture srcRT, RenderTexture dstRT)
        {
            [DllImport("__Internal", EntryPoint = "setRTCopyTargets")]
            static extern void SetRTCopyTargets(IntPtr src, IntPtr dst);

            var src = srcRT ? srcRT.colorBuffer : Display.main.colorBuffer;
            var dst = dstRT ? dstRT.colorBuffer : Display.main.colorBuffer;
            SetRTCopyTargets(src.GetNativeRenderBufferPtr(), dst.GetNativeRenderBufferPtr());

            CallRenderEventFunc(EventType.CopyRTtoRT);
        }

        /// <summary>
        /// サンプルのレンダリングイベント
        /// </summary>
        private enum EventType
        {
            /// <summary>
            /// Unityが持つレンダーターゲットに対して、追加で描画イベントの呼び出しを行う
            /// </summary>
            /// <remarks>Unityが実行する既存の描画をフックし、追加の描画を行うサンプル</remarks>
            ExtraDrawCall = 0,

            /// <summary>
            /// `src`を内部的なテクスチャにコピーし、それを`dst`上の矩形に対し描画する
            /// </summary>
            /// <remarks>独自のエンコーダーを実行する幾つかの例</remarks>
            CopyRTtoRT,
        }

        private static void CallRenderEventFunc(EventType eventType)
        {
            [DllImport("__Internal", EntryPoint = "getRenderEventFunc")]
            static extern IntPtr GetRenderEventFunc();

            GL.IssuePluginEvent(GetRenderEventFunc(), (int)eventType);
        }
    }
}