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

  // This is the initializer for the Renderer class.
  // We will need access to the mtkView later, so we add it as a parameter here.
  init?(mtkView: MTKView) {
    device = mtkView.device!

    commandQueue = device.makeCommandQueue()!
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

  func draw(in view: MTKView) {
    //        let device = view.device!

    struct FormatInfo {
      let format: MTLPixelFormat;
      let name: String;
      let bytesPerPixel: Int;
    };
    let formats: [FormatInfo] = [
      /*
      // 0
      FormatInfo(  format: .a8Unorm, name: "a8Unorm", bytesPerPixel: 1 ), //   Ordinary format with one 8-bit normalized unsigned integer component.
      FormatInfo(  format: .r8Unorm, name: "r8Unorm", bytesPerPixel: 1 ), //   Ordinary format with one 8-bit normalized unsigned integer component.
      FormatInfo(  format: .r8Unorm_srgb, name: "r8Unorm_srgb", bytesPerPixel: 1 ), //   Ordinary format with one 8-bit normalized unsigned integer component with conversion between sRGB and linear space.
      FormatInfo(  format: .r8Snorm, name: "r8Snorm", bytesPerPixel: 1 ), //   Ordinary format with one 8-bit normalized signed integer component.
      // 4
      FormatInfo(  format: .r8Uint, name: "r8Uint", bytesPerPixel: 1 ), //   Ordinary format with one 8-bit unsigned integer component.
      FormatInfo(  format: .r8Sint, name: "r8Sint", bytesPerPixel: 1 ), //   Ordinary format with one 8-bit signed integer component.
      //Ordinary 16-Bit Pixel Formats
      FormatInfo(  format: .r16Unorm, name: "r16Unorm", bytesPerPixel: 2 ), //   Ordinary format with one 16-bit normalized unsigned integer component.
      FormatInfo(  format: .r16Snorm, name: "r16Snorm", bytesPerPixel: 2 ), //   Ordinary format with one 16-bit normalized signed integer component.
      // 8
      FormatInfo(  format: .r16Uint, name: "r16Uint", bytesPerPixel: 2 ), //   Ordinary format with one 16-bit unsigned integer component.
      FormatInfo(  format: .r16Sint, name: "r16Sint", bytesPerPixel: 2 ), //   Ordinary format with one 16-bit signed integer component.
      FormatInfo(  format: .r16Float, name: "r16Float", bytesPerPixel: 2 ), //   Ordinary format with one 16-bit floating-point component.
      FormatInfo(  format: .rg8Unorm, name: "rg8Unorm", bytesPerPixel: 2 ), //   Ordinary format with two 8-bit normalized unsigned integer components.
      // 12
      FormatInfo(  format: .rg8Unorm_srgb, name: "rg8Unorm_srgb", bytesPerPixel: 2 ), //   Ordinary format with two 8-bit normalized unsigned integer components with conversion between sRGB and linear space.
      FormatInfo(  format: .rg8Snorm, name: "rg8Snorm", bytesPerPixel: 2 ), //   Ordinary format with two 8-bit normalized signed integer components.
      FormatInfo(  format: .rg8Uint, name: "rg8Uint", bytesPerPixel: 2 ), //   Ordinary format with two 8-bit unsigned integer components.
      FormatInfo(  format: .rg8Sint, name: "rg8Sint", bytesPerPixel: 2 ), //   Ordinary format with two 8-bit signed integer components.
      //Packed 16-Bit Pixel Formats
      // 16
      FormatInfo(  format: .b5g6r5Unorm, name: "b5g6r5Unorm", bytesPerPixel: 2 ), //   Packed 16-bit format with normalized unsigned integer color components: 5 bits for blue, 6 bits for green, 5 bits for red, packed into 16 bits.
      FormatInfo(  format: .a1bgr5Unorm, name: "a1bgr5Unorm", bytesPerPixel: 2 ), //   Packed 16-bit format with normalized unsigned integer color components: 5 bits each for BGR and 1 for alpha, packed into 16 bits.
      FormatInfo(  format: .abgr4Unorm, name: "abgr4Unorm", bytesPerPixel: 2 ), //   Packed 16-bit format with normalized unsigned integer color components: 4 bits each for ABGR, packed into 16 bits.
      FormatInfo(  format: .bgr5A1Unorm, name: "bgr5A1Unorm", bytesPerPixel: 2 ), //   Packed 16-bit format with normalized unsigned integer color components: 5 bits each for BGR and 1 for alpha, packed into 16 bits.
      // 20
      //Ordinary 32-Bit Pixel Formats
      FormatInfo(  format: .r32Uint, name: "r32Uint", bytesPerPixel: 4 ), //   Ordinary format with one 32-bit unsigned integer component.
      FormatInfo(  format: .r32Sint, name: "r32Sint", bytesPerPixel: 4 ), //   Ordinary format with one 32-bit signed integer component.
      */
      FormatInfo(  format: .r32Float, name: "r32Float", bytesPerPixel: 4 ), //   Ordinary format with one 32-bit floating-point component.
      /*
      FormatInfo(  format: .rg16Unorm, name: "rg16Unorm", bytesPerPixel: 4 ), //   Ordinary format with two 16-bit normalized unsigned integer components.
      // 24
      FormatInfo(  format: .rg16Snorm, name: "rg16Snorm", bytesPerPixel: 4 ), //   Ordinary format with two 16-bit normalized signed integer components.
      FormatInfo(  format: .rg16Uint, name: "rg16Uint", bytesPerPixel: 4 ), //   Ordinary format with two 16-bit unsigned integer components.
      FormatInfo(  format: .rg16Sint, name: "rg16Sint", bytesPerPixel: 4 ), //   Ordinary format with two 16-bit signed integer components.
      FormatInfo(  format: .rg16Float, name: "rg16Float", bytesPerPixel: 4 ), //   Ordinary format with two 16-bit floating-point components.
      // 28
      FormatInfo(  format: .rgba8Unorm, name: "rgba8Unorm", bytesPerPixel: 4 ), //   Ordinary format with four 8-bit normalized unsigned integer components in RGBA order.
      FormatInfo(  format: .rgba8Unorm_srgb, name: "rgba8Unorm_srgb", bytesPerPixel: 4 ), //   Ordinary format with four 8-bit normalized unsigned integer components in RGBA order with conversion between sRGB and linear space.
      FormatInfo(  format: .rgba8Snorm, name: "rgba8Snorm", bytesPerPixel: 4 ), //   Ordinary format with four 8-bit normalized signed integer components in RGBA order.
      FormatInfo(  format: .rgba8Uint, name: "rgba8Uint", bytesPerPixel: 4 ), //   Ordinary format with four 8-bit unsigned integer components in RGBA order.
      // 32
      FormatInfo(  format: .rgba8Sint, name: "rgba8Sint", bytesPerPixel: 4 ), //   Ordinary format with four 8-bit signed integer components in RGBA order.
      FormatInfo(  format: .bgra8Unorm, name: "bgra8Unorm", bytesPerPixel: 4 ), //   Ordinary format with four 8-bit normalized unsigned integer components in BGRA order.
      FormatInfo(  format: .bgra8Unorm_srgb, name: "bgra8Unorm_srgb", bytesPerPixel: 4 ), //   Ordinary format with four 8-bit normalized unsigned integer components in BGRA order with conversion between sRGB and linear space.
      //Packed 32-Bit Pixel Formats
      FormatInfo(  format: .bgr10a2Unorm, name: "bgr10a2Unorm", bytesPerPixel: 4 ), //   A 32-bit packed pixel format with four normalized unsigned integer components: 10-bit blue, 10-bit green, 10-bit red, and 2-bit alpha.
      FormatInfo(  format: .rgb10a2Unorm, name: "rgb10a2Unorm", bytesPerPixel: 4 ), //   A 32-bit packed pixel format with four normalized unsigned integer components: 10-bit red, 10-bit green, 10-bit blue, and 2-bit alpha.
      FormatInfo(  format: .rgb10a2Uint, name: "rgb10a2Uint", bytesPerPixel: 4 ), //   A 32-bit packed pixel format with four unsigned integer components: 10-bit red, 10-bit green, 10-bit blue, and 2-bit alpha.
      FormatInfo(  format: .rg11b10Float, name: "rg11b10Float", bytesPerPixel: 4 ), //   32-bit format with floating-point color components, 11 bits each for red and green and 10 bits for blue.
      FormatInfo(  format: .rgb9e5Float, name: "rgb9e5Float", bytesPerPixel: 4 ), //   Packed 32-bit format with floating-point color components: 9 bits each for RGB and 5 bits for an exponent shared by RGB, packed into 32 bits.
      //Ordinary 64-Bit Pixel Formats
      FormatInfo(  format: .rg32Uint, name: "rg32Uint", bytesPerPixel: 8 ), //   Ordinary format with two 32-bit unsigned integer components.
      FormatInfo(  format: .rg32Sint, name: "rg32Sint", bytesPerPixel: 8 ), //   Ordinary format with two 32-bit signed integer components.
      FormatInfo(  format: .rg32Float, name: "rg32Float", bytesPerPixel: 8 ), //   Ordinary format with two 32-bit floating-point components.
      FormatInfo(  format: .rgba16Unorm, name: "rgba16Unorm", bytesPerPixel: 8 ), //   Ordinary format with four 16-bit normalized unsigned integer components in RGBA order.
      FormatInfo(  format: .rgba16Snorm, name: "rgba16Snorm", bytesPerPixel: 8 ), //   Ordinary format with four 16-bit normalized signed integer components in RGBA order.
      FormatInfo(  format: .rgba16Uint, name: "rgba16Uint", bytesPerPixel: 8 ), //   Ordinary format with four 16-bit unsigned integer components in RGBA order.
      FormatInfo(  format: .rgba16Sint, name: "rgba16Sint", bytesPerPixel: 8 ), //   Ordinary format with four 16-bit signed integer components in RGBA order.
      FormatInfo(  format: .rgba16Float, name: "rgba16Float", bytesPerPixel: 8 ), //   Ordinary format with four 16-bit floating-point components in RGBA order.
      // Ordinary 128-Bit Pixel Formats
      FormatInfo(  format: .rgba32Uint, name: "rgba32Uint", bytesPerPixel: 16 ), //   Ordinary format with four 32-bit unsigned integer components in RGBA order.
      FormatInfo(  format: .rgba32Sint, name: "rgba32Sint", bytesPerPixel: 16 ), //   Ordinary format with four 32-bit signed integer components in RGBA order.
      FormatInfo(  format: .rgba32Float, name: "rgba32Float", bytesPerPixel: 16 ), //   Ordinary format with four 32-bit floating-point components in RGBA order.
      */
    ]

    struct TypeInfo {
      let type: MTLTextureType;
      let name: String;
    }

    let textureTypes: [TypeInfo] = [
      TypeInfo(type: .type2D, name: "type2D"),
      //TypeInfo(type: .type3D, name: "type3D"),
      //TypeInfo(type: .type2DArray, name: "type2DArray"),
    ];

    let bufferSize = 2048
    let dstBuffer = device.makeBuffer(length: bufferSize, options: [MTLResourceOptions.storageModeShared])!
    var count: UInt8 = 0;

    let start = 0

    for texInfo in textureTypes
    {
      let textureType = texInfo.type

      print("\n========================[ \(texInfo.name) ] ============================")

      for ndx in start..<formats.count
      {
        let format = formats[ndx]
        count = count &+ 1
        let srcOrigin = MTLOrigin(x: 0, y: 0, z: 0);
        let srcSize = MTLSize(width: 64, height: 8, depth: textureType == .type3D ? 5 : 1);
        let dstSize = MTLSize(width: 64, height: 8, depth: textureType == .type3D ? 5 : 1)
        let dstBufferBytesPerRow = dstSize.width * format.bytesPerPixel;
        let dstBufferBytesPerImage = dstSize.height * dstBufferBytesPerRow;

        let textureDescriptor: MTLTextureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = textureType
        textureDescriptor.pixelFormat = format.format
        textureDescriptor.width = srcSize.width
        textureDescriptor.height = srcSize.height
        textureDescriptor.depth = srcSize.depth;

        // let destinationOffset = 0;
        let destinationOffset = 0

        let dstEndOffset = destinationOffset + dstSize.height * dstBufferBytesPerRow
        if (dstEndOffset > bufferSize) {
          print("ERROR: bufferSize \(bufferSize) too small, need \(dstEndOffset)")
        }

        print("\nFormat: \(format.name), type: \(texInfo.name) texSize: \(srcSize.width), \(srcSize.height), \(srcSize.depth), copySize: \(dstSize.width), \(dstSize.height), \(dstSize.depth), destinationOffset: \(destinationOffset), destinationBytesPerRow: \(dstBufferBytesPerRow), destinationBytesPerImage: \(dstBufferBytesPerImage)")

        let texture = device.makeTexture(descriptor: textureDescriptor)!
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: srcSize)

        let numBytes = format.bytesPerPixel * srcSize.width * srcSize.height * srcSize.depth;
        print ("numBytes: \(numBytes)")
        var data = [UInt8](repeating: 0, count: numBytes)
        for i in 0..<numBytes {
          data[i] = (count &+ UInt8(i & 0xFF)) | 0x80
        }
        //print(data)
        texture.replace(
            region: region,
            mipmapLevel: 0,
            slice: 0,
            withBytes: data,
            bytesPerRow: format.bytesPerPixel * srcSize.width,
            bytesPerImage: format.bytesPerPixel * srcSize.width * srcSize.height)

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        do {
          guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return }

          blitEncoder.fill(
            buffer: dstBuffer,
            range: 0..<bufferSize,
            value: 1
          )
          for row in 0..<dstSize.height {
            let localSrcOrigin = MTLOrigin(x: 0, y: row, z: 0)
            let localDstSize = MTLSize(width: dstSize.width, height: 1, depth: 1)
            let localDstOffset = destinationOffset + dstBufferBytesPerRow * row
            blitEncoder.copy(
              from: texture,
              sourceSlice: 0,
              sourceLevel: 0,
              sourceOrigin: localSrcOrigin,
              sourceSize: localDstSize,
              to: dstBuffer,
              destinationOffset: localDstOffset,
              destinationBytesPerRow: dstBufferBytesPerRow,
              destinationBytesPerImage: dstBufferBytesPerImage);
          }
          blitEncoder.endEncoding()
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let copied = checkContents(
            srcOrigin: srcOrigin,
            srcSize: srcSize,
            buffer: dstBuffer,
            bufferSize: bufferSize,
            destinationOffset: destinationOffset,
            bytesPerPixel: format.bytesPerPixel,
            bufferBytesPerRow: dstBufferBytesPerRow,
            bufferBytesPerImage: dstBufferBytesPerImage,
            dstSize: dstSize,
            dataStartValue: count);
        print("data was \(copied ? "copied" : "NOT copied")")
        //exit(0)
      }
    }

    exit(0)
  }

  func hexdump(data: [UInt8])
  {
    for off in stride(from:0, to: data.count, by: 32) {
      let end = min(off + 32, data.count)
      let part = data[off...end]
      print("0x\(String(format: "%06x", off)): \(part)")
    }
  }

  func checkContents(srcOrigin: MTLOrigin, srcSize: MTLSize, buffer: MTLBuffer, bufferSize: Int, destinationOffset: Int, bytesPerPixel: Int, bufferBytesPerRow: Int, bufferBytesPerImage: Int, dstSize: MTLSize, dataStartValue: UInt8) -> Bool
  {
    let width = dstSize.width;
    let height = dstSize.height;
    let depth = dstSize.depth;
    let rawPointer = buffer.contents()
    let typedPointer = rawPointer.bindMemory(to: UInt8.self, capacity: bufferSize)
    let uint8Buffer = UnsafeBufferPointer(start: typedPointer, count: bufferSize)
    let data = Array(uint8Buffer)
    //hexdump(data: data)
    //print("bpr: \(bytesPerRow)")

    for i in 0..<bufferSize {
      let p = i > destinationOffset ? i - destinationOffset : 0;
      let slice = p / bufferBytesPerImage
      let row = p % bufferBytesPerImage / bufferBytesPerRow
      let byteX = p % bufferBytesPerImage % bufferBytesPerRow
      let x = byteX / bytesPerPixel
      let value = data[i]
      let srcOffset = (slice + srcOrigin.z) * srcSize.width * srcSize.height +
                      (row + srcOrigin.y) * srcSize.width * bytesPerPixel +
                      srcOrigin.x * bytesPerPixel + byteX;
      let inBounds = i >= destinationOffset && slice < depth && row < height && x < width
      let expected = inBounds ? ((dataStartValue &+ UInt8(srcOffset & 0xFF)) | 0x80) : 1
      if (value != expected) {
        print("ERROR:\(inBounds ? "" : "DATA CORRUPTION!: ")buffer not correct value at \(x), \(row), \(slice), srcOffset: \(srcOffset), expected \(expected), was: \(value)")
        return false
      }
    }

    return true
  }



  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
  }
}
