#pragma once

#include <simd/simd.h>

#define BufferIndexMeshPositions 0
#define BufferIndexMeshColors 1
#define BufferIndexUniforms 2

#define VertexAttributePosition 0
#define VertexAttributeColor 1

struct Uniforms {
    matrix_float3x3 transform;
};
