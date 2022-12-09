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

struct PaddedVec2 {
    PaddedVec2(float2 f) : v(f) {};
    PaddedVec2() {};
private:
    float2 v;
    float2 unused;
};

/*
struct Float {
  Float
  private:
    float v;
};
 */

struct UBufTest {
public:
    PaddedVec2 foo[3];
};

// ----

vertex VertexOut vertexShader(const device Vertex *vertexArray [[buffer(0)]], unsigned int vid [[vertex_id]])
{
    
    UBufTest ubt;
    
    ubt.foo[1] = float2(1,2);
    //float tst = ubt.foo[1].x;
    
    Vertex in = vertexArray[vid];
    VertexOut out;
    out.pos.zxy = in.pos.xyz;
    out.pos = in.pos;
    out.color = in.color;
    return out;
}

fragment float4 fragmentShader(VertexOut interpolated [[stage_in]])
{
    return interpolated.color;
}


