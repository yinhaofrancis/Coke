//
//  CokeRender.metal
//  CokeVideo
//
//  Created by hao yin on 2021/3/25.
//

#include <metal_stdlib>
using namespace metal;


struct renderUniform{
    float4x4 camera;
    float4x4 world;
};

struct ObjectVertexResult{
    float4 location [[position]];
    float2 textureVX;
};

struct ObjectVertex{
    float4 location [[attribute(0)]];
    float2 textureVX [[attribute(1)]];
};

vertex ObjectVertexResult renderVertex(
                                       ObjectVertex vector [[stage_in]],
                                       const device  renderUniform * uniform [[buffer(0)]]){
    float4 location = uniform->camera * uniform->world * vector.location;
    struct ObjectVertexResult result;
    result.location = location;
    result.textureVX = vector.textureVX;
    return  result;
}
fragment half4 renderFragment(ObjectVertex in [[stage_in]],
                              const texture2d<half> texture [[texture(0)]],
                              const sampler textureSampler [[sampler(0)]]){
    half4 color = texture.sample(textureSampler, in.textureVX);
    return half4(color.xyz,1);
}
