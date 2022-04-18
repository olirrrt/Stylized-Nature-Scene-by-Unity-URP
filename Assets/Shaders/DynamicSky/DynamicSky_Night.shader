Shader "Custom/ Dynamic Sky Night"
{
    Properties{
        [Header(Sky)]
        [NoScaleOffset] _MainTex("Gradient Sky", 2D) = "white" {} 
        
        [Header(Star)]
        _StarTex("Star", 2D) = "white" {}  
        _StarThreshold("Star Threshold", Range(0, 1)) = 0.95
        [NoScaleOffset]_NoiseTex("Sparkle Noise", 2D) = "" {}
        [NoScaleOffset]_NoiseTex2("Sparkle Noise Color", 2D) = "" {} 
        _StarNoiseThreshold("Star Noise Threshold", Range(0, 1)) = 0.768
        _StarNoiseStrength("Star Noise Strength", Range(0, 20)) =9
 _StarSpeed("Move Speed", Range(0, 0.1)) = 0.01
        [Header(Aurora)]
        _AurorasStrength("Auroras Strength", Range(0, 30)) = 8
        _AuroraTilingOffset("Auroras Tiling Offset",Vector) = (4, 0.18, 0, 0)
        _IterNum("Iter Num", Range(0, 150)) = 25
        _Rotate("Rotate Angle", Range(0, 360)) = 60
        _AuroraSpeed("Move Speed", Range(0, 10)) = 0.01
        
        
    } SubShader
    {

        Tags{
            "RenderPipeline" = "UniversalPipeline"
            "QUEUE" = "Background"
            "RenderType" = "Background"
        "PreviewType" = "Skybox"}

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
            
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
            

            TEXTURE2D(_StarTex);
            SAMPLER(sampler_StarTex);

            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            TEXTURE2D(_NoiseTex2);
            SAMPLER(sampler_NoiseTex2);

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            float4 _StarTex_ST;
            float _StarThreshold;
            float _StarNoiseThreshold;
            float _StarNoiseStrength;
  float _StarSpeed ;
            

            float _AurorasStrength;
            float4 _AuroraTilingOffset;
            float _Rotate  ;
            float _AuroraSpeed ;
            float _IterNum;
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
                float4 positionOS : TEXCOORD4;
            };

            Varyings vert(Attributes i)
            {
                Varyings o;
                o.positionHCS = TransformObjectToHClip(i.positionOS.xyz);
                o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
                o.positionSS = ComputeScreenPos(o.positionHCS);
                o.normal = TransformObjectToWorldNormal(i.normal);
                o.uv = i.uv;
                o.positionOS = i.positionOS;
                return o;
            }

            // 2d旋转矩阵
            float2x2 clockwiseRotate(float a)
            {
                float c = cos(a), s = sin(a);
                return float2x2(c, s, -s, c);
            }          
            
            float2x2 counterClockRotate(float a)
            {
                float c = cos(a), s = sin(a);
                return float2x2(c, -s, s, c);
            }

            float tri(float x)
            {
                return   abs(frac(x) - 0.5) ;

                // return clamp(abs(frac(x) - 0.5), 0.01, 0.49);
            }

            float2 tri2(float2 p)
            {
                return float2(tri(p.x) + tri(p.y), tri(p.y + tri(p.x)));
            }
            // float hash21(float2 n){
                //     return frac(sin(dot(n, float2(12.9898, 4.1414))) * 43758.5453);
            // }

            float toRadiant(float angle){
                return angle /180 * PI;
            }

            float triNoise2d(float2 p)
            {
                //  float2x2 m2 = float2x2(0.95534, 0.29552, -0.29552, 0.95534);
                float2x2 m2 = clockwiseRotate(toRadiant(90));

                float z = 1.8;
                // 弯曲度
                float z2 = 2.5;
                float rz = 0.0;
                // float _Rotate = 60;
                // float _AuroraSpeed = 0.01;
                p = mul(clockwiseRotate(toRadiant(_Rotate)), p);
                float2 bp = p;
                for (float i = 0.; i < 15 ; i++)
                {
                    float2 dg = tri2(bp * 1.85) * .75;
                    dg = mul( clockwiseRotate(toRadiant(_Time.y  * _AuroraSpeed)), dg);
                    p -= dg / z2;

                    bp *= 1.3;
                    z2 *= 0.45;
                    // 震幅减少
                    z *= 0.42;
                    p *= 1.21 + (rz - 1.0) * 0.02;

                    // xz平面
                    rz += tri(p.x + tri(p.y)) * z;
                    p = mul( -m2,p);
                }
                return clamp(1. / pow(rz * 29., 1.1), 0., .55);
            }

            float4 RayMarching(float3 ro, float3 rd)
            {
                float dis = 0;

                float3 scatteredLight = 0;
                float transmittance = 1;

                

                float4 col = 0;
                float4 avgCol = 0;

                
                for (float i = 0; i < _IterNum; ++i)
                {

                    // 平铺
                    float pt = ((0.8 + pow(i, 1.4) * 0.002)) / (rd.y * _AuroraTilingOffset.x + _AuroraTilingOffset.y  ); // 密度
                    
                    float3 pos = ro + pt * rd;
                    float2 p = pos.zx;
                    float rzt = triNoise2d(p);
                    float4 col2 = float4(0, 0, 0, rzt);
                    // r--, g++, b--
                    // 2.15, -.5, 0.8
                    col2.rgb = (sin(1.0 - float3(3.15, -0.5, -0.3) + i * 0.043) * 0.5 + 0.5) * rzt;
                    avgCol = lerp(avgCol, col2, 0.65);
                    col += avgCol * pow(2, -i * 0.065 - 2.5) ;//* smoothstep(0., 5., i);

                    //  col *= saturate(rd.y * 15. + .4);
                }

                col.rgb *= _AurorasStrength;

                return col;

            }
            

            
            float4 renderStar(float3 v, float3 pos)
            {
                if (v.y < 0)
                return 0;
                
                // n<0, 接近0时增长快
                float fade = pow(v.y, 0.099);
                // fade = 1;
                
                // float fade = saturate(1 - 3 * (_MainLightPosition.y));
                
               
                float2 move = float2(_Time.y * _StarSpeed, 0);
                
                float2 uv2 = pos.xz  + move;                
                float2 uv = v.xz / v.y  + move;

                uv *= _StarTex_ST.xy;

                float4 starColor = 1 - SAMPLE_TEXTURE2D(_StarTex, sampler_StarTex, uv);
                
                // 超过一定阈值保留
                
                starColor *= step(_StarThreshold, starColor.r) * fade;
                // starColor = pow(starColor, 2);

                float noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, uv  ).r;
                float4 noiseColor = SAMPLE_TEXTURE2D(_NoiseTex2, sampler_NoiseTex2, uv2);
                
                // float4 noiseColor2 = SAMPLE_TEXTURE2D(_NoiseTex2, sampler_NoiseTex2, uv2);
                // starColor  +=  step(0.78, noise) * noiseColor2  * _StarNoiseStrength; 

                //  return starColor;    
                noise = step(_StarNoiseThreshold, noise);
                
                
                
                starColor  +=  step(_StarNoiseThreshold, noise) * noiseColor  * _StarNoiseStrength; 
                
                return starColor ;
                
            }
            

            float4 frag(Varyings i) : SV_Target
            {
                float3 ro = 0;
                float3 rd = normalize(i.positionOS - ro);

                //////////////////////////////////////////////////////////////////////////////////////////

                float3 v = normalize(i.positionOS.xyz);

                float2 uv = float2(1 - (i.positionOS.y * 0.5 + 0.5), 0.5);
                float4 skyColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                float4 starColor =  renderStar(v, i.positionOS);

                

                skyColor += starColor;

                
                float4 aurorasColor =  RayMarching(_WorldSpaceCameraPos, rd);

                return aurorasColor * aurorasColor.a + (1 - aurorasColor.a) * skyColor;

                
            }
            ENDHLSL
        }
    }
}