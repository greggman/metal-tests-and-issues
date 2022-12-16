//
//  Renderer.swift
//  metaltest
//
//  Created by Gregg Tavares on 9/27/21.
//

import Foundation
import Metal
import MetalKit

enum RendererError: Error {
    case poop
}

class Renderer : NSObject, MTKViewDelegate {

    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLRenderPipelineState
    let vertexBufferR: MTLBuffer
    let vertexBufferG: MTLBuffer
    let vertexBufferB: MTLBuffer
    let vertexBufferY: MTLBuffer

    // This is the initializer for the Renderer class.
    // We will need access to the mtkView later, so we add it as a parameter here.
    init?(mtkView: MTKView) {
        device = mtkView.device!
        
        mtkView.depthStencilPixelFormat = MTLPixelFormat.depth16Unorm            // fails
        //mtkView.depthStencilPixelFormat = MTLPixelFormat.depth32Float            // works
        //mtkView.depthStencilPixelFormat = MTLPixelFormat.depth24Unorm_stencil8;  // works
        //mtkView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8;  // works

        commandQueue = device.makeCommandQueue()!

        // Create the Render Pipeline
        do {
            pipelineState = try Renderer.buildRenderPipelineWith(device: device, metalKitView: mtkView)
        } catch {
            print("Unable to compile render pipeline state: \(error)")
            return nil
        }
        
        /*
         +----+
         |\   |
         |r\  |
         |rr\ | red triangle
         |rrr\|
         +----+
         */
        do {
            let vertices = [
                Vertex(color: [1, 0, 0, 1], pos: [-1, -1, 0.5, 1]),
                Vertex(color: [1, 0, 0, 1], pos: [ 1, -1, 0.5, 1]),
                Vertex(color: [1, 0, 0, 1], pos: [-1,  1, 0.5, 1]),
            ]
            vertexBufferR = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])!
        }
        
        /*
         +----+
         |    |
         |    |
         | /\ |
         |/gg\| green triangle
         +----+
         */
        do {
            let vertices = [
                Vertex(color: [0, 1, 0, 1], pos: [-1, -1, 0.5, 1]),
                Vertex(color: [0, 1, 0, 1], pos: [ 1, -1, 0.5, 1]),
                Vertex(color: [0, 1, 0, 1], pos: [ 0,  0, 0.5, 1]),
            ]
            vertexBufferG = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])!
        }
        
        /*
         +----+
         |\bbb| blue triangle
         | \bb|
         |  \b|
         |   \|
         +----+
         */
        do {
            let vertices = [
                Vertex(color: [0, 0, 1, 1], pos: [-1,  1, 0.5, 1]),
                Vertex(color: [0, 0, 1, 1], pos: [ 1, -1, 0.5, 1]),
                Vertex(color: [0, 0, 1, 1], pos: [ 1,  1, 0.5, 1]),
            ]
            vertexBufferB = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])!
        }
        
        /*
         +----+
         |\yy/| yellow triangle
         | \/ |
         |    |
         |    |
         +----+
         */
        do {
            let vertices = [
                Vertex(color: [1, 1, 0, 1], pos: [-1,  1, 0.5, 1]),
                Vertex(color: [1, 1, 0, 1], pos: [ 0,  0, 0.5, 1]),
                Vertex(color: [1, 1, 0, 1], pos: [ 1,  1, 0.5, 1]),
            ]
            vertexBufferY = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])!
        }
    }

    // Create our custom rendering pipeline, which loads shaders using `device`, and outputs to the format of `metalKitView`
    class func buildRenderPipelineWith(device: MTLDevice, metalKitView: MTKView) throws -> MTLRenderPipelineState {
        // Create a new pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD3<Float>>.stride;
        
        pipelineDescriptor.vertexDescriptor = vertexDescriptor;
        
        // Setup the shaders in the pipeline
        let library = device.makeDefaultLibrary()
        
        pipelineDescriptor.vertexFunction = library?.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "fragmentShader")
 
        // Setup the output pixel format to match the pixel format of the metal kit view
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        if (metalKitView.depthStencilPixelFormat == MTLPixelFormat.depth24Unorm_stencil8 ||
                metalKitView.depthStencilPixelFormat == MTLPixelFormat.depth32Float_stencil8)
        {
            pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat;
        }

        // Compile the configured pipeline descriptor to a pipeline state object
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    func draw(in view: MTKView) {
        let device = view.device!
        
        // Get an available command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        // Get the default MTLRenderPassDescriptor from the MTKView argument
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        
        struct Step {
            var depthBias: Float;
            var vertexBuffer: MTLBuffer;
        }
        
        // Should see Green/Yellow triangles on top of Red/Blue triangles
        /*
        +----+
        |\yy/|     yellow
        |r\/b|   red   blue
        |r/\b|     green
        |/gg\|
        +----+
        */
        let steps = [
            Step(depthBias:  0, vertexBuffer: vertexBufferR),  // draw at depthBias 0
            Step(depthBias: -1, vertexBuffer: vertexBufferG),  // draw same place at depthBias -1.
                                                               // Because depth test is less should draw
            Step(depthBias:  1, vertexBuffer: vertexBufferB),  // draw at depthBias 1
            Step(depthBias:  0, vertexBuffer: vertexBufferY),  // draw same place at depthBias 0.
                                                               // Because depth test is less should draw.
        ]

        // Change default settings. For example, we change the clear color from black to red.
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.25, 0.25, 0.25, 1)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        renderPassDescriptor.depthAttachment.loadAction = .clear

        // We compile renderPassDescriptor to a MTLRenderCommandEncoder.
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        // Setup render commands to encode
        // We tell it what render pipeline to use
        renderEncoder.setRenderPipelineState(pipelineState)

        for i in 0..<steps.count
        {
            let step = steps[i]

            let depthStencilState = MTLDepthStencilDescriptor()
            depthStencilState.depthCompareFunction = .less
            depthStencilState.isDepthWriteEnabled = true

            renderEncoder.setDepthBias(step.depthBias, slopeScale: 0, clamp: 0)
            renderEncoder.setDepthStencilState(device.makeDepthStencilState(descriptor: depthStencilState));
            
            // What vertex buffer data to use
            renderEncoder.setVertexBuffer(step.vertexBuffer, offset: 0, index: 0)

            // And what to draw
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        }

        // This finalizes the encoding of drawing commands.
        renderEncoder.endEncoding()

        // Tell Metal to send the rendering result to the MTKView when rendering completes
        commandBuffer.present(view.currentDrawable!)

        // Finally, send the encoded command buffer to the GPU.
        commandBuffer.commit()
        
        /*
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

            for offset in stride(from: 0, to: pixels.count, by: 4) {
                if (pixels[offset    ] != 255 ||
                    pixels[offset + 1] !=   0 ||
                    pixels[offset + 2] != 255 ||
                    pixels[offset + 3] != 255) {
                    
                    let p = offset / 4;
                    let x = p % width;
                    let y = p / width;
                    print("pixel at \(x),\(y) expected to be 255, 0, 255, 255 was \(pixels[offset]), \(pixels[offset + 1]), \(pixels[offset + 2]), \(pixels[offset + 3])")
                }
            }
         }
        */
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
}
