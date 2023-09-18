//
//  CokeLighting.metal
//  Coke
//
//  Created by wenyang on 2023/9/17.
//

#include <metal_stdlib>
#include "CokeLighting.h"
using namespace metal;

half3 CokeLighting::ambient(float2 texturevx,float3 ambient) {
    half4 color = this->ambientTexture.sample(this->textureSampler, texturevx);
    float3 calc = float3(color.xyz) * ambient;
    return half3(calc);
}

half3 CokeLighting::specular(const float2 texturevc,
                             const float3 specular,
                             const float3 normal,
                             const float3 lightDir,
                             const float3 viewPos,
                             const float3 vertexLocation,
                             const float specularStrength,
                             const float shininess,
                             const float attenuation){
    auto norm = normalize(normal);
    float3 viewDir = normalize(viewPos - vertexLocation); //相机到顶点的距离
    float3 reflectDir = reflect(-lightDir, norm);  //反射方向
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), shininess) * specularStrength * attenuation; //反射
    half3 specularColor = half3(specular) * spec * specularTexture.sample(textureSampler, texturevc).xyz;
    return specularColor;
}
float CokeLighting::attenuation(float constantValue, float linear, float distance, float quadratic){
    return 1.0 / (constantValue + linear * distance + quadratic * (distance * distance));
}

half3 CokeLighting::diffuse(const float2 texturevc, const float3 diffuse, const float3 normal, const float3 lightDir,const float attenuation) {
    auto norm = normalize(normal);
    float diff = max(dot(norm, lightDir), 0.0) * attenuation; //光强
    half3 diffOrigin = diffuseTexture.sample(textureSampler, texturevc).xyz;
    half3 diffColor =  half3(diffuse) * diff * diffOrigin;
    return diffColor;
}

//{
//    return ambientTexture.sample(textureSampler,texturevx) * half3(lu->ambient);
//}
