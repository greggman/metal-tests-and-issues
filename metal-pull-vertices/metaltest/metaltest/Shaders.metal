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
    float2 uv;
    float4 pos [[position]];
};

vertex VertexOut vertexShader(const device Vertex *vertexArray [[buffer(0)]], unsigned int vid [[vertex_id]])
{
    Vertex in = vertexArray[vid];
 
    VertexOut out;

    out.uv = in.uv;
    out.pos = float4(in.pos.xy, 0, 1);

    return out;
    
}

fragment float4 fragmentShader(VertexOut interpolated [[stage_in]],
                               metal::texture2d<float> texture [[texture(0)]],
                               metal::sampler sampler [[sampler(0)]])
{
    return texture.sample(sampler, interpolated.uv);
}
