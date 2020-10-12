#pragma once

#include <simd/simd.h>

#define BufferIndexVertices 0
#define BufferIndexUniforms 1

struct Uniforms {
    simd_float3 translation;
    simd_float3x3 transform;
    
    /// Diagonalized view transform matrix.
    simd_float2 viewTransform;
};

struct Vertex {
    simd_float3 position;
    simd_float3 normal;
    simd_float3 color;
};
