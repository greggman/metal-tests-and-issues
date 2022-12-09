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

precedencegroup PowerPrecedence { higherThan: MultiplicationPrecedence }
infix operator ^^ : PowerPrecedence
func ^^ (radix: Int, power: Int) -> Int {
  return Int(pow(Double(radix), Double(power)))
}

class Renderer : NSObject, MTKViewDelegate {

  let device: MTLDevice
  let commandQueue: MTLCommandQueue
  let renderPipelineState: MTLRenderPipelineState
  var vertexBuffers: [[[MTLBuffer]]] = []  //for each size, for each mode, array of buffers
  var stagingBuffers: [[[MTLBuffer]]] = []  //for each size, for each mode, array of buffers
  //    var sizes: [[Vertex]] = []
  var vertices: [[Vertex]] = []  // for each size, data
  #if DEBUG
    let numBuffers = 4;
    let minDraws = 2;
    let minPowerOf2 = 16;
    let maxPowerOf2 = 18;
    let capture = true;
    let minTime = 0.0;
    let timeLimit = 2.0;
  #else
    let numBuffers = 128
    let minDraws = 40;
    let minPowerOf2 = 5;
    let maxPowerOf2 = 22;
    let capture = false;
    let minTime = 0.5;
    let timeLimit = 2.0;
  #endif
  enum StorageMode: Int {
    case sharedMode = 0, managedMode = 1, privateMode = 2
  }
  let modes = [MTLResourceOptions.storageModeShared, MTLResourceOptions.storageModeManaged, MTLResourceOptions.storageModePrivate]
  let modeNames = ["shared", "managed", "private"]
  let captureManager = MTLCaptureManager.shared()
  let captureDescriptor = MTLCaptureDescriptor()
  var frameCount = 0;
  let numFramesToCapture = 1;

  // This is the initializer for the Renderer class.
  // We will need access to the mtkView later, so we add it as a parameter here.
  init?(mtkView: MTKView) {
    print("numBuffers \(numBuffers)");
    device = mtkView.device!

    if (capture) {
      captureDescriptor.captureObject = device
      do {
          try captureManager.startCapture(with: captureDescriptor)
      }
      catch
      {
          fatalError("error when trying to capture: \(error)")
      }
    }

    commandQueue = device.makeCommandQueue()!

    // Create the Render Pipeline
    do {
      renderPipelineState = try Renderer.buildRenderPipelineWith(device: device, metalKitView: mtkView)
    } catch {
      print("Unable to compile render pipeline state: \(error)")
      return nil
    }

    for powerOf2 in minPowerOf2..<maxPowerOf2
    {
      let numBytes = 2 ^^ powerOf2
      let numVertex = numBytes / MemoryLayout<Vertex>.stride;
      var verts: [Vertex] = []
      for _ in 0..<numVertex
      {
        verts.append(Vertex(pos: [0, 0, 0, 0]))
      }
      vertices.append(verts)

      var modeBuffers: [[MTLBuffer]] = []
      var stageBuffers: [[MTLBuffer]] = []
      for modeNdx in 0..<modes.count
      {
        let mode = modes[modeNdx]
        let modeName = modeNames[modeNdx]
        var buffers: [MTLBuffer] = []
        var stages: [MTLBuffer] = []
        for i in 0..<numBuffers
        {
          do {
            let vertexBuffer = mode == MTLResourceOptions.storageModePrivate ?  device.makeBuffer(length: numBytes, options: [mode])! : device.makeBuffer(bytes: verts, length: numBytes, options: [mode])!
            vertexBuffer.label = "VertBuf_\(modeName)_\(i)"
            buffers.append(vertexBuffer)
            let stage = mode == MTLResourceOptions.storageModePrivate ?  device.makeBuffer(length: numBytes, options: [mode])! : device.makeBuffer(bytes: verts, length: numBytes, options: [mode])!
            stage.label = "StageBuf_\(modeName)_\(i)"
            stages.append(stage)
          }
        }
        modeBuffers.append(buffers)
        stageBuffers.append(stages)
      }
      vertexBuffers.append(modeBuffers)
      stagingBuffers.append(stageBuffers)
    }
  }

  // Create our custom rendering pipeline, which loads shaders using `device`, and outputs to the format of `metalKitView`
  class func buildRenderPipelineWith(device: MTLDevice, metalKitView: MTKView) throws -> MTLRenderPipelineState {
    // Create a new pipeline descriptor
    let pipelineDescriptor = MTLRenderPipelineDescriptor()

    let vertexDescriptor = MTLVertexDescriptor()
    vertexDescriptor.attributes[0].format = .float4
    vertexDescriptor.attributes[0].bufferIndex = 0
    vertexDescriptor.attributes[0].offset = 0
    vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD4<Float>>.stride;

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

  func noop(blitEncoder: MTLBlitCommandEncoder, mode: MTLResourceOptions, vertexBuffer: MTLBuffer, sizeVertices: [Vertex], byteCount: Int, ndx: Int, stagingBuffers: [[MTLBuffer]])
  {
  }

