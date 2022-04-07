#ifndef _COMMON_HLSL
#define _COMMON_HLSL

// 原范围内的数,通过线性映射到新范围内
float remap(float2 inRange, float2 outRange, float n)
{
    return outRange.x + (n - inRange.x) * (outRange.y - outRange.x) / (inRange.y - inRange.x);
}

float2 remap(float2 inRange, float2 outRange, float2 n)
{
    float2 res;
    res.x = outRange.x + (n - inRange.x) * (outRange.y - outRange.x) / (inRange.y - inRange.x);
    res.y = outRange.x + (n - inRange.x) * (outRange.y - outRange.x) / (inRange.y - inRange.x);
    return res;
}

float4x4 getViewToWorldMatrix()
{
    /* float4x4 tmp=unity_CameraToWorld;
    rd=mul(tmp,float4(rd,1)).xyz;
    */

    // 从相机右手到世界左手
    float3 V = -normalize(_WorldSpaceCameraPos);
    float3 Right = cross(float3(0, 1, 0), V);
    float3 Up = cross(V, Right);

    float4x4 changeBasis = {
        float4(Right.x, Right.y, Right.z, 0),
        float4(Up.x, Up.y, Up.z, 0),
        float4(V.x, V.y, V.z, 0),
        float4(0, 0, 0, 1)};

    float4x4 translation = {
        float4(1, 0, 0, -_WorldSpaceCameraPos.x),
        float4(0, 1, 0, -_WorldSpaceCameraPos.y),
        float4(0, 0, 1, -_WorldSpaceCameraPos.z),
        float4(0, 0, 0, 1)};

    // return changeBias;
    return changeBasis * translation;
}
#endif