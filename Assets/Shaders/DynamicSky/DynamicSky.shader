Shader "Costumn/Dynamic Sky"
{
    Properties{
        _WindTex("Wind", 2D) = "white" {} 
        _MainTex("Texture2d", 2D) = "white" {} 
        [NoScaleOffset] _RampTex("Gradient Sky", 2D) = "white" {}
        _CloudTex("Cloud", 2D) = "white" {}
        [NoScaleOffset] _CloudNormalTex("Cloud Normal", 2D) = "bump" {} 
        _WindTex("Wind", 2D) = "white" {} 
        
        _StarTex("Star", 2D) = "white" {}
        _NoiseTex("Star", 2D) = "" {}
        _MoonTex("Moon Texture", 2D) = "white" {}
        _SunSize("Sun Size", Range(0, 0.5)) = 0.06 
        _FogStrength("Fog Strength", Range(0, 1)) = 0.2

    } SubShader
    {
        Tags{"RenderPipeline" = "UniversalPipeline"
            "QUEUE" = "Background"
            "RenderType" = "Background"
            "PreviewType" = "Skybox"
        }
        // LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
        // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        #include "../Common.hlsl"
        ENDHLSL
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            // #pragma multi_compile_fog

            struct TBNMatrix
            {
                float3 tspace0; // tangent.x, bitangent.x, normal.x
                float3 tspace1; // tangent.y, bitangent.y, normal.y
                float3 tspace2; // tangent.z, bitangent.z, normal.z
            };
            struct Attributes
            {
                float4 positionOS : POSITION;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };
            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float4 positionOS : TEXCOORD4;

                //  TBNMatrix tbn: TEXCOORD1;
            };

            /* sampler2D _MainTex,_CloudTex,_WindTex,_StarTex,_CloudNormalTex;
            sampler2D  _RampTex,_RampTex_2,_RampTex_3,_RampTex_4,_RampTex_5,_RampTex_6,_RampTex_7;
            float4 _MainTex_ST, _NoiseTex_ST, _CloudTex_ST;*/
            float _SunSize;
            float _FogStrength;

            // float _daySpan;
            float _Speed;

            TEXTURE2D(_MoonTex);
            SAMPLER(sampler_MoonTex);  
            
            TEXTURE2D(_StarTex);
            SAMPLER(sampler_StarTex);   
            
            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);
            
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            Varyings vert(Attributes i)
            {
                Varyings o;
                o.positionOS = i.positionOS;
                o.positionHCS = TransformObjectToHClip(i.positionOS);
                /*  float3 wNormal=i.normal;
                float3 wTangent=UnityObjectToWorldDir(i.tangent.xyz);
                float tangentSign = i.tangent.w * unity_WorldTransformParams.w;
                float3 wBitangent = cross(wNormal, wTangent) * tangentSign;
                TBNMatrix tbn;
                tbn.tspace0 = half3(wTangent.x, wBitangent.x, wNormal.x);
                tbn.tspace1 = half3(wTangent.y, wBitangent.y, wNormal.y);
                tbn.tspace2 = half3(wTangent.z, wBitangent.z, wNormal.z);
                o.tbn=tbn;*/
                return o;
            }

            float2 getUV(float3 v)
            {
                v = normalize(v);
                return float2(atan2(v.z, v.x) / (2 * PI) + 0.5, asin(v.y) / PI + 0.5);
            }

            // 随时间插值
            float4 renderSun(float3 sunCenter, float3 pos)
            {
                // return (1-attenuate*6)*1;
                // return 1;//float4(1,1,0,1);
                float2 uv = (pos.xy - sunCenter.xy) / _SunSize * 0.5 + 0.5;
                return SAMPLE_TEXTURE2D(_MoonTex, sampler_MoonTex, uv);
            }

            // 计算月亮的遮照
            bool inMask(float3 sunPos, float3 v)
            {
                float3 offset = float3(0.3, 0.3, -0.2);
                float3 maskPos = normalize(sunPos + offset);
                float radius = 0.34;
                return distance(v, maskPos) < radius;
            }

            float4 renderCloud(float3 v){
                return 1;
            }

            float4 renderStar(float3 v){
                if(v.y < 0) return 0;
                float intensity=8;
                intensity = lerp(0,2,pow(v.y,0.9));
                //v.y = 1 - ( 0.5 * v.y + 0.5);
                // float2 uv = (v.xz*12);// *(v.y+1);                 
                // float2 uv = (v.xz*12);// *(v.y+1);
                float scale = 1;
                float speed = 0.05;
                float2 uv = v.xz / v.y * scale + _Time.y * speed;
                float4  starColor = 1 - SAMPLE_TEXTURE2D(_StarTex, sampler_StarTex, uv);                 
                
                //return starColor ;
                
                float  noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, uv).r; 
                
                starColor *= step(0.93, starColor.r); 

                starColor *= step(0.6,noise)*100;
                return starColor ;
                return pow(starColor, intensity);
            }

            float4 renderSky(float3 positionOS){
                positionOS.y = positionOS.y * 0.5 + 0.5;
                float2 uv = float2(1- positionOS.y, 0.5);
                float4 color= SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                //return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, getUV( positionOS.yxz));
                // return SAMPLE_TEXTURECUBE(_MainTex2,sampler_MainTex2, normalize(i.positionOS.xyz));

                //
                return color;

            }
            float4 renderAuroras(){
                
            }

            float4 frag(Varyings i) : SV_Target
            {
                float3 v = normalize(i.positionOS.xyz);
                float3 sunPos = normalize(_MainLightPosition.xyz);

                /*   float4  cloudColor= getCloud(v,i.tbn,sunPos);

                float4  starColor=getStar(v);*/
                float dis = distance(sunPos, v);
                bool aboveHorizon = i.positionOS.y > 0;

                float4 fogColor =  float4(1,0,0,1);
                if (dis < _SunSize && aboveHorizon)
                return renderSun(sunPos, v);
                else
                {

                    float4 color=renderSky(normalize(i.positionOS.xyz));
                    float4 star  = renderStar(i.positionOS.xyz);
                    color+=star;
                    // apply fog
                    //UNITY_APPLY_FOG(i.fogCoord, col);

                    //  if(aboveHorizon)
                    //   color=lerp(color,renderSun(), getAttenuate(dis));
                    //  if(aboveHorizon)
                    //  color=color*(1-cloudColor.a)+cloudColor*cloudColor.a;
                    //if(starColor.a>0.2)
                    //color=color*(1-starColor.a)+starColor*starColor.a;
                    /*  if(aboveHorizon)
                    color=lerp(fogColor,color,pow(v.y,_FogStrength));*/
                    return color;
                }
            }
            ENDHLSL
        }
    }
}