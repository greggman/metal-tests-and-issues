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
    out.pos = in.pos * float4(0.00001) + float4(1000000);
    return out;
}

fragment float4 fragmentShader(VertexOut interpolated [[stage_in]])
{
    return float4(1,0,0,1);
}


