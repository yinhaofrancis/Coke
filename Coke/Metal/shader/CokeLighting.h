//
//  CokeLight.h
//  CokeVideo
//
//  Created by wenyang on 2023/9/17.
//

#ifndef CokeLight_h
#define CokeLight_h
#include <metal_stdlib>

using namespace metal;

class CokeLighting {
public:
    CokeLighting();
    ~CokeLighting();
    
    /// 环境光
    /// - Parameters:
    ///   - texturevx: 采样点
    ///   - ambient: 环境光
    half3 ambient(float2 texturevx,float3 ambient);
    ///  镜面反射
    /// - Parameters:
    ///   - texturevc: texture 采样点
    ///   - normal: 法线向量
    ///   - lightDir: 光线方向
    ///   - viewPos: 视角方向
    ///   - vertexLocation: 顶点位置
    ///   - specularStrength: 反射强度
    ///   - shininess: 光泽度
    ///   - attenuation: 衰减程度
    half3 specular(const float2 texturevc,
                   const float3 specular,
                   const float3 normal,
                   const float3 lightDir,
                   const float3 viewPos,
                   const float3 vertexLocation,
                   const float specularStrength,
                   const float shininess,
                   const float attenuation);
    float attenuation(float constantValue,
                      float linear,
                      float distance,
                      float quadratic);
    
    /// 散射光
    /// - Parameters:
    ///   - texturevc: 采样点
    ///   - diffuse: 散射材质
    ///   - normal: 法线
    ///   - lightDir: 光线方向
    ///   - attenuation: 衰退值
    half3 diffuse(const float2 texturevc,
                  const float3 diffuse,
                  const float3 normal,
                  const float3 lightDir,
                  const float attenuation);
    
private:
    texture2d<half> ambientTexture;
    texture2d<half> diffuseTexture;
    texture2d<half> specularTexture;
    sampler textureSampler;
    
};

#endif /* CokeLight_h */
