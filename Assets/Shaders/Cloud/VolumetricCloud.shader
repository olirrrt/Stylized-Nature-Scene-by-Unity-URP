Shader "Costumn/Simplest Ray Marching Cloud"
{
    Properties{
        [MainColor] _BaseColor("base color", color) = (1, 1, 1, 1)
        _NoiseTex("texture 3d", 3d) = "" {} _WeatherTex("Weather texture ", 2d) = "" {}

        _SigmaS("scattering coefficient", color) = (1, 1, 1, 1)
        _SigmaA("absorption coefficient", color) = (0, 0, 0, 0)
        _maxIterNum("Max Iteration Num", range(0, 1000)) = 1000 _Light_maxIterNum("Light Max Iteration Num", range(0, 1000)) = 4

    }

    SubShader
    {

        Tags{
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        ENDHLSL

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            // Blend one zero

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            float4 _BaseColor;
            float4 _bbox_Min;
            float4 _bbox_Max;
            float _UVScale;
            float4x4 _WorldToCubeMat;
            float _Step;
            float _Density_Strength;

            float _maxIterNum, _Light_maxIterNum;

            float4 _SigmaS;
            float4 _SigmaA;

            float4 weather;
            float2 _Weather_UVScale;

            //#define _SigmaT 12
            #define _SigmaT (25 * _SigmaS + 0 * _SigmaA)

            TEXTURE3D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);

            TEXTURE2D(_WeatherTex);
            SAMPLER(sampler_WeatherTex);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normal : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float4 positionSS : TEXCOORD2;
            };

            Varyings vert(Attributes i)
            {
                Varyings o;
                o.positionHCS = TransformObjectToHClip(i.positionOS.xyz);
                o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
                o.positionSS = ComputeScreenPos(o.positionHCS);
                o.normal = TransformObjectToWorldNormal(i.normal);
                return o;
            }

            // aabb包围盒
            // 转到cube空间算距离
            bool inBox(float3 org, float3 dir, out float near, out float far)
            {
                // compute intersection of ray with all six bbox planes
                float3 invR = 1.0 / dir;
                float3 tbot = invR * (_bbox_Min.xyz - org);
                float3 ttop = invR * (_bbox_Max.xyz - org);

                // re-order intersections to find smallest and largest on each axis
                float3 tmin = min(ttop, tbot);
                float3 tmax = max(ttop, tbot);

                // find the largest tmin and the smallest tmax
                float2 t0 = max(tmin.xx, tmin.yz);
                near = max(t0.x, t0.y);
                t0 = min(tmax.xx, tmax.yz);
                far = min(t0.x, t0.y);

                // check for hit
                // t_enter < t_exit && t_exit >= 0
                return near < far && far > 0.0;
            }

            // 瑞利散射
            float phaseFunction()
            {
                return 1.0;
                // return 3.0 / (16.0 * PI)*(1+cos);
            }
            float4 color_backGround;

            // 向光源步进，需要步进的是体积阴影
            float3 getScatteredLight(float3 pos)
            {
                #define dd _Step

                Light light = GetMainLight();
                // 平行光的近似位置
                float3 lightPos = _MainLightPosition * 12;
                float3 L = lightPos - pos;

                #define MAX_ITER min(_Light_maxIterNum, length(L) / dd)

                float3 ro = pos;
                float3 rd = normalize(L);

                float dis = 0;
                float4 positionL = TransformWorldToShadowCoord(pos);
                float shadow = 1; // SAMPLE_TEXTURE2D_SHADOW(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture, positionL.xyz);
                float density = 0;
                // volshadow
                for (int i = 0; i < MAX_ITER; ++i)
                {
                    pos = ro + dis * rd;
                    dis += dd;
                    density = pow(SAMPLE_TEXTURE3D_LOD(_NoiseTex, sampler_NoiseTex, pos * _UVScale, 0).r, _Density_Strength);

                    shadow *= exp(-dd * _SigmaT * density);
                }

                return phaseFunction() * shadow * light.color * 1.0 / (dot(L, L));
            }

            // _bbox_Min相对于中心的距离
            float4 RayMarching(float3 ro, float3 rd)
            {
                float4 _Tint = float4(1, 1, 1, 0);

                float near = 0;
                float far = 0;

                float density = 0;
                float3 scatteredLight = 0;
                float transmittance = 1;

                Light light = GetMainLight();

                // 和包围盒求交点，求出起始点
                // 是则采样密度、累加距离
                if (inBox(ro, rd, near, far))
                {
                    float dis = near;
                    #define dd _Step
                    #define MAX_ITER min(1000, (far - near) / dd)

                    for (float i = 0; i < MAX_ITER; ++i)
                    {
                        float3 pos = ro + dis * rd;
                        dis += dd;
                        // ？采样时模糊减轻走样
                        // ?不lod会报错循环超1024 unable to unroll loop
                        density = pow(SAMPLE_TEXTURE3D_LOD(_NoiseTex, sampler_NoiseTex, pos * _UVScale, 0).r, _Density_Strength);
                        weather = SAMPLE_TEXTURE2D_LOD(_WeatherTex, sampler_WeatherTex, pos.xz / 22, 0);
                        density *= weather.r;
                        density *= weather.g;
                        float height = (pow(abs(pos.y - 3) / (3), 5));
                        density *= height;
                        if (density > 0.0)
                        {

                            scatteredLight += transmittance * dd * getScatteredLight(pos) * _SigmaS;

                            transmittance *= exp(-dd * density * _SigmaT);
                        }
                    }
                }

                float3 color = color_backGround * transmittance + scatteredLight;
                color = pow(color, 1.0 / 2.2);
                return float4(color, 1 - transmittance);

                // return float4(scatteredLight,  transmittance);
            }

            half4 frag(Varyings i) : SV_Target
            {

                float2 screenUV = i.positionSS.xy / i.positionSS.w;

                float3 viewDir = normalize(_WorldSpaceCameraPos - i.positionWS);

                // https://docs.unity3d.com/Manual/SL-UnityShaderVariables.html

                float3 ro = mul(_WorldToCubeMat, float4(_WorldSpaceCameraPos, 1)).xyz;
                float3 rd = normalize(i.positionWS - _WorldSpaceCameraPos);
                color_backGround = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenUV);

                float4 color = RayMarching(ro, rd);

                return color;
            }
            ENDHLSL
        }
    }
}
