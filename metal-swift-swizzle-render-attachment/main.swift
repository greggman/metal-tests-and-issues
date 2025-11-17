// main.swift
//
// compile with:
//    xcrun swiftc -o main main.swift -framework Metal -framework MetalKit -framework Foundation -framework CoreGraphics -framework UniformTypeIdentifiers
//
// run with:
//    ./main
//
import Metal
import MetalKit
import Foundation
import CoreGraphics // For CGImage
import UniformTypeIdentifiers // For UTType (modern replacement for kUTTypePNG)

// Extension to convert MTLPixelFormat to CGImageAlphaInfo
extension MTLPixelFormat {
    var cgImageAlphaInfo: CGImageAlphaInfo {
        switch self {
        case .rgba8Unorm, .rgba8Unorm_srgb:
            return .premultipliedLast // Or .noneSkipLast, depending on your needs
        case .bgra8Unorm, .bgra8Unorm_srgb:
            return .premultipliedFirst // Or .noneSkipFirst
        default:
            return .none
        }
    }
}

func main() {
    guard let device = MTLCreateSystemDefaultDevice() else {
        fatalError("Metal is not supported on this device.")
    }

    guard let commandQueue = device.makeCommandQueue() else {
        fatalError("Failed to create command queue.")
    }

    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba8Unorm,
        width: 256,
        height: 256,
        mipmapped: false
    )
    textureDescriptor.usage = [.renderTarget, .shaderRead] // Texture can be rendered to and read from

    textureDescriptor.swizzle = MTLTextureSwizzleChannels(
        red: .blue,
        green: .green,
        blue: .red,
        alpha: .alpha
    )

    print("makeTexture")
    guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
        fatalError("Failed to create texture.")
    }

    let metalSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float4 position [[attribute(0)]];
    };

    struct VertexOut {
        float4 position [[position]];
    };

    vertex VertexOut vertexShader(
        VertexIn in [[stage_in]]
    ) {
        VertexOut out;
        out.position = in.position;
        return out;
    }

    fragment float4 fragmentShader() {
        return float4(1.0, 0.0, 0.0, 1.0); // Red color (RGBA)
    }
    """

    let library: MTLLibrary
    do {
        library = try device.makeLibrary(source: metalSource, options: nil)
    } catch {
        fatalError("Failed to create Metal library from source: \(error)")
    }

    print("makeShaders")
    let vertexFunction = library.makeFunction(name: "vertexShader")
    let fragmentFunction = library.makeFunction(name: "fragmentShader")

    let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
    renderPipelineDescriptor.vertexFunction = vertexFunction
    renderPipelineDescriptor.fragmentFunction = fragmentFunction
    renderPipelineDescriptor.colorAttachments[0].pixelFormat = texture.pixelFormat

    let vertexDescriptor = MTLVertexDescriptor()
    vertexDescriptor.attributes[0].format = .float4
    vertexDescriptor.attributes[0].offset = 0
    vertexDescriptor.attributes[0].bufferIndex = 0

    vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 4
    vertexDescriptor.layouts[0].stepFunction = .perVertex

    renderPipelineDescriptor.vertexDescriptor = vertexDescriptor

    print("makePipeline")
    let renderPipelineState: MTLRenderPipelineState
    do {
        renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
    } catch {
        fatalError("Failed to create render pipeline state: \(error)")
    }

    guard let commandBuffer = commandQueue.makeCommandBuffer() else {
        fatalError("Failed to create command buffer.")
    }

    let renderPassDescriptor = MTLRenderPassDescriptor()
    renderPassDescriptor.colorAttachments[0].texture = texture
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0) // Black background
    renderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderPassDescriptor.colorAttachments[0].storeAction = .store

    print("makeRenderCommandEncoder")
    guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
        fatalError("Failed to create render command encoder.")
    }

    renderEncoder.setRenderPipelineState(renderPipelineState)

    let vertices: [Float] = [
        0.0,  0.7, 0.0, 1.0, // Top vertex
        -0.7, -0.7, 0.0, 1.0, // Bottom-left vertex
        0.7, -0.7, 0.0, 1.0  // Bottom-right vertex
    ]
    renderEncoder.setVertexBytes(vertices, length: MemoryLayout<Float>.stride * vertices.count, index: 0)
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    renderEncoder.endEncoding()

    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * texture.width
    var imageBytes = [UInt8](repeating: 0, count: bytesPerRow * texture.height)

    texture.getBytes(&imageBytes, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: texture.pixelFormat.cgImageAlphaInfo.rawValue | CGImageByteOrderInfo.order32Little.rawValue)

    guard let dataProvider = CGDataProvider(data: Data(bytes: imageBytes, count: imageBytes.count) as CFData) else {
        fatalError("Failed to create CGDataProvider.")
    }

    guard let cgImage = CGImage(
        width: texture.width,
        height: texture.height,
        bitsPerComponent: 8,
        bitsPerPixel: bytesPerPixel * 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo,
        provider: dataProvider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    ) else {
        fatalError("Failed to create CGImage.")
    }

    let fileURL = URL(fileURLWithPath: "result.png")
    guard let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Failed to create CGImageDestination for \(fileURL.lastPathComponent).")
    }

    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Failed to write image to \(fileURL.lastPathComponent).")
    }

    print("saved it to \(fileURL.path)")
}

main()