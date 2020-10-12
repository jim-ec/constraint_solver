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
    
    out.position = uniforms.projection * float4(uniforms.transform * in.position, 1.0);
    out.color = in.color;
    
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    return float4(in.color, 1.0);
}
