/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file provides the platform-independent renderer class showing how to use MetalFX.
*/

import Metal
import MetalFX
import MetalKit

/// The app's available scaling modes.
enum AAPLScalingMode: Int {
    case defaultScaling
    case spatialScaling
    case temporalScaling
}

/// The view controller's platform-independent view renderer.
class AAPLRenderer: NSObject, MTKViewDelegate {
    public var animationEnabled: Bool = true
    public var resetHistoryEnabled: Bool = false
    public var firstFrameTemporal: Bool = false
    public var proceduralTextureEnabled: Bool = true
    public var textureMipmapBias: Float32 = -2

    let helper: AAPLRendererHelper
    let view: MTKView
    let device: MTLDevice
    let renderTarget: AAPLRenderTarget

    var mfxDirty: Bool = true
    var mfxScalingMode = AAPLScalingMode.defaultScaling
    var mfxSpatialScaler: MTLFXSpatialScaler!
    var mfxTemporalScaler: MTLFXTemporalScaler!
    var isDepthReversed: Bool = false
    var mfxMakeMotionVectors: Bool = false

    var pixelJitter = simd_float2()
    var ndcJitter = simd_float2()
    var texelJitter = simd_float2()

    let inFlightSemaphore = DispatchSemaphore(value: AAPLMaxBuffersInFlight)

    var frameData = FrameData()

    var rotation: Float = 1.07

    init?(metalKitView: MTKView) {
        view = metalKitView
        device = metalKitView.device!

        // Set up the MetalKit view parameters.
        view.depthStencilPixelFormat = .depth32Float
        view.colorPixelFormat = .bgra8Unorm_srgb
        view.sampleCount = 1

        // Set up the renderer helper to draw the scene.
        helper = AAPLRendererHelper(mtkView: view)
        helper.updateDynamicBufferState()

        // Set up the render target.
        renderTarget = AAPLRenderTarget(mtlDevice: device)
        renderTarget.resize(width: Int(view.drawableSize.width), height: Int(view.drawableSize.height))

        super.init()

        setupMetalFX()
    }
    
    /// Checks the current scaling mode and free unused resources, if necessary.
    func releaseMetalFXResources() {
        mfxMakeMotionVectors = false

        // Free the spatial upscaling effect if you're not using it.
        if mfxScalingMode != .spatialScaling {
            mfxSpatialScaler = nil
        }
        
        if mfxScalingMode != .temporalScaling {
            mfxTemporalScaler = nil
        }
    }
    
    /// Creates the MetalFX spatial scaler.
    ///
    /// If you're using the spatial scaler, please keep in mind that it expects an antialiased input texture.
    /// Since this sample focuses on showing you how to use MetalFX upscaling, it doesn't perform an antialiasing step here.
    /// For example, you may prepass your input texture with a shader that computes antialiasing.
    func setupSpatialScaler() {
        let desc = MTLFXSpatialScalerDescriptor()
        desc.inputWidth = renderTarget.renderSize.width
        desc.inputHeight = renderTarget.renderSize.height
        desc.outputWidth = renderTarget.windowSize.width
        desc.outputHeight = renderTarget.windowSize.height
        desc.colorTextureFormat = renderTarget.currentFrameColor.pixelFormat
        desc.outputTextureFormat = renderTarget.currentFrameUpscaledColor.pixelFormat
        desc.colorProcessingMode = .perceptual
        
        guard let spatialScaler = desc.makeSpatialScaler(device: device) else {
            print("The spatial scaler effect is not usable!")
            mfxScalingMode = .defaultScaling
            return
        }

        mfxSpatialScaler = spatialScaler
    }
    
    /// Creates the MetalFX temporal scaler.
    func setupTemporalScaler() {
        let desc = MTLFXTemporalScalerDescriptor()
        desc.inputWidth = renderTarget.renderSize.width
        desc.inputHeight = renderTarget.renderSize.height
        desc.outputWidth = renderTarget.windowSize.width
        desc.outputHeight = renderTarget.windowSize.height
        desc.colorTextureFormat = renderTarget.currentFrameColor.pixelFormat
        desc.depthTextureFormat = renderTarget.currentFrameDepth.pixelFormat
        desc.motionTextureFormat = renderTarget.currentFrameMotion.pixelFormat
        desc.outputTextureFormat = renderTarget.currentFrameUpscaledColor.pixelFormat

        guard let temporalScaler = desc.makeTemporalScaler(device: device) else {
            print("The temporal scaler effect is not usable!")
            mfxScalingMode = .defaultScaling
            return
        }

        temporalScaler.motionVectorScaleX = renderTarget.renderSizeX()
        temporalScaler.motionVectorScaleY = renderTarget.renderSizeY()
        mfxTemporalScaler = temporalScaler
        mfxMakeMotionVectors = true
        firstFrameTemporal = true
    }
    
