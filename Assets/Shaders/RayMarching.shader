Shader "Costumn/Simplest Ray Marching"
{
    Properties{
        [MainColor] _BaseColor("base color", color) = (1, 1, 1, 1)

    }

    SubShader
    {
        
        Tags{
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        ENDHLSL

        Pass
        {

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            float4 _BaseColor;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normal : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float4 positionSS : TEXCOORD2;
            };

            Varyings vert(Attributes i)
            {
                Varyings o;
                o.positionHCS = TransformObjectToHClip(i.positionOS.xyz);
                o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
                o.positionSS = ComputeScreenPos(o.positionHCS);
                o.normal = TransformObjectToWorldNormal(i.normal);
                return o;
            }

            // https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
            // p:pos-圆心
            float sdSphere(float3 p, float radius)
            {
                return length(p) - radius;
            }

            // ro : ray origin
            // rd : ray direction
            float4 RayMarching(float3 ro, float3 rd)
            {
                #define MIN_DISTANCE 1e-4
                #define MAX_TRACE_DISTANCE 100
                #define WHITE float4(1, 1, 1, 1)
                #define CENTER float3(3,0, 0)
                #define RADIUS 6

                float total_distance_traveled = 0;

                for (int i = 0; i < 32; ++i)
                {
                    float3 pos = ro + total_distance_traveled * rd;
                    float distance_to_closest = sdSphere(pos - CENTER, RADIUS);

                    // hit
                    if (distance_to_closest < MIN_DISTANCE)
                    {
                        return total_distance_traveled / 10;
                    }
                    // 到达最大预设距离
                    if (distance_to_closest > MAX_TRACE_DISTANCE)
                    {
                        break;
                    }
                    total_distance_traveled += distance_to_closest;
                }
                // not hit
                return -1;
            }
            

            
            half4 frag(Varyings i) : SV_Target
            {
                // ？so在0到1之间
                //float2 screenUV = i.positionSS.xy / i.positionSS.w;

                float3 viewDir = normalize(_WorldSpaceCameraPos - i.positionWS);

                //float2 worldUV = (screenUV.x + 0.5 - _ScreenParams.x / 2.0, -(screenUV.y + 0.5) + _ScreenParams.y / 2.0);
                //float4 color = RayMarching(_WorldSpaceCameraPos, float3(worldUV, -_ScreenParams.y / (2 * tan(60 / 2))));
                // return color;

                float aspect = _ScreenParams.x / _ScreenParams.y;
                
                float2 screenUV = float2(2 * aspect, 2) * i.positionSS.xy / i.positionSS.w - 1;
                //https://docs.unity3d.com/Manual/SL-UnityShaderVariables.html
                //_ProjectionParams.y
                //??
                float4 color = RayMarching(_WorldSpaceCameraPos, float3(screenUV, 1));
                //float4 color = RayMarching(_WorldSpaceCameraPos, normalize(_WorldSpaceCameraPos+float3(screenUV, 1)));

                clip(color.r-0.001);
                return color;
            }
            ENDHLSL
        }
    }
}