Shader "Custom/Volumetric Cloud with Atmosphere Model"
{
    Properties{
        [Header(Shape)]
        [NoScaleOffset]_NoiseTex("Texture 3d", 3d) = "" {} 
        [NoScaleOffset]_WeatherTex("Weather texture ", 2d) = "" {} 
        _Cloud_Height_Strength("Cloud Height", range(50, 300)) = 100

        [Header(Rendering)]
        _SigmaS("Scattering Coefficient", color) = (1, 1, 1, 1)
        _SigmaA("Absorption Coefficient", color) = (0, 0, 0, 0)
        _SigmaE_Strength("*extinction coefficient ", range(1, 20)) =1
        _PhaseParameter("Phase Parameter", range(-1,1)) = 1
        _Density_UVStrength("Density UVStrength", range(0.0001, 10)) = 1 
        _UVScale("UVScale", range(0.001, 0.1)) = 0.05 

        [Header(Coverage)]
        _Start_Height("Cloud Start Height",float) = 1000
        _End_Height("Cloud End Height",float) = 2000
        _Weather_UVScale("Weather UV Scale", range(0.01, 300)) = 1

        _Max_Iter("Max Iter Num",range(8,256)) = 32
        _LightIterNum("Light Iteration Num", range(0, 128)) = 4
        

        [NoScaleOffset]_StepNoiseTex("Step Noise Tex", 2d) = "White" {}
    } SubShader
    {

        Tags{
            "Queue" = "Transparent"
        "RenderPipeline" = "UniversalPipeline"}

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

            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);

            TEXTURE3D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            TEXTURE2D(_WeatherTex);
            SAMPLER(sampler_WeatherTex);
            

            TEXTURE2D(_StepNoiseTex);
            SAMPLER(sampler_StepNoiseTex);

            float4 _SigmaS;
            float4 _SigmaA;

            float _SigmaE_Strength;
            
            #define _SigmaE ((_SigmaS+_SigmaA)/_SigmaE_Strength)

            
            float _Density_UVStrength;
            float _UVScale;
            float _Weather_UVScale;

            
            
            float _Start_Height;
            float _End_Height;
            float3 _Start_Pos;
            float3 _End_Pos;
            
            float EarthRadius;
            float AtmosRadius;
            float _PhaseParameter;
            
            float3 EarthCenter;

            float _Cloud_Height_Strength ;
            float _Sun_Height ;
            float _Sun_Intensity;
            float _Max_Iter;
            float _LightIterNum;

            float4x4 _CamtoWorld;

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
            };

            Varyings vert(Attributes i)
            {
                Varyings o;
                o.positionHCS = TransformObjectToHClip(i.positionOS.xyz);
                o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
                o.positionSS = ComputeScreenPos(o.positionHCS);
                o.normal = TransformObjectToWorldNormal(i.normal);
                o.uv = i.uv;
                return o;
            }

            


            float getDensity(float3 pos)
            {
                //float noise = hash(_Time.y * 10)*0.1;
                float noise= 0;// hash(pos.x +_Time.y * 10)  ;
                float2 uv = pos.xz /25 + noise;
                // uv[0]=remap(float2(_Start_Pos.x, _End_Pos.x), float2(0,1), pos.x);
                // uv[1]=remap(float2(_Start_Pos.z, _End_Pos.z), float2(0,1), pos.z);

                // uv+= float2(_Time.y, 0)*10;
                //float4 weather = SAMPLE_TEXTURE2D_LOD(_WeatherTex, sampler_WeatherTex, (uv+_Time.y) / _Weather_UVScale, 0);
                float4 weather = SAMPLE_TEXTURE2D_LOD(_WeatherTex, sampler_WeatherTex, (uv) / _Weather_UVScale, 0);

                // coverage, height, altitude
                float density = weather.r;


                float real_Height = weather.g * _Cloud_Height_Strength;
                float start_altitude = _Start_Height + weather.b * (_End_Height - _Start_Height);
                float end_altitude = start_altitude + real_Height;
                float current_height = distance(pos, EarthCenter) - EarthRadius;

                // 映射回(0,1)
                // 一元二次方程(x-x1)(x-x2), 最大值-(x2-x1)^2/4
                float x = remap(float2(_Start_Pos.y, _End_Pos.y), float2(0, 1), current_height);
                float x2 = remap(float2(_Start_Height, _End_Height), float2(0, 1), end_altitude);
                float x1 = weather.b;

                density *= (x - x1) * (x - x2) * (-4 / ((x2 - x1) * (x2 - x1)));

                //  cloud shape，采样3d纹理
                // 边缘_Density_UVStrength较大，云朵形状更细碎
                density *= pow(SAMPLE_TEXTURE3D_LOD(_NoiseTex, sampler_NoiseTex, pos * _UVScale, 0).r, _Density_UVStrength);

                //  height gradient
                // float height = (pow((current_height - _Start_Height), 0.50));
                // density *= height;
                return saturate(density);                

            }

            // Henyey-Greenstein散射
            float phaseFunction(float c)
            {
                // return 1;
                float g =  _PhaseParameter;
                return (1 - g * g) / (4 * PI * pow((1 + g * g - 2 * g * c), 1.5));
                
            }

            float3 getShadow(float3 pos){
                float3 lightDir = normalize( GetMainLight().direction); 
                
                
                float dd = distance(_End_Pos, pos) / _LightIterNum;

                float3 ro = pos;
                float3 rd = lightDir;
                float dis = 0;

                float shadow = 1; 
                float density = 0;

                for (int i = 0; i < _LightIterNum; ++i)
                {
                    pos = ro + dis * rd;
                    dis += dd;
                    
                    density = getDensity(pos);         
                    
                    if(density>0)
                    {
                        shadow *= exp(-dd * _SigmaE * density);
                    }
                    
                }
                return shadow;
            }
            
            

            float4 RayMarching(float3 ro, float3 rd)
            {
                float  ini_dd = (distance(_Start_Pos, _End_Pos)) / _Max_Iter;
                float dis = 0;

                float density = 0;
                float3 scatteredLight = 0;
                float transmittance = 1;

                float3 albedo = _SigmaS / (_SigmaS + _SigmaA);
                Light light = GetMainLight();
                float3 lightDir = normalize(light.direction); 
                float3 viewDir =0 ;
                
                float3 env = _GlossyEnvironmentColor;
                float3 pos = 0;
                float  dd = 0;
                float noise = 1;

                for (float i = 0; i < _Max_Iter; ++i)
                {

                    if (transmittance <= 0.01)
                    break;

                    // 随机步长
                    // float  dd = ini_dd  + 50 * hash(_Time.y + pos.x);
                    noise =   SAMPLE_TEXTURE2D_LOD(_StepNoiseTex, sampler_StepNoiseTex, pos.xz, 0);
                    
                    dd = ini_dd  * noise;

                    pos = ro + dis * rd;
                    dis += dd;

                    density = getDensity(pos);
                    
                    if (density >  0.0)
                    { 
                        // 环境光随海拔增加而线性增加
                        viewDir = normalize(_WorldSpaceCameraPos - pos);
                        scatteredLight +=  env  * _SigmaS * transmittance * density;
                        
                        // float3 ambient = float3(92, 156, 199)/255.0;
                        // ambient = ambient * remap(float2(abs(_Start_Pos.y), abs(_End_Pos.y)), float2(0,1), abs(pos.y));
                        scatteredLight += transmittance * density * dd  * phaseFunction(dot(lightDir,viewDir)) * getShadow(pos) * light.color * _SigmaS ;//+ ambient*_SigmaS;
                        
                        transmittance *= exp(-dd * density * _SigmaE);
                    }
                    
                }
                
                
                
                return float4( scatteredLight, 1- transmittance);

            }

            // 射线P+t*d,t标量，P起点,d方向
            // c圆心,R半径
            // 联立解方程
            float2 getRaySphereIntersect(float3 P, float3 d, float R)
            {
                
                float3 C = EarthCenter;

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

            
            void getRayStartandEndLength(out float start, out float end, float3 ro, float3 rd)
            {
                float2 startPos = getRaySphereIntersect( ro, rd, _Start_Height + EarthRadius);
                float2 endPos = getRaySphereIntersect(ro, rd, _End_Height + EarthRadius);

                // 云层之下
                // x < y
                if (_WorldSpaceCameraPos.y < _Start_Height)
                {
                    start = startPos.y;
                    end = endPos.y;
                }
                // 云层之中
                else if (_WorldSpaceCameraPos.y >= _Start_Height && _WorldSpaceCameraPos.y < _End_Height)
                {
                    start = 0;
                    if(startPos.x > 0)
                    end = startPos.x;
                    else
                    end = endPos.y;
                }
                // 云层之上
                else
                {
                    start = endPos.x;
                    if(startPos.x > 0)
                    end = startPos.x;
                    else
                    end = endPos.y;

                }
            }

            
            
            half4 frag(Varyings i) : SV_Target
            {
                //return 1;
                EarthRadius = 6371e2;
                EarthCenter =_WorldSpaceCameraPos - float3(0, 1, 0) * (EarthRadius + _WorldSpaceCameraPos.y);
                
                // test
                //  EarthCenter =_WorldSpaceCameraPos - _WorldSpaceCameraPos * (EarthRadius );
                
                float linearDepth = LinearEyeDepth(SampleSceneDepth(i.uv), _ZBufferParams);
                

                // 校正屏幕长宽比
                float aspect = _ScreenParams.x / _ScreenParams.y;
                float2 screenUV = 2 * i.uv - 1;
                screenUV.y *= 1 / aspect;
                

                clip(linearDepth - _Start_Height);

                float3 ro = _WorldSpaceCameraPos;
                float3 rd = normalize(float3(screenUV, 1));
                // clip(rd.y < 0.5);
                // rd = mul(unity_CameraToWorld, float4(rd, 1)).xyz; 
                rd = mul(getViewToWorldMatrix(), float4(rd, 1)).xyz;                 
                //rd = mul(_CamtoWorld, float4(rd, 1)).xyz;

                float start = 0;
                float end = 0;
                getRayStartandEndLength(start, end, ro, rd);

                
                clip(start);
                clip(end);

                _Start_Pos = ro + rd * start;
                _End_Pos = ro + rd * end;

                clip(_Start_Pos.y); 
                
                
                float4 ray = RayMarching(_Start_Pos, rd);

                return ray;
            }
            ENDHLSL
        }
    }
}