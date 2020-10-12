#pragma once

#include <simd/simd.h>

#define BufferIndexVertices 0
#define BufferIndexUniforms 1

struct Uniforms {
    simd_float3 translation;
    simd_float3x3 transform;
    simd_float4x4 projection;
};

struct Vertex {
    simd_float3 position;
    simd_float3 normal;
    simd_float3 color;
};
