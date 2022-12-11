import Foundation
import Metal

final class MetalPlugin {
    static var shared: MetalPlugin! = nil

    private enum EventId: Int32 {
        case extraDrawCall = 0
        case captureRT = 1
    }

    private let unityMetal: IUnityGraphicsMetalV1
    private let vertexShader: MTLFunction
    private let fragmentShaderColor: MTLFunction
    private let fragmentShaderTexture: MTLFunction
    private let verticesBuffer: MTLBuffer
    private let indicesBuffer: MTLBuffer
    private let vertexDesc: MTLVertexDescriptor

    // ExtraDrawCall
    private var extraDrawCallPixelFormat: MTLPixelFormat = .invalid
    private var extraDrawCallSampleCount: Int = 0
    private var extraDrawCallPipelineState: MTLRenderPipelineState? = nil

    // CaptureRT
    private var rtCopy: MTLTexture? = nil
    private var rtCopyPixelFormat: MTLPixelFormat = .invalid
    private var rtCopySampleCount: Int = 0
    private var rtCopyPipelineState: MTLRenderPipelineState? = nil
    private var copySrc: UnityRenderBuffer? = nil
    private var copyDst: UnityRenderBuffer? = nil

    init(with unityMetal: IUnityGraphicsMetalV1) {
        self.unityMetal = unityMetal

        guard let device: MTLDevice = unityMetal.MetalDevice() else {
            preconditionFailure("MTLDeviceが見つからない")
        }

        do {
            let library = try device.makeLibrary(source: Shader.shaderSrc, options: nil)
            guard let vertexShader = library.makeFunction(name: "vprog"),
                  let fragmentShaderColor = library.makeFunction(name: "fshader_color"),
                  let fragmentShaderTexture = library.makeFunction(name: "fshader_tex")
            else {
                preconditionFailure("シェーダーの読み込みで失敗")
            }

            self.vertexShader = vertexShader
            self.fragmentShaderColor = fragmentShaderColor
            self.fragmentShaderTexture = fragmentShaderTexture
        } catch let error {
            preconditionFailure(error.localizedDescription)
        }

        // pos.x pos.y uv.x uv.y
        let vertices: [Float] = [
            -1.0, 0.0, 0.0, 0.0,
            -1.0, -1.0, 0.0, 1.0,
            0.0, -1.0, 1.0, 1.0,
            0.0, 0.0, 1.0, 0.0,
        ]
        let indices: [UInt16] = [0, 1, 2, 2, 3, 0]
        let verticesLength = vertices.count * MemoryLayout<Float>.size
        let indicesLength = indices.count * MemoryLayout<UInt16>.size

        guard let verticesBuffer = device.makeBuffer(bytes: vertices, length: verticesLength, options: .cpuCacheModeWriteCombined),
              let indicesBuffer = device.makeBuffer(bytes: indices, length: indicesLength, options: .cpuCacheModeWriteCombined)
        else {
            preconditionFailure("バッファの生成に失敗")
        }

        self.verticesBuffer = verticesBuffer
        self.indicesBuffer = indicesBuffer

        let vertexAttributeDesc = MTLVertexAttributeDescriptor()
        vertexAttributeDesc.format = .float4

        let vertexBufferLayoutDesc = MTLVertexBufferLayoutDescriptor()
        vertexBufferLayoutDesc.stride = 4 * MemoryLayout<Float>.size
        vertexBufferLayoutDesc.stepFunction = .perVertex
        vertexBufferLayoutDesc.stepRate = 1

        vertexDesc = MTLVertexDescriptor()
        vertexDesc.attributes[0] = vertexAttributeDesc
        vertexDesc.layouts[0] = vertexBufferLayoutDesc
    }

    func onRenderEvent(eventId: Int32) {
        switch EventId(rawValue: eventId)! {
        case .extraDrawCall:
            extraDrawCall()
            break
        case .captureRT:
            captureRT()
            break
        }
    }

    func setRTCopyTargets(_ src: UnityRenderBuffer, _ dst: UnityRenderBuffer) {
        copySrc = src
        copyDst = dst
    }

