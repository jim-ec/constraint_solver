#include <metal_stdlib>
#include <simd/simd.h>

#include "ShaderTypes.h"

using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float3 color;
};

// Implicit matrix multiplication:
// x <- x, y <- -z, z <- y, w <- w
float4x4 toClipSpace(float4x4 matrix) {
    return float4x4(matrix[0], -matrix[2], matrix[1], matrix[3]);
}

vertex VertexOut vertexShader(device Vertex const *vertices [[buffer(BufferIndexVertices)]],
                              constant Uniforms& uniforms [[buffer(BufferIndexUniforms)]],
                              uint vertexId [[vertex_id]])
{
    Vertex in = vertices[vertexId];
    VertexOut out;
    
    out.position = toClipSpace(uniforms.projection) * float4((uniforms.rotation * in.position + uniforms.translation), 1.0);
    
    out.color = in.color * dot(uniforms.rotation * in.normal, float3(0, -1, 0));
    
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               constant Uniforms& uniforms [[buffer(BufferIndexUniforms)]])
{
    return float4(in.color, 1.0);
}
