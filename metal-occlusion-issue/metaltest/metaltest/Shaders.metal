//
//  Shaders.metal
//  metaltest
//
//  Created by Gregg Tavares on 9/27/21.
//

#include <metal_stdlib>
#include "ShaderDefinitions.h"
using namespace metal;

struct VertexOut {
    float4 color;
    float4 pos [[position]];
};

// ----

vertex VertexOut vertexShader(const device Vertex *vertexArray [[buffer(0)]], unsigned int vid [[vertex_id]])
{
    Vertex in = vertexArray[vid];
    VertexOut out;
    out.pos = in.pos;
    out.color = in.color;
    return out;
}

fragment float4 fragmentShader(VertexOut interpolated [[stage_in]])
{
    return interpolated.color;
}

// ---------------------------------------------------------------------------------------------

constant bool kCombineWithExistingResult [[function_constant(1000)]];

kernel void computeShader(uint idx [[thread_position_in_grid]],
                          constant CombineVisibilityResultOptions &options [[buffer(0)]],
                          constant ushort4 *renderpassVisibilityResult [[buffer(1)]],
                          device ushort4 *finalResults [[buffer(2)]])
{
    if (idx > 0)
    {
        return;
    }

    ushort4 finalResult16x4;
    if (kCombineWithExistingResult)
    {
        finalResult16x4 = finalResults[0];
    }
    else
    {
        finalResult16x4 = ushort4(0, 0, 0, 0);
    }

    for (uint i = 0; i < options.numOffsets; ++i)
    {
        uint offset = options.startOffset + i;
        ushort4 renderpassResult = renderpassVisibilityResult[offset];

        finalResult16x4 = finalResult16x4 | renderpassResult;
    }
    finalResults[0] = finalResult16x4;
}


