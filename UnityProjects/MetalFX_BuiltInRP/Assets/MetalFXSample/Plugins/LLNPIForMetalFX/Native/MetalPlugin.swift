import Foundation
import Metal
import MetalFX

final class MetalPlugin {
    static var shared: MetalPlugin! = nil

    private enum EventId: Int32 {
        case spatialScaling = 0
    }

    private let unityMetal: IUnityGraphicsMetalV1

    private var srcRenderBuffer: UnityRenderBuffer? = nil
    private var dstTexture: MTLTexture? = nil
    private var mfxSpatialScaler: MTLFXSpatialScaler? = nil

    init(with unityMetal: IUnityGraphicsMetalV1) {
        self.unityMetal = unityMetal
    }

    func onRenderEvent(eventId: Int32) {
        switch EventId(rawValue: eventId)! {
        case .spatialScaling:
            spatialScaling()
            break
        }
    }

    func setRenderTarget(_ src: UnityRenderBuffer) {
        srcRenderBuffer = src
    }

    private func spatialScaling() {
        if (srcRenderBuffer == nil) {
            print("ソースがまだ設定されていない");
            return
        }

        guard let device: MTLDevice = unityMetal.MetalDevice() else {
            preconditionFailure("MTLDeviceが見つからない")
        }

        unityMetal.EndCurrentCommandEncoder()


        // コピー対象のテクスチャを取得
        guard let srcRenderBuffer = srcRenderBuffer,
              let srcTexture: MTLTexture = getColorTexture(from: srcRenderBuffer)
        else {
            preconditionFailure("スケーリング対象のテクスチャの取得に失敗")
        }

        let srcWidth = srcTexture.width
        let srcHeight = srcTexture.height
        let srcPixelFormat = srcTexture.pixelFormat

        // 必要に応じて `src` のコピー先を生成
        if dstTexture == nil ||
               mfxSpatialScaler == nil ||
               dstTexture!.width != srcWidth ||
               dstTexture!.height != srcHeight ||
               dstTexture!.pixelFormat != srcPixelFormat {

            let texDesc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: srcPixelFormat,
                width: srcWidth,
                height: srcHeight,
                mipmapped: false)
            dstTexture = device.makeTexture(descriptor: texDesc)

            let desc = MTLFXSpatialScalerDescriptor()
            desc.inputWidth = srcWidth
            desc.inputHeight = srcHeight
            desc.outputWidth = srcWidth * 2
            desc.outputHeight = srcHeight * 2
            desc.colorTextureFormat = srcPixelFormat
            desc.outputTextureFormat = srcPixelFormat
            desc.colorProcessingMode = .linear

            guard let spatialScaler = desc.makeSpatialScaler(device: device) else {
                preconditionFailure("The spatial scaler effect is not usable")
            }

            mfxSpatialScaler = spatialScaler
        }

        guard let dstTexture = dstTexture,
              let cmdBuffer = unityMetal.CurrentCommandBuffer(),
              let mfxSpatialScaler = mfxSpatialScaler
        else {
            preconditionFailure("コピー対象のテクスチャの生成に失敗している")
        }

        mfxSpatialScaler.colorTexture = srcTexture
        mfxSpatialScaler.outputTexture = dstTexture
        mfxSpatialScaler.encode(commandBuffer: cmdBuffer)
    }

    /// UnityRenderBuffer から MTLTexture を取得
    ///
    /// - Parameter renderBuffer: 対象の UnityRenderBuffer
    /// - Returns: 取得に成功した MTLTexture を返す (失敗時はnil)
    ///
    /// NOTE:
    /// - 渡すバッファの条件によって呼び出す関数が変わるので分岐を挟んでいる
    /// - 例えば前者の `AAResolvedTextureFromRenderBuffer` はAAが掛かっている必要がある
    ///     - 非AAのバッファやDepth形式のバッファを渡すとnilが返ってくるとのこと (詳しくは関数のコメント参照)
    private func getColorTexture(from renderBuffer: UnityRenderBuffer) -> MTLTexture? {
        if let texture = unityMetal.AAResolvedTextureFromRenderBuffer(renderBuffer) {
            return texture
        } else {
            if let texture = unityMetal.TextureFromRenderBuffer(renderBuffer) {
                return texture
            } else {
                return nil
            }
        }
    }
}
