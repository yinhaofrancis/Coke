//
//  CokeModel.metal
//  Coke
//
//  Created by wenyang on 2023/9/16.
//

#include "CokeShaderDefine.h"
#include <metal_stdlib>
using namespace metal;

vertex CokeModel cokeTriagle(CokeModelIn vertices [[stage_in]],
                              const device TransformUniform * um [[buffer(ShaderVertexWorldMatrixIndex)]], // world matrix
                              const device TransformUniform * cu [[buffer(ShaderVertexCameraMatrixIndex)]]  // camera matrix
                              ){
    CokeModel r;
    r.location = cu->mat * um->mat * float4(vertices.location,1);
    r.normal = (transpose(um->invert) * float4(vertices.normal , 1)).xyz;
    r.fragLocation = float3(um->mat * float4(vertices.location,1));
    r.textureVX = vertices.textureVX;
    return r;
}
fragment half4 cokeTriagleFragment(CokeModel in [[stage_in]],
                                   const device LightingUniform * lu [[buffer(ShaderFragmentLightingIndex)]],
                                   const texture2d<half> texture [[texture(ShaderFragmentDiffuseTextureIndex)]],
                                   const texture2d<half> specular [[texture(ShaderFragmentSpecularTextureIndex)]],
                                   const sampler textureSampler [[sampler(ShaderFragmentSamplerIndex)]]){

    float3 norm = normalize(in.normal); //单位法线线向量
    float3 lightDir = float3(0,0,0); //默认光线方向
    float attenuation = 1;
    if (lu->lightType == directlight){
        lightDir = normalize(-lu->lightDir); //平行光
    }else if (lu->lightType == spotlight){
        lightDir = normalize(lu->lightPos - in.fragLocation); // 光源方向
        float distance = length(lu->lightPos - in.fragLocation);
        attenuation = 1.0 / (lu->constantValue + lu->linear * distance +
                             lu->quadratic * (distance * distance));
    }
     
    float diff = max(dot(norm, lightDir), 0.0) * attenuation; //光强
    half3 diffOrigin = texture.sample(textureSampler, in.textureVX).xyz;
    half3 diffColor =  half3(lu->diffuse) * diff * diffOrigin;
    
    half3 ambientColor = diffOrigin * half3(lu->ambient);
    
    float3 viewDir = normalize(lu->viewPos - in.fragLocation); //相机到顶点的距离
    float3 reflectDir = reflect(-lightDir, norm);  //反射方向
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), lu->shininess) * lu->specularStrength * attenuation; //反射
    half3 specularColor = half3(lu->specular) * spec * half3(specular.sample(textureSampler, in.textureVX).x);
    
    return half4(diffColor + ambientColor + specularColor,0.9);
}



vertex CokeModel2D coke2dvertex(CokeModel2DIn vertices [[stage_in]],
                                const device float4x4 * cu [[buffer(1)]]){
    CokeModel2D r;
    r.location = *cu * float4(vertices.location.x,vertices.location.y,0,1);
    r.color = vertices.color;
    return r;
}
fragment half4 coke2dfragment(CokeModel2D vertices [[stage_in]]){
    
    return half4(vertices.color);
}
kernel void coke_image_diff(const texture2d<half, access::read> origin [[ texture(0) ]],
                            texture2d<half, access::read> diff [[texture(1)]],
                            texture2d<half, access::write> out [[texture(2)]],
                            uint2 gid [[thread_position_in_grid]]){
    half4 h = fabs(diff.read(gid) - origin.read(gid));
    out.write(h, gid);
}
kernel void coke_image_hamming(const texture2d<float, access::read> origin [[ texture(0) ]],
                               texture2d<float, access::read> diff [[texture(1)]],
                               texture2d<float, access::write> out [[texture(2)]],
                               uint2 gid [[thread_position_in_grid]]){
    
}

kernel void coke_sum(const texture2d<half, access::read> origin [[ texture(0) ]],
                         uint2 gid [[thread_position_in_grid]],
                         device atomic_uint * average  [[buffer(0)]]){
    half4 f = origin.read(gid);
    float sum = (f.x + f.y + f.z + f.w);
    uint r = uint(clamp(sum, 0.0, 4.0) * 1024);
    atomic_fetch_add_explicit(average, r, memory_order_relaxed);
}


kernel void coke_image_hamming_diff(const texture2d<half, access::read> origin [[ texture(0) ]],
                            texture2d<half, access::read> diff [[texture(1)]],
                            texture2d<half, access::write> out [[texture(2)]],
                            uint2 gid [[thread_position_in_grid]]){

    half4 diffColor = diff.read(gid);
    half4 originColor = origin.read(gid);
    float x = hammingDistanceFloat(diffColor.x, originColor.x);
    float y = hammingDistanceFloat(diffColor.y, originColor.y);
    float z = hammingDistanceFloat(diffColor.z, originColor.z);
    float w = hammingDistanceFloat(diffColor.w, originColor.w);
    out.write(half4(x,y,z,w), gid);
}
uint32_t colorHalfBitInt(half f)
{
    return (int)(f * 1000);
}

int hammingDistance(uint32_t a){
    int c = 0;
    for (int i = 0; i < 32; i++){
        if (((a >> i) & 1) == 1){
            c++;
        }
    }
    return c;
}
half hammingDistanceFloat(half t1,half t2) {
    uint32_t t3 = colorHalfBitInt(t1) ^ colorHalfBitInt(t2);

    return clamp(half(hammingDistance(t3)), half(0.0), half(16.0)) / 16.0;
}
