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
    let width = 16
    let height = 16
    var frameCount: Int = 0
    
    // This is the initializer for the Renderer class.
    // We will need access to the mtkView later, so we add it as a parameter here.
    init?(mtkView: MTKView) {
        device = mtkView.device!
        commandQueue = device.makeCommandQueue()!
        mtkView.framebufferOnly = true
    }
    
    // Create our custom rendering pipeline, which loads shaders using `device`, and outputs to the format of `metalKitView`
    class func buildRenderPipelineWith(device: MTLDevice, metalKitView: MTKView, fragName: String, sampleCount: Int) throws -> MTLRenderPipelineState {
        // Create a new pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        
        // Setup the shaders in the pipeline
        let library = device.makeDefaultLibrary()
        pipelineDescriptor.vertexFunction = library?.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library?.makeFunction(name: fragName)

        // Setup the output pixel format to match the pixel format of the metal kit view
        pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.rgba8Unorm;
        pipelineDescriptor.sampleCount = sampleCount;
        
        // Compile the configured pipeline descriptor to a pipeline state object
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    // mtkView will automatically call this function
    // whenever it wants new content to be rendered.
    func draw(in view: MTKView) {
        let pipelineState: MTLRenderPipelineState
        let vertexBuffer: MTLBuffer
        let texture: MTLTexture
        let resolveTexture: MTLTexture

        // Create the Render Pipeline
        do {
            pipelineState = try Renderer.buildRenderPipelineWith(device: device, metalKitView: view, fragName: "fragmentShader", sampleCount: 4)
        } catch {
            Swift.print("Unable to compile render pipeline state: \(error)")
            return
        }

        // Create our vertex data
        let vertices = [
            Vertex(pos: [-1, -1]),
            Vertex(pos: [ 1, -1]),
            Vertex(pos: [-1,  1]),
            
            Vertex(pos: [-1,  1]),
            Vertex(pos: [ 1, -1]),
            Vertex(pos: [ 1,  1]),
        ]
        // And copy it to a Metal buffer...
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])!

        Swift.print("texture size: width: \(width), height: \(height)")
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                  pixelFormat: MTLPixelFormat.rgba8Unorm,
                  width: width,
                  height: height,
                  mipmapped: false)
        textureDescriptor.sampleCount = 4
        textureDescriptor.usage = [.renderTarget]
        // textureDescriptor.usage = [.shaderRead, .renderTarget]  // fix is adding .shaderRead but it seems like this should not be required.
        textureDescriptor.textureType = .type2DMultisample
        textureDescriptor.storageMode = .private

        texture = device.makeTexture(descriptor: textureDescriptor)!

        let resolveTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                  pixelFormat: MTLPixelFormat.rgba8Unorm,
                  width: width,
                  height: height,
                  mipmapped: false)
        resolveTextureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]

        resolveTexture = device.makeTexture(descriptor: resolveTextureDescriptor)!

        do {
          guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

          do {
            let renderPassDescriptor = MTLRenderPassDescriptor();

            renderPassDescriptor.colorAttachments[0].texture = texture;
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1)
            renderPassDescriptor.colorAttachments[0].resolveTexture = resolveTexture;
            renderPassDescriptor.colorAttachments[0].loadAction = .load
            renderPassDescriptor.colorAttachments[0].storeAction = .storeAndMultisampleResolve

            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
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
        var good = true;
        for y in 0..<height {
          for x in 0..<width {
            let offset = (y * width + x) * 4
            if (pixels[offset + 0] != 0x80 ||
                pixels[offset + 1] != 0x99 ||
                pixels[offset + 2] != 0xB2 ||
                pixels[offset + 3] != 0xCC) {
                  good = false;
                  print("FAIL: pixel at \(String(format:"%d", x)),\(String(format:"%d", y)) was \(String(format:"%02X", pixels[offset])), \(String(format:"%02X", pixels[offset + 1])), \(String(format:"%02X", pixels[offset + 2])), \(String(format:"%02X", pixels[offset + 3])), expected: (0x80, 0x99, 0xB2, 0xCC)")
            }
          }
        }
        if (good) {
          print("PASS: pixels correct")
        }
        //myCaptureScope?.end()
        exit(0)
    }

    // mtkView will automatically call this function
    // whenever the size of the view changes (such as resizing the window).
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {

    }
}
