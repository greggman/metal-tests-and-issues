//
//  ShaderDefinitions.h
//  metaltest
//
//  Created by Gregg Tavares on 9/27/21.
//

#ifndef ShaderDefinitions_h
#define ShaderDefinitions_h

#include <simd/simd.h>

struct Vertex {
    vector_float4 color;
    vector_float4 pos;
};

struct CombineVisibilityResultOptions
{
    uint startOffset;
    uint numOffsets;
};

#endif /* ShaderDefinitions_h */
