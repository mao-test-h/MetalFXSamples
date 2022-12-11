import Foundation

/// NOTE:
/// - 以下2つの関数はC側で定義されているマクロ周りの都合から`UnityPluginRegister.m`で外部宣言されている
///     - `onUnityGfxDeviceEventInitialize`
///     - `onRenderEvent`

/// プラグインの初期化
/// NOTE: `OnGraphicsDeviceEvent -> kUnityGfxDeviceEventInitialize`のタイミングで呼び出される
@_cdecl("onUnityGfxDeviceEventInitialize")
func onUnityGfxDeviceEventInitialize() {
    let unityMetal = UnityGraphicsBridge.getUnityGraphicsMetalV1().pointee
    MetalPlugin.shared = MetalPlugin(with: unityMetal)
}

/// Unity側から GL.IssuePluginEvent を呼ぶとレンダリングスレッドから呼び出されるメソッド
@_cdecl("onRenderEvent")
func onRenderEvent(eventId: Int32) {
    MetalPlugin.shared.onRenderEvent(eventId: eventId)
}

// P/Invoke

@_cdecl("setRenderTarget")
func setRenderTarget(_ renderBuffer: UnityRenderBuffer) {
    MetalPlugin.shared.setRenderTarget(renderBuffer)
}
