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

            // 视线，半程向量，基础反射率(0度入射角)
            // 返回反射光比例ks
            // Fresnel-Schlick近似仅仅对电介质或者说非金属表面有定义。对于导体(Conductor)表面（金属），使用它们的折射指数计算基础折射率并不能得出正确结果
            // 这个参数F0会因为材料不同而不同，而且会因为材质是金属而发生变色
            // 用金属性对kd插值
            float3 Fresnel_Schlick(float3 v, float3 h, float3 f0){
                return f0 + (1 - f0 ) * pow((1 - dot(h, v)),5);
            }
            
            #define WaterF0 float3(0.02, 0.02, 0.02)
            
            float3 UnpackDerivativeHeight (float4 textureData) {
                float3 dh = textureData.agb;
                dh.xy = dh.xy * 2 - 1;
                return dh;
            }

            // d=floor(c)
            // c=d + 0.5
            // where d is the discrete (integer) index of the pixel and c is the continuous (floating point) value within the pixel.
            // nearest neighbour
            float2 pointFilter (float2 uv) {
                /*#if UNITY_UV_STARTS_AT_TOP
                if (_CameraDepthTexture_TexelSize.y < 0) {
                    uv.y = 1 - uv.y;
                }
            #endif*/
            
            return
            (floor(uv * _CameraDepthTexture_TexelSize.zw) + 0.5) *
            abs(_CameraDepthTexture_TexelSize.xy);
        }


        float3 getUnderWaterColor(float4 screenPos, float3 tangentSpaceNormal){
            float2 uvOffset = tangentSpaceNormal.xy * _RefractionStrength;

            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl
            // float surface= UNITY_Z_0_FAR_FROM_CLIPSPACE(screenPos.w);
            // float surface= UNITY_Z_0_FAR_FROM_CLIPSPACE(screenPos.z);
            float surface= (screenPos.w);

            float2 screenUV=pointFilter((screenPos.xy + uvOffset) / screenPos.w);
            float bottom= LinearEyeDepth(SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture,screenUV).r,_ZBufferParams );
            float depth=(bottom - surface);

            
            uvOffset*=saturate(depth);
            screenUV=pointFilter((screenPos.xy + uvOffset) / screenPos.w);
            bottom= LinearEyeDepth(SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture,screenUV).r,_ZBufferParams );
            depth=saturate(bottom - surface);
            
            float4 bgColor= SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenUV);                  
            float4 fogColor=lerp(_WaterFogColor,_WaterFogColor2,saturate(depth/28.0) );
            //float4 fogColor=_WaterFogColor;

            return lerp(fogColor, bgColor, exp2(-_WaterFogDensity * depth)).rgb;
        }

        float getFoam(float4 screenPos){
            float surface= (screenPos.w);
            float2 screenUV=pointFilter(screenPos.xy / screenPos.w);
            float bottom= LinearEyeDepth(SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture,screenUV).r,_ZBufferParams );
            float depth=(bottom - surface);
            
            half4 foamMask =1 - saturate(_FoamThickness* depth);
            //float4 noise=SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, screenUV);
            return foamMask ;///* noise;
        }

        half4 frag(Varyings input) : SV_Target
        {  

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
            input.normal=normalize(float3(-(dhA.xy+dhB.xy), 1));

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
            
            color.rgb=color.rgb*_Alpha + getUnderWaterColor(input.positionSC,input.normal)*(1-_Alpha);

            float noise=1-SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, uvwA.xy).r;            
            float noise2=1-SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, uvwB.xy).r;

            float foamMask= getFoam(input.positionSC)-noise;            
            float foamMask2= getFoam(input.positionSC)-noise2;

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

 