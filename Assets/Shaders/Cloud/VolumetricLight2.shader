Shader "Costumn/Volumetric Light Post Process"
{
    Properties{
        _SigmaS("scattering coefficient", color) = (1, 1, 1, 1)
        _SigmaA("absorption coefficient", color) = (0, 0, 0, 0)
        

        _maxIterNum("Max Iteration Num", range(0, 1000)) = 1000 
        _Light_maxIterNum("Light Max Iteration Num", range(0, 1000)) = 8

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

            ZWrite Off
            //  ZTest on
            Blend SrcAlpha OneMinusSrcAlpha
            // Blend SrcAlpha One
            // Blend One zero
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

            // TEXTURE2D(_ScreenSpaceShadowmapTexture);
            // SAMPLER(sampler_ScreenSpaceShadowmapTexture);

            float4 _SigmaS;
            float4 _SigmaA;
            // float4 _SigmaT;
            
            #define _SigmaT 0.02
            
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
            // Henyey-Greenstein散射
            float phaseFunction(float c)
            {
                
                float g =     -0.99;
                return (1 - g * g) / (4 * PI * pow((1 + g * g - 2 * g * c), 1.5));
                
            }
            // 瑞利散射
            // float phaseFunction()
            // {

                //    return 3.0 / (16.0 * PI)*(1+cos);
            //}
            float4 color_bg;

            float3 getShadow(float3 pos){
                

                Light light = GetMainLight();
                // 平行光
                //  float3 lightDir = normalize(light.direction);
                // float3 lightPos = normalize(light.direction);
                // 平行光的近似位置
                //float3 lightPos = _MainLightPosition ;               
                //float3 lightPos = -normalize(light.direction)*2;

                float3 lightDir = normalize(light.direction);

                // Light light=GetAdditionalLight(0,pos);

                float MAX_ITER = 28;
                float dd =(100)/MAX_ITER;

                float3 ro = pos;
                float3 rd = lightDir;

                float dis = 0;
                float4 positionL = TransformWorldToShadowCoord(pos);
                float3 shadow = SAMPLE_TEXTURE2D_SHADOW(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture, positionL.xyz);
 
                // volshadow
                for (int i = 0; i < MAX_ITER; ++i)
                {
                    pos = ro + dis * rd;
                    dis += dd;

                    shadow *= exp(-dd * _SigmaT);
                }
                
                return shadow;// *(1/dot(l,l));
            }
            

            float4 RayMarching(float3 ro, float3 rd, float maxDistance)
            {

                
                float MAX_ITER = 64;

                float dd = (maxDistance) / MAX_ITER;

                float dis = 0;
                float transmittance = 1;
                float3 scatteredLight = 0;
                

                for (int i = 0; i < MAX_ITER; ++i)
                {
                    float3 pos = ro + dis * rd;
                    dis += dd;
                    Light light = GetMainLight();
                    //  scatteredLight += transmittance * dd * phaseFunction() *light.color* getShadow(pos);// * _SigmaS.rgb;
                    // scatteredLight += transmittance * dd *light.color* getShadow(pos)   * _SigmaS.rgb;
                    scatteredLight +=  getShadow(pos) ;

                    transmittance *= exp(-_SigmaT * dd);
                }
                //仅有透射，近白远黑
                // return float4(transmittance, transmittance, transmittance, 1);
                //仅有散射，离光越近越白
                return float4(scatteredLight/MAX_ITER, 1);
                //  return float4(scatteredLight.x, scatteredLight.y,    scatteredLight.z, transmittance);
                // return float4(   scatteredLight/5, 1-transmittance);

                //return float4(transmittance * color_bg.rgb + scatteredLight/5, 1);
            }
            half4 frag(Varyings i) : SV_Target
            {
                
                float linearDepth = LinearEyeDepth(SampleSceneDepth(i.uv), _ZBufferParams);
                color_bg = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, i.uv);
                //return linearDepth/200;
                // 校正屏幕长宽比
                float aspect = _ScreenParams.x / _ScreenParams.y;
                float2 screenUV = 2 * i.uv - 1;
                screenUV.y *= 1 / aspect;

                


                float3 ro = _WorldSpaceCameraPos;
                float3 rd = normalize(float3(screenUV, 1));
                rd = mul(getViewToWorldMatrix(), float4(rd, 1)).xyz;
                ro= ro + rd * linearDepth;

                return  RayMarching(ro, rd, 20);
            }
            ENDHLSL
        }
    }
}