import Foundation
import Metal
import MetalFX

final class MetalPlugin {
    static var shared: MetalPlugin! = nil

    private enum EventId: Int32 {
        case spatialScaling = 0
    }

    private let unityMetal: IUnityGraphicsMetalV1
    private var renderBuffer: UnityRenderBuffer? = nil

    private var upscaledTexture: MTLTexture? = nil
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

    func setRenderTarget(_ renderBuffer: UnityRenderBuffer) {
        self.renderBuffer = renderBuffer
    }

    // MARK:- Private Methods

    private func spatialScaling() {
        if (renderBuffer == nil) {
            print("`renderBuffer`が未設定");
            return
        }

        guard let device: MTLDevice = unityMetal.MetalDevice() else {
            preconditionFailure("MTLDeviceが見つからない")
        }

        unityMetal.EndCurrentCommandEncoder()

        // コピー対象のテクスチャを取得
        guard let renderBuffer = renderBuffer,
              let renderTarget: MTLTexture = getColorTexture(from: renderBuffer)
        else {
            preconditionFailure("`renderTarget`の取得に失敗")
        }

        // TODO: 雑に2倍にスケーリング
        let srcWidth = renderTarget.width
        let srcHeight = renderTarget.height
        let dstWidth = renderTarget.width * 2
        let dstHeight = renderTarget.height * 2
        let pixelFormat = renderTarget.pixelFormat

        // 必要に応じて `src` のコピー先を生成
        if (upscaledTexture == nil ||
            mfxSpatialScaler == nil ||
            upscaledTexture!.width != dstWidth ||
            upscaledTexture!.height != dstHeight ||
            upscaledTexture!.pixelFormat != pixelFormat) {

            let texDesc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: pixelFormat, width: dstWidth, height: dstHeight, mipmapped: false)
            upscaledTexture = device.makeTexture(descriptor: texDesc)

            let scalerDesc = MTLFXSpatialScalerDescriptor()
            scalerDesc.inputWidth = srcWidth
            scalerDesc.inputHeight = srcHeight
            scalerDesc.outputWidth = dstWidth
            scalerDesc.outputHeight = dstHeight
            scalerDesc.colorTextureFormat = pixelFormat
            scalerDesc.outputTextureFormat = pixelFormat
            scalerDesc.colorProcessingMode = .perceptual

            guard let spatialScaler = scalerDesc.makeSpatialScaler(device: device) else {
                preconditionFailure("The spatial scaler effect is not usable")
            }

            mfxSpatialScaler = spatialScaler
        }

        guard let upscaledTexture = upscaledTexture,
              let cmdBuffer = unityMetal.CurrentCommandBuffer(),
              let mfxSpatialScaler = mfxSpatialScaler
        else {
            preconditionFailure("書き込み先のテクスチャの生成に失敗、若しくはスケーラーの生成で失敗")
        }

        mfxSpatialScaler.colorTexture = renderTarget
        mfxSpatialScaler.outputTexture = upscaledTexture
        mfxSpatialScaler.encode(commandBuffer: cmdBuffer)

        // TODO: 雑にBlitで描き込む (一応描画はされるが表示が拡大後なのでおかしい)
        if let blit = cmdBuffer.makeBlitCommandEncoder() {
            blit.copy(
                from: upscaledTexture,
                sourceSlice: 0,
                sourceLevel: 0,
                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                sourceSize: MTLSize(width: srcWidth, height: srcHeight, depth: 1),
                to: renderTarget,
                destinationSlice: 0,
                destinationLevel: 0,
                destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
            blit.endEncoding()
        } else {
            preconditionFailure("BlitCommandEncoder の実行に失敗")
        }
    }

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