    /// Releases the previous resources, if necessary, and sets up the MetalFX scalers.
    func setupMetalFX() {
        releaseMetalFXResources()
        if mfxScalingMode == .spatialScaling {
            setupSpatialScaler()
        } else if mfxScalingMode == .temporalScaling {
            setupTemporalScaler()
        }
    }

    /// Calculates the jitter offsets necessary for the temporal antialiasing effects.
    private func updateJitterOffsets() {
        if mfxMakeMotionVectors {
            // The sample uses a Halton sequence rather than purely random numbers to generate the sample positions to ensure good pixel coverage.
            // This has the result of sampling a different point within each pixel every frame.

            let jitterIndex: UInt32 = (UInt32)(frameData.motionVectorFrameIndex % 32 + 1)

            // Return Halton samples (+/- 0.5, +/- 0.5) that represent offsets of up to half a pixel.
            pixelJitter.x = halton(index: jitterIndex, base: 2) - 0.5
            pixelJitter.y = halton(index: jitterIndex, base: 3) - 0.5

            // Shear the projection matrix by plus or minus half a pixel for temporal antialiasing.
            // Store the amount of jitter so that the shader can "unjitter" it when computing motion vectors (0...1).
            // The sign of the jitter flips because the translation has the opposite effect.
            // For example, an NDC x offset of +20 to the right ends up being -10 pixels to the left.
            // To counter this, multiply by -2.0f.
            ndcJitter = -2 * pixelJitter / frameData.renderResolution

            // Flip the y-coordinate direction because the bottom left is the origin of a texture.
            pixelJitter *= simd_float2(1, -1)

            // Calculate the texel jitter by dividing by the resolution because the texture coordinates go (0...1).
            texelJitter = pixelJitter / frameData.renderResolution
        }

        // The fragment shader creates the motion vectors using the texelJitter property.
        if resetHistoryEnabled || !mfxMakeMotionVectors {
            frameData.motionVectorFrameIndex = 0
            pixelJitter = simd_float2()
            texelJitter = simd_float2()
            ndcJitter = simd_float2()
        } else {
            frameData.motionVectorFrameIndex += 1
        }

        // Update the shader parameters that affect the motion vector texture.
        frameData.projectionMatrix.columns.2[0] += ndcJitter.x
        frameData.projectionMatrix.columns.2[1] += ndcJitter.y
        frameData.texelJitter = texelJitter
    }

    /// Prepares the GPU buffers for the next frame.
    private func update() {
        // Update animation parameters.
        if animationEnabled {
            rotation += 0.002
        }
        helper.proceduralTextureEnabled = proceduralTextureEnabled
        if proceduralTextureEnabled {
            frameData.timeInSeconds += 0.0001
        }

        // Make the math for the jitter offset straightforward by using a simd_float2 of the render resolution.
        frameData.renderResolution = renderTarget.simdRenderSize()
        frameData.windowResolution = renderTarget.simdWindowSize()
        
        // Update the transformation matrix.
        frameData.modelMatrix = matrix4x4_rotation(radians: rotation, axis: SIMD3<Float>(1, 1, 0))
        frameData.modelMatrix = simd_mul(frameData.modelMatrix, matrix4x4_rotation(radians: rotation * 0.8, axis: SIMD3<Float>(0, 1, 0)))
        frameData.viewMatrix = matrix4x4_translation(0.0, 0.0, -8.0)
        frameData.modelViewMatrix = simd_mul(frameData.viewMatrix, frameData.modelMatrix)
        
        // Configure the projection matrix.
        let fovy: Float = 65 * 3.141_592 / 180.0
        let aspect: Float = renderTarget.aspectRatio
        frameData.projectionMatrix = matrix_perspective_right_hand(fovyRadians: fovy, aspectRatio: aspect, nearZ: 0.1, farZ: 100.0)
        
        // Set the mipmap bias from the UI.
        if mfxScalingMode == .spatialScaling {
            // The expected spatial upscaler mipmap bias is about one unit higher than with the temporal upscaler.
            // For example, if you're using the temporal upscaler, you may use a value of -2.
            // But if you're using the spatial upscaler, you use a value of -1.
            frameData.mipmapBias = textureMipmapBias + 1
        } else {
            frameData.mipmapBias = textureMipmapBias
        }

        // If the motion vectors are in an enabled state, create the jitter offset for this frame.
        updateJitterOffsets()
        
        // Update the constants data buffer for the shader.
        helper.updateDynamicBufferState()
        helper.updateFrameData(frame: frameData)
    }

