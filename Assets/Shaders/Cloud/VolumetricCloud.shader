Shader "Custom/Box Volumetric Cloud"
{
    Properties
    {
        // [MainColor] _BaseColor("Tint", color) = (1, 1, 1, 1)
        _NoiseTex("Texture 3d", 3d) = "" {}

        _UVScale("UV Scale", Range(0, 0.01)) = 0.006

        _Density_Strength("Density Strength", Range(0, 50)) = 1 _Erode_Strength(" Erode Strength", Range(0.01, 50)) = 1

        [Header(Rendering)] _SigmaS("Scattering Coefficient", color) = (1, 1, 1, 1)
        _SigmaA("Absorption Coefficient", color) = (0, 0, 0, 0)
        _SigmaE_Strength("*extinction coefficient ", range(1, 20)) = 1
        _PhaseParameter("Phase Parameter", range(-1,1)) = 1

        [Header(Coverage)] _WeatherTex("Weather Texture ", 2d) = "white"{}
        _Height_Strength("Height Strength", Range(1, 25)) = 4

        _IterNum("Iteration Num", range(0, 512)) = 8 _LightIterNum("Light Iteration Num", range(0, 128)) = 4
        [NoScaleOffset] _StepNoiseTex("Step Noise Tex", 2d) = "White"{}
    }

    SubShader
    {

        Tags{
            "Queue" = "Transparent"
        "RenderPipeline" = "UniversalPipeline"}

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        ENDHLSL

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            float4 _BaseColor;
            float4 _bbox_Min;
            float4 _bbox_Max;
            float4 _Transform;
            // float4x4 _WorldToCubeMat;

            float boxHMin;
            float boxHMax;

            float _UVScale;
            float _Density_Strength;

            float _IterNum;
            float _LightIterNum;

            float4 _SigmaS;
            float4 _SigmaA;

            float _SigmaE_Strength;

            #define _SigmaE ((_SigmaS + _SigmaA) / _SigmaE_Strength)

            float4 weather;
            float2 _Weather_UVScale;
            float _Erode_Strength;
            float _Height_Strength;
            float _PhaseParameter;
            TEXTURE3D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            float4 _WeatherTex_ST;
            TEXTURE2D(_WeatherTex);
            SAMPLER(sampler_WeatherTex);
            TEXTURE2D(_StepNoiseTex);
            SAMPLER(sampler_StepNoiseTex);

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
                half fogFactor : TEXCOORD4;
            };

            Varyings vert(Attributes i)
            {
                Varyings o;
                o.positionHCS = TransformObjectToHClip(i.positionOS.xyz);
                o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
                o.positionSS = ComputeScreenPos(o.positionHCS);
                o.normal = TransformObjectToWorldNormal(i.normal);
                o.fogFactor = ComputeFogFactor(o.positionHCS.z);
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

            float phaseFunction(float c)
            {
                // return 1;
                float g = _PhaseParameter;
                return (1 - g * g) / (4 * PI * pow((1 + g * g - 2 * g * c), 1.5));
            }
            
            float getHeight(float3 pos)
            {
                // float height = (pow(abs(pos.y - _Transform.y) / ( _Transform.y), 5));

                float h1 = boxHMin;
                float h2 = boxHMax;
                float height = (pos.y - h1) * (pos.y - h2) / (-_Transform.y * _Transform.y / 4);
                 height = pow(height, _Height_Strength);

               // height *= (pow(abs(pos.y - _Transform.y) / (_Transform.y), 1 ));

                return height;
            }

            float getDensity(float3 pos)
            {
                // float density = pow(SAMPLE_TEXTURE3D_LOD(_NoiseTex, sampler_NoiseTex, pos * _UVScale, 0).r, _Density_Strength);
                float density = SAMPLE_TEXTURE3D_LOD(_NoiseTex, sampler_NoiseTex, pos * _UVScale, 0).r * _Density_Strength;

                 pos.xz += float2( -_Time.y ,  0  )* 0.5;
                weather = SAMPLE_TEXTURE2D_LOD(_WeatherTex, sampler_WeatherTex, pos.xz * _WeatherTex_ST.xy + _WeatherTex_ST.zw, 0);
                density *= weather.r;

                density *= getHeight(pos);
                density = pow(density, _Erode_Strength);

                return density;
            }

            // 向光源步进，需要步进的是体积阴影
            float3 getShadow(float3 pos)
            {

                Light light = GetMainLight(TransformWorldToShadowCoord(pos));
                float dd_in = 5; //    (distance(_bbox_Max, _bbox_Min)) / _LightIterNum;
                float dd_out = 20;
                float dd = 0;

                float3 ro = pos;
                float3 rd = normalize(light.direction);

                float dis = dd_in;

                float3 shadow = 1; // SAMPLE_TEXTURE2D_SHADOW(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture, positionL.xyz);
                float density = 0;

                
                // volshadow
                for (int i = 0; i < _LightIterNum; ++i)
                {
                    pos = ro + dis * rd;

                    // 在包围盒之外
                    // 包围盒之内调整步长
                    if (pos.y > boxHMax)
                    {
                        break;
                        // dd = dd_out;
                        // density = 10;
                    }
                    else
                    {
                        dd = dd_in;
                        density = getDensity(pos);
                    }

                    dis += dd;

                    if (density > 0.0)
                    {
                        shadow *= exp(-dd * _SigmaE * density);
                    }
                }

                return shadow; // pow(shadow,999);//0.99;//* light.shadowAttenuation;
            }

            // _bbox_Min相对于中心的距离
            float4 RayMarching(float3 ro, float3 rd)
            {

                float near = 0;
                float far = 0;
                // (worldPos_y, scale_y)

                float density = 0;
                float3 scatteredLight = 0;
                float transmittance = 1;
                float3 env = _GlossyEnvironmentColor;
                
                Light light = GetMainLight();
                float3 lightDir = normalize(light.direction);
                float3 viewDir = 0;

                float3 pos;

                // 和包围盒求交点，求出起始点
                // 是则采样密度、累加距离
                if (inBox(ro, rd, near, far))
                {
                    float dis = near;

                    float ini_dd = (far - near) / _IterNum;
                    float noise = 0;
                    float dd = 0;
                    for (float i = 0; i < _IterNum; ++i)
                    {
                        if (transmittance < 0.01)
                        break;

                        noise = SAMPLE_TEXTURE2D_LOD(_StepNoiseTex, sampler_StepNoiseTex, pos.xz, 0);
                        dd = ini_dd * noise;

                        pos = ro + dis * rd;
                        dis += dd;

                        density = getDensity(pos);
                        if (density > 0.0)
                        {
                            
                            scatteredLight += env * _SigmaS * transmittance * density;
                            
                            scatteredLight += phaseFunction(dot(lightDir, viewDir)) * light.color * (transmittance)*dd * getShadow(pos) * _SigmaS * density;
                            
                            transmittance *= exp(-dd * density * _SigmaE);
                        }
                    }
                }

                return float4(scatteredLight, 1 - transmittance);
            }

            half4 frag(Varyings i) : SV_Target
            {

                boxHMin = _Transform.x - _Transform.y * 0.5;
                boxHMax = _Transform.x + _Transform.y * 0.5;

                // float3 viewDir = normalize(_WorldSpaceCameraPos - i.positionWS);

                //  float3 ro = mul(_WorldToCubeMat, float4(_WorldSpaceCameraPos, 1)).xyz;
                float3 ro = _WorldSpaceCameraPos;
                float3 rd = normalize(i.positionWS - _WorldSpaceCameraPos);

                float4 color = RayMarching(ro, rd);
                color.rgb = MixFog(color.rgb, i.fogFactor);
                return color;
            }
            ENDHLSL
        }
    }
}
