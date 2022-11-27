using System;
using System.Runtime.InteropServices;
using UnityEngine;

namespace MetalFXSamples.Plugins.MetalNativeRenderSample.Managed
{
    public sealed class NativeProxyForIOS : INativeRender
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

        // we will do several pretty useless events to show the usage of all api functions
        private enum EventType
        {
            // will do an extra draw call to currently setup rt with custom shader
            ExtraDrawCall = 0,

            // copy src rt to internal texture and draws rect using it to dst r
            CopyRTtoRT
        }

        private static void CallRenderEventFunc(EventType eventType)
        {
            [DllImport("__Internal", EntryPoint = "getRenderEventFunc")]
            static extern IntPtr GetRenderEventFunc();

            GL.IssuePluginEvent(GetRenderEventFunc(), (int)eventType);
        }
    }
}