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
    float2 uv;
};

vertex VertexOut vertexShader(const device Vertex *vertexArray [[buffer(0)]], unsigned int vid [[vertex_id]])
{
    Vertex in = vertexArray[vid];
 
    VertexOut out;

    out.uv = in.pos.xy * 0.5 + 0.5;
    out.pos = float4(in.pos.xy, 0, 1);

    return out;
    
}

fragment float4 fragmentShader()
{
    return float4(0.5, 0.6, 0.7, 0.8);
}

fragment float4 textureFShader(VertexOut interpolated [[stage_in]],
                               metal::texture2d<float> texture [[texture(0)]],
                               metal::sampler sampler [[sampler(0)]])
{
    return texture.sample(sampler, interpolated.uv);
}
