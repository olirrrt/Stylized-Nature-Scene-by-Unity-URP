#ifndef COSTUMN_UNIVERSAL_SHADOW_CASTER_PASS_INCLUDED
#define COSTUMN_UNIVERSAL_SHADOW_CASTER_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

// Shadow Casting Light geometric parameters. These variables are used when applying the shadow Normal Bias and are set by UnityEngine.Rendering.Universal.ShadowUtils.SetupShadowCasterConstantBuffer in com.unity.render-pipelines.universal/Runtime/ShadowUtils.cs
// For Directional lights, _LightDirection is used when applying shadow Normal Bias.
// For Spot lights and Point lights, _LightPosition is used to compute the actual light direction because it is different at each shadow caster geometry vertex.
float3 _LightDirection;
float3 _LightPosition;


TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex); 
float _AlphaClipThreshold;

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv : TEXCOORD0;
    float4 positionCS : SV_POSITION;
};

float4 GetShadowPositionHClip(Attributes input)
{
    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(input.normal);

#if _CASTING_PUNCTUAL_LIGHT_SHADOW
    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
#else
    float3 lightDirectionWS = _LightDirection;
#endif

    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

#if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#else
    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#endif

    return positionCS;
}

Varyings ShadowPassVertex(Attributes input)
{
    Varyings output;
 
    UNITY_SETUP_INSTANCE_ID(input);

 //    output.uv = TRANSFORM_TEX(input.uv, _MainTex);
    output.uv = (input.uv);
    output.positionCS = GetShadowPositionHClip(input);
    return output;
}
 

half4 ShadowPassFragment(Varyings input) : SV_TARGET
{
    //Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
   
    float4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);

    //#if _ALPHACLIP_ON
        clip(albedo.a - _AlphaClipThreshold);
    //#endif
   // if(albedo.a<0.4)return 0;
 
    return half4(1, 1, 1,  albedo.a);
}

#endif
