//
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
    let renderPipelineState: MTLRenderPipelineState
    let computePipelineState: MTLComputePipelineState
    let onScreenTriangleVertexBuffer: MTLBuffer
    let offScreenTriangleVertexBuffer: MTLBuffer
    let visibilityBuffer: MTLBuffer
    let combineResultsBuffer: MTLBuffer
    let event: MTLEvent;
    var cbEventId: UInt64 = 0;

    // This is the initializer for the Renderer class.
    // We will need access to the mtkView later, so we add it as a parameter here.
    init?(mtkView: MTKView) {
        device = mtkView.device!
        
        event = device.makeEvent()!

        commandQueue = device.makeCommandQueue()!
        
        // Create the Render Pipeline
        do {
            renderPipelineState = try Renderer.buildRenderPipelineWith(device: device, metalKitView: mtkView)
        } catch {
            print("Unable to compile render pipeline state: \(error)")
            return nil
        }
        
        do {
            computePipelineState = try Renderer.buildComputePipelineWith(device: device, keepOldValue: false)
        } catch {
            print("Unable to compile compute pipeline state: \(error)")
            return nil
        }
        
        /*
         +----+
         |\   |
         |r\  |
         |rr\ | red triangle (larger than screen)
         |rrr\|
         +----+
         */
        do {
            let vertices = [
                Vertex(color: [1, 0, 0, 1], pos: [-1, -1, 0.5, 1]),
                Vertex(color: [1, 0, 0, 1], pos: [ 2, -1, 0.5, 1]),
                Vertex(color: [1, 0, 0, 1], pos: [-1,  2, 0.5, 1]),
            ]
            onScreenTriangleVertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])!
        }

        do {
            let vertices = [
                Vertex(color: [0, 1, 0, 1], pos: [-3, -3, 0.5, 1]),
                Vertex(color: [0, 1, 0, 1], pos: [-3, -2, 0.5, 1]),
                Vertex(color: [0, 1, 0, 1], pos: [-2,  3, 0.5, 1]),
            ]
            offScreenTriangleVertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])!
        }

        visibilityBuffer = device.makeBuffer(length: 16)!
        let zero = [UInt8](repeating: 0, count: 8)
        combineResultsBuffer = device.makeBuffer(bytes: zero, length: 8)!
    }
    
    func getCurentEventId() -> UInt64 {
        return cbEventId
    }
    func getNextEventId() -> UInt64 {
        cbEventId = cbEventId + 1
        return cbEventId
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
        
        // Compile the configured pipeline descriptor to a pipeline state object
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    class func buildComputePipelineWith(device: MTLDevice, keepOldValue: Bool) throws -> MTLComputePipelineState {
        //let pipelineDescriptor = MTLComputePipelineDescriptor();
        
        let funcConstants = MTLFunctionConstantValues()
        var keepOldValueVal = keepOldValue
        funcConstants.setConstantValue(&keepOldValueVal, type: .bool, withName: "kCombineWithExistingResult")
        
        let library = device.makeDefaultLibrary()!
        let computeFunction = try library.makeFunction(name: "computeShader", constantValues: funcConstants)
        
        return try device.makeComputePipelineState(function: computeFunction)
    }
    
    func draw(in view: MTKView) {
//        let device = view.device!
        
        
        for i in 0..<256
        {
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

            do {
                guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return }
                blitEncoder.__fill(combineResultsBuffer, range: NSMakeRange(0, 8), value: 0)
                blitEncoder.endEncoding()
            }
//            commandBuffer.encodeSignalEvent(event, value: getNextEventId())

            // Get the default MTLRenderPassDescriptor from the MTKView argument
            guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
            
            renderPassDescriptor.colorAttachments[0].loadAction = .load
            renderPassDescriptor.visibilityResultBuffer = visibilityBuffer;

            var drawn = false;
            for j in 0..<4
            {
                let scissor = (((i >> 4) >> j) & 1) != 0
                let draw = i & (1 << j) != 0
                if (draw) {
                    drawn = drawn || !scissor

                    commandBuffer.encodeWaitForEvent(event, value: getCurentEventId())
                    do {
                        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
                        renderEncoder.setVisibilityResultMode(.boolean, offset: 8)
                        renderEncoder.setRenderPipelineState(renderPipelineState)
                        renderEncoder.setVertexBuffer(scissor ? offScreenTriangleVertexBuffer : onScreenTriangleVertexBuffer, offset: 0, index: 0)
                        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                        renderEncoder.endEncoding()
                    }
                    commandBuffer.encodeSignalEvent(event, value: getNextEventId())

                    // combineResultsBuffer: [previousResult]
                    // visiblityBuffer contains: [unknown, newResult]
                    
                 //   commandBuffer.encodeWaitForEvent(event, value: getCurentEventId())
                    do {
                        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return }
                        blitEncoder.copy(from: combineResultsBuffer, sourceOffset: 0, to: visibilityBuffer, destinationOffset: 0, size: 8)
                        blitEncoder.endEncoding()
                    }
                  //  commandBuffer.encodeSignalEvent(event, value: getNextEventId())

                    // combineResultsBuffer: [previousResult]
                    // visiblityBuffer contains: [previousReuslt, newResult]
          
                    commandBuffer.encodeWaitForEvent(event, value: getCurentEventId())
                    do {
                        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
                        computeEncoder.setComputePipelineState(computePipelineState)
                        var data = CombineVisibilityResultOptions(startOffset: 0, numOffsets: 2)
                        computeEncoder.setBytes(&data, length: 16, index: 0); // uniforms
                        computeEncoder.setBuffer(visibilityBuffer, offset: 0, index: 1)
                        computeEncoder.setBuffer(combineResultsBuffer, offset: 0, index: 2)
                        computeEncoder.dispatchThreads(MTLSize(width: 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
                        computeEncoder.endEncoding()
                    }
                    commandBuffer.encodeSignalEvent(event, value: getNextEventId())

                    // combineResultsBuffer: [combinedResult]
                    // visiblityBuffer contains: [previousReuslt, newResult]
                }
            }

            commandBuffer.encodeWaitForEvent(event, value: getCurentEventId())
            do {
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
            }
            let bytesPointer = combineResultsBuffer.contents()
            let result = bytesPointer.load(as: UInt64.self)
            let rendered = result != 0
            let okay = rendered == drawn ? "" : "----------------- bad!------------------"
            print("\(i): actually drawn: \(drawn), occlusion query drawn result: \(rendered) \(okay)")
        }
        
        
        exit(0)
        
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
}
