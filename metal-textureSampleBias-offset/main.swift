// main.swift
//
// compile with:
//   xcrun swiftc -o main main.swift -framework Metal -framework MetalKit -framework Foundation -framework CoreGraphics -framework UniformTypeIdentifiers
//
// run with:
//    ./main
//
import Metal
import Foundation

func main() {
    guard let device = MTLCreateSystemDefaultDevice() else {
        fatalError("Metal is not supported on this device.")
    }

    guard let commandQueue = device.makeCommandQueue() else {
        fatalError("Failed to create command queue.")
    }

    let width = 12
    let height = 12
    let layers = 4
    let mipCount = 3

    let textureDescriptor = MTLTextureDescriptor()
    textureDescriptor.pixelFormat = .rgba8Unorm
    textureDescriptor.width = width
    textureDescriptor.height = height
    textureDescriptor.depth = 1
    textureDescriptor.arrayLength = layers
    textureDescriptor.mipmapLevelCount = mipCount
    textureDescriptor.textureType = .type2DArray
    textureDescriptor.usage = [.shaderRead]
    
    guard let srcTexture = device.makeTexture(descriptor: textureDescriptor) else {
        fatalError("Failed to create source texture.")
    }

    let outTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba8Unorm,
        width: 2,
        height: 2,
        mipmapped: false
    )
    outTextureDescriptor.usage = [.renderTarget, .shaderRead]
    guard let outTexture = device.makeTexture(descriptor: outTextureDescriptor) else {
        fatalError("Failed to create output texture.")
    }

    let metalSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexOut {
        float4 position [[position]];
    };

    vertex VertexOut vertexShader(uint vid [[vertex_id]]) {
        float2 pos[3] = {
            float2(-1, -1),
            float2( 3, -1),
            float2(-1,  3)
        };
        VertexOut out;
        out.position = float4(pos[vid], 0, 1);
        return out;
    }

    fragment float4 fragmentShader(
        float4 fragCoord [[position]],
        texture2d_array<float> T [[texture(0)]],
        sampler S [[sampler(0)]]
    ) {
        float2 dims = float2(T.get_width(), T.get_height());
        float2 derivativeBase = (fragCoord.xy - 0.5) / dims;
        float2 derivativeMult = float2(0, 2445.079343096111);
        float2 baseCoords = float2(0.20833333333333334, 0.5416666666666666);
        float2 coords = baseCoords + derivativeBase * derivativeMult;
        
        return T.sample(S, coords, 0, bias(-9.655665566213429), int2(-2, -3));
    }
    """

    let library: MTLLibrary
    do {
        library = try device.makeLibrary(source: metalSource, options: nil)
    } catch {
        fatalError("Failed to create Metal library: \(error)")
    }

    let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
    renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexShader")
    renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
    renderPipelineDescriptor.colorAttachments[0].pixelFormat = outTexture.pixelFormat

    let renderPipelineState = try! device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)

    let samplerDescriptor = MTLSamplerDescriptor()
    samplerDescriptor.minFilter = .linear
    samplerDescriptor.magFilter = .linear
    samplerDescriptor.mipFilter = .linear
    samplerDescriptor.sAddressMode = .clampToEdge
    samplerDescriptor.tAddressMode = .repeat
    let samplerState = device.makeSamplerState(descriptor: samplerDescriptor)!

    func clearTexture() {
        let max_size = width * height * 4
        let black = [UInt8](repeating: 0, count: max_size)
        for m in 0..<mipCount {
            let mw = max(1, width >> m)
            let mh = max(1, height >> m)
            for s in 0..<layers {
                 black.withUnsafeBytes { ptr in
                     srcTexture.replace(region: MTLRegionMake2D(0, 0, mw, mh), mipmapLevel: m, slice: s, withBytes: ptr.baseAddress!, bytesPerRow: mw * 4, bytesPerImage: mw * mh * 4)
                 }
            }
        }
    }

    struct Texel: Hashable {
        var m: Int
        var s: Int
        var x: Int
        var y: Int
    }

    func render(withWhiteTexels texels: [Texel]) -> [Float] {
        clearTexture()
        let white = [UInt8](repeating: 255, count: 4)
        for t in texels {
            white.withUnsafeBytes { ptr in
                srcTexture.replace(region: MTLRegionMake2D(t.x, t.y, 1, 1), mipmapLevel: t.m, slice: t.s, withBytes: ptr.baseAddress!, bytesPerRow: 4, bytesPerImage: 4)
            }
        }

        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setFragmentTexture(srcTexture, index: 0)
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        renderEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        var result = [UInt8](repeating: 0, count: 4)
        outTexture.getBytes(&result, bytesPerRow: 8, from: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0)
        return result.map { Float($0) / 255.0 }
    }

    var allTexels: [Texel] = []
    for m in 0..<mipCount {
        let mw = max(1, width >> m)
        let mh = max(1, height >> m)
        for s in 0..<layers {
            for y in 0..<mh {
                for x in 0..<mw {
                    allTexels.append(Texel(m: m, s: s, x: x, y: y))
                }
            }
        }
    }

    func findSampled(in texels: [Texel]) -> [Texel: [Float]] {
        if texels.isEmpty { return [:] }
        let res = render(withWhiteTexels: texels)
        if res.reduce(0, +) < (0.5 / 255.0) { return [:] }
        
        if texels.count == 1 {
            return [texels[0]: res]
        }
        
        let mid = texels.count / 2
        let left = Array(texels[0..<mid])
        let right = Array(texels[mid..<texels.count])
        
        var found = findSampled(in: left)
        let rightFound = findSampled(in: right)
        found.merge(rightFound) { (current, _) in current }
        return found
    }

    print("Searching for sampled texels...")
    let sampled = findSampled(in: allTexels)

    print("\n  sample points:")
    print("got:")
    
    let sortedSampled = sampled.keys.sorted {
        if $0.m != $1.m { return $0.m < $1.m }
        if $0.s != $1.s { return $0.s < $1.s }
        if $0.y != $1.y { return $0.y < $1.y }
        return $0.x < $1.x
    }

    var currentMip = -1
    var currentSlice = -1
    var mipWeight: Float = 0
    for (i, t) in sortedSampled.enumerated() {
        if t.m != currentMip || t.s != currentSlice {
            if currentMip != -1 {
                print("mip level (\(currentMip)) weight: \(String(format: "%.5f", mipWeight))")
                print("")
            }
            print("layer: \(t.s) mip(\(t.m))")
            currentMip = t.m
            currentSlice = t.s
            mipWeight = 0
        }
        let weights = sampled[t]!
        let w = weights[0]
        mipWeight += w
        print("at: [\(t.x), \(t.y), \(t.s)], weight: \(String(format: "%.5f", w))")
        
        if i == sortedSampled.count - 1 {
            print("mip level (\(currentMip)) weight: \(String(format: "%.5f", mipWeight))")
        }
    }
}

main()
