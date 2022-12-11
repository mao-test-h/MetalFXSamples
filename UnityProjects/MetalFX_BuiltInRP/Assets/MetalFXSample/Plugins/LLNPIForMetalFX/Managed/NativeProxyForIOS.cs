using System;
using System.Runtime.InteropServices;
using UnityEngine;

namespace MetalFXSample.Plugins.LLNPIForMetalFX.Managed
{
    public sealed class NativeProxyForIOS : INativeProxy
    {
        void INativeProxy.DoSpatialScaling(RenderTexture renderTexture)
        {
            [DllImport("__Internal", EntryPoint = "setRenderTarget")]
            static extern void SetRenderTarget(IntPtr renderTexture);

            var src = renderTexture ? renderTexture.colorBuffer : Display.main.colorBuffer;
            SetRenderTarget(src.GetNativeRenderBufferPtr());
            CallRenderEventFunc(EventType.SpatialScaling);
        }

        private enum EventType
        {
            SpatialScaling = 0,
        }

        private static void CallRenderEventFunc(EventType eventType)
        {
            [DllImport("__Internal", EntryPoint = "getRenderEventFunc")]
            static extern IntPtr GetRenderEventFunc();

            GL.IssuePluginEvent(GetRenderEventFunc(), (int)eventType);
        }
    }
}