import Metal
import MetalFX

final class MTLHelper {
    private static var mfxSpatialScaler: MTLFXSpatialScaler? = nil
    private static var commandQueue: MTLCommandQueue? = nil

    public static func callSpatialScaling(
        _ srcTexture: MTLTexture, _ dstTexture: MTLTexture,
        _ width: Int32, _ height: Int32) {

        if mfxSpatialScaler == nil {
            let desc = MTLFXSpatialScalerDescriptor()
            desc.inputWidth = Int(width)
            desc.inputHeight = Int(height)
            desc.outputWidth = Int(width) * 2
            desc.outputHeight = Int(height) * 2
            desc.colorTextureFormat = .bgra8Unorm
            desc.outputTextureFormat = .bgra8Unorm
            desc.colorProcessingMode = .linear

            let mtlDevice = MTLCreateSystemDefaultDevice()!
            guard let spatialScaler = desc.makeSpatialScaler(device: mtlDevice) else {
                print("The spatial scaler effect is not usable")
                return
            }

            mfxSpatialScaler = spatialScaler
            commandQueue = mtlDevice.makeCommandQueue()
        }

        guard let spatialScaler = mfxSpatialScaler,
              let commandQueue = commandQueue,
              let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            print("Error in make CommandBuffer")
            return
        }

        spatialScaler.colorTexture = srcTexture
        spatialScaler.outputTexture = dstTexture
        spatialScaler.encode(commandBuffer: commandBuffer)

        commandBuffer.commit()
    }
}

@_cdecl("callMetalFX_SpatialScaling")
func callMetalFX_SpatialScaling(
    _ srcTexturePtr: UnsafeRawPointer?,
    _ dstTexturePtr: UnsafeRawPointer?,
    _ width: Int32, _ height: Int32) {

    guard let srcTexturePtr = srcTexturePtr,
          let dstTexturePtr = dstTexturePtr
    else {
        return
    }

    let srcTexture: MTLTexture = Unmanaged.fromOpaque(srcTexturePtr).takeUnretainedValue()
    let dstTexture: MTLTexture = Unmanaged.fromOpaque(dstTexturePtr).takeUnretainedValue()

    MTLHelper.callSpatialScaling(srcTexture, dstTexture, width, height)
}
