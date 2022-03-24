#ifndef _COMMON_HLSL
#define _COMMON_HLSL

// 原范围内的数,通过线性映射到新范围内
float remap(float2 inRange, float2 outRange, float n)
{
    return outRange.x + (n - inRange.x) * (outRange.y - outRange.x) / (inRange.y - inRange.x);
}

float2 remap(float2 inRange, float2 outRange, float2 n)
{
    return outRange + (n - inRange) * (outRange - outRange) / (inRange - inRange);
}
#endif