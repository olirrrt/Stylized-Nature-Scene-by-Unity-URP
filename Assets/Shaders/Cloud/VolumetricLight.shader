Shader "Costumn/Volumetric Light"
{
    Properties{
        _SigmaS("scattering coefficient", color) = (1, 1, 1, 1)
        _SigmaA("absorption coefficient", color) = (0, 0, 0, 0)
        //_SigmaT("extinction coefficient", range(0, 0.2)) = 0.03
        _Step("First March Step Size", range(0.01, 4)) = 1 _LightStep("Light March Step Size", range(0.01, 40)) = 40

        _maxIterNum("Max Iteration Num", range(0, 1000)) = 1000 _Light_maxIterNum("Light Max Iteration Num", range(0, 1000)) = 8

    } SubShader
    {

        Tags{
            "Queue" = "Transparent"
        "RenderPipeline" = "UniversalPipeline"}

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        #include "../Common.hlsl"

        ENDHLSL

        Pass
        {

            // ZWrite Off
            //  ZTest on
             Blend SrcAlpha OneMinusSrcAlpha
            // Blend SrcAlpha One
          //  Blend One zero
            // Blend DstColor Zero
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);

            float4 _SigmaS;
            float4 _SigmaA;
            // float4 _SigmaT;
            float _Step;
            float _LightStep;
            #define _SigmaT 0.02
            //？hdr
            /// #define _SigmaT (20*_SigmaS+_SigmaA)

            float _maxIterNum;
            float _Light_maxIterNum;

            // #define _SigmaT (_SigmaS+_SigmaA)
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normal : NORMAL; 
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float4 positionSS : TEXCOORD2;                
                float2 uv : TEXCOORD3;

            };

            Varyings vert(Attributes i)
            {
                Varyings o;
                o.positionHCS = TransformObjectToHClip(i.positionOS.xyz);
                o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
                o.positionSS = ComputeScreenPos(o.positionHCS);
                o.normal = TransformObjectToWorldNormal(i.normal);
                o.uv=i.uv;
                return o;
            }

            // 各向同性散射
            float phaseFunction()
            {
                return 1;
                return 1.0 / (4.0 * PI);
            }
            // 瑞利散射
            // float phaseFunction()
            // {

                //    return 3.0 / (16.0 * PI)*(1+cos);
            //}
            float4 color_test;

            // 向光源步进，需要步进的是体积阴影
            float3 getScatteredLight(float3 pos)
            {
                //#define dd _LightStep

                Light light = GetMainLight();
                // 平行光的近似位置
                //float3 lightPos = _MainLightPosition;//  * 6;
                // float3 lightPos =  -normalize(light.direction)*22; 
                float3 lightPos =float3(0.562, 23.64, 5.05);
                //float3 L = lightPos - pos;

                #define MAX_ITER 8
                float dd=100/MAX_ITER;
                float3 ro = pos;
                float3 rd = normalize(light.direction);

                float dis = 0;
                float4 positionL = TransformWorldToShadowCoord(pos);
                float shadow = SAMPLE_TEXTURE2D_SHADOW(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture, positionL.xyz);
                // volshadow
                for (int i = 0; i < MAX_ITER; ++i)
                {
                    pos = ro + dis * rd;
                    dis += dd;

                    shadow *= exp(-dd * _SigmaT);
                }

                return phaseFunction() * shadow * light.color ;// * 1.0 / (length(L));
            }
            

            float4 RayMarching(float3 ro, float3 rd, float maxDistance)
            {

                #define dd _Step
                #define MAX_ITER min(1000, maxDistance / dd)

                float  transmittance = 1;
                float3 scatteredLight = 0;

                // 累积走过的距离
                float dis = 0;
                _SigmaS = max(float4(0.01, 0, 0, 1), _SigmaS);
                float3 albedo = _SigmaS / (_SigmaS + _SigmaA);
                //_SigmaT = _SigmaS + _SigmaA;

                for (int i = 0; i < MAX_ITER; ++i)
                {
                    float3 pos = ro + dis * rd;
                    dis += dd;

                    scatteredLight += transmittance * dd * getScatteredLight(pos) * _SigmaS.rgb;
                    // scatteredLight +=   transmittance * dd * getScatteredLight(pos) ;

                    transmittance *= exp(-_SigmaT * dd);
                }
                //仅有透射，近白远黑
                // return float4(transmittance,1);
                //仅有散射，离光越近越白
                return float4(scatteredLight, 1-transmittance);

                //return float4(transmittance * color_test.rgb + scatteredLight, 1);
            }

            half4 frag(Varyings i) : SV_Target
            {
                //if(_MainLightPosition.y<3)return 1;
                float2 screenUV = i.positionSS.xy / i.positionSS.w;

                float linearDepth = LinearEyeDepth(SampleSceneDepth(screenUV), _ZBufferParams);

                float3 ro = _WorldSpaceCameraPos;
                float3 rd = normalize(i.positionWS - ro);

                color_test = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenUV);
                float4 ray = RayMarching(ro, rd, min(50, linearDepth)); 
             
               // step(0.99,ray.a);
                ray.rgb  =ray.rgb*10 + color_test.rgb;
               
                return ray;
            }
            ENDHLSL
        }
    }
}