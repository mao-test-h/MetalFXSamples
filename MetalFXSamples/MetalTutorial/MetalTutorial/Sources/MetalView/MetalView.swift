import SwiftUI
import MetalKit

/// SwiftUIでのMTKView表示クラス
///
/// NOTE: SwiftUIでMTKViewに相当するViewが無いので自作している
struct MetalView: UIViewRepresentable {

    typealias UIViewType = MTKView

    /// MTKViewの生成
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.delegate = context.coordinator

        // デバイスの検索
        // 主にIntelMacと言ったGPUが複数搭載される想定のある端末を想定してデフォルトを決定しておく必要がある
        // ただ、iOS端末は基本的にデバイスが1つなのであまり考える必要はなさそう
        view.device = MTLCreateSystemDefaultDevice()

        // ClearColor(デフォルトは黒)
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 1, alpha: 1)

        if let device = view.device {
            context.coordinator.setup(device: device, view: view)
        }

        return view
    }

    /// Coordinatorの生成
    ///
    /// NOTE:
    /// - Coordinatorとは「UIKitとSwiftUI」の橋渡し役であり、この実装で言えば`Renderer`が該当する
    /// - 一般的なやり方ではCoordinatorは入れ子クラスとして定義されることが多いが、
    ///   今回は実装が大きいので別クラスに分けて定義している
    func makeCoordinator() -> Renderer {
        return Renderer(self)
    }

    /// Viewの更新処理
    func updateUIView(_ uiView: MTKView, context: Context) {
        // do noting
    }
}

/// MetalViewのCoordinatorクラス
class Renderer: NSObject, MTKViewDelegate {

    // 表示するSwiftUIのView
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
        commandQueue = device.makeCommandQueue()
        setupPipelineState(device: device, view: view)
    }

    func setupPipelineState(device: MTLDevice, view: MTKView) {

        // 自動的にロードされたライブラリの取得
        //
        // NOTE:
        // プロジェクトに組み込まれたシェーダーはアプリビルド時に以下の流れでライブラリが生成される
        // > ソースコード(.metal) -> 中間オブジェクト(.air) -> ライブラリ(.metallib)
        // その上でビルドされたライブラリはアプリに組み込まれ、起動時に自動でロードされる
        guard let library = device.makeDefaultLibrary() else {
            return
        }

        // シェーダー関数はライブラリに格納されているので、名前指定で取得する
        //
        // NOTE: ここで指定している`vertexShader`と`fragmentShader`は別途実装しているシェーダーファイル(Shader.metal)を参照
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
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineStateDesc)
        } catch let error {
            print(error)
        }
    }

    /// Viewのサイズが変わるときに発火されるイベント
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {

        // ビューポートに指定するサイズは`Drawable`のサイズであり、こちらのプロトコルメソッドから取得可能
        viewportSize = size

        // 表示する三角形の頂点を設定
        let wh = Float(min(size.width, size.height))
        let v1 = ShaderVertex(position: vector_float2(0.0, wh / 4.0), color: vector_float4(1.0, 0.0, 0.0, 1.0))
        let v2 = ShaderVertex(position: vector_float2(-wh / 4.0, -wh / 4.0), color: vector_float4(0.0, 1.0, 0.0, 1.0))
        let v3 = ShaderVertex(position: vector_float2(wh / 4.0, -wh / 4.0), color: vector_float4(0.0, 0.0, 1.0, 1.0))
        vertices = [v1, v2, v3]
    }

    /// Metalの描画イベント
    func draw(in view: MTKView) {

        // コマンドバッファの生成
        guard let cmdBuffer = commandQueue?.makeCommandBuffer() else {
            return
        }

        // ここで`MTKView`自身が発行する描画コマンド(RenderPassDescriptor)を取得
        guard let renderPassDesc = view.currentRenderPassDescriptor else {
            return
        }

        // 取得した`RenderPassDescriptor`から描画エンコーダーを作成
        guard let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc) else {
            return
        }

        // ビューポートの設定
        //
        // NOTE: Metalは左手系
        let viewport = MTLViewport(
            originX: 0, originY: 0,
            width: Double(viewportSize.width), height: Double(viewportSize.height),
            znear: 0.0, zfar: 1.0)
        encoder.setViewport(viewport)

        // `drawPrimitives`を呼び出す一連の流れを設定
        if let pipeline = pipelineState {

            // PSOを設定
            // → これによりPSO作成時に指定したVertex/Fragment関数が実行されるようになる
            encoder.setRenderPipelineState(pipeline)

            // Vertex関数の引数を設定
            //
            // NOTE: ここで使う`setVertexBytes`はVRAMに於ける一時領域っぽく、小さなデータをコピーする目的で設計されているっぽい(4KBまで)
            encoder.setVertexBytes(
                vertices,
                length: MemoryLayout<ShaderVertex>.size * vertices.count,
                index: kShaderVertexInputIndexVertices)

            var vpSize = vector_float2(
                Float(viewportSize.width / 2.0),
                Float(viewportSize.height / 2.0))

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

struct MetalView_Previews: PreviewProvider {
    static var previews: some View {
        MetalView()
    }
}
