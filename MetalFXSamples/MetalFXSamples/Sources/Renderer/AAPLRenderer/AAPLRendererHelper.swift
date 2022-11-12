/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file provides the rendering code to draw a scene.
*/

import MetalKit

/// Define the 256-byte-aligned size of the constant frame data structure.
let AAPLAlignedFrameDataSize = (MemoryLayout<FrameData>.size + 0xFF) & -0x100

/// Define the number of frames that may render in advance.
let AAPLMaxBuffersInFlight = 3

class AAPLRendererHelper {
    let mtlDevice: MTLDevice!
    let view: MTKView
    let commandQueue: MTLCommandQueue
    let depthState: MTLDepthStencilState
    let library: MTLLibrary
    var frameDataBuffers = [MTLBuffer]()
    let depthStateDescriptor = MTLDepthStencilDescriptor()
    let vertexDescriptor = MTLVertexDescriptor()
    var frameCount: Int = 0
    
    var frameDataBuffer: MTLBuffer!
    var prevFrameDataBuffer: MTLBuffer!
    var frameData: UnsafeMutablePointer<FrameData>!
    var prevFrameData: UnsafeMutablePointer<FrameData>!
    
    var renderPipelineState: MTLRenderPipelineState? = nil
    var renderTAAPipelineState: MTLRenderPipelineState? = nil
    var copyToViewPipelineState: MTLRenderPipelineState? = nil
    
    var mesh: MTKMesh!
    
    var diffClouds1: MTLTexture!
    var diffClouds2: MTLTexture!
    var albedoTexture: MTLTexture!
    var normalTexture: MTLTexture!
    var roughnessTexture: MTLTexture!
    
    public var proceduralTextureEnabled: Bool = false

    init(mtkView: MTKView) {
        mtlDevice = mtkView.device!
        view = mtkView
        commandQueue = mtlDevice.makeCommandQueue()!
        library = mtlDevice.makeDefaultLibrary()!

        // Set up the constants frame data.
        frameDataBuffers.append(mtlDevice.makeBuffer(length: AAPLAlignedFrameDataSize, options: [.storageModeShared])!)
        frameDataBuffers.append(mtlDevice.makeBuffer(length: AAPLAlignedFrameDataSize, options: [.storageModeShared])!)
        frameDataBuffers.append(mtlDevice.makeBuffer(length: AAPLAlignedFrameDataSize, options: [.storageModeShared])!)

        frameDataBuffers[0].label = "FrameDataBuffer0"
        frameDataBuffers[1].label = "FrameDataBuffer1"
        frameDataBuffers[2].label = "FrameDataBuffer2"
        
        // Set up the default depth state with a less comparison.
        depthStateDescriptor.depthCompareFunction = .less
        depthStateDescriptor.isDepthWriteEnabled = true
        depthState = mtlDevice.makeDepthStencilState(descriptor: depthStateDescriptor)!

        // Set up the frame buffer pointers before rendering.
        updateDynamicBufferState()

        // Build the vertex descriptors for the pipeline states.
        buildMetalVertexDescriptor()

        // Load the model to use in the sample.
        mesh = buildMesh()!
        
        // Load the texture maps to use in the sample.
        diffClouds1 = loadTexture(textureName: "diffClouds1")!
        diffClouds2 = loadTexture(textureName: "diffClouds2")!
        albedoTexture = loadTexture(textureName: "texture-albedo")!
        normalTexture = loadTexture(textureName: "texture-normal")!
        roughnessTexture = loadTexture(textureName: "texture-roughness")!
        
        // Build the nontemporal pipeline state objects.
        renderPipelineState = buildRenderPipeline(vertexFunctionName: "vertexShader", fragmentFunctionName: "fragmentShader",
                                                  color1PixelFormat: .invalid, useForDrawingMeshes: true)!

        // Build the motion vector pipeline state object.
        renderTAAPipelineState = buildRenderPipeline(vertexFunctionName: "vertexShader", fragmentFunctionName: "fragmentShaderTAA",
                                                     color1PixelFormat: .rg16Float, useForDrawingMeshes: true)!
        
        // Create the "copy to view" pipeline state object.
        copyToViewPipelineState = buildRenderPipeline(vertexFunctionName: "FSQ_VS_V4T2", fragmentFunctionName: "FSQ_simpleCopy",
                                                      color1PixelFormat: .invalid,
                                                      useForDrawingMeshes: false)!
    }
    
    /// Sets up the attributes and layout of the vertex descriptor.
    ///
    /// - Parameter attribute: The vertex attribute like position or texture coordinate.
    /// - Parameter numComponents: Can be 2, 3, or 4; defaults to 4
    func setVertexDescriptorForAttribute(_ attribute: AAPLVertexAttribute, numComponents: Int = 4) {
        let index = attribute.rawValue
        vertexDescriptor.attributes[index].offset = 0
        vertexDescriptor.attributes[index].bufferIndex = index
        if numComponents == 2 {
            vertexDescriptor.attributes[index].format = .float2
            vertexDescriptor.layouts[index].stride = 8
        } else if numComponents == 3 {
            vertexDescriptor.attributes[index].format = .float3
            vertexDescriptor.layouts[index].stride = 12
        } else {
            vertexDescriptor.attributes[index].format = .float4
            vertexDescriptor.layouts[index].stride = 16
        }
        vertexDescriptor.layouts[index].stepRate = 1
        vertexDescriptor.layouts[index].stepFunction = .perVertex
    }

    /// Creates a Metal vertex descriptor to define the vertex layout for the render pipeline.
    func buildMetalVertexDescriptor() {
        setVertexDescriptorForAttribute(.position, numComponents: 3)
        setVertexDescriptorForAttribute(.texcoord, numComponents: 2)
        setVertexDescriptorForAttribute(.normal, numComponents: 3)
        setVertexDescriptorForAttribute(.tangent, numComponents: 3)
        setVertexDescriptorForAttribute(.bitangent, numComponents: 3)
    }

    /// Builds a render state pipeline object for the given vertex and fragment functions.
    func buildRenderPipeline(
        vertexFunctionName: String,
        fragmentFunctionName: String,
        color1PixelFormat: MTLPixelFormat,
        useForDrawingMeshes: Bool) -> MTLRenderPipelineState? {
        let vertexFunction = library.makeFunction(name: vertexFunctionName)
        let fragmentFunction = library.makeFunction(name: fragmentFunctionName)

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = vertexFunctionName + "/" + fragmentFunctionName
        if #unavailable(macOS 13) {
            pipelineDescriptor.sampleCount = view.sampleCount
        }
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction

        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        if color1PixelFormat != .invalid {
            pipelineDescriptor.colorAttachments[1].pixelFormat = color1PixelFormat
        }

        if useForDrawingMeshes {
            pipelineDescriptor.vertexDescriptor = vertexDescriptor
            pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        }

        var pipelineState: MTLRenderPipelineState
        do {
            pipelineState = try mtlDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("The app is unable to create the render pipeline state.  Error info: \(error)")
            return nil
        }