    /// MTLRenderPipelineState の生成
    ///
    /// NOTE:
    /// - 2つの描画イベントがあるが、 PipelineState は共通化している
    /// - 途中でレンダーターゲットのフォーマットなどが変わっても問題ないようにメソッド呼び出しで都度生成するようにしている
    private func createCommonRenderPipeline(
        label: String,
        fragmentShader: MTLFunction,
        format: MTLPixelFormat,
        sampleCount: Int) -> MTLRenderPipelineState {

        guard let device: MTLDevice = unityMetal.MetalDevice() else {
            preconditionFailure("MTLDeviceが見つからない")
        }

        let colorDesc = MTLRenderPipelineColorAttachmentDescriptor()
        colorDesc.pixelFormat = format

        let pipelineStateDesc = MTLRenderPipelineDescriptor()
        pipelineStateDesc.label = label
        pipelineStateDesc.vertexFunction = vertexShader
        pipelineStateDesc.vertexDescriptor = vertexDesc
        pipelineStateDesc.fragmentFunction = fragmentShader
        pipelineStateDesc.colorAttachments[0] = colorDesc
        pipelineStateDesc.rasterSampleCount = sampleCount

        do {
            return try device.makeRenderPipelineState(descriptor: pipelineStateDesc)
        } catch let error {
            preconditionFailure(error.localizedDescription)
        }
    }

    // MARK:- ExtraDrawCall

