import MetalKit

let allDevices = MTLCopyAllDevices()
for device in allDevices {
    print("========================")
    print("GPU: \(device.name)")
    
    let commandQueue = device.makeCommandQueue()!
    let library = device.makeDefaultLibrary()!
    //----------------------------------------------------------------------
    // pipeline
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(try device.makeComputePipelineState(function: library.makeFunction(name: "doit")!))
    //----------------------------------------------------------------------
    // Set Data
    let numSteps = 16;
    let outputBuffer = device.makeBuffer(length: MemoryLayout<Float>.stride * (numSteps + 1) * 4, options: [])!
    encoder.setBuffer(outputBuffer, offset: 0, index: 0)
    //----------------------------------------------------------------------
    let textureDescriptor: MTLTextureDescriptor = MTLTextureDescriptor()
    textureDescriptor.textureType = .type2D
    textureDescriptor.pixelFormat = .rgba8Unorm
    textureDescriptor.width = 2
    textureDescriptor.height = 1
    textureDescriptor.depth = 1
    textureDescriptor.mipmapLevelCount = 2
    
    let texture = device.makeTexture(descriptor: textureDescriptor)!
    
    var data = [UInt32](repeating: 0, count: 1)
    data[0] = 0xFFFFFFFF
    texture.replace(
        region: MTLRegion(origin: MTLOrigin(x: 1, y: 0, z: 0), size: MTLSize(width: 1, height: 1, depth: 1)),
        mipmapLevel: 0,
        slice: 0,
        withBytes: data,
        bytesPerRow: 4,
        bytesPerImage: 8)
    
    texture.replace(
        region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: 1, height: 1, depth: 1)),
        mipmapLevel: 1,
        slice: 0,
        withBytes: data,
        bytesPerRow: 4,
        bytesPerImage: 4)
    
    let samplerDescriptor = MTLSamplerDescriptor()
    samplerDescriptor.magFilter = MTLSamplerMinMagFilter.linear
    samplerDescriptor.minFilter = MTLSamplerMinMagFilter.linear
    samplerDescriptor.mipFilter = MTLSamplerMipFilter.linear
    samplerDescriptor.rAddressMode = MTLSamplerAddressMode.clampToEdge
    samplerDescriptor.sAddressMode = MTLSamplerAddressMode.clampToEdge
    samplerDescriptor.tAddressMode = MTLSamplerAddressMode.clampToEdge
    let samplerState = device.makeSamplerState(descriptor: samplerDescriptor)!
    
    encoder.setSamplerState(samplerState, index: 0)
    encoder.setTexture(texture, index: 0)
    
    // Run Kernel
    let numThreadgroups = MTLSize(width: 1, height: 1, depth: 1)
    let threadsPerThreadgroup = MTLSize(width: numSteps + 1, height: 1, depth: 1)
    encoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
    encoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    //----------------------------------------------------------------------
    // Results
    let bufferLength = outputBuffer.length
    let floatCount = bufferLength / MemoryLayout<Float>.stride
    let bufferPointer = outputBuffer.contents().bindMemory(to: Float.self, capacity: floatCount)
    let result = Array(UnsafeBufferPointer(start: bufferPointer, count: floatCount))
    
    print("mix level between mips")
    for i in 0...numSteps {
        let mipLevel = Float(i) / Float(numSteps)
        let offset = i * 4;
        print(String(format: "mipLevel: %f   weight: %f", mipLevel, result[offset]))
    }
    
    print("")
    print("mix level between texels in same mip")
    for i in 0...numSteps {
        let tx = Float(i) / Float(numSteps)
        let offset = i * 4;
        print(String(format: "tx: %f   weight: %f", tx, result[offset + 1]))
    }
}
