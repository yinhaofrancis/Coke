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


#define ShaderVertexBufferIndex 0

#define ShaderVertexWorldMatrixIndex 1

#define ShaderVertexCameraMatrixIndex 2

#define ShaderFragmentLightingIndex 3

#define ShaderFragmentDiffuseTextureIndex 0

#define ShaderFragmentSpecularTextureIndex 1

#define ShaderFragmentSamplerIndex 0


enum LightType:int {
    directlight = 0,
    spotlight = 1,
};


struct CokeModelIn{
    float3 location [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 textureVX [[attribute(2)]];
};
struct CokeModel{
    float4 location [[position]];
    float3 fragLocation;
    float3 normal;
    float2 textureVX;
};

struct TransformUniform{
    float4x4 mat;
    float4x4 invert;
};
struct LightingUniform{
    LightType lightType;
    float3 ambient;
    float3 diffuse;
    float3 specular;
    float3 lightPos;
    float3 lightDir;
    float specularStrength;
    float3 viewPos;
    float cutOff;
    float shininess;
    float constantValue;
    float linear;
    float quadratic;
    
};


struct CokeModel2DIn{
    float2 location [[attribute(0)]];
    float4 color [[attribute(1)]];
};

struct CokeModel2D{
    float4 location [[position]];
    float4 color;
    float2 textureVX;
};

uint32_t colorHalfBitInt(half f);
int hammingDistance(uint32_t a);
half hammingDistanceFloat(half t1,half t2);

#endif /* CokeShaderDefine_h */
