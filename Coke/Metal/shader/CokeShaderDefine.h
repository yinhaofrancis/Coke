//
//  CokeShaderDefine.h
//  CokeVideo
//
//  Created by wenyang on 2023/9/16.
//
#include <metal_stdlib>
using namespace metal;

#ifndef CokeShaderDefine_h
#define CokeShaderDefine_h

struct CokeVertex{
    float4 location [[position]];
    float2 textureVX;
};
struct CokeVertexIn{
    float4 location [[attribute(0)]];
    float2 textureVX [[attribute(1)]];
};
struct renderUniform{
    float4x4 camera;
    float4x4 world;
};
struct RenderFragmentUniform{
    float bias;
};



struct CokeModelIn{
    float3 location [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 textureVX [[attribute(2)]];
};
struct CokeModel{
    float4 location [[position]];
    float3 normal;
    float2 textureVX;
};

struct TransformUniform{
    float4x4 mat;
};

#endif /* CokeShaderDefine_h */
