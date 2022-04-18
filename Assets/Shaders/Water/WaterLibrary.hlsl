#ifndef _WATER_LIBRARY_
#define _WATER_LIBRARY_

TEXTURE2D(_CameraOpaqueTexture);
SAMPLER(sampler_CameraOpaqueTexture);

float4 _CameraDepthTexture_TexelSize;

TEXTURE2D(_CameraDepthTexture);
SAMPLER(sampler_CameraDepthTexture);
      
TEXTURE2D(_PlanarReflectionTexture);
SAMPLER(sampler_PlanarReflectionTexture);


void CircleWave(out float2 D, float2 xz, float cicle)
{
     D = (xz - cicle) / (max(0.01, length(xz - cicle)));
       // D/=10.0;
    // D=normalize(D);
     
  
}

// 视线，半程向量，基础反射率(0度入射角)
// 返回反射光比例ks
// Fresnel-Schlick近似仅仅对电介质或者说非金属表面有定义。对于导体(Conductor)表面（金属），使用它们的折射指数计算基础折射率并不能得出正确结果
// 这个参数F0会因为材料不同而不同，而且会因为材质是金属而发生变色
// 用金属性对kd插值
float3 Fresnel_Schlick(float3 v, float3 h, float3 f0)
{
    return f0 + (1 - f0) * pow((1 - dot(h, v)), 5);
}

#define WaterF0 float3(0.02, 0.02, 0.02)

float3 UnpackDerivativeHeight(float4 textureData)
{
    float3 dh = textureData.agb;
    dh.xy = dh.xy * 2 - 1;
    return dh;
}



// d=floor(c)
// c=d + 0.5
// where d is the discrete (integer) index of the pixel and c is the continuous (floating point) value within the pixel.
// nearest neighbour
float2 pointFilter(float2 uv)
{
    /*#if UNITY_UV_STARTS_AT_TOP
    if (_CameraDepthTexture_TexelSize.y < 0) {
        uv.y = 1 - uv.y;
    }
#endif*/

    return (floor(uv * _CameraDepthTexture_TexelSize.zw) + 0.5) *
           abs(_CameraDepthTexture_TexelSize.xy);
}

float3 getUnderWaterColor(float4 screenPos, float3 tangentSpaceNormal, float4 _WaterFogColor, float4 _WaterFogColor2, float _RefractionStrength, float _WaterFogDensity)
{
    float2 uvOffset = tangentSpaceNormal.xy * _RefractionStrength;

    // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl
    // float surface= UNITY_Z_0_FAR_FROM_CLIPSPACE(screenPos.w);
    // float surface= UNITY_Z_0_FAR_FROM_CLIPSPACE(screenPos.z);
    float surface = (screenPos.w);

    float2 screenUV = pointFilter((screenPos.xy + uvOffset) / screenPos.w);
    float bottom = LinearEyeDepth(SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r, _ZBufferParams);
    float depth = (bottom - surface);

    uvOffset *= saturate(depth);
    screenUV = pointFilter((screenPos.xy + uvOffset) / screenPos.w);
    bottom = LinearEyeDepth(SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r, _ZBufferParams);
    depth = saturate(bottom - surface);

    float4 bgColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenUV);
    float _DepthStrength = 1 ;
    depth /= _DepthStrength;
    float4 fogColor = lerp(_WaterFogColor, _WaterFogColor2, saturate(depth ));

    //return depth  ; 
    return lerp(fogColor, bgColor, exp2(-_WaterFogDensity * depth)).rgb;
}

#endif