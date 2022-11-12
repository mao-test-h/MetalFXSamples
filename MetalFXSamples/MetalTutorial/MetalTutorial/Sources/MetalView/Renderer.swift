import Foundation
import MetalKit

class Renderer: NSObject, MTKViewDelegate {

    let present: MetalView

    // GPUに送信するコマンドを積むQueue
    var commandQueue: MTLCommandQueue?

    // PSO (PipelineStateObject)
    var pipelineState: MTLRenderPipelineState?

    // ビューポート
    var viewportSize = CGSize()

    // 頂点
    var vertices: [ShaderVertex] = [ShaderVertex]()


    init(_ present: MetalView) {
        self.present = present
    }

    func setup(device: MTLDevice, view: MTKView) {
        self.commandQueue = device.makeCommandQueue()
        setupPipelineState(device: device, view: view)
    }

    func setupPipelineState(device: MTLDevice, view: MTKView) {

        // 自動的にロードされたライブラリの取得
        //
        // NOTE:
        // プロジェクトに登録されたシェーダはアプリのビルド時にビルド+ライブラリが生成されアプリに組み込まれる。
        // 組み込まれたライブラリは自動的にロードされるので、イ
        guard let library = device.makeDefaultLibrary() else {
            return
        }

        // シェーダー関数はライブラリに格納されているので、名前指定で取得する
        //
        // NOTE: ここで指定している`vertexShader`と`fragmentShader`は別途実装しているシェーダーファイルを参照
        guard let vertexFunc = library.makeFunction(name: "vertexShader"),
              let fragmentFunc = library.makeFunction(name: "fragmentShader")
        else {
            return
        }

        // PSO(Pipeline State Object)の作成
        //
        // NOTE: `label`は任意だが、指定しておくとデバッグ時に便利
        let pipelineStateDesc = MTLRenderPipelineDescriptor()
        pipelineStateDesc.label = "Triangle Pipeline"
        pipelineStateDesc.vertexFunction = vertexFunc
        pipelineStateDesc.fragmentFunction = fragmentFunc
        pipelineStateDesc.colorAttachments[0].pixelFormat = view.colorPixelFormat

        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineStateDesc)
        } catch let error {
            print(error)
        }
    }

    // NOTE: ビューのサイズが変わるときに発火

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {

        // ビューポートに指定するサイズは`Drawable`のサイズであり、こちらのプロトコルメソッドから取得可能
        self.viewportSize = size

        // 表示する三角形の頂点を設定
        let wh = Float(min(size.width, size.height))
        let v1 = ShaderVertex(position: vector_float2(0.0, wh / 4.0), color: vector_float4(1.0, 0.0, 0.0, 1.0))
        let v2 = ShaderVertex(position: vector_float2(-wh / 4.0, -wh / 4.0), color: vector_float4(0.0, 1.0, 0.0, 1.0))
        let v3 = ShaderVertex(position: vector_float2(wh / 4.0, -wh / 4.0), color: vector_float4(0.0, 0.0, 1.0, 1.0))
        self.vertices = [v1, v2, v3]
    }

    // 描画イベント

    func draw(in view: MTKView) {

        // コマンドバッファの生成
        guard let cmdBuffer = self.commandQueue?.makeCommandBuffer() else {
            return
        }

        // ここで`MTKView`自身が発行する描画コマンド(RenderPassDescriptor)を取得
        guard let renderPassDesc = view.currentRenderPassDescriptor else {
            return
        }

        // 取得した`RenderPassDescriotor`から描画エンコーダーを作成
        guard let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc) else {
            return
        }

        // ビューポートの設定
        //
        // NOTE: Metalは左手系
        let viewport = MTLViewport(
            originX: 0, originY: 0,
            width: Double(self.viewportSize.width),
            height: Double(self.viewportSize.height),
            znear: 0.0, zfar: 1.0)
        encoder.setViewport(viewport)

        //
        if let pipeline = self.pipelineState {
            // PSOを設定 (これによりPSO作成時に指定したVertex/Fragment関数が実行されるようになる)
            encoder.setRenderPipelineState(pipeline)

            // Vertex関数の引数を設定
            //
            // NOTE: ここで使う`setVertexBytes`はVRAMに於ける一時領域っぽく、小さなデータをコピーする目的で設計されているっぽい(4KBまで)
            encoder.setVertexBytes(
                self.vertices,
                length: MemoryLayout<ShaderVertex>.size * self.vertices.count,
                index: kShaderVertexInputIndexVertices)

            var vpSize = vector_float2(
                Float(self.viewportSize.width / 2.0),
                Float(self.viewportSize.height / 2.0))

            encoder.setVertexBytes(
                &vpSize,
                length: MemoryLayout<vector_float2>.size,
                index: kShaderVertexInputIndexViewportSize)

            // 三角形を描画
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        }

        // エンコードを完了させる
        encoder.endEncoding()

        // 上記の流れで結果がフレームに書き込まれるので、そのフレームを表示するためにこちらを`MTLDrawable`に書き込む
        // → `MTKView.currentDrawable`にて`MTKView`自身の`MTLDrawable`を取得可能
        if let drawable = view.currentDrawable {
            cmdBuffer.present(drawable)
        }

        // ここまでの流れを実行する
        cmdBuffer.commit()
    }
}
