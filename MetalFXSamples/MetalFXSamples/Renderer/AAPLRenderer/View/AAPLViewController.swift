import UIKit
import SwiftUI
import MetalKit

class AAPLViewController: UIViewController {
    var renderer: AAPLRenderer!

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }

        // MTKViewはUIKitベースで一番下に追加
        let mtkView = MTKView(frame: view.bounds, device: defaultDevice)
        view.addSubview(mtkView)

        // パラメータの操作部はSwiftUIで上に重ねて実装
        let contentsController = UIHostingController(rootView: AAPLContents())
        guard let contents = contentsController.view else {
            return
        }

        view.addSubview(contents)
        contents.backgroundColor = .clear
        contents.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contents.topAnchor.constraint(equalTo: view.topAnchor),
            contents.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: contents.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: contents.bottomAnchor)
        ])

        guard let newRenderer = AAPLRenderer(metalKitView: mtkView) else {
            print("The app is unable to create the renderer.")
            return
        }

        renderer = newRenderer
        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)
        mtkView.delegate = renderer
    }
}
