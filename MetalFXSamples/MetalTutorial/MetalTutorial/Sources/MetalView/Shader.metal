#include <metal_stdlib>
#include "ShaderTypes.h"
using namespace metal;

// NOTE: Metalの言語仕様はC言語の拡張なので、`ShaderTypes.h`をincludeして定義済みの構造体を使い回すことが可能

typedef struct {
    float4 position [[position]];
    float4 color;
} RasterizerData;

vertex RasterizerData vertexShader(
    uint vertexID [[vertex_id]],
    constant ShaderVertex* vertices [[buffer(kShaderVertexInputIndexVertices)]],
    constant vector_float2* viewportSize [[buffer(kShaderVertexInputIndexViewportSize)]])
{
    RasterizerData result = {};
    result.position = float4(0.0, 0.0, 0.0, 1.0);
    result.position.xy = vertices[vertexID].position / (*viewportSize);
    result.color = vertices[vertexID].color;
    return result;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]])
{
    return metal::floor(in.color * 5.0) / 5.0;
}
