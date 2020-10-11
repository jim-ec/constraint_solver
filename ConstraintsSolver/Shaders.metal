#include <metal_stdlib>
#include <simd/simd.h>

#include "ShaderTypes.h"

using namespace metal;

struct Vertex {
    float3 position [[attribute(VertexAttributePosition)]];
    float3 color [[attribute(VertexAttributeColor)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 color;
};

vertex VertexOut vertexShader(Vertex in [[stage_in]], constant Uniforms& uniforms [[buffer(BufferIndexUniforms)]]) {
    VertexOut out;
    
    out.position = float4(uniforms.transform * in.position, 1.0);
    out.color = in.color;
    
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    return float4(in.color, 1.0);
}
