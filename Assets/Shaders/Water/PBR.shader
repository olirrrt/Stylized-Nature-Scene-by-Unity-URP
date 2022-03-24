Shader "Costumn/PBR"
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

    }
    
    SubShader
    {
        Tags { 
            "RenderPipeline" = "UniversalPipeline" 
            "RenderType" = "Opaque"
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
            
            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);
            
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            TEXTURE2D(_DerivHeightMap);
            SAMPLER(sampler_DerivHeightMap);

            TEXTURE2D(_NoiseMap);
            SAMPLER(sampler_NoiseMap);

            float4 _BaseColor;
            float4 _FlowMap_ST;
            float4 _WaterFogColor,_WaterFogColor2;
            float4 _WaterFogColorMap_TexelSize;
            float4 _CameraDepthTexture_TexelSize;

            float _Speed;
            float _Strength;
            float _UJump, _VJump;
            float _Alpha;

            float _WaterFogDensity;
            float _RefractionStrength;
            float _FoamThickness;
            float4 _FoamColor;

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
                o.positionHCS = TransformObjectToHClip(i.positionOS.xyz);
                o.positionWS=TransformObjectToWorld(i.positionOS.xyz);
                o.positionSC=ComputeScreenPos(o.positionHCS);
                //o.uv= TRANSFORM_TEX(i.uv, _FlowMap ); 偏移也会平铺
                o.uv= i.uv;
                
                o.normal=TransformObjectToWorldNormal(i.normal);
                
                return o;
            }

            
            half4 frag(Varyings input) : SV_Target
            {  

                  
                float4 color=_BaseColor * (albedoA+ albedoB);
                //return color;

                //float3 normal1=UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,uvwA.xy));
                //float3 normal2=UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,uvwB.xy));
                //input.normal=normalize(normal1+normal2);

                
                i.normal=normalize(float3(-(dhA.xy+dhB.xy), 1));

                Light light=GetMainLight();
                float3 viewDir=normalize(_WorldSpaceCameraPos - i.positionWS);
                float3 lightDir=normalize(light.direction);
                float3 h=saturate(normalize(viewDir + lightDir));
                float3 ks=Fresnel_Schlick(viewDir, h, WaterF0);
                float3 kd=float3(1, 1, 1)-ks;
                
                //kd*=1-_metallic;

                // 直接光源
                float3 normal=i.normal;
                float NdotL=saturate(dot(lightDir, normal));                
                float NdotV=saturate(dot(viewDir, normal));

                color.xyz=light.color * (dot(color.xyz,kd)/PI + 0.6*ks/(4*NdotL*NdotV+0.00001)) *NdotL;
                
                // 间接光源
                float3 ref=reflect(-viewDir, i.normal);
                float4 env=SAMPLE_TEXTURECUBE(unity_SpecCube0,sampler_MainTex,ref);    
                float4 tmp=float4(kd*env.xyz+ks*env.xyz,0);
                //return color+tmp;
                // return env;
                color+=0.4*env;  

                //float4 bgColor=SAMPLE_TEXTURE2D(_CameraOpaqueTexture,sampler_CameraOpaqueTexture,i.positionSC.xy/i.positionSC.w);
                //return bgColor;

                //color.a=_Alpha;
                
                color.rgb=color.rgb*_Alpha + getUnderWaterColor(i.positionSC,i.normal)*(1-_Alpha);

                float noise=1-SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, uvwA.xy).r;            
                float noise2=1-SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, uvwB.xy).r;

                float foamMask= getFoam(i.positionSC)-noise;            
                float foamMask2= getFoam(i.positionSC)-noise2;

                //color.rgb +=saturate(foamMask * _FoamColor);
                //return color;
                return foamMask+foamMask2>0 ? _FoamColor : color;
            }
            ENDHLSL
        }

        // 水面不投射阴影
        //   Pass{
            //      Tags{"LightMode"="ShadowCaster"}
        // }     

    }
}

