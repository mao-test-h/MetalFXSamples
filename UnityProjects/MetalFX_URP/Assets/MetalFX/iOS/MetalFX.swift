import Metal
import MetalFX

final class MTLHelper {
    private static var mfxSpatialScaler: MTLFXSpatialScaler? = nil
    private static var commandQueue: MTLCommandQueue? = nil

    public static func callSpatialScaling(_ srcTexture: MTLTexture, _ dstTexture: MTLTexture) {

        let width = srcTexture.width
        let height = srcTexture.height

        if mfxSpatialScaler == nil {
            let desc = MTLFXSpatialScalerDescriptor()
            desc.inputWidth = width
            desc.inputHeight = height
            desc.outputWidth = width * 2
            desc.outputHeight = height * 2
            desc.colorTextureFormat = srcTexture.pixelFormat
            desc.outputTextureFormat = dstTexture.pixelFormat
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
func callMetalFX_SpatialScaling(_ srcTexturePtr: UnsafeRawPointer?, _ dstTexturePtr: UnsafeRawPointer?) {

    guard let srcTexturePtr = srcTexturePtr,
          let dstTexturePtr = dstTexturePtr
    else {
        return
    }

    let srcTexture: MTLTexture = Unmanaged.fromOpaque(srcTexturePtr).takeUnretainedValue()
    let dstTexture: MTLTexture = Unmanaged.fromOpaque(dstTexturePtr).takeUnretainedValue()

    MTLHelper.callSpatialScaling(srcTexture, dstTexture)
}
