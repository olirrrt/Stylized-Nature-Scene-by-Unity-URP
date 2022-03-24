Shader "Costumn/Water"
{
    Properties
    {         
        [MainColor] _BaseColor("base color",color)=(1,1,1,1)
        [NoScaleOffset]_MainTex ("Albedo (RGB)", 2D) = "white" {}        
        [NoScaleOffset]_NormalMap ("Normal Map", 2D) = "bumps" {}
        [NoScaleOffset] _DerivHeightMap ("Deriv (AG) Height (B)", 2D) = "black" {}
        _FlowMap ("Flow Map(RG, A noise)", 2D) = "white" {}

        _Strength ("flow Strength",Range(0,10))=1
        _Speed ("flow Speed",Range(0,10))=1
        _UJump ("U jump per phase", Range(-0.25, 0.25)) = 0.25
        _VJump ("V jump per phase", Range(-0.25, 0.25)) = 0.25

        _Alpha ("transparency", Range(0, 1)) = 0.5

        _WaterFogColor ("Water Fog Color", Color) =(1,1,1,1)        
        _WaterFogColor2 ("Water Fog Color2", Color) =(1,1,1,1)

        _WaterFogDensity ("Water Fog Density", Range(0, 1)) = 0.1
        // _WaterFogColorMap ("Water Fog Color", 2D) ="white" {}   
        _RefractionStrength ("Refraction Strength", Range(0, 1)) = 0.25        
        
        _FoamThickness ("Foam Thickness", Range(0, 1)) = 0.25
        _FoamColor("Foam color",color)=(1,1,1,1)
        _NoiseMap ("noise", 2D) = "black" {}
        _Wavelength("Wavelength", Range(0, 15)) = 1
        _Wave_Speed("Wave Speed", Range(0, 5)) = 0.5   
        _Amplitude("Amplitude", Range(0, 5)) = 0.05
    }
    
    SubShader
    {
        Tags { 
            "RenderPipeline" = "UniversalPipeline" 
            // "RenderType" = "Opaque"
            "Queue" = "Transparent"
        }

        HLSLINCLUDE           
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        //https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"

        #include "WaterLibrary.hlsl"
        
        ENDHLSL
        
        Pass
        {      
            ZWrite off
            ZTest on
            
            Blend one zero
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            TEXTURE2D(_FlowMap);
            SAMPLER(sampler_FlowMap);

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
           
            SAMPLER(sampler_unity_SpecCube0);
            

            


            TEXTURE2D(_DerivHeightMap);
            SAMPLER(sampler_DerivHeightMap);

            TEXTURE2D(_NoiseMap);
            SAMPLER(sampler_NoiseMap);

            float4 _BaseColor;
            float4 _FlowMap_ST;
            float4 _WaterFogColor,_WaterFogColor2;
            float4 _WaterFogColorMap_TexelSize;


            float _Speed;
            float _Strength;
            float _UJump, _VJump;
            float _Alpha;

            float _WaterFogDensity;
            float _RefractionStrength;
            float _FoamThickness;
            float4 _FoamColor;

            float _Wave_Speed;
            float  _Wavelength;
            float _Amplitude;

            #define L _Wavelength
            #define S _Wave_Speed
            #define A _Amplitude

            struct Attributes
            {
                float4 positionOS   : POSITION;                
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };
            
            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 positionWS : TEXCOORD2;
                float4 positionSC : TEXCOORD3;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
            };
            
            Varyings vert(Attributes i)
            {
                Varyings o; 

                //i.positionOS.xyz/=10.0;

                float W = 2 * PI / L;
                //+：向内运动，-：向外运动
                float2 D=0;// =  normalize(_Direction);
                CircleWave(D,i.positionOS.xz,float2(0,0));
                //D=  normalize( D );
                //D/=10;
                float P = W * (dot(D,i.positionOS.xz) - S * _Time.y);
                i.positionOS.y = A * sin(P);
                
                
                // T:对(x, y=f(Dx+Dz), z) x求导
                float3 Tangent = normalize(float3(1, D.x * W * A * cos(P), 0));
                // B:对z求导
                float3 Bitangent = float3(0, D.y * W * A * cos(P), 1);
                o.normal=normalize(cross(Bitangent, Tangent));


                o.positionHCS = TransformObjectToHClip(i.positionOS.xyz);
                o.positionWS=TransformObjectToWorld(i.positionOS.xyz);
                o.positionSC=ComputeScreenPos(o.positionHCS);
                //o.uv= TRANSFORM_TEX(i.uv, _FlowMap ); 偏移也会平铺
                o.uv= i.uv;
                
                //o.normal=TransformObjectToWorldNormal(i.normal);
                
                return o;
            }

            // _Time 自关卡加载以来的时间 (t/20, t, t*2, t*3)
            float3 gatFlowUVW (float2 uv, bool flowB) { 
                float phaseOffset = flowB ? 0.5 : 0;
                float2 jump = float2(_UJump, _VJump);
                float3 uvw;
                
                float4 color = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, uv);//* _Strength;directional alian
                float2 flowVector =(color.rg * 2 - 1) * _Strength;
                float timeOffset = color.a;

                float time=(_Time.y * _Speed + timeOffset); 
                // 1个周期内时间
                float progress=frac( time + phaseOffset);
                // uvw.xy =uv - flowVector * time + phaseOffset;  
                uvw.xy =uv - flowVector * progress;
                //uvw.xy=uvw.xy * 4 + phaseOffset;                
                uvw.xy=uvw.xy * _FlowMap_ST.xy + phaseOffset;

                uvw.xy += (time- progress) * jump;
                // 权重                
                uvw.z = 1 - abs(1 - 2 * progress);
                
                return uvw;
            }





            float getFoam(float4 screenPos){
                float surface= (screenPos.w);
                float2 screenUV=pointFilter(screenPos.xy / screenPos.w);
                float bottom= LinearEyeDepth(SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture,screenUV).r,_ZBufferParams );
                float depth=(bottom - surface);
                
                half4 foamMask =1 - saturate(_FoamThickness* depth);
                //float4 noise=SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, screenUV);
                return foamMask.r ;///* noise;
            }

            half4 frag(Varyings input) : SV_Target
            {  
                // return float4(normalize(input.normal),1);

                float3 uvwA=gatFlowUVW(input.uv,true);
                float3 uvwB=gatFlowUVW(input.uv,false);
                float4 albedoA=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uvwA.xy)* uvwA.z;
                float4 albedoB=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uvwB.xy)* uvwB.z;
                
                float4 color=_BaseColor * (albedoA+ albedoB);
                //return color;

                //float3 normal1=UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,uvwA.xy));
                //float3 normal2=UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,uvwB.xy));
                //input.normal=normalize(normal1+normal2);

                float3 dhA=UnpackDerivativeHeight(SAMPLE_TEXTURE2D(_DerivHeightMap, sampler_DerivHeightMap, uvwA.xy))* uvwA.z;
                float3 dhB=UnpackDerivativeHeight(SAMPLE_TEXTURE2D(_DerivHeightMap, sampler_DerivHeightMap, uvwB.xy))* uvwB.z;
                // input.normal=normalize(float3(-(dhA.xy+dhB.xy), 1));
                input.normal=normalize(float3(-(dhA.xy+dhB.xy), 1)+ input.normal);
                //input.normal=normalize(   input.normal);

                Light light=GetMainLight();
                float3 viewDir=normalize(_WorldSpaceCameraPos - input.positionWS);
                float3 lightDir=normalize(light.direction);
                float3 h=saturate(normalize(viewDir + lightDir));
                float3 ks=Fresnel_Schlick(viewDir, h, WaterF0);
                float3 kd=float3(1, 1, 1)-ks;
                
                //kd*=1-_metallic;

                // 直接光源
                float3 normal=input.normal;
                float NdotL=saturate(dot(lightDir, normal));                
                float NdotV=saturate(dot(viewDir, normal));

                color.xyz=light.color * (dot(color.xyz,kd)/PI + 0.6*ks/(4*NdotL*NdotV+0.00001)) *NdotL;
                
                // 间接光源
                float3 ref=reflect(-viewDir, input.normal);
                float4 env=SAMPLE_TEXTURECUBE(unity_SpecCube0,sampler_MainTex,ref);    
                float4 tmp=float4(kd*env.xyz+ks*env.xyz,0);
                //return color+tmp;
                // return env;
                color+=0.4*env;  

                //float4 bgColor=SAMPLE_TEXTURE2D(_CameraOpaqueTexture,sampler_CameraOpaqueTexture,input.positionSC.xy/input.positionSC.w);
                //return bgColor;

                //color.a=_Alpha;
                
                color.rgb=color.rgb*_Alpha + getUnderWaterColor(input.positionSC,input.normal,_WaterFogColor,_WaterFogColor2,_RefractionStrength,_WaterFogDensity)*(1-_Alpha);

                float noise=1-SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, uvwA.xy).r;            
                float noise2=1-SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, uvwB.xy).r;

                float foamMask= getFoam(input.positionSC)-noise;            
                float foamMask2= getFoam(input.positionSC)-noise2;

                // return color;
                return foamMask+foamMask2>0 ? _FoamColor : color;
            }
            ENDHLSL
        }

        // 水面不投射阴影
        Pass{
            Tags{"LightMode"="ShadowCaster"}
        }     

    }
}