  func noUpdateContent(blitEncoder: MTLBlitCommandEncoder, mode: MTLResourceOptions, vertexBuffer: MTLBuffer, sizeVertices: [Vertex], byteCount: Int, ndx: Int, stagingBuffers: [[MTLBuffer]])
  {
    switch (mode) {
    case MTLResourceOptions.storageModeShared:
      vertexBuffer.contents()
      break;
    case MTLResourceOptions.storageModeManaged:
      vertexBuffer.contents()
      break;
    case MTLResourceOptions.storageModePrivate:
      break;
    default:
      break;
    }
  }

  func updateBuffer(blitEncoder: MTLBlitCommandEncoder, mode: MTLResourceOptions, vertexBuffer: MTLBuffer, sizeVertices: [Vertex], byteCount: Int, ndx: Int, stagingBuffers: [[MTLBuffer]])
  {
    switch (mode) {
    case MTLResourceOptions.storageModeShared:
      vertexBuffer.contents().copyMemory(from: sizeVertices, byteCount: byteCount)
      break;
    case MTLResourceOptions.storageModeManaged:
      vertexBuffer.contents().copyMemory(from: sizeVertices, byteCount: byteCount)
      vertexBuffer.didModifyRange(Range<Int>(0...byteCount - 1))
      break;
    case MTLResourceOptions.storageModePrivate:
      break;
    default:
      break;
    }
  }

  func blitToBufferViaShared(blitEncoder: MTLBlitCommandEncoder, mode: MTLResourceOptions, vertexBuffer: MTLBuffer, sizeVertices: [Vertex], byteCount: Int, ndx: Int, stagingBuffers: [[MTLBuffer]])
  {
    let stagingBuffer = stagingBuffers[0 /*StorageMode.sharedMode*/][ndx];  // shared
    blitEncoder.copy(from: stagingBuffer, sourceOffset:0, to: vertexBuffer, destinationOffset: 0, size: stagingBuffer.length);
  }

  func blitToBufferViaManaged(blitEncoder: MTLBlitCommandEncoder, mode: MTLResourceOptions, vertexBuffer: MTLBuffer, sizeVertices: [Vertex], byteCount: Int, ndx: Int, stagingBuffers: [[MTLBuffer]])
  {
    let stagingBuffer = stagingBuffers[1 /*StorageMode.managedMode*/][ndx];  // managed
    blitEncoder.copy(from: stagingBuffer, sourceOffset:0, to: vertexBuffer, destinationOffset: 0, size: stagingBuffer.length);
  }

  func copyBlitToBufferViaShared(blitEncoder: MTLBlitCommandEncoder, mode: MTLResourceOptions, vertexBuffer: MTLBuffer, sizeVertices: [Vertex], byteCount: Int, ndx: Int, stagingBuffers: [[MTLBuffer]])
  {
    let stagingBuffer = stagingBuffers[0 /*StorageMode.sharedMode*/][ndx];  // shared
    stagingBuffer.contents().copyMemory(from: sizeVertices, byteCount: byteCount)
    blitEncoder.copy(from: stagingBuffer, sourceOffset:0, to: vertexBuffer, destinationOffset: 0, size: stagingBuffer.length);
  }

  func copyBlitToBufferViaManaged(blitEncoder: MTLBlitCommandEncoder, mode: MTLResourceOptions, vertexBuffer: MTLBuffer, sizeVertices: [Vertex], byteCount: Int, ndx: Int, stagingBuffers: [[MTLBuffer]])
  {
    let stagingBuffer = stagingBuffers[1 /*StorageMode.managedMode*/][ndx];  // managed
    stagingBuffer.contents().copyMemory(from: sizeVertices, byteCount: byteCount)
    stagingBuffer.didModifyRange(Range<Int>(0...byteCount - 1))
    blitEncoder.copy(from: stagingBuffer, sourceOffset:0, to: vertexBuffer, destinationOffset: 0, size: stagingBuffer.length);
  }

  func blitToHalfBufferViaManaged(blitEncoder: MTLBlitCommandEncoder, mode: MTLResourceOptions, vertexBuffer: MTLBuffer, sizeVertices: [Vertex], byteCount: Int, ndx: Int, stagingBuffers: [[MTLBuffer]])
  {
    let stagingBuffer = stagingBuffers[1 /*StorageMode.managedMode*/][ndx];  // managed
    let length = stagingBuffer.length / 2;
    if (length > 4) {
      blitEncoder.copy(from: stagingBuffer, sourceOffset:0, to: vertexBuffer, destinationOffset: 0, size: length);
    }
  }