    /// Unityが持つレンダーターゲットに対して、追加で描画イベントの呼び出しを行う
    ///
    /// NOTE:
    /// - ここでは現在のレンダリングをフックし、単色の矩形を追加描画する例
    private func extraDrawCall() {
        // 現在のレンダリング情報を取得
        guard let desc = unityMetal.CurrentRenderPassDescriptor(),
              let rt: MTLTexture = desc.colorAttachments[0].texture,
              let cmdEncoder: MTLCommandEncoder = unityMetal.CurrentCommandEncoder()
        else {
            preconditionFailure("レンダリング情報の取得に失敗")
        }

        // 現在のレンダーパスの設定を取得し、レンダーターゲットの形式に変更があったら PipelineState を再生成する
        if (rt.pixelFormat != extraDrawCallPixelFormat || rt.sampleCount != extraDrawCallSampleCount) {
            extraDrawCallPixelFormat = rt.pixelFormat
            extraDrawCallSampleCount = rt.sampleCount
            extraDrawCallPipelineState = createCommonRenderPipeline(
                label: "ExtraDrawCall",
                fragmentShader: fragmentShaderColor,
                format: extraDrawCallPixelFormat,
                sampleCount: extraDrawCallSampleCount)
        }

        guard let extraDrawCallPipelineState = extraDrawCallPipelineState,
              let renderCmdEncoder = cmdEncoder as? MTLRenderCommandEncoder
        else {
            preconditionFailure("PipelineState の取得に失敗、若しくはCommandEncoderの形式が不正")
        }

        renderCmdEncoder.setRenderPipelineState(extraDrawCallPipelineState)
        renderCmdEncoder.setCullMode(.none)
        renderCmdEncoder.setVertexBuffer(verticesBuffer, offset: 0, index: 0)
        renderCmdEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: indicesBuffer,
            indexBufferOffset: 0)
    }

    // MARK:- CaptureRT

    /// `src`を内部的なテクスチャにコピーし、それを`dst`上の矩形に対し描画する
    ///
    /// NOTE:
    /// - Unityが実行するエンコーダーを完了させ、その後に独自のエンコーダーを実行する幾つかの例
    ///     - 1. `src` を `rtCopy` にコピー
    ///     - 2. `dst` 上に矩形を描画し、フラグメントシェーダーで `rtCopy` を描き込む
    private func captureRT() {
        if (copySrc == nil || copyDst == nil) {
            print("コピー対象のレンダーターゲットがまだ設定されていない");
            return
        }

        guard let device: MTLDevice = unityMetal.MetalDevice() else {
            preconditionFailure("MTLDeviceが見つからない")
        }

        // 独自のエンコーダーを作成する前に、Unityが持つエンコーダーを先に終了させる必要がある。
        // NOTE: ただし、これを行う場合にはUnityに制御を戻す前に自前で走らせたエンコーダーは終了させておく必要がある。
        unityMetal.EndCurrentCommandEncoder()

        // コピー対象のテクスチャを取得
        guard let copySrc = copySrc,
              let srcTexture: MTLTexture = getColorTexture(from: copySrc)
        else {
            preconditionFailure("コピー対象のテクスチャの取得に失敗")
        }

        // 必要に応じて `src` のコピー先を生成
        if rtCopy == nil ||
               rtCopy!.width != srcTexture.width ||
               rtCopy!.height != srcTexture.height ||
               rtCopy!.pixelFormat != srcTexture.pixelFormat {

            let texDesc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: srcTexture.pixelFormat,
                width: srcTexture.width,
                height: srcTexture.height,
                mipmapped: false)

            self.rtCopy = device.makeTexture(descriptor: texDesc)
        }

        guard let rtCopy = rtCopy else {
            preconditionFailure("コピー対象のテクスチャの生成に失敗している")
        }

        // BlitCommandEncoder を利用して `src` を `rtCopy` にコピーする
        if let cmdBuffer = unityMetal.CurrentCommandBuffer(),
           let blit = cmdBuffer.makeBlitCommandEncoder() {
            blit.copy(
                from: srcTexture,
                sourceSlice: 0,
                sourceLevel: 0,
                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                sourceSize: MTLSize(width: srcTexture.width, height: srcTexture.height, depth: 1),
                to: rtCopy,
                destinationSlice: 0,
                destinationLevel: 0,
                destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
            blit.endEncoding()
        } else {
            preconditionFailure("BlitCommandEncoder の実行に失敗")
        }

        // 書き込み先のテクスチャを取得
        guard let copyDst = copyDst,
              let dstTexture: MTLTexture = getColorTexture(from: copyDst)
        else {
            preconditionFailure("書き込み先のテクスチャの取得に失敗")
        }

        // NOTE: AAは既に解決済みであることを想定
        let colorAttachment = MTLRenderPassColorAttachmentDescriptor()
        colorAttachment.texture = dstTexture
        colorAttachment.loadAction = .load
        colorAttachment.storeAction = .store

        let desc = MTLRenderPassDescriptor()
        desc.colorAttachments[0] = colorAttachment

        // 書き込み先の設定を取得し、レンダーターゲットの形式に変更があったら PipelineState を再生成する
        if (dstTexture.pixelFormat != rtCopyPixelFormat || dstTexture.sampleCount != rtCopySampleCount) {
            rtCopyPixelFormat = dstTexture.pixelFormat
            rtCopySampleCount = dstTexture.sampleCount
            rtCopyPipelineState = createCommonRenderPipeline(
                label: "CaptureRT",
                fragmentShader: fragmentShaderTexture,
                format: rtCopyPixelFormat,
                sampleCount: rtCopySampleCount)
        }

        // RenderCommandEncoder を利用して `dst` 上に矩形を描画し、フラグメントシェーダーで`rtCopy`を描き込む
        if let cmdBuffer = unityMetal.CurrentCommandBuffer(),
           let cmd = cmdBuffer.makeRenderCommandEncoder(descriptor: desc),
           let rtCopyPipelineState = rtCopyPipelineState {
            cmd.setRenderPipelineState(rtCopyPipelineState)
            cmd.setCullMode(.none)
            cmd.setVertexBuffer(verticesBuffer, offset: 0, index: 0)
            cmd.setFragmentTexture(rtCopy, index: 0)
            cmd.drawIndexedPrimitives(
                type: .triangle,
                indexCount: 6,
                indexType: .uint16,
                indexBuffer: indicesBuffer,
                indexBufferOffset: 0)
            cmd.endEncoding()
        } else {
            preconditionFailure("RenderCommandEncoder の実行に失敗")
        }
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
