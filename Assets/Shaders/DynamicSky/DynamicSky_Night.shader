Shader "Custom/ Auroras"
{
    Properties{
        [NoScaleOffset] _MainTex("Gradient Sky", 2D) = "white" {} _StarTex("Star", 2D) = "white" {} _NoiseTex("Star Noise", 2D) = "" {} _AurorasStrength("Auroras Strength", Range(0, 30)) = 8

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
            //  ZTest on
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            // debug
            #define BABYBLUE float4(0, 1, 1, 1)
            #define RED float4(1, 0, 0, 1)

            TEXTURE2D(_StarTex);
            SAMPLER(sampler_StarTex);

            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            float EarthRadius;
            float3 _Start_Pos;
            float3 _End_Pos;
            float3 _Earth_Center;
            float _AurorasStrength;
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
            float2x2 mm2(float a)
            {
                float c = cos(a), s = sin(a);
                return float2x2(c, s, -s, c);
            }

            float tri(float x)
            {
                return clamp(abs(frac(x) - 0.5), 0.01, 0.49);
            }

            float2 tri2(float2 p)
            {
                return float2(tri(p.x) + tri(p.y), tri(p.y + tri(p.x)));
            }
            // float hash21(float2 n){
                //     return frac(sin(dot(n, float2(12.9898, 4.1414))) * 43758.5453);
            // }

            float triNoise2d(float2 p, float spd)
            {
                float2x2 m2 = float2x2(0.95534, 0.29552, -0.29552, 0.95534);

                float z = 1.8;
                float z2 = 2.5;
                float rz = 0.;
                p = mul(mm2(p.x * 0.06), p);
                float2 bp = p;
                for (float i = 0.; i < 5.; i++)
                {
                    float2 dg = tri2(bp * 1.85) * .75;
                    // dg *= mm2(time*spd);
                    p -= dg / z2;

                    bp *= 1.3;
                    z2 *= .45;
                    z *= .42;
                    p *= 1.21 + (rz - 1.0) * .02;

                    rz += tri(p.x + tri(p.y)) * z;
                    // p = mul( -m2,p);
                }
                return clamp(1. / pow(rz * 29., 1.3), 0., .55);
            }

            float4 RayMarching(float3 ro, float3 rd)
            {
                // float dd = (distance(_Start_Pos, _End_Pos)) / _Max_Iter;
                float dis = 0;

                float3 scatteredLight = 0;
                float transmittance = 1;

                Light light = GetMainLight();
                float3 lightDir = normalize(light.direction);
                float3 viewDir = 0;

                float4 col = float4(0, 0, 0, 0);
                float4 avgCol = float4(0, 0, 0, 0);
                ;
                for (float i = 0; i < 50; ++i)
                {

                    // if (transmittance <= 0.01)
                    // break;

                    // float3 pos = ro + dis * rd;
                    //  dis += dd;

                    // float of =0.;// 0.006*hash21(gl_FragCoord.xy)*smoothstep(0.,15., i);
                    // ?累积距离
                    float pt = ((0.8 + pow(i, 1.4) * 0.002)) / (rd.y * 4.0 + 0.5); // 密度
                    // pt -= of;
                    // pt =0.5;
                    float3 pos = ro + pt * rd;
                    float2 p = pos.zx;
                    float rzt = triNoise2d(p, 0.36);
                    float4 col2 = float4(0, 0, 0, rzt);
                    // r--, g++, b--
                    col2.rgb = (sin(1. - float3(2.15, -.5, 0.8) + i * 0.043) * 0.5 + 0.5) * rzt;
                    avgCol = lerp(avgCol, col2, 0.5);
                    col += avgCol * pow(2, -i * 0.065 - 2.5) * smoothstep(0., 5., i);

                    col *= saturate(rd.y * 15. + .4);
                }
                col.rgb *= _AurorasStrength;
                return col;

                // return float4( scatteredLight.x, scatteredLight.y, scatteredLight.z, 1- transmittance);
            }
            float2 getRaySphereIntersect(float3 P, float3 d, float R)
            {
                // circle center
                float3 C = _Earth_Center;

                float a = dot(d, d);
                float b = 2 * dot(d, P - C);
                float c = dot(P - C, P - C) - R * R;
                float delta = b * b - 4 * a * c;
                if (delta < 0)
                return float2(-1, -1);
                float x1 = (-b - sqrt(delta)) / (2 * a);
                float x2 = (-b + sqrt(delta)) / (2 * a);
                return float2(x1, x2);
            }

            float4 renderStar(float3 v)
            {
                if (v.y < 0)
                return 0;
                float intensity = 4;
                intensity = lerp(0, 2, pow(v.y, 0.9));
                float fade = saturate(1 - 3 * (_MainLightPosition.y));
                // v.y = 1 - ( 0.5 * v.y + 0.5);
                // float2 uv = (v.xz*12);// *(v.y+1);
                // float2 uv = (v.xz*12);// *(v.y+1);
                float _Star_Scale = 0.45;
                float speed = 0.01;
                float2 uv = v.xz / v.y * _Star_Scale + _Time.y * speed;
                float4 starColor = 1 - SAMPLE_TEXTURE2D(_StarTex, sampler_StarTex, uv);

                // return starColor ;

                float noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, uv).r;

                starColor *= step(0.9, starColor.r);

                starColor *= step(0.6, noise) * 1;
                // return starColor * fade;
                return pow(starColor, intensity);
            }

            float4 frag(Varyings i) : SV_Target
            {
                // EarthRadius = 6360e3;
                //_Earth_Center = float3(0, 0, 0) - float3(0, 1, 0) * (EarthRadius);

                float3 ro = 0;
                float3 rd = normalize(i.positionOS - ro);

                //////////////////////////////////////////////////////////////////////////////////////////

                float3 v = normalize(i.positionOS.xyz);

                float2 uv = float2(1 - (i.positionOS.y * 0.5 + 0.5), 0.5);
                float4 skyColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                float4 starColor = renderStar(v);

                // float4 skyColor = 0;

                skyColor += starColor;
                float4 aurorasColor = RayMarching(_WorldSpaceCameraPos, rd);
                return aurorasColor * aurorasColor.a + (1 - aurorasColor.a) * skyColor;

                return skyColor + skyColor.a * (starColor); //+float4(0.5,0.2,0.2,1);
            }
            ENDHLSL
        }
    }
}