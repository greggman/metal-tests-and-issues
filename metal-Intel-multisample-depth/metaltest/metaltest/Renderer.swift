//
//  Renderer.swift
//  metaltest
//
import Foundation
import Metal
import MetalKit

class Renderer : NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let samplerState: MTLSamplerState
    let width = 16
    let height = 16
    var frameCount: Int = 0
    let myCaptureScope: MTLCaptureScope
    
    // This is the initializer for the Renderer class.
    // We will need access to the mtkView later, so we add it as a parameter here.
    init?(mtkView: MTKView) {
        device = mtkView.device!
        
        let captureDescriptor = MTLCaptureDescriptor()
        captureDescriptor.captureObject = device
        captureDescriptor.destination = .gpuTraceDocument
        captureDescriptor.outputURL = URL.init(fileURLWithPath: "intel-issue.gputrace")
        
        let sharedCaptureManager = MTLCaptureManager.shared()
        myCaptureScope = sharedCaptureManager.makeCaptureScope(device: device)
        do {
            try sharedCaptureManager.startCapture(with: captureDescriptor)
        }
        catch
        {
            fatalError("error when trying to capture: \(error)")
        }
        myCaptureScope.begin()
        
        commandQueue = device.makeCommandQueue()!
        mtkView.framebufferOnly = true

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.magFilter = MTLSamplerMinMagFilter.nearest
        samplerDescriptor.minFilter = MTLSamplerMinMagFilter.nearest
        samplerDescriptor.mipFilter = MTLSamplerMipFilter.nearest
        samplerDescriptor.rAddressMode = MTLSamplerAddressMode.repeat
        samplerDescriptor.sAddressMode = MTLSamplerAddressMode.repeat
        samplerDescriptor.tAddressMode = MTLSamplerAddressMode.clampToEdge
        samplerState = device.makeSamplerState(descriptor: samplerDescriptor)!
    }
    
    // Create our custom rendering pipeline, which loads shaders using `device`, and outputs to the format of `metalKitView`
    class func buildRenderPipelineWith(device: MTLDevice, metalKitView: MTKView, fragName: String, sampleCount: Int, depth: Bool) throws -> MTLRenderPipelineState {
        // Create a new pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        
        // Setup the shaders in the pipeline
        let library = device.makeDefaultLibrary()
        pipelineDescriptor.vertexFunction = library?.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library?.makeFunction(name: fragName)
        
        // Setup the output pixel format to match the pixel format of the metal kit view
        pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.rgba8Unorm
        pipelineDescriptor.sampleCount = sampleCount;
        if (depth) {
            pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormat.depth32Float
        }
        
        // Compile the configured pipeline descriptor to a pipeline state object
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    // mtkView will automatically call this function
    // whenever it wants new content to be rendered.
    func draw(in view: MTKView) {
        let pipelineState: MTLRenderPipelineState
        let texPipelineState: MTLRenderPipelineState
        let zPipelineState: MTLRenderPipelineState
        let vertexBuffer: MTLBuffer
        let msTexture: MTLTexture
        let msDepthTexture: MTLTexture
        let resolveTexture: MTLTexture
        let resolveDepthTexture: MTLTexture
        
        // Create the Render Pipeline
        do {
            pipelineState = try Renderer.buildRenderPipelineWith(device: device, metalKitView: view, fragName: "fragmentShader", sampleCount: 4, depth: true)
            texPipelineState = try Renderer.buildRenderPipelineWith(device: device, metalKitView: view, fragName: "textureFShader", sampleCount: 1, depth: false)
            zPipelineState = try Renderer.buildRenderPipelineWith(device: device, metalKitView: view, fragName: "zFShader", sampleCount: 1, depth: true)
        } catch {
            Swift.print("Unable to compile render pipeline state: \(error)")
            return
        }
        
        // Create our vertex data
        let vertices = [
            Vertex(pos: [-1, -1, 0.0]),
            Vertex(pos: [ 1, -1, 0.5]),
            Vertex(pos: [-1,  1, 0.5]),
            
            Vertex(pos: [-1,  1, 0.5]),
            Vertex(pos: [ 1, -1, 0.5]),
            Vertex(pos: [ 1,  1, 1.0]),
        ]
        // And copy it to a Metal buffer...
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])!
        
        Swift.print("texture size: width: \(width), height: \(height)")
        let msTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: MTLPixelFormat.rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false)
        msTextureDescriptor.sampleCount = 4
        msTextureDescriptor.usage = [.renderTarget]
        msTextureDescriptor.textureType = .type2DMultisample
        msTextureDescriptor.storageMode = .private
        
        msTexture = device.makeTexture(descriptor: msTextureDescriptor)!
        
        let msDepthTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: MTLPixelFormat.depth32Float,
            width: width,
            height: height,
            mipmapped: false)
        msDepthTextureDescriptor.sampleCount = 4
        msDepthTextureDescriptor.usage = [.renderTarget]
        msDepthTextureDescriptor.textureType = .type2DMultisample
        msDepthTextureDescriptor.storageMode = .private
        
        msDepthTexture = device.makeTexture(descriptor: msDepthTextureDescriptor)!
        
        let resolveTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: MTLPixelFormat.rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false)
        resolveTextureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        
        resolveTexture = device.makeTexture(descriptor: resolveTextureDescriptor)!
        
        let resolveDepthTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: MTLPixelFormat.depth32Float,
            width: width,
            height: height,
            mipmapped: false)
        resolveDepthTextureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        resolveDepthTextureDescriptor.storageMode = .private
        
        resolveDepthTexture = device.makeTexture(descriptor: resolveDepthTextureDescriptor)!
        do {
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

            do {
                let renderPassDescriptor = MTLRenderPassDescriptor();
                
                renderPassDescriptor.colorAttachments[0].texture = msTexture;
                renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1)
                renderPassDescriptor.colorAttachments[0].loadAction = .clear
                renderPassDescriptor.colorAttachments[0].storeAction = .store
                
                renderPassDescriptor.depthAttachment.texture = msDepthTexture;
                renderPassDescriptor.depthAttachment.clearDepth = 1
                renderPassDescriptor.depthAttachment.loadAction = .clear
                renderPassDescriptor.depthAttachment.storeAction = .store
                
                guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
                
                renderEncoder.setRenderPipelineState(pipelineState)

                let depthStencilDescriptor = MTLDepthStencilDescriptor()
                depthStencilDescriptor.depthCompareFunction = .always
                depthStencilDescriptor.isDepthWriteEnabled = true
                let depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
                renderEncoder.setDepthStencilState(depthStencilState)

                renderEncoder.endEncoding()
            }
            commandBuffer.commit()
        }

        do {
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

            do {
                let renderPassDescriptor = MTLRenderPassDescriptor();
                
                renderPassDescriptor.colorAttachments[0].texture = msTexture;
                renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1)
                renderPassDescriptor.colorAttachments[0].resolveTexture = resolveTexture;
                renderPassDescriptor.colorAttachments[0].loadAction = .load
                renderPassDescriptor.colorAttachments[0].storeAction = .storeAndMultisampleResolve
                
                renderPassDescriptor.depthAttachment.texture = msDepthTexture;
                renderPassDescriptor.depthAttachment.clearDepth = 1
                renderPassDescriptor.depthAttachment.resolveTexture = resolveDepthTexture;
                renderPassDescriptor.depthAttachment.loadAction = .load
                renderPassDescriptor.depthAttachment.storeAction = .storeAndMultisampleResolve
                
                guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
                
                renderEncoder.setRenderPipelineState(pipelineState)

                let depthStencilDescriptor = MTLDepthStencilDescriptor()
                depthStencilDescriptor.depthCompareFunction = .always
                depthStencilDescriptor.isDepthWriteEnabled = true
                let depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
                renderEncoder.setDepthStencilState(depthStencilState)

                renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                
                renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                renderEncoder.endEncoding()
            }
            commandBuffer.commit()
        }
        myCaptureScope.end()
        exit(0)
        do {
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

            // Copy the depth texture to the color texture
            /*
            do {
                let renderPassDescriptor = MTLRenderPassDescriptor();
                
                renderPassDescriptor.colorAttachments[0].texture = resolveTexture;
                renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1)
                renderPassDescriptor.colorAttachments[0].loadAction = .load
                renderPassDescriptor.colorAttachments[0].storeAction = .store
                
                guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
                
                renderEncoder.setRenderPipelineState(texPipelineState)
                renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                renderEncoder.setFragmentSamplerState(samplerState, index: 0)
                renderEncoder.setFragmentTexture(resolveDepthTexture, index: 0)

                renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                renderEncoder.endEncoding()
            }
            */
            
            // Derive the depth values by peeling
            do {
                let renderPassDescriptor = MTLRenderPassDescriptor();
                
                renderPassDescriptor.colorAttachments[0].texture = resolveTexture;
                renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1)
                renderPassDescriptor.colorAttachments[0].loadAction = .load
                renderPassDescriptor.colorAttachments[0].storeAction = .store

                renderPassDescriptor.depthAttachment.texture = resolveDepthTexture;
                renderPassDescriptor.depthAttachment.loadAction = .load
                renderPassDescriptor.depthAttachment.storeAction = .store

                guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

                let depthStencilDescriptor = MTLDepthStencilDescriptor()
                depthStencilDescriptor.depthCompareFunction = .less
                depthStencilDescriptor.isDepthWriteEnabled = false
                let depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
                renderEncoder.setDepthStencilState(depthStencilState)

                renderEncoder.setRenderPipelineState(zPipelineState)
                renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                
                let steps = 64;
                for i in 0..<steps
                {
                    let l = Float(i) / Float(steps)
                    let c = l;
                    let z = c;

                    let vertices = [
                        Vertex(pos: [-1, -1, z]),
                        Vertex(pos: [ 1, -1, z]),
                        Vertex(pos: [-1,  1, z]),
                        
                        Vertex(pos: [-1,  1, z]),
                        Vertex(pos: [ 1, -1, z]),
                        Vertex(pos: [ 1,  1, z]),
                    ]
                    // And copy it to a Metal buffer...
                    let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])!
                    renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                }

                renderEncoder.endEncoding()
            }

            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
        
        do {
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
            
            guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return }
            blitEncoder.synchronize(texture: resolveTexture, slice: 0, level: 0);
            blitEncoder.endEncoding();
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
        
        let pixelCount = width * height
        let region = MTLRegionMake2D(0, 0, width, height)
        
        var pixels = Array<UInt8>(repeating: UInt8(0), count: pixelCount * 4)
        resolveTexture.getBytes(
            &pixels,
            bytesPerRow: width * 4,
            from: region,
            mipmapLevel: 0);
        print("dest size: width: \(width), height: \(height)")
        let good = true;
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                print("\(String(format:"%02X", pixels[offset])),", terminator: "")
                /*
                print("pixel at \(String(format:"%d", x)),\(String(format:"%d", y)) was \(String(format:"%02X", pixels[offset])), \(String(format:"%02X", pixels[offset + 1])), \(String(format:"%02X", pixels[offset + 2])), \(String(format:"%02X", pixels[offset + 3]))")
                 if (pixels[offset + 0] != 0x80 ||
                 pixels[offset + 1] != 0x99 ||
                 pixels[offset + 2] != 0xB2 ||
                 pixels[offset + 3] != 0xCC) {
                 good = false;
                 print("FAIL: pixel at \(String(format:"%d", x)),\(String(format:"%d", y)) was \(String(format:"%02X", pixels[offset])), \(String(format:"%02X", pixels[offset + 1])), \(String(format:"%02X", pixels[offset + 2])), \(String(format:"%02X", pixels[offset + 3])), expected: (0x80, 0x99, 0xB2, 0xCC)")
                 }
                 */
            }
            print("")
        }
        if (good) {
            print("PASS: pixels correct")
        }
        myCaptureScope.end()
        exit(0)
    }
    
    // mtkView will automatically call this function
    // whenever the size of the view changes (such as resizing the window).
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
}
