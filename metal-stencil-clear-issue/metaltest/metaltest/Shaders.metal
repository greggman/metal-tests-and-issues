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
    float4 pos [[position]];
};

// ----

vertex VertexOut vertexShader(const device Vertex *vertexArray [[buffer(0)]], unsigned int vid [[vertex_id]])
{
    Vertex in = vertexArray[vid];
    VertexOut out;
    out.pos = float4(in.pos.x, in.pos.y, 0, 1);
    return out;
}

fragment float4 fragmentShader()
{
    return float4(0, 1, 0, 1);
}


