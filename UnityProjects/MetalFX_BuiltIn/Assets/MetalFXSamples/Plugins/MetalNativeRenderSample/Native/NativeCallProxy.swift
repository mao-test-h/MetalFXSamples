import Foundation

/// Unity側から GL.IssuePluginEvent を呼ぶとレンダリングスレッドから呼び出されるメソッド
///
/// NOTE:
/// - P/Invokeで呼び出される関数自体はマクロ周りの都合から`UnityPluginRegister.m`で宣言されている
/// - ここでは↑で返している外部宣言関数を実装しているだけ
@_cdecl("onRenderEvent")
public func onRenderEvent(eventId: Int32) {
    MetalPlugin.onRenderEvent(eventId: eventId)
}

// P/Invoke

@_cdecl("setRTCopyTargets")
public func setRTCopyTargets(_ src: UnsafeRawPointer?, _ dst: UnsafeRawPointer?) {
    MetalPlugin.setRTCopyTargets(src, dst)
}