    func drawScene(_ commandBuffer: MTLCommandBuffer) {
        // Choose the pipeline state that produces motion vectors if you're using the TAA or TAAU effect.
        var pipelineState: MTLRenderPipelineState
        if mfxMakeMotionVectors {
            pipelineState = helper.renderTAAPipelineState!
        } else {
            pipelineState = helper.renderPipelineState!
        }

        // Render the scene to the render scale texture.
        let renderPassDescriptor = renderTarget.renderPassDescriptorForRender(makeMotionVectors: mfxMakeMotionVectors)
        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            renderEncoder.label = "Draw Scene"
            helper.drawScene(with: renderEncoder, pipelineState: pipelineState)
            renderEncoder.endEncoding()
        }
    }

    func upscaleTexture(_ commandBuffer: MTLCommandBuffer) -> MTLTexture {
        var currentSourceTexture = renderTarget.currentFrameColor!
        
        // Apply the spatial scaler if it's in an enabled state.
        if let spatialScaler = mfxSpatialScaler {
            spatialScaler.colorTexture = currentSourceTexture
            spatialScaler.outputTexture = renderTarget.currentFrameUpscaledColor!
            spatialScaler.encode(commandBuffer: commandBuffer)
            
            currentSourceTexture = renderTarget.currentFrameUpscaledColor
        }
        
        // Apply the temporal scaler if it's in an enabled state.
        if let temporalScaler = mfxTemporalScaler {
            temporalScaler.reset = resetHistoryEnabled || firstFrameTemporal
            temporalScaler.colorTexture = renderTarget.currentFrameColor!
            temporalScaler.depthTexture = renderTarget.currentFrameDepth!
            temporalScaler.motionTexture = renderTarget.currentFrameMotion!
            temporalScaler.outputTexture = renderTarget.currentFrameUpscaledColor!
            temporalScaler.isDepthReversed = isDepthReversed
            temporalScaler.jitterOffsetX = pixelJitter.x
            temporalScaler.jitterOffsetY = pixelJitter.y
            temporalScaler.encode(commandBuffer: commandBuffer)

            firstFrameTemporal = false
            currentSourceTexture = renderTarget.currentFrameUpscaledColor
        }
        
        return currentSourceTexture
    }
    
    /// Adjusts the app's render resolution and ensures it isn't smaller than the scaler's minimum size.
    func adjustRenderScale(_ newRenderScale: Float) {
        let oldRenderScale = renderTarget.renderScale
        renderTarget.adjustRenderScale(newRenderScale)
        if oldRenderScale != renderTarget.renderScale {
            setupMetalFX()
        }
    }

    /// Draws the scene with the MetalFX upscaling effect.
    func draw(in view: MTKView) {
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)

        if let commandBuffer = helper.commandQueue.makeCommandBuffer() {
            let semaphore = inFlightSemaphore
            commandBuffer.addCompletedHandler { _ in
                semaphore.signal()
            }

            // Update frame data, draw the scene, and upscale to the window resolution.
            update()
            drawScene(commandBuffer)
            let currentSourceTexture = upscaleTexture(commandBuffer)

            // Copy to the drawable.
            let renderPassDescriptor = renderTarget.renderPassDescriptor(view)
            helper.copyToDrawable(from: currentSourceTexture, with: commandBuffer, using: renderPassDescriptor)

            // Present to the screen.
            if let drawable = view.currentDrawable {
                commandBuffer.present(drawable)
            }

            commandBuffer.commit()
        }
    }

    /// Responds to changes to the drawable's size by resizing the render textures, and updating the MetalFX scaler, if necessary.
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Determine the content scale between the drawable size and the view bounds.
        let boundsSize = Float(max(view.bounds.width, view.bounds.height))
        let drawableSize = Float(max(view.drawableSize.width, view.drawableSize.height))
        let contentScale = Int(round(drawableSize / boundsSize))

        // Make sure the width and the height are divisible by 2.
        // Also make sure the dimensions satisfy the MetalFX minimum size requirements.
        let adjustedWidth = (Int(view.bounds.width) >> 1) * 2 * contentScale
        let adjustedHeight = (Int(view.bounds.height) >> 1) * 2 * contentScale

        renderTarget.resize(width: adjustedWidth, height: adjustedHeight)
        setupMetalFX()
    }
}
