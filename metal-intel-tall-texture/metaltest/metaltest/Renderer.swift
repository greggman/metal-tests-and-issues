//
//  Renderer.swift
//  metaltest
//
//  Created by Gregg Tavares on 9/27/21.
//

import Foundation
import Metal
import MetalKit

class Renderer : NSObject, MTKViewDelegate {

    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLRenderPipelineState
    let vertexBuffer: MTLBuffer
    let texture: MTLTexture
    let samplerState: MTLSamplerState
    var frameCount: Int = 0
    
    // This is the initializer for the Renderer class.
    // We will need access to the mtkView later, so we add it as a parameter here.
    init?(mtkView: MTKView) {
        device = mtkView.device!
        mtkView.framebufferOnly = false

        commandQueue = device.makeCommandQueue()!

        // Create the Render Pipeline
        do {
            pipelineState = try Renderer.buildRenderPipelineWith(device: device, metalKitView: mtkView)
        } catch {
            print("Unable to compile render pipeline state: \(error)")
            return nil
        }
        
        // Create our vertex data
        let vertices = [
            Vertex(uv: [0, 0], pos: [-1, -1]),
            Vertex(uv: [1, 0], pos: [ 1, -1]),
            Vertex(uv: [0, 1], pos: [-1,  1]),
            
            Vertex(uv: [0, 1], pos: [-1,  1]),
            Vertex(uv: [1, 0], pos: [ 1, -1]),
            Vertex(uv: [1, 1], pos: [ 1,  1]),
        ]
        // And copy it to a Metal buffer...
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])!

        let width = 1;
        let height = 16384;
        print("texture size: width: \(width), height: \(height)")
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                  pixelFormat: MTLPixelFormat.rgba8Unorm,
                  width: width,
                  height: height,
                  mipmapped: true)
        textureDescriptor.usage = [.shaderRead]
        texture = device.makeTexture(descriptor: textureDescriptor)!
        
        var h = height;
        var level = 0;
        while (h > 0) {
           Renderer.setMip(texture: texture, width: width, height: h, level: level, color: 0x11223344)
           level = level + 1
           h = h / 2;
        }

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.magFilter = MTLSamplerMinMagFilter.linear
        samplerDescriptor.minFilter = MTLSamplerMinMagFilter.linear
        samplerDescriptor.mipFilter = MTLSamplerMipFilter.nearest
        samplerDescriptor.rAddressMode = MTLSamplerAddressMode.repeat
        samplerDescriptor.sAddressMode = MTLSamplerAddressMode.repeat
        samplerDescriptor.tAddressMode = MTLSamplerAddressMode.clampToEdge
        samplerState = device.makeSamplerState(descriptor: samplerDescriptor)!
    }
    
    class func setMip(texture: MTLTexture, width: Int, height: Int, level: Int, color: UInt32) {
        let region = MTLRegionMake2D(0, 0, width, height)
        let data = [UInt32](repeating: color, count: width * height)
        texture.replace(region: region, mipmapLevel: level, withBytes: data, bytesPerRow: width * 4)
    }

    // Create our custom rendering pipeline, which loads shaders using `device`, and outputs to the format of `metalKitView`
    class func buildRenderPipelineWith(device: MTLDevice, metalKitView: MTKView) throws -> MTLRenderPipelineState {
        // Create a new pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        
        // Setup the shaders in the pipeline
        let library = device.makeDefaultLibrary()
        pipelineDescriptor.vertexFunction = library?.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "fragmentShader")

        // Setup the output pixel format to match the pixel format of the metal kit view
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        
        // Compile the configured pipeline descriptor to a pipeline state object
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    // mtkView will automatically call this function
    // whenever it wants new content to be rendered.
    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }

        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1)

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        renderEncoder.setFragmentTexture(texture, index: 0)

        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        
        if let curDrawable = view.currentDrawable {
            let width = Int(view.drawableSize.width);
            let height = Int(view.drawableSize.height);
            let pixelCount = width * height
            let region = MTLRegionMake2D(0, 0, width, height)

            var pixels = Array<UInt8>(repeating: UInt8(0), count: pixelCount * 4)
            curDrawable.texture.getBytes(
                &pixels,
                bytesPerRow: width * 4,
                from: region,
                mipmapLevel: 0);

            print("dest size: width: \(width), height: \(height)")
            print("Top Left    : \(String(format:"%02X", pixels[0])), \(String(format:"%02X", pixels[1])), \(String(format:"%02X", pixels[2])), \(String(format:"%02X", pixels[3])), expected: (0x22, 0x33, 0x44, 0x11)")
            let offset = width * height * 4 - 4;
            print("Bottom Right: \(String(format:"%02X", pixels[offset])), \(String(format:"%02X", pixels[offset + 1])), \(String(format:"%02X", pixels[offset + 2])), \(String(format:"%02X", pixels[offset + 3])), expected: (0x22, 0x33, 0x44, 0x11)")
        }
        exit(0)
    }

    // mtkView will automatically call this function
    // whenever the size of the view changes (such as resizing the window).
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {

    }
}
