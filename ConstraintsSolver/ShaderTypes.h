#pragma once

#include <simd/simd.h>

#define BufferIndexVertices 0
#define BufferIndexUniforms 1

struct Uniforms {
    matrix_float3x3 transform;
};

struct Vertex {
    simd_float3 position;
    simd_float3 color;
};
