#include <metal_stdlib>
#include <simd/simd.h>

#include "ShaderTypes.h"

using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float3 color;
};

vertex VertexOut vertexShader(device Vertex const *vertices [[buffer(BufferIndexVertices)]],
                              constant Uniforms& uniforms [[buffer(BufferIndexUniforms)]],
                              uint vertexId [[vertex_id]])
{
    Vertex in = vertices[vertexId];
    VertexOut out;
    
    // Implicit axis re-order:
    // x <- x
    // y <- -z
    // z <- y
    // w <- w
    float4x4 projection = float4x4(uniforms.projection[0], -uniforms.projection[2], uniforms.projection[1], uniforms.projection[3]);
    
    out.position = projection * float4((uniforms.rotation * in.position + uniforms.translation), 1.0);
    
    out.color = in.color * dot(uniforms.rotation * in.normal, float3(0, -1, 0));
    
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    return float4(in.color, 1.0);
}
