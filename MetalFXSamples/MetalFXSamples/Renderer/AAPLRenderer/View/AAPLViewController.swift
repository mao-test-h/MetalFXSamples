import UIKit
import SwiftUI
import MetalKit
import Combine

class AAPLViewController: UIViewController {
    private var renderer: AAPLRenderer!

    private let contentsState = AAPLContentsState()
    private var cancellableSet = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }

        // MTKViewはUIKitベースで一番下に追加
        let mtkView = MTKView(frame: view.bounds, device: defaultDevice)
        view.addSubview(mtkView)

        // パラメータの操作部はSwiftUIで上に重ねて実装
        let contentsController = UIHostingController(rootView: AAPLContents(with: contentsState))
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

        binding()
    }

    private func binding() {
        contentsState.$selectedScalingModeIndex.sink { [weak self] value in
                guard let self = self else {
                    return
                }

                // Save the current mode to configure MetalFX if the combo button changes.
                let previousScalingMode = self.renderer.mfxScalingMode

                // Set the current scaling mode.
                let currentScalingMode = AAPLScalingMode(rawValue: value)!
                self.renderer.mfxScalingMode = currentScalingMode

                if previousScalingMode != self.renderer.mfxScalingMode {
                    self.renderer.setupMetalFX()
                }
            }
            .store(in: &cancellableSet)

        contentsState.$resetHistorySwitch.sink { [weak self] value in
                guard let self = self else {
                    return
                }

                self.renderer.resetHistoryEnabled = value
            }
            .store(in: &cancellableSet)


        contentsState.$animationSwitch.sink { [weak self] value in
                guard let self = self else {
                    return
                }

                self.renderer.animationEnabled = value
            }
            .store(in: &cancellableSet)

        contentsState.$proceduralTextureSwitch.sink { [weak self] value in
                guard let self = self else {
                    return
                }

                self.renderer.proceduralTextureEnabled = value
            }
            .store(in: &cancellableSet)

        contentsState.$renderScaleSlider.sink { [weak self] value in
                guard let self = self else {
                    return
                }

                self.renderer.adjustRenderScale(value)
                let scale = self.renderer.renderTarget.renderScale
                self.contentsState.renderScaleLabel = String(format: "% 3d%%", arguments: [Int(scale * 100)])
            }
            .store(in: &cancellableSet)


        contentsState.$mipBiasSlider.sink { [weak self] value in
                guard let self = self else {
                    return
                }

                self.renderer.textureMipmapBias = value
                self.contentsState.mipBiasLabel = String(format: "% 1.3f", arguments: [value])
            }
            .store(in: &cancellableSet)

    }
}

final class AAPLContentsState: ObservableObject {
    @Published var selectedScalingModeIndex: Int = 0

    @Published var resetHistorySwitch: Bool = false
    @Published var animationSwitch: Bool = false
    @Published var proceduralTextureSwitch: Bool = false

    @Published var renderScaleSlider: Float = 0.5
    @Published var renderScaleLabel: String = "0%"

    @Published var mipBiasSlider: Float = -1
    @Published var mipBiasLabel: String = "-1.000"
}