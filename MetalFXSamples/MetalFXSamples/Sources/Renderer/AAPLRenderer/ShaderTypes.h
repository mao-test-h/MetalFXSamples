/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file provides types and enumeration constants that the Metal shaders and the Swift source share.
*/

#pragma once

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

typedef NS_ENUM(NSInteger, AAPLBufferIndex)
{
    AAPLBufferIndexMeshPositions  = 0,
    AAPLBufferIndexMeshTexcoords  = 1,
    AAPLBufferIndexMeshNormals    = 2,
    AAPLBufferIndexMeshTangents   = 3,
    AAPLBufferIndexMeshBitangents = 4,
    AAPLBufferIndexFrameData      = 10,
    AAPLBufferIndexPrevFrameData  = 11
};

typedef NS_ENUM(NSInteger, AAPLVertexAttribute)
{
    AAPLVertexAttributePosition = 0,
    AAPLVertexAttributeNormal = 1,
    AAPLVertexAttributeTexcoord = 2,
    AAPLVertexAttributeTangent = 3,
    AAPLVertexAttributeBitangent = 4
};

typedef NS_ENUM(NSInteger, AAPLTextureIndex)
{
    AAPLTextureIndexColor1 = 0,
    AAPLTextureIndexColor2 = 1,
    AAPLTextureIndexColor3 = 2
};

typedef struct
{
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
    matrix_float4x4 modelMatrix;
    matrix_float3x3 normalMatrix;
    matrix_float4x4 viewMatrix;

    simd_float2 texelJitter;
    simd_float2 renderResolution;
    simd_float2 windowResolution;
    int motionVectorFrameIndex;
    
    float mipmapBias;
    
    float timeInSeconds;
    bool proceduralTextureEnabled;
} FrameData;