        return pipelineState
    }

    /// Creates and conditions the mesh data to feed into a pipeline using the given vertex descriptor.
    func buildMesh() -> MTKMesh? {
        let metalAllocator = MTKMeshBufferAllocator(device: mtlDevice)

        let mdlMesh = MDLMesh.newBox(withDimensions: SIMD3<Float>(4, 4, 4),
                                     segments: SIMD3<UInt32>(1, 1, 1),
                                     geometryType: MDLGeometryType.triangles,
                                     inwardNormals: false,
                                     allocator: metalAllocator)
        mdlMesh.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                                normalAttributeNamed: MDLVertexAttributeNormal,
                                tangentAttributeNamed: MDLVertexAttributeTangent)
        mdlMesh.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                                tangentAttributeNamed: MDLVertexAttributeTangent,
                                bitangentAttributeNamed: MDLVertexAttributeBitangent)

        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)

        if let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] {
            attributes[AAPLVertexAttribute.position.rawValue].name = MDLVertexAttributePosition
            attributes[AAPLVertexAttribute.texcoord.rawValue].name = MDLVertexAttributeTextureCoordinate
            attributes[AAPLVertexAttribute.normal.rawValue].name = MDLVertexAttributeNormal
            attributes[AAPLVertexAttribute.tangent.rawValue].name = MDLVertexAttributeTangent
            attributes[AAPLVertexAttribute.bitangent.rawValue].name = MDLVertexAttributeBitangent
        }

        mdlMesh.vertexDescriptor = mdlVertexDescriptor

        var mesh: MTKMesh?
        do {
            mesh = try MTKMesh(mesh: mdlMesh, device: mtlDevice)
        } catch {
            print("The app is unable to create the mesh.")
        }

        return mesh
    }

    /// Loads the texture data with optimal parameters for sampling.
    func loadTexture(textureName: String) -> MTLTexture? {
        let textureLoader = MTKTextureLoader(device: mtlDevice)

        let textureLoaderOptions = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue)
        ]

        var texture: MTLTexture?
        do {
            texture = try textureLoader.newTexture(name: textureName,
                                                   scaleFactor: 1.0,
                                                   bundle: nil,
                                                   options: textureLoaderOptions)
        } catch {
            print("The app is unable to load the texture '\(textureName)'.")
        }

        return texture
    }
    
    /// Updates the state of the constant uniform buffers before rendering.
    func updateDynamicBufferState() {
        // Advance the frame count and set the current frame data buffer indexes.
        let prevBufferIndex = frameCount % AAPLMaxBuffersInFlight
        let currentBufferIndex = (frameCount + 1) % AAPLMaxBuffersInFlight
        frameCount += 1
        
        // Select the next frame data buffer to use.
        prevFrameDataBuffer = frameDataBuffers[prevBufferIndex]
        frameDataBuffer = frameDataBuffers[currentBufferIndex]
        
        // Get unsafe pointers to the contents of the shader data.
        prevFrameData = UnsafeMutableRawPointer(prevFrameDataBuffer.contents()).bindMemory(to: FrameData.self, capacity: 1)
        frameData = UnsafeMutableRawPointer(frameDataBuffer.contents()).bindMemory(to: FrameData.self, capacity: 1)
    }
    
    /// Updates any scene state before rendering.
    func updateFrameData(frame: FrameData) {
        frameData[0].projectionMatrix = frame.projectionMatrix
        frameData[0].modelViewMatrix = frame.modelViewMatrix
        frameData[0].modelMatrix = frame.modelMatrix
        frameData[0].normalMatrix = normalMatrixFromFloat4x4(frame.modelMatrix)
        frameData[0].viewMatrix = frame.viewMatrix
        frameData[0].texelJitter = frame.texelJitter
        frameData[0].renderResolution = frame.renderResolution
        frameData[0].windowResolution = frame.windowResolution
        frameData[0].motionVectorFrameIndex = frame.motionVectorFrameIndex
        frameData[0].timeInSeconds = frame.timeInSeconds
        frameData[0].mipmapBias = frame.mipmapBias
        frameData[0].proceduralTextureEnabled = proceduralTextureEnabled
    }

    /// Draws the scene using the specified render encoder and pipeline state,
    func drawScene(with renderEncoder: MTLRenderCommandEncoder, pipelineState: MTLRenderPipelineState) {
        renderEncoder.setCullMode(.back)
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        
        renderEncoder.setVertexBuffer(frameDataBuffer, offset: 0, index: AAPLBufferIndex.frameData.rawValue)
        renderEncoder.setFragmentBuffer(frameDataBuffer, offset: 0, index: AAPLBufferIndex.frameData.rawValue)
        renderEncoder.setVertexBuffer(prevFrameDataBuffer, offset: 0, index: AAPLBufferIndex.prevFrameData.rawValue)
        renderEncoder.setFragmentBuffer(prevFrameDataBuffer, offset: 0, index: AAPLBufferIndex.prevFrameData.rawValue)
        
        for (index, element) in mesh.vertexDescriptor.layouts.enumerated() {
            guard let layout = element as? MDLVertexBufferLayout else {
                return
            }
            
            if layout.stride != 0 {
                let buffer = mesh.vertexBuffers[index]
                renderEncoder.setVertexBuffer(buffer.buffer, offset: buffer.offset, index: index)
            }
        }
        
        if proceduralTextureEnabled {
            renderEncoder.setFragmentTexture(diffClouds1, index: AAPLTextureIndex.color1.rawValue)
            renderEncoder.setFragmentTexture(diffClouds2, index: AAPLTextureIndex.color2.rawValue)
        } else {
            renderEncoder.setFragmentTexture(albedoTexture, index: AAPLTextureIndex.color1.rawValue)
            renderEncoder.setFragmentTexture(normalTexture, index: AAPLTextureIndex.color2.rawValue)
            renderEncoder.setFragmentTexture(roughnessTexture, index: AAPLTextureIndex.color3.rawValue)
        }
        
        for submesh in mesh.submeshes {
            renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset)
        }
    }
    
    /// Copies the source texture to the drawable.
    func copyToDrawable(from sourceTexture: MTLTexture, with commandBuffer: MTLCommandBuffer, using renderPassDescriptor: MTLRenderPassDescriptor) {
        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            renderEncoder.label = "Copy To View"
            renderEncoder.setRenderPipelineState(copyToViewPipelineState!)
            renderEncoder.setFragmentBuffer(frameDataBuffer, offset: 0, index: 0)
            renderEncoder.setFragmentTexture(sourceTexture, index: 0)
            renderEncoder.drawPrimitives(type: MTLPrimitiveType.triangle, vertexStart: 0, vertexCount: 3)
            renderEncoder.endEncoding()
        }
    }
}
