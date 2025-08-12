
import Metal
import Foundation

func main() {
    guard let device = MTLCreateSystemDefaultDevice() else {
        fatalError("Metal is not supported on this device")
    }

    guard let commandQueue = device.makeCommandQueue() else {
        fatalError("Could not create command queue")
    }

    let shaderSource = """
    using namespace metal;

    struct VertexOut {
        float4 position [[position]];
    };

    vertex VertexOut vertex_main(uint vid [[vertex_id]]) {
        VertexOut out;
        // A single large triangle that covers the entire viewport
        float2 pos[3] = {
            float2(-1.0, -1.0),
            float2( 3.0, -1.0),
            float2(-1.0,  3.0)
        };
        out.position = float4(pos[vid], 0.0, 1.0);
        return out;
    }

    fragment uint4 fragment_main(VertexOut in [[stage_in]],
                                   texture2d<uint> texture [[texture(0)]],
                                   sampler smp [[sampler(0)]]) {
        uint4 result = texture.gather(smp, float2(0.5), 0);
        return result;
    }
    """

    let library: MTLLibrary
    do {
        library = try device.makeLibrary(source: shaderSource, options: nil)
    } catch {
        fatalError("Could not compile shader library: \(error)")
    }

    guard let vertexFunction = library.makeFunction(name: "vertex_main"),
          let fragmentFunction = library.makeFunction(name: "fragment_main") else {
        fatalError("Could not find shader functions")
    }

    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = .rgba8Uint

    let pipelineState: MTLRenderPipelineState
    do {
        pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    } catch {
        fatalError("Could not create render pipeline state: \(error)")
    }

    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Uint, width: 2, height: 2, mipmapped: false)
    textureDescriptor.usage = [.shaderRead]
    guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
        fatalError("Could not create texture")
    }

    // Initialize texture data directly
    let textureData: [UInt8] = [
        10, 20, 30, 40,
        50, 60, 70, 80,
        90, 100, 110, 120,
        130, 140, 150, 160
    ]
    let region = MTLRegionMake2D(0, 0, 2, 2)
    texture.replace(region: region, mipmapLevel: 0, withBytes: textureData, bytesPerRow: 2 * 4)

    let outputTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Uint, width: 1, height: 1, mipmapped: false)
    outputTextureDescriptor.usage = [.renderTarget, .shaderRead]
    guard let outputTexture = device.makeTexture(descriptor: outputTextureDescriptor) else {
        fatalError("Could not create output texture")
    }

    let swizzles: [MTLTextureSwizzleChannels] = [
        MTLTextureSwizzleChannels(red: .red, green: .green, blue: .blue, alpha: .alpha),
        MTLTextureSwizzleChannels(red: .one, green: .one, blue: .one, alpha: .one),
        MTLTextureSwizzleChannels(red: .zero, green: .zero, blue: .zero, alpha: .zero),
        MTLTextureSwizzleChannels(red: .red, green: .red, blue: .red, alpha: .red),
        MTLTextureSwizzleChannels(red: .green, green: .green, blue: .green, alpha: .green),
        MTLTextureSwizzleChannels(red: .blue, green: .blue, blue: .blue, alpha: .blue),
        MTLTextureSwizzleChannels(red: .alpha, green: .alpha, blue: .alpha, alpha: .alpha),
        MTLTextureSwizzleChannels(red: .alpha, green: .blue, blue: .green, alpha: .red),
    ]
    
    func swizzleToString(_ sw: MTLTextureSwizzle) -> String {
        switch sw {
        case .red: return "r"
        case .green: return "g"
        case .blue: return "b"
        case .alpha: return "a"
        case .one: return "1"
        case .zero: return "0"
        default: return "?"
        }
    }

    let samplerDescriptor = MTLSamplerDescriptor()
    guard let sampler = device.makeSamplerState(descriptor: samplerDescriptor) else {
        fatalError("Could not create sampler state")
    }

    for swizzle in swizzles {
        let swizzleChannels = MTLTextureSwizzleChannels(red: swizzle.red, green: swizzle.green, blue: swizzle.blue, alpha: swizzle.alpha)
        guard let textureView = texture.makeTextureView(pixelFormat: texture.pixelFormat, textureType: .type2D, levels: 0..<1, slices: 0..<1, swizzle: swizzleChannels) else {
             fatalError("Could not create texture view")
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            fatalError("Could not create command buffer")
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            fatalError("Could not create render command encoder")
        }

        renderCommandEncoder.setRenderPipelineState(pipelineState)
        renderCommandEncoder.setFragmentTexture(textureView, index: 0)
        renderCommandEncoder.setFragmentSamplerState(sampler, index: 0)
        renderCommandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        renderCommandEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        var pixel = [UInt8](repeating: 0, count: 4)
        let region = MTLRegionMake2D(0, 0, 1, 1)
        outputTexture.getBytes(&pixel, bytesPerRow: 4, from: region, mipmapLevel: 0)

        print("\(pixel[0]) \(pixel[1]) \(pixel[2]) \(pixel[3]) : swizzle: \(swizzleToString(swizzle.red)) \(swizzleToString(swizzle.green)) \(swizzleToString(swizzle.blue)) \(swizzleToString(swizzle.alpha))")
    }
    exit(0)
}

main()