  func test(view: MTKView, includePrivate: Bool, drawCount: Int, fn: (MTLBlitCommandEncoder, MTLResourceOptions, MTLBuffer, [Vertex], Int, Int, [[MTLBuffer]]) -> Void, name: String)
  {
    print("{name: \"\(name)\", data: [")
    for sizeNdx in 0..<vertexBuffers.count
    {
      let sizeVertices = vertices[sizeNdx]
      let sizeBuffers = vertexBuffers[sizeNdx]
      let sizeStagingBuffers = stagingBuffers[sizeNdx]
      let sizeInBytes = sizeVertices.count * MemoryLayout<Vertex>.stride
      let sizeStr = String(sizeInBytes).padding(toLength: 7, withPad: " ", startingAt: 0)
      print ("  { size: \(sizeStr), ", terminator: "")

      let numModes = includePrivate ? 3 : 2
      for modeNdx in 0..<numModes
      {
        let mode = modes[modeNdx]
        let modeName = modeNames[modeNdx]
        let vertexBuffers = sizeBuffers[modeNdx]
        let verts = vertices[sizeNdx];

        let start = DispatchTime.now();
        var numDraws = 0
        // for drawId in 0..<maxDraws
        while(true)
        {
          numDraws += 1;
          guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
          commandBuffer.label = "cmdbuf: \(name), \(modeName), \(sizeInBytes)";

          // Get the default MTLRenderPassDescriptor from the MTKView argument
          guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }

          renderPassDescriptor.colorAttachments[0].loadAction = .load

          do {
            guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return }
            blitEncoder.label = "blitEncoder: \(name), \(modeName), \(sizeInBytes)";

            for i in 0..<vertexBuffers.count
            {
              let vertexBuffer = vertexBuffers[i]
              let byteCount = sizeVertices.count * MemoryLayout<Vertex>.stride;
              fn(blitEncoder, mode, vertexBuffer, sizeVertices, byteCount, i, sizeStagingBuffers)
            }

            blitEncoder.endEncoding()
          }

          do {
            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
            renderEncoder.setRenderPipelineState(renderPipelineState)
            renderEncoder.label = "renderEncoder: \(name), \(modeName), \(sizeInBytes)";

            for i in 0..<vertexBuffers.count
            {
              let vertexBuffer = vertexBuffers[i]
              // if (drawId == 0) {
              //  print("storageMode: \(vertexBuffer.storageMode), len: \(vertexBuffer.length), count: \(verts.count)")
              // }
              for dc in 0..<drawCount {
                let count = verts.count / drawCount;
                let start = count * dc;
                renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                renderEncoder.drawPrimitives(type: .triangle, vertexStart: start, vertexCount: count)
              }
            }

            renderEncoder.endEncoding()
          }

          commandBuffer.commit()
          commandBuffer.waitUntilCompleted()
          let time = DispatchTime.now();
          let elapsedTime = Double(time.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000;
          if (elapsedTime >= timeLimit || (elapsedTime >= minTime && numDraws >= minDraws)) {
            break;
          }
        }
        let end = DispatchTime.now();
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1_000_000_000
        let iterationsPerSecond = Double(numDraws) / timeInterval;
        let ipsStr = String(format: "%7.2f", iterationsPerSecond);
        print ("\(modeName): \(ipsStr), ", terminator: "")
      }
      print(" },")
    }
    print("]},")
  }

  func draw(in view: MTKView) {
    frameCount += 1
    //        let device = view.device!

    /* need to check Private, Shared, Managed

     1. Is Shared slower in general

     render without updating but call buffer.content()

     If Shared has to copy the data every time then Shared should be slower than Private/Managed

     2. Updating Shared vs Managed

     copy data to buffer. In managed we need to call didModifyRange
     is Managed slower than Shared for difference sizes

     3. Update via Blit -> Shared, Managed, Private

     test all combos of
     staged = Managed, Shared,
     dest = Shared, Managed, Private

     */
    print("[")
    test(view: view, includePrivate: true, drawCount: 1, fn: noop,
         name: "noop (checks drawing with unmodified buffers)")
    test(view: view, includePrivate: true, drawCount: 4, fn: noop,
         name: "noop (checks drawing by 1/4th with unmodified buffers)")
    test(view: view, includePrivate: true, drawCount: 1, fn: noUpdateContent,
         name: "noUpdateContent (checks drawing with unmodified buffers but calls buffer.contents())")
    test(view: view, includePrivate: false, drawCount: 1, fn: updateBuffer,
         name: "updateBuffer (checks modifying the buffer via buffer.contents().copyBytes)")
    test(view: view, includePrivate: true, drawCount: 1, fn: blitToBufferViaShared,
         name: "blitToBufferViaShared (checks updating the buffer via blit from a storageMode.shared buffer)")
    test(view: view, includePrivate: true, drawCount: 1, fn: blitToBufferViaManaged,
         name: "blitToBufferViaManaged (checks updating the buffer via blit from a storageMode.managed buffer )")
    test(view: view, includePrivate: true, drawCount: 1, fn: copyBlitToBufferViaShared,
         name: "copyBlitToBufferViaShared (checks updating the buffer via blit from a storageMode.shared buffer)")
    test(view: view, includePrivate: true, drawCount: 1, fn: copyBlitToBufferViaManaged,
         name: "copyBlitToBufferViaManaged (checks updating the buffer via blit from a storageMode.managed buffer )")
    test(view: view, includePrivate: true, drawCount: 1, fn: blitToBufferViaManaged,
         name: "blitToHalfBufferViaManaged (checks updating half the buffer via blit from a storageMode.managed buffer)")
    print("{}]")

    if (numFramesToCapture == frameCount) {
      if (capture) {
        captureManager.stopCapture()
      }
      exit(0)
    }
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
  }
}
