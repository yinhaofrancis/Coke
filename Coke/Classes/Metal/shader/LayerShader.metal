//
//  LayerShader.metal
//  CokeVideo
//
//  Created by hao yin on 2021/3/22.
//

#include <metal_stdlib>
using namespace metal;


struct layerUniform{
    int blendMode;
};

half4 rgb_blend(half4 sc,half4 dc,half fs,half fd){
    return half4(sc.rgb * fs + dc.rgb * fd,sc.a * fs + dc.a * fd);
}
half4 clear(half4 sc,half4 dc){
    return half4(0,0,0,0);
}
half4 src(half4 sc,half4 dc){
    return sc;
}
half4 dst(half4 sc,half4 dc){
    return dc;
}
half4 src_over(half4 sc,half4 dc){
    return rgb_blend(sc, dc, 1, 1 - sc.a);
}
half4 dst_over(half4 sc,half4 dc){
    return rgb_blend(sc, dc, 1 - dc.a, 1);
}
half4 src_in(half4 sc,half4 dc){
    return rgb_blend(sc, dc, dc.a, 0);
}
half4 dst_in(half4 sc,half4 dc){
    return rgb_blend(sc, dc, 0, sc.a);
}

half4 src_out(half4 sc,half4 dc){
    return rgb_blend(sc, dc, 1 - dc.a, 0);
}
half4 dst_out(half4 sc,half4 dc){
    
    return rgb_blend(sc, dc, 0, 1 - sc.a);
}
half4 src_atop(half4 sc,half4 dc){
    return rgb_blend(sc, dc, dc.a, 1 - sc.a);
}
half4 dst_atop(half4 sc,half4 dc){
    return rgb_blend(sc, dc, 1 - dc.a, sc.a);
}
half4 blend_xor(half4 sc,half4 dc){
    return rgb_blend(sc, dc, 1 - dc.a, 1 - sc.a);
}

enum blendMode{
    blendClear,
    blendSrc,
    blendDst,
    blendSrcOver,
    blendDstOver,
    blendSrcIn,
    blendDstIn,
    blendSrcOut,
    blendDstOut,
    blendSrcAtop,
    blendDstAtop,
    blendXor
};

kernel void blend(const texture2d<half, access::sample> topTexture [[ texture(0) ]],
                       const texture2d<half, access::sample> bottomTexture [[ texture(1) ]],
                       texture2d<half, access::write> outTexture [[ texture(2) ]],
                       const device layerUniform* uniform [[ buffer(0) ]],
                       uint2 gid [[thread_position_in_grid]]){
    if(uniform->blendMode == blendClear){
        half4 color = clear(bottomTexture.read(gid), topTexture.read(gid));
        outTexture.write(color, gid);
    }
    if(uniform->blendMode == blendSrc){
        half4 color = src(bottomTexture.read(gid), topTexture.read(gid));
        outTexture.write(color, gid);
    }
    if(uniform->blendMode == blendDst){
        half4 color = dst(bottomTexture.read(gid), topTexture.read(gid));
        outTexture.write(color, gid);
    }
    if(uniform->blendMode == blendSrcOver){
        half4 color = src_over(bottomTexture.read(gid), topTexture.read(gid));
        outTexture.write(color, gid);
    }
    if(uniform->blendMode == blendDstOver){
        half4 color = dst_over(bottomTexture.read(gid), topTexture.read(gid));
        outTexture.write(color, gid);
    }
    if(uniform->blendMode == blendSrcIn){
        half4 color = src_in(bottomTexture.read(gid), topTexture.read(gid));
        outTexture.write(color, gid);
    }
    if(uniform->blendMode == blendDstIn){
        half4 color = dst_in(bottomTexture.read(gid), topTexture.read(gid));
        outTexture.write(color, gid);
    }
    if(uniform->blendMode == blendSrcOut){
        half4 color = src_out(bottomTexture.read(gid), topTexture.read(gid));
        outTexture.write(color, gid);
    }
    if(uniform->blendMode == blendDstOut){
        half4 color = dst_out(bottomTexture.read(gid), topTexture.read(gid));
        outTexture.write(color, gid);
    }
    if(uniform->blendMode == blendSrcAtop){
        half4 color = src_atop(bottomTexture.read(gid), topTexture.read(gid));
        outTexture.write(color, gid);
    }
    if(uniform->blendMode == blendDstAtop){
        half4 color = dst_atop(bottomTexture.read(gid), topTexture.read(gid));
        outTexture.write(color, gid);
    }
    if(uniform->blendMode == blendXor){
        half4 color = blend_xor(bottomTexture.read(gid), topTexture.read(gid));
        outTexture.write(color, gid);
    }
}


