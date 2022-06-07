Shader "Custom/Directional Water"
{
    Properties{
        [Header(Base Map)]
        [MainColor] _BaseColor("base color", color) = (1, 1, 1, 1)
        [NoScaleOffset] _DerivHeightMap("Deriv (AG) Height (B)", 2D) = "black" {} 
        _FlowMap("Flow Map(RG, A noise)", 2D) = "white" {}

        [Header(Flow)]
        _Speed("flow Speed", Range(0, 10)) = 1 
        _Tiling ("Tiling",   Range(0, 10)) = 1
        _GridResolution ("Grid Resolution",Range(0, 30)) = 10

        [Header(Surface)]   
        _Transparency("Transparency", Range(0, 1)) = 0.5
        _SpecularRange("Specular Range", Range(0, 1024)) = 256 
        _SpecularStrength("Specular Strength", Range(0, 1000)) = 100
        _Strength("flow Strength", Range(0, 10)) = 1 
        
        _RefNoiseTex("noise", 2D) = "black" {} 
 
        _RefNoiseStrength("Noise Strength", Range(0, 1)) = 0.6 
        _RefNoiseSpeed("Noise Speed", Range(0, 1)) = 0.6 
        

        [Header(UnderWater)]
        _WaterFogColor("Fog Color (shallow)", Color) = (1, 1, 1, 1)
        _WaterFogColor2("Fog Color (deep)", Color) = (1, 1, 1, 1)

        _WaterFogDensity("Fog Density", Range(0, 1)) = 0.1
        _RefractionStrength("Refraction Strength", Range(0, 1)) = 0.25

        [Header(Foam)]
        _FoamTex("Foam Map", 2D) = "white" {} 
        _FoamThreshold("Threshold", Range(0, 1)) = 0.4
        _FoamRange("Range", Range(0, 1)) = 0.25
        _FoamStrength("Strength", Range(0, 10)) = 1
        _FoamColor("Tint", color) = (1, 1, 1, 1)
        
    }

    SubShader
    {
        Tags{
            "RenderPipeline" = "UniversalPipeline"
        "Queue" = "Transparent"}

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"

        ENDHLSL



        Pass
        {
            
            
            ZWrite off
            ZTest on

            // Blend one zero
            // Blend SrcAlpha OneMinusSrcAlpha
            Cull OFF

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "WaterLibrary.hlsl"
            
            float3 _RippleCamPos;
            float _RippleCamSize;
            float4 _RippleMap_TexelSize;
            TEXTURE2D(_RippleMap);
            SAMPLER(sampler_RippleMap);

            TEXTURE2D(_FlowMap);
            SAMPLER(sampler_FlowMap);

            SAMPLER(sampler_unity_SpecCube0);

            TEXTURE2D(_DerivHeightMap);
            SAMPLER(sampler_DerivHeightMap);

            TEXTURE2D(_RefNoiseTex);
            SAMPLER(sampler_RefNoiseTex);
            
            TEXTURE2D(_FoamTex);
            SAMPLER(sampler_FoamTex);
            
            TEXTURE2D(_WaterDepthTex);
            SAMPLER(sampler_WaterDepthTex);

            float4 _FlowMap_ST;
            float4 _WaterFogColor, _WaterFogColor2;
            float4 _WaterFogColorMap_TexelSize;
            float _Tiling;
            float _GridResolution;
            float _Speed;
            float _Strength;
            float _Transparency;

            float _WaterFogDensity;
            float _RefractionStrength;
            
            float _SpecularRange;
            float _SpecularStrength;
            float _RefNoiseStrength;
            float _RefNoiseSpeed;
            float4 _RefNoiseTex_ST;

            float4 _BaseColor;

            float _FoamRange;
            float4 _FoamColor;            
            float _FoamThreshold;  
            float _FoamStrength;
            float4 _FoamTex_ST;
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD2;
                float4 positionSC : TEXCOORD3;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                half fogFactor : TEXCOORD4;

            };
            
            Varyings vert(Attributes IN)
            {
                Varyings o;
                o.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                o.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                o.positionSC = ComputeScreenPos(o.positionHCS);
                // o.uv= TRANSFORM_TEX(IN.uv, _FlowMap ); 偏移也会平铺
                o.uv = IN.uv;

                o.normalWS = TransformObjectToWorldNormal(IN.normal);
                o.fogFactor = ComputeFogFactor(o.positionHCS.z);

                return o;
            }

            float2 gatFlowUV(float2 uv,float2 offset, float2 shift, out float2x2 rotation)
            {
                
                // float2 flowVector = float2(0, 0);
                float2 uvTiled =( floor(uv * _GridResolution + offset) + shift) / _GridResolution;
                float4 color = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, uvTiled * _Speed  );
                float2 flowVector = (color.rg * 2 - 1) ;//* _Strength;
                
                //float2 dir = float2(sin(_Time.y), cos(_Time.y));
                float2 dir = normalize(flowVector.xy);	  

                rotation = float2x2(dir.y, dir.x, -dir.x, dir.y);

                uv = mul(float2x2(dir.y, -dir.x, dir.x, dir.y), uv);

                //float time = (_Time.y * _Speed);               
                float time =  _Time.y   * color.z * _Strength;
                //float time =  _Time.y     * _Strength;

                uv -= time;
                

                return uv * _Tiling;
            }


            float4 getFoam(Varyings IN)
            {
                float surface = (IN.positionSC.w);
                float2 screenUV = pointFilter(IN.positionSC.xy / IN.positionSC.w);
                float bottom = LinearEyeDepth(SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r, _ZBufferParams);
                float depth = (bottom - surface);

                float foamMask = 1 - saturate(_FoamRange * depth);
                float noise = SAMPLE_TEXTURE2D(_FoamTex, sampler_FoamTex, IN.positionWS.xz * _FoamTex_ST.xy + frac(_Time.y)*0).r;
               noise = step(_FoamThreshold, noise);
                noise = pow(noise, 4) * 1;

                float _phaseSpeed = 3;
                //foamMask *= saturate(sin((foamMask - _Time.y) * _phaseSpeed * PI));

                return foamMask * noise * _FoamStrength *_FoamColor;
            }
             float4 getSideFoam(Varyings IN)
            {
                float surface = (IN.positionSC.w);
                float2 screenUV = pointFilter(IN.positionSC.xy / IN.positionSC.w);
                float bottom = LinearEyeDepth(SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r, _ZBufferParams);
                float depth = (bottom - surface);

                float foamMask = 1 - saturate(_FoamRange * depth);
                float noise = SAMPLE_TEXTURE2D(_FoamTex, sampler_FoamTex, IN.positionWS.xz * _FoamTex_ST.xy + frac(_Time.y)*0).r;
               noise = step(_FoamThreshold, noise);
                noise = pow(noise, 4) * 1;

                float _phaseSpeed = 3;
                foamMask *= saturate(sin((foamMask - _Time.y) * _phaseSpeed * PI));

                return foamMask * noise * _FoamStrength *_FoamColor;
            }
            float3 flowCell(float2 uv, float2 offset){ 
                float2 shift = 1 - offset;
                shift *= 0.5;

                offset *= 0.5;
                float2x2 derivRotation;
                float2 uvFlow = gatFlowUV(uv + offset, offset, shift, derivRotation);
                
                float3 dh  = UnpackDerivativeHeight(SAMPLE_TEXTURE2D(_DerivHeightMap, sampler_DerivHeightMap, uvFlow)) ;
                dh.xy = mul(derivRotation, dh.xy);
                dh *= 4;
                return dh;
            }

            // 用ddx替换
            void blendRipples(inout Varyings IN){
                float2 uv =  (IN.positionWS.xz - _RippleCamPos.xz)/_RippleCamSize * 0.5 + 0.5;
                float2 du = float2(_RippleMap_TexelSize.x * 0.5, 0);
                float u1 = SAMPLE_TEXTURE2D(_RippleMap, sampler_RippleMap,  uv + du);
                float u2 = SAMPLE_TEXTURE2D(_RippleMap, sampler_RippleMap,  uv - du);

                float2 dv = float2(0, _RippleMap_TexelSize.y * 0.5);
                float v1 = SAMPLE_TEXTURE2D(_RippleMap, sampler_RippleMap,  uv + dv);
                float v2 = SAMPLE_TEXTURE2D(_RippleMap, sampler_RippleMap,  uv - dv);

                float3 normal = normalize(float3(u1 - u2, 1, v1 - v2));
                IN.normalWS = normalize(IN.normalWS + normal);
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float3 tmp = normalize(IN.normalWS);

                float3 dhA  = flowCell(IN.uv, float2(0,0)); 
                float3 dhB  = flowCell(IN.uv, float2(1,0)); 
                float3 dhC = flowCell(IN.uv, float2(0, 1));
                float3 dhD = flowCell(IN.uv, float2(1, 1));

                float2 t = abs(2 * frac(IN.uv * _GridResolution) - 1);
                float wA = (1 - t.x) * (1 - t.y);
                float wB = t.x * (1 - t.y);
                float wC = (1 - t.x) * t.y;
                float wD = t.x * t.y;

                float3 dh = dhA * wA + dhB * wB + dhC * wC + dhD * wD;
                float4 albedo = dh.z * dh.z ;

                // return albedo;
                

                IN.normalWS = normalize(float3(-dh.xy, 1));
                blendRipples(IN);
                //      return float4(IN.normalWS ,1);

                ////////////////////////////////////////////////////////////////////////////////////
                
                Light light = GetMainLight();

                float3 V = normalize(_WorldSpaceCameraPos - IN.positionWS);
                float3 L = normalize(light.direction); 
                
                float3 H = saturate(normalize(V + L));
                float3 N =  IN.normalWS ;

                float3 ks = saturate(Fresnel_Schlick(V, H, WaterF0));
                float3 kd = float3(1, 1, 1) - ks;
                float NdotL = saturate(dot(L, N));
                float NdotV = saturate(dot(V, N));
                
                
                ////////////////////////////////////////////////////////////////////////////////////

                float2 screenUV = IN.positionSC.xy / IN.positionSC.w;

                float3 refCol = 0;
                
                float2 uvOffset = SAMPLE_TEXTURE2D(_RefNoiseTex, sampler_RefNoiseTex, screenUV * _RefNoiseTex_ST + frac(_Time.y)*_RefNoiseSpeed).rg * _RefNoiseStrength ;
                // aspect
                uvOffset.y *=  _CameraDepthTexture_TexelSize.z * _CameraDepthTexture_TexelSize.y;
                // uvOffset.y=0;
                
                float3 ref = reflect(-V, tmp);
                //float3 ref = reflect(-V, N);

                 
                //   if(IN.normalWS.y >= 0.0) {
                //          refCol =  SAMPLE_TEXTURE2D(_PlanarReflectionTexture, sampler_PlanarReflectionTexture, screenUV + uvOffset  ).rgb;
                 //  }
                //  else {
                    refCol = SAMPLE_TEXTURECUBE(unity_SpecCube0, sampler_unity_SpecCube0, ref).rgb;
                    // refCol = DecodeHDR(refCol, unity_SpecCube0_HDR);
                 //}
                
                //  return float4(refCol, _Transparency);

                // return float4(refCol.x, refCol.y, refCol.z, 1); 
                float3 specular = pow(saturate(dot(IN.normalWS, H)), _SpecularRange);

                
                float4 surfaceColor =  1;
                surfaceColor.rgb = _BaseColor.rgb * albedo * kd  +  ks * refCol.rgb + specular  * _SpecularStrength ; 
                

                // 水底颜色
                float4 underColor = 1;
                underColor.rgb = getUnderWaterColor(IN.positionSC, IN.normalWS , _WaterFogColor, _WaterFogColor2, _RefractionStrength, _WaterFogDensity);  


                float4 color; 
                
                color = underColor * (_Transparency) +  surfaceColor * (1 - _Transparency);

                // 白沫
                color += getFoam(IN)*0.4;
                
                

                //  color.rgb = MixFog(color.rgb,  IN.fogFactor );                
                color.a = 1; 

                return color;
            }
            ENDHLSL
        }

    }
}
