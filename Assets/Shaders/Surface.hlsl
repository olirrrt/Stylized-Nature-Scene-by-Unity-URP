#ifndef _SURFACE_HLSL
#define _SURFACE_HLSL
// Material Keywords
//#pragma shader_feature _NORMALMAP
//#pragma shader_feature _ALPHATEST_ON
//#pragma shader_feature _ALPHAPREMULTIPLY_ON
//#pragma shader_feature _EMISSION

//#pragma shader_feature _METALLICSPECGLOSSMAP
//#pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
//#pragma shader_feature _OCCLUSIONMAP
 
//#pragma shader_feature _SPECULARHIGHLIGHTS_OFF
//#pragma shader_feature _ENVIRONMENTREFLECTIONS_OFF
//#pragma shader_feature _SPECULAR_SETUP
//#pragma shader_feature _RECEIVE_SHADOWS_OFF
 
// URP Keywords
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
#pragma multi_compile _ _SHADOWS_SOFT
#pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
 
// Unity defined keywords
#pragma multi_compile _ DIRLIGHTMAP_COMBINED
#pragma multi_compile _ LIGHTMAP_ON
#pragma multi_compile_fog

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

//#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// And need to adjust the CBUFFER to include these too
        CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST; // Texture tiling & offset inspector values
            float4 _BaseColor;
            float _BumpScale;
            float4 _EmissionColor;
            float _Smoothness;
            float _Cutoff;
        CBUFFER_END

struct Attributes {
    float4 positionOS   : POSITION;
    float3 normal     : NORMAL;
    float4 tangentOS    : TANGENT;
    float4 color        : COLOR;
    float2 uv           : TEXCOORD0;
    float2 lightmapUV   : TEXCOORD1;
};
 
struct Varyings {
    float4 positionCS               : SV_POSITION;
    float4 color                    : COLOR;
    float2 uv                       : TEXCOORD0;
    DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
    // Note this macro is using TEXCOORD1
#ifdef REQUIRES_WORLD_SPACE_POS_INTERPOLATOR
    float3 positionWS               : TEXCOORD2;
#endif
    float3 normalWS                 : TEXCOORD3;
#ifdef _NORMALMAP
    float4 tangentWS                : TEXCOORD4;
#endif
    float3 viewDirWS                : TEXCOORD5;
    half4 fogFactorAndVertexLight   : TEXCOORD6;
    // x: fogFactor, yzw: vertex light
#ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
    float4 shadowCoord              : TEXCOORD7;
#endif
float4 positionSC : TEXCOORD8;
};

InputData InitializeInputData(Varyings IN, half3 normalTS){
    InputData inputData = (InputData)0;
 
#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    inputData.positionWS = IN.positionWS;
#endif
                 
    half3 viewDirWS = SafeNormalize(IN.viewDirWS);
#ifdef _NORMALMAP
    float sgn = IN.tangentWS.w; // should be either +1 or -1
    float3 bitangent = sgn * cross(IN.normalWS.xyz, IN.tangentWS.xyz);
    inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(IN.tangentWS.xyz, bitangent.xyz, IN.normalWS.xyz));
#else
    inputData.normalWS = IN.normalWS;
#endif
 
    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = viewDirWS;
 
#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    inputData.shadowCoord = IN.shadowCoord;
#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif
 
    inputData.fogCoord = IN.fogFactorAndVertexLight.x;
    inputData.vertexLighting = IN.fogFactorAndVertexLight.yzw;
    inputData.bakedGI = SAMPLE_GI(IN.lightmapUV, IN.vertexSH, inputData.normalWS);
    return inputData;
}
 
SurfaceData InitializeSurfaceData(Varyings IN){
    // 初始化0
    SurfaceData surfaceData = (SurfaceData)0;
    
         
    half4 albedoAlpha = SampleAlbedoAlpha(IN.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    surfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);
    surfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb * IN.color.rgb;
 
    // Not supporting the metallic/specular map or occlusion map
    // for an example of that see : https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl
 
    surfaceData.smoothness = _Smoothness;
    surfaceData.normalTS = SampleNormal(IN.uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
    surfaceData.emission = SampleEmission(IN.uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
    surfaceData.occlusion = 1;
    return surfaceData;
}

#endif