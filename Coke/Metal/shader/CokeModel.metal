//
//  CokeModel.metal
//  Coke
//
//  Created by wenyang on 2023/9/16.
//

#include "CokeShaderDefine.h"


vertex CokeModel cokeTriagle(CokeModelIn vertices [[stage_in]],
                              const device TransformUniform * um [[buffer(1)]], // world matrix
                              const device TransformUniform * cu [[buffer(2)]]  // camera matrix
                              ){
    CokeModel r;
    r.location = cu->mat * um->mat * float4(vertices.location,1);
    r.normal = vertices.normal;
    r.textureVX = vertices.textureVX;
    return r;
}
fragment half4 cokeTriagleFragment(CokeModel in [[stage_in]],
                                   const texture2d<half> texture [[texture(0)]],
                                   const sampler textureSampler [[sampler(0)]]){

    return texture.sample(textureSampler, in.textureVX);
}
