// main.swift
//
// compile with:
//    xcrun swiftc -o main main.swift -framework Metal -framework MetalKit -framework Foundation
//
// run with:
//    ./main
//
import Metal
import Foundation

func main() {
    let devices = MTLCopyAllDevices()
    guard !devices.isEmpty else {
        fatalError("No Metal devices found.")
    }

    for device in devices {
        print("Testing device: \(device.name)")
        runOnDevice(on: device)
    }
}

func runOnDevice(on device: MTLDevice) {
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

    fragment float4 fragment_main(VertexOut in [[stage_in]],
                                   depth2d<float> texture [[texture(0)]],
                                   sampler smp [[sampler(0)]]) {
        constexpr float ref = 0.5;
        float4 result = texture.gather_compare(smp, float2(0.5), ref);
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
    pipelineDescriptor.colorAttachments[0].pixelFormat = .rgba8Unorm

    let pipelineState: MTLRenderPipelineState
    do {
        pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    } catch {
        fatalError("Could not create render pipeline state: \(error)")
    }

    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: 2, height: 2, mipmapped: false)
    textureDescriptor.usage = [.shaderRead]
    guard let depthTexture = device.makeTexture(descriptor: textureDescriptor) else {
        fatalError("Could not create depth texture")
    }

    // Initialize texture data directly
    let textureData: [Float32] = [0.2, 0.4, 0.6, 0.8]
    let region = MTLRegionMake2D(0, 0, 2, 2)
    depthTexture.replace(region: region, mipmapLevel: 0, withBytes: textureData, bytesPerRow: 2 * MemoryLayout<Float32>.size)

    let outputTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
    outputTextureDescriptor.usage = [.renderTarget, .shaderRead]
    guard let outputTexture = device.makeTexture(descriptor: outputTextureDescriptor) else {
        fatalError("Could not create output texture")
    }

    let compareFunctions: [MTLCompareFunction] = [.less, .greater]
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

    for compareFunction in compareFunctions {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.compareFunction = compareFunction
        guard let sampler = device.makeSamplerState(descriptor: samplerDescriptor) else {
            fatalError("Could not create sampler state")
        }

        print("compare: \(compareFunction == .less ? "less" : "greater")")

        for swizzle in swizzles {
            let swizzleChannels = MTLTextureSwizzleChannels(red: swizzle.red, green: swizzle.green, blue: swizzle.blue, alpha: swizzle.alpha)
            guard let textureView = depthTexture.makeTextureView(pixelFormat: depthTexture.pixelFormat, textureType: .type2D, levels: 0..<1, slices: 0..<1, swizzle: swizzleChannels) else {
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

            print("\(Float(pixel[0]) / 255.0) \(Float(pixel[1]) / 255.0) \(Float(pixel[2]) / 255.0) \(Float(pixel[3]) / 255.0) : swizzle: \(swizzleToString(swizzle.red)) \(swizzleToString(swizzle.green)) \(swizzleToString(swizzle.blue)) \(swizzleToString(swizzle.alpha))")
        }
    }
    exit(0)
}

main()
