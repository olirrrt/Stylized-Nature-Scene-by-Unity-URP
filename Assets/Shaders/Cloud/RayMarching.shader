Shader "Costumn/Simplest Ray Marching"
{
    Properties{
        [MainColor] _BaseColor("base color", color) = (1, 1, 1, 1)
        _NoiseTex("texture 3d",3d)=""{}

    }

    SubShader
    {
        
        Tags{
            //"RenderType" = "Opaque"
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }

        //Cull Front
        //Cull Off

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        ENDHLSL

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha

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
            TEXTURE3D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            // https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
            // p:pos-圆心
            float sdSphere(float3 p, float radius)
            {
                return length(p) - radius;
            }

            float sdBox( float3 p, float3 b )
            {
                float3 q = abs(p) - b;
                return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
            }

            // ro : ray origin
            // rd : ray direction
            float4 RayMarching(float3 ro, float3 rd)
            {
                #define MIN_DISTANCE 1e-4
                #define MAX_TRACE_DISTANCE 200
                #define WHITE float4(1, 1, 1, 1)
                #define CENTER float3(3,0, 0)
                #define RADIUS 6

                float total_distance_traveled = 0;
                float sum=0;
                float4 density;

                for (int i = 0; i < 32; ++i)
                {
                    float3 pos = ro + total_distance_traveled * rd;
                    //float distance_to_closest = sdSphere(pos - CENTER, RADIUS);
                    float distance_to_closest = sdBox(pos - CENTER, float3(2,2,2));

                    // hit
                    if (distance_to_closest < 2)
                    {
                        //return total_distance_traveled / 10;
                        //sum+=0.02;
                        //采样3d纹理
                        //density+=pow(SAMPLE_TEXTURE3D(_NoiseTex,sampler_NoiseTex,pos),1);
                        //density+= SAMPLE_TEXTURE3D(_NoiseTex,sampler_NoiseTex,pos) ;

                        sum+=pow(SAMPLE_TEXTURE3D(_NoiseTex,sampler_NoiseTex,pos/5),5);
                    }
                    // 到达最大预设距离
                    if (distance_to_closest > MAX_TRACE_DISTANCE)
                    {
                        break;
                    }
                    total_distance_traveled += distance_to_closest;
                }
                // not hit
                //return -1;
                return sum;
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
                //float4 color = RayMarching(_WorldSpaceCameraPos, float3(screenUV, 1));
                float4 color = RayMarching(_WorldSpaceCameraPos, normalize(-_WorldSpaceCameraPos+i.positionWS));

                //clip(color.a-0.1);
                return color;
            }
            ENDHLSL
        }
    }
}