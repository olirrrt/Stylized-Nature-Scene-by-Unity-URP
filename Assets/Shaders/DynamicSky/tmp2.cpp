#include "Common.cg"
float4 main(float4 c0
            : COLOR0, float4 c1
            : COLOR1, float3 v3Direction
            : TEXCOORD0, uniform float3 v3LightDirection, uniform float g, uniform float g2) : COLOR
{
    float fCos = dot(v3LightDirection, v3Direction) / length(v3Direction);
    float fCos2 = fCos * fCos;
    float4 color = getRayleighPhase(fCos2) * c0 + getMiePhase(fCos, fCos2, g, g2) * c1;
    color.a = color.b;
    return color;
}
