import SwiftUI
import MetalKit

/// MTKViewの表示クラス
struct MetalView: UIViewRepresentable {

    typealias UIViewType = MTKView

    // MTKViewの生成

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.delegate = context.coordinator

        // デバイスの検索
        // 主にIntelMacなどでGPUが複数搭載されている端末を想定してデフォルトを決定しておく必要がある
        // ただ、iOS端末は基本的にデバイスが1つなのであまり考える必要はなさそう
        view.device = MTLCreateSystemDefaultDevice()

        // ClearColor
        // (デフォルトは黒)
        view.clearColor = MTLClearColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0)

        if let device = view.device {
            context.coordinator.setup(device: device, view: view)
        }

        return view
    }

    // Coordinatorの生成

    //
    // NOTE:
    // - Coordinatorとは「UIKitとSwiftUI」の橋渡し役であり、
    //   このコード場で言えば`Renderer`が該当する
    // - 一般的なやり方ではCoordinatorは入れ子クラスとして定義されることが多いが、
    //   今回はMetalと言う特性上、やることが多いので可読性の観点から別クラスに分けている
    func makeCoordinator() -> Renderer {
        return Renderer(self)
    }

    // 更新処理

    func updateUIView(_ uiView: MTKView, context: Context) {
        //
    }
}

struct MetalView_Previews: PreviewProvider {
    static var previews: some View {
        MetalView()
    }
}
