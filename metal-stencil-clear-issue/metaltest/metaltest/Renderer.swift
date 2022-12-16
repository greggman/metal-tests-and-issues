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
    let vertexBuffer: MTLBuffer
    
    // This is the initializer for the Renderer class.
    // We will need access to the mtkView later, so we add it as a parameter here.
    init?(mtkView: MTKView) {
        device = mtkView.device!
        
        mtkView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8;

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
            Vertex(pos: [-1, -1]),
            Vertex(pos: [ 1, -1]),
            Vertex(pos: [-1,  1]),
        
            Vertex(pos: [-1,  1]),
            Vertex(pos: [ 1, -1]),
            Vertex(pos: [ 1,  1]),
        ]
        // And copy it to a Metal buffer...
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])!
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
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat

        // Compile the configured pipeline descriptor to a pipeline state object
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    func draw(in view: MTKView) {
        let device = view.device!
        
        // Get an available command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        // Get the default MTLRenderPassDescriptor from the MTKView argument
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }

        // Change default settings. For example, we change the clear color from black to red.
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.25, 0.25, 0.25, 1)
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        renderPassDescriptor.stencilAttachment.clearStencil = 0
        renderPassDescriptor.stencilAttachment.loadAction = .clear;

        // We compile renderPassDescriptor to a MTLRenderCommandEncoder.
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        // Setup render commands to encode
        // We tell it what render pipeline to use
        renderEncoder.setRenderPipelineState(pipelineState)

        let depthStencilState = MTLDepthStencilDescriptor()
        depthStencilState.depthCompareFunction = .always
        depthStencilState.isDepthWriteEnabled = false
        
        depthStencilState.frontFaceStencil.depthFailureOperation = .keep
        depthStencilState.frontFaceStencil.stencilFailureOperation = .keep
        depthStencilState.frontFaceStencil.depthStencilPassOperation = .keep
        depthStencilState.frontFaceStencil.stencilCompareFunction =  MTLCompareFunction.equal
        depthStencilState.frontFaceStencil.readMask = 0xFF
        
        depthStencilState.backFaceStencil.depthFailureOperation = .keep
        depthStencilState.backFaceStencil.stencilFailureOperation = .keep
        depthStencilState.backFaceStencil.depthStencilPassOperation = .keep
        depthStencilState.backFaceStencil.stencilCompareFunction =  MTLCompareFunction.equal
        depthStencilState.backFaceStencil.readMask = 0xFF

        renderEncoder.setDepthStencilState(device.makeDepthStencilState(descriptor: depthStencilState));
        renderEncoder.setStencilReferenceValue(0x0)
        
        // What vertex buffer data to use
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

        // And what to draw
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

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
