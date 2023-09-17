//
//  CokeModel.metal
//  Coke
//
//  Created by wenyang on 2023/9/16.
//

#include "CokeShaderDefine.h"


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
    float3 lightDir = normalize(lu->lightPos - in.fragLocation); // 光源方向
    float diff = max(dot(norm, lightDir), 0.0); //光强
    half3 diffOrigin = texture.sample(textureSampler, in.textureVX).xyz;
    half3 diffColor =  half3(lu->diffuse) * diff * diffOrigin;
    
    half3 ambientColor = diffOrigin * half3(lu->ambient);
    
    float3 viewDir = normalize(lu->viewPos - in.fragLocation); //相机到顶点的距离
    float3 reflectDir = reflect(-lightDir, norm);  //反射方向
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), lu->shininess) * lu->specularStrength; //反射
    half3 specularColor = half3(lu->specular) * spec * half3(specular.sample(textureSampler, in.textureVX).x);
    
    return half4(diffColor + ambientColor + specularColor,1) * 1.2;
}
