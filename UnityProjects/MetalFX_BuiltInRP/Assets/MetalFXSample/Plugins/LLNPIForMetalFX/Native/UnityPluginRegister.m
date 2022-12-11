#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import "UnityAppController.h"
#import "UnityFramework.h"

#include "Unity/IUnityInterface.h"
#include "Unity/IUnityGraphics.h"
#include "Unity/IUnityGraphicsMetal.h"


// MARK:- P/Invoke

// NOTE:
// - ここではC側で定義されてるシンボルが必要な関数のみ宣言する
//     - それ以外はSwift側の`NativeCallProxy`に定義すること

extern void onUnityGfxDeviceEventInitialize();

extern void onRenderEvent();

// GL.IssuePluginEvent で登録するコールバック関数のポインタを返す
UnityRenderingEvent UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API getRenderEventFunc() {
    // Swift側で実装している`onRenderEvent`を返す
    return onRenderEvent;
}



// MARK:- Low-level native plug-in interface

static IUnityInterfaces* g_UnityInterfaces = 0;
static IUnityGraphics* g_Graphics = 0;

// NB finally in 2017.4 we switched to versioned metal plugin interface
// NB old unversioned interface will be still provided for some time for backwards compatibility
static IUnityGraphicsMetalV1* g_MetalGraphics = 0;

static void UNITY_INTERFACE_API OnGraphicsDeviceEvent(UnityGfxDeviceEventType eventType) {
    switch (eventType) {
        case kUnityGfxDeviceEventInitialize:
            assert(g_Graphics->GetRenderer() == kUnityGfxRendererMetal);
            onUnityGfxDeviceEventInitialize();
            break;
        default:
            // ignore others
            break;
    }
}

// Pluginのロードイベント
void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API UnityPluginLoad(IUnityInterfaces* unityInterfaces) {
    g_UnityInterfaces = unityInterfaces;
    g_Graphics = UNITY_GET_INTERFACE(g_UnityInterfaces, IUnityGraphics);
    g_MetalGraphics = UNITY_GET_INTERFACE(g_UnityInterfaces, IUnityGraphicsMetalV1);

    // IUnityGraphics にイベントを登録
    // NOTE: kUnityGfxDeviceEventInitialize の後にプラグインのロードを受けるので、コールバックは手動で行う必要があるとのこと
    g_Graphics->RegisterDeviceEventCallback(OnGraphicsDeviceEvent);
    OnGraphicsDeviceEvent(kUnityGfxDeviceEventInitialize);
}

// Pluginのアンロードイベント
void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API UnityPluginUnload() {
    g_Graphics->UnregisterDeviceEventCallback(OnGraphicsDeviceEvent);
}



// MARK:- UnityGraphicsBridgeの実装

// NOTE:
// - Swiftからアクセスしたいので、@interface の宣言は UmbrellaHeaderである `UnityFramework.h` にある

@implementation UnityGraphicsBridge {
}
+ (IUnityGraphicsMetalV1*)getUnityGraphicsMetalV1 {
    return g_MetalGraphics;
}
@end



// MARK:- UnityPluginLoad と UnityPluginUnload の登録 (iOSのみ)

// Unityが UnityAppController と言う UIApplicationDelegate の実装クラスを持っているので、
// メンバ関数である shouldAttachRenderDelegate をオーバーライドすることで登録を行う必要がある。
@interface MyAppController : UnityAppController {
}
- (void)shouldAttachRenderDelegate;
@end

@implementation MyAppController

- (void)shouldAttachRenderDelegate {
    // NOTE: iOSはデスクトップとは違い、自動的にロードされて登録されないので手動で行う必要がある。
    UnityRegisterRenderingPluginV5(&UnityPluginLoad, &UnityPluginUnload);
}
@end

// 定義したサブクラスはこちらのマクロを経由して老録する必要がある
IMPL_APP_CONTROLLER_SUBCLASS(MyAppController);
