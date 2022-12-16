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
    var textures: [MTLTexture] = []
    let samplerState: MTLSamplerState
    var frameCount: Int = 0
    let num: Int = 100
   
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

        let width = 1024;
        let height = 1024;
        for _ in 0...(num - 1) {
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                      pixelFormat: MTLPixelFormat.rgba8Unorm,
                      width: width,
                      height: height,
                      mipmapped: false)
            textureDescriptor.usage = [.shaderRead]
            textureDescriptor.storageMode = .private
            textures.append(device.makeTexture(descriptor: textureDescriptor)!)
        }

        /*
        Renderer.setMip(texture: texture, size: 64, level: 0, color: 0x00000000)
        Renderer.setMip(texture: texture, size: 32, level: 1, color: 0x01010101)
        Renderer.setMip(texture: texture, size: 16, level: 2, color: 0x02020202)
        Renderer.setMip(texture: texture, size:  8, level: 3, color: 0x03030303)
        Renderer.setMip(texture: texture, size:  4, level: 4, color: 0x04040404)
        Renderer.setMip(texture: texture, size:  2, level: 5, color: 0x05050505)
        Renderer.setMip(texture: texture, size:  1, level: 6, color: 0x06060606)
        */

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.magFilter = MTLSamplerMinMagFilter.nearest
        samplerDescriptor.minFilter = MTLSamplerMinMagFilter.nearest
        samplerDescriptor.mipFilter = MTLSamplerMipFilter.nearest
        samplerDescriptor.rAddressMode = MTLSamplerAddressMode.repeat
        samplerDescriptor.sAddressMode = MTLSamplerAddressMode.repeat
        samplerDescriptor.tAddressMode = MTLSamplerAddressMode.clampToEdge
        samplerState = device.makeSamplerState(descriptor: samplerDescriptor)!
    }
    
    class func setMip(texture: MTLTexture, size: Int, level: Int, color: UInt32) {
        let region = MTLRegionMake2D(0, 0, size, size)
        let data = [UInt32](repeating: color, count: size * size)
        texture.replace(region: region, mipmapLevel: level, withBytes: data, bytesPerRow: size * 4)
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

        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 0, 0, 1)

        let width = Int(view.drawableSize.width);
        let height = Int(view.drawableSize.height);

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)

        let across = floor(sqrt(Double(num)));
        let down = floor(Double(num) / across);
        for i in 0...(textures.count - 1) {
            let x = fmod(Double(i), across)
            let y = floor(Double(i) / across)
            let u = x / across * Double(width)
            let v = y / down * Double(height)
            
            renderEncoder.setFragmentTexture(textures[i], index: 0)
            let viewport = MTLViewport(originX: u, originY: v, width: 10, height: 10, znear: 0, zfar: 1)
            renderEncoder.setViewport(viewport)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        }
        renderEncoder.endEncoding()
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
    }

    // mtkView will automatically call this function
    // whenever the size of the view changes (such as resizing the window).
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {

    }
}
