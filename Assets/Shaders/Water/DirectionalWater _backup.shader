Shader "Custom/Directional Water"
{
    Properties{
        [Header(Texture)]
        [MainColor] _BaseColor("base color", color) = (1, 1, 1, 1)
        [NoScaleOffset] _DerivHeightMap("Deriv (AG) Height (B)", 2D) = "black" {} 
        _FlowMap("Flow Map(RG, A noise)", 2D) = "white" {}

        [Header(Flow)]
        _Speed("flow Speed", Range(0, 10)) = 1 
        _Tiling ("Tiling",   Range(0, 10)) = 1
        _GridResolution ("Grid Resolution",Range(0, 30)) = 10

        [Header(Surface)]   
        _Transparency("Transparency", Range(0, 1)) = 0.5
        _SpecularStrength("Specular Strength", Range(0, 512)) = 0.6 
        
        _Strength("flow Strength", Range(0, 10)) = 1 
        
        _NoiseTex("noise", 2D) = "black" {} 
        _RefNoiseTiling("Noise Tiling", Range(0, 10)) = 1
        _RefNoiseStrength("Noise Strength", Range(0, 1)) = 0.6 
        _RefNoiseSpeed("Noise Speed", Range(0, 1)) = 0.6 
        

        [Header(UnderWater)]
        _WaterFogColor("Water Fog Color", Color) = (1, 1, 1, 1)
        _WaterFogColor2("Water Fog Color2", Color) = (1, 1, 1, 1)

        _WaterFogDensity("Water Fog Density", Range(0, 1)) = 0.1
        // _WaterFogColorMap ("Water Fog Color", 2D) ="white" {}
        _RefractionStrength("Refraction Strength", Range(0, 1)) = 0.25

        [Header(Foam)]
        _FoamThickness("Foam Thickness", Range(0, 1)) = 0.25 
        _FoamColor("Foam color", color) = (1, 1, 1, 1)
        
        //_Wavelength("Wavelength", Range(0, 15)) = 1 
        //_Wave_Speed("Wave Speed", Range(0, 5)) = 0.5 
        //_Amplitude("Amplitude", Range(0, 5)) = 0.05
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
            // Tags{
                //  "LightMode" = "ForwardBase"
            //}
            
            ZWrite off
            ZTest on

            Blend one zero

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "WaterLibrary.hlsl"
            


            TEXTURE2D(_FlowMap);
            SAMPLER(sampler_FlowMap);

            

            SAMPLER(sampler_unity_SpecCube0);

            TEXTURE2D(_DerivHeightMap);
            SAMPLER(sampler_DerivHeightMap);

            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);
            

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
            float _FoamThickness;
            float4 _FoamColor;
            float _SpecularStrength;
            float _RefNoiseStrength;
            float _RefNoiseSpeed;
            float _RefNoiseTiling;

            float4 _BaseColor;

            /*            Varyings vert(Attributes i)
            {
                Varyings o;


                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
                o.positionSC = ComputeScreenPos(o.positionCS);
                // o.uv= TRANSFORM_TEX(i.uv, _FlowMap ); 偏移也会平铺
                o.uv = i.uv;

                o.normalWS = TransformObjectToWorldNormal(i.normal);

                return o;
            }*/

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
            
            Varyings vert(Attributes i)
            {
                Varyings o;

                

                o.positionHCS = TransformObjectToHClip(i.positionOS.xyz);
                o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
                o.positionSC = ComputeScreenPos(o.positionHCS);
                // o.uv= TRANSFORM_TEX(i.uv, _FlowMap ); 偏移也会平铺
                o.uv = i.uv;

                o.normalWS = TransformObjectToWorldNormal(i.normal);
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

            float getFoam(float4 screenPos)
            {
                float surface = (screenPos.w);
                float2 screenUV = pointFilter(screenPos.xy / screenPos.w);
                float bottom = LinearEyeDepth(SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r, _ZBufferParams);
                float depth = (bottom - surface);

                half4 foamMask = 1 - saturate(_FoamThickness * depth);
                // float4 noise=SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, screenUV);
                return foamMask.r; ///* noise;
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

            half4 frag(Varyings i) : SV_Target
            {
                float3 tmp = normalize(i.normalWS);
                
                //float2x2 derivRotation;
                //float2 uv =gatFlowUV( i.uv  , derivRotation );

                //float3 dh  = UnpackDerivativeHeight(SAMPLE_TEXTURE2D(_DerivHeightMap, sampler_DerivHeightMap, uv)) ;
                //dh.xy = mul(derivRotation, dh.xy);
                float3 dhA  = flowCell(i.uv, float2(0,0)); 
                float3 dhB  = flowCell(i.uv, float2(1,0)); 
                float3 dhC = flowCell(i.uv, float2(0, 1));
                float3 dhD = flowCell(i.uv, float2(1, 1));

                float2 t = abs(2 * frac(i.uv * _GridResolution) - 1);
                float wA = (1 - t.x) * (1 - t.y);
                float wB = t.x * (1 - t.y);
                float wC = (1 - t.x) * t.y;
                float wD = t.x * t.y;

                float3 dh = dhA * wA + dhB * wB + dhC * wC + dhD * wD;
                float4 albedo = dh.z * dh.z ;

                // return albedo;
                

                i.normalWS = normalize(float3(-dh.xy, 1));

                

                ////////////////////////////////////////////////////////////////////////////////////
                
                Light light = GetMainLight();

                float3 viewDir = normalize(_WorldSpaceCameraPos - i.positionWS);
                float3 lightDir = normalize(light.direction); 
                
                float3 H = saturate(normalize(viewDir + lightDir));

                float3 ks = Fresnel_Schlick(viewDir, H, WaterF0);
                float3 kd = float3(1, 1, 1) - ks;
                float NdotL = saturate(dot(lightDir, i.normalWS));
                float NdotV = saturate(dot(viewDir, i.normalWS));
                
                // float3 surfaceColor =  light.color * (dot(albedo.rgb, kd) / PI +  _SpecularStrength * ks / (4 * NdotL * NdotV + 0.00001)) * NdotL;
                
                ////////////////////////////////////////////////////////////////////////////////////

                float2 screenUV = i.positionSC.xy / i.positionSC.w;

                float3 refCol = 0;
                
                float2 uvOffset = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, screenUV * _RefNoiseTiling + frac(_Time.y)*_RefNoiseSpeed).rg * _RefNoiseStrength ;
                // aspect
                uvOffset.y *=  _CameraDepthTexture_TexelSize.z * _CameraDepthTexture_TexelSize.y;
                
                
                
                float3 ref = reflect(-viewDir, tmp);
                
                // return SAMPLE_TEXTURE2D(_PlanarReflectionTexture, sampler_PlanarReflectionTexture, screenUV  );
                
                  if(i.normalWS.y >= 0.0) {
                    refCol =  SAMPLE_TEXTURE2D(_PlanarReflectionTexture, sampler_PlanarReflectionTexture, screenUV + uvOffset  ).rgb;
                 }
                   else {
                         refCol = SAMPLE_TEXTURECUBE(unity_SpecCube0, sampler_unity_SpecCube0, ref);
                  }
                
                

                // return float4(refCol.x, refCol.y, refCol.z, 1); 
                float3 specular = pow(saturate(dot(i.normalWS, H)), _SpecularStrength);

                
                float4 surfaceColor =  1;
                surfaceColor.rgb = _BaseColor.rgb * albedo * kd  +  ks * refCol.rgb + specular * 1000 ; 
                //return surfaceColor; 
                


                ////////////////////////////////////////////////////////////////////////////////////

                float4 underColor = 1;
                underColor.rgb = getUnderWaterColor(i.positionSC, i.normalWS , _WaterFogColor, _WaterFogColor2, _RefractionStrength, _WaterFogDensity);
                //return underColor;     
                
                float4 color; 
                
                
                color.rgb   = underColor.rgb * kd  +  ks * refCol.rgb + specular * 100 ; 

                color = underColor * (_Transparency) +  surfaceColor * (1-_Transparency);

                color.a = 1;  
                //  float noise = 1 - SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, uvwA.xy).r;
                
                //   float noise2 = 1 - SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, uvwB.xy).r;

                //   float foamMask = getFoam(i.positionSC) - noise;
                //  float foamMask2 = getFoam(i.positionSC) - noise2;

                // return color;
                // return foamMask + foamMask2 > 0 ? _FoamColor : color;


                color.rgb = MixFog(color.rgb,  i.fogFactor );                

                return color;
            }
            ENDHLSL
        }

    }
}
