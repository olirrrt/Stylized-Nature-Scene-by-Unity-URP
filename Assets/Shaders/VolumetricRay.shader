Shader "Costumn/Simplest Volumetric Ray"
{
    Properties{
        [MainColor] _BaseColor("base color", color) = (1, 1, 1, 1)

    }

    SubShader
    {
        
        Tags{
           // "RenderType" = "Opaque"
            "RenderQueue"="Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

        ENDHLSL
    Pass{
            Tags{    "LightMode" = "DepthOnly"}
        }
        Pass
        {
            //ZWrite Off
            //ZTest on
            

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            // TEXTURE2D(_CameraDepthTexture);
            // SAMPLER(sampler_CameraDepthTexture);
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normal : NORMAL;
            };
            float4 _BaseColor;

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
            float inShadow(float3 positionWS){
                //     shadowCoord.xy /= shadowCoord.w;
                //     return float4(shadowCoord.xyz, 0);
                //float4 shadowCoord=TransformWorldToShadowCoord(positionWS);
                //float attenuation = SAMPLE_TEXTURE2D_SHADOW(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture, shadowCoord.xyz);
                // return attenuation;
                Light light=GetMainLight(TransformWorldToShadowCoord(positionWS));
                //return  light.shadowAttenuation<0.5?0:1;
                return  light.shadowAttenuation ;

            }

            // ro : ray origin
            // rd : ray direction
            // in??
            float4 RayMarching(float3 ro, float3 rd,out float3 finalPos)
            {
                #define MIN_DISTANCE 1e-4
                
                #define MAX_ITER 32
                #define STEP 0.5

                float total_distance_traveled = 0;

                for (int i = 0; i < MAX_ITER; ++i)
                {
                    float3 pos = ro + total_distance_traveled * rd;
                    
                    float dd =  inShadow(pos);

                    // hit
                    if (dd < MIN_DISTANCE)
                    {
                        return total_distance_traveled;
                    }
                    // 到达最大预设距离
                    // if (pos > finalPos)
                    //  {
                        //          break;
                    // }
                    total_distance_traveled += STEP;
                }
                // not hit
                return -1;
            }
            // _CameraOpaqueTexture
            half4 frag(Varyings i) : SV_Target
            {
                
                float2 screenUV = i.positionSS.xy / i.positionSS.w;
                // float4 color=SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_CameraDepthTexture,screenUV);
                float4 color=SAMPLE_TEXTURE2D(_ScreenSpaceShadowmapTexture,sampler_ScreenSpaceShadowmapTexture,screenUV);
                 return color.a;
                //Light light=GetMainLight(TransformWorldToShadowCoord(positionWS));
                //return  light.shadowAttenuation<0.5?0:1;
               // return  light.shadowAttenuation ;
                
                float linearDepth=LinearEyeDepth(SampleSceneDepth(screenUV),_ZBufferParams);
                return linearDepth;///20.0;
                

                
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.positionWS);
                //= RayMarching(_WorldSpaceCameraPos, viewDir, i.positionWS);

                //return TransformWorldToShadowCoord(i.positionWS);
                return inShadow(i.positionWS);


                //float aspect = _ScreenParams.x / _ScreenParams.y; 
                //float2 screenUV = float2(2 * aspect, 2) * i.positionSS.xy / i.positionSS.w - 1;
                
                //float4 color = RayMarching(_WorldSpaceCameraPos, normalize(_WorldSpaceCameraPos+float3(screenUV, 1)));

                //clip(color.r-0.001);
                return color;
            }
            ENDHLSL
        }
        Pass{
            Tags{    "LightMode" = "ShadowCaster"}
        }     
     
    }
}