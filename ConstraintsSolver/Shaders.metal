#include <metal_stdlib>
#include <simd/simd.h>

#include "ShaderTypes.h"

using namespace metal;

struct VertexOut {
    float4 clipSpacePosition [[position]];
    float3 position;
    float3 normal;
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
    
    out.color = in.color;
    out.normal = (uniforms.view * uniforms.model * float4(in.normal, 0)).xyz;
    out.position = (uniforms.view * uniforms.model * float4(in.position, 1)).xyz;
    out.clipSpacePosition = toClipSpace(uniforms.projection) * float4(out.position, 1);
    
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               constant Uniforms& uniforms [[buffer(BufferIndexUniforms)]])
{
    float3 ambientLight = float3(0.01);

    float3 v = normalize(float3(0, 0, 1) - in.position);
    float NoV = dot(in.normal, v);

    float3 color = in.color * NoV + ambientLight;
    return float4(color, 1.0);
}
