Shader "Costumn/ Auroras"
{
    Properties{
        _NoiseTex("texture 3d", 3d) = "" {} _WeatherTex("Weather texture ", 2d) = "" {} 
        _Cloud_Height_Strength("Cloud Height", range(50, 300)) = 100
        _SigmaS("scattering coefficient", color) = (1, 1, 1, 1)
        _SigmaA("absorption coefficient", color) = (0, 0, 0, 0)
        _SigmaT_Strength("*extinction coefficient ", range(1, 50)) =1
        _Density_UVStrength("_Density_UVStrength", range(0.0001, 10)) = 1 
        _UVScale("_UVScale", range(0.001, 0.1)) = 0.05 
        _Weather_UVScale("Weather UV Scale", range(0.01, 150)) = 1
        _Max_Iter("Max Iter Num",range(8,256)) = 32

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

            float4 _SigmaS;
            float4 _SigmaA;

            float _SigmaT_Strength;
            
            #define _SigmaT ((_SigmaS+_SigmaA)/_SigmaT_Strength)

            
            float _Density_UVStrength;
            float _UVScale;
            float _Weather_UVScale;

            float4 color_bg;
            
            float _Start_Height;
            float _End_Height;
            float3 _Start_Pos;
            float3 _End_Pos;
            #define EarthRadius 6000e3
            float3 _Earth_Center;
            float _Cloud_Height_Strength ;
            float _Sun_Height ;
            float _Sun_Intensity;
            float _Max_Iter;

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

   

          
            float2x2 mm2(float a){
                float c = cos(a), s = sin(a);
                return float2x2(c,s,-s,c);
            }
            
            float tri(float x){
                return clamp(abs(frac(x)-0.5),0.01,0.49);
            }

            float2 tri2(float2 p){
                return float2(tri(p.x)+tri(p.y),tri(p.y+tri(p.x)));
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
                for (float i=0.; i<5.; i++ )
                {
                    float2 dg = tri2(bp*1.85)*.75;
                    //dg *= mm2(time*spd);
                    p -= dg/z2;

                    bp *= 1.3;
                    z2 *= .45;
                    z *= .42;
                    p *= 1.21 + (rz-1.0)*.02;
                    
                    rz += tri(p.x+tri(p.y))*z;
                    //p = mul( -m2,p);
                }
                return clamp(1./pow(rz*29., 1.3),0.,.55);
            }

            float4 RayMarching(float3 ro, float3 rd)
            {
                float dd = (distance(_Start_Pos, _End_Pos)) / _Max_Iter;
                float dis = 0;

                float density = 0;
                float3 scatteredLight = 0;
                float transmittance = 1;

                float3 albedo = _SigmaS / (_SigmaS + _SigmaA);
                Light light = GetMainLight();
                float3 lightDir = normalize(light.direction); 
                float3 viewDir =0 ;

                float4 col = float4(0, 0, 0, 0);
                float4 avgCol = float4(0, 0, 0, 0);;
                for (float i = 0; i < 50; ++i)
                {

                    // if (transmittance <= 0.01)
                    // break;

                   // float3 pos = ro + dis * rd;
                  //  dis += dd;
                    
                    // float of =0.;// 0.006*hash21(gl_FragCoord.xy)*smoothstep(0.,15., i);
                    // ?累积距离
                    float pt = ((0.8 + pow(i,1.4)*0.002)) /(rd.y * 4.0 + 0.5);// 密度
                    // pt -= of;
                    // pt =0.5;
                    float3  pos = ro + pt * rd;
                    float2 p =  pos.zx;
                    float rzt = triNoise2d(p, 0.36);
                    float4 col2 = float4(0,0,0, rzt);
                    col2.rgb = (sin(1.-float3(2.15,-.5, 1.2)+i*0.043)*0.5+0.5)*rzt;
                    avgCol =  lerp(avgCol, col2, 0.5);
                    col += avgCol * pow(2, -i * 0.065 - 2.5) * smoothstep(0.,5., i);
                    
                    
                    
                    col *= saturate(rd.y * 15.+.4);
                    
                }
                col.rgb *= 3;
                return col;

                //return float4( scatteredLight.x, scatteredLight.y, scatteredLight.z, 1- transmittance);

            }

            // 射线P+t*d,t标量，P起点,d方向
            // c圆心,R半径
            // 联立解方程
            float2 getRaySphereIntersect(float R, float3 P, float3 d, float h)
            {
                float3 C = P - float3(0, 1, 0) * (P.y + R);
                _Earth_Center = C;
                R = R + h;
                float a = dot(d, d);
                float b = 2 * dot(d, P - C);
                float c = dot(P - C, P - C) - R * R;
                float delta = b * b - 4 * a * c;
                if(delta < 0) return float2(-1, -1);
                float x1 = (-b - sqrt(delta)) / (2 * a);
                float x2 = (-b + sqrt(delta)) / (2 * a);
                return float2(x1, x2);
            }

             void getRayStartandEndLength(out float start, out float end, float3 ro, float3 rd)
            {
                float2 startPos = getRaySphereIntersect(EarthRadius, ro, rd, _Start_Height);
                float2 endPos = getRaySphereIntersect(EarthRadius, ro, rd, _End_Height);

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
                
                //float linearDepth = LinearEyeDepth(SampleSceneDepth(i.uv), _ZBufferParams);
                color_bg = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, i.uv);

                // 校正屏幕长宽比
                float aspect = _ScreenParams.x / _ScreenParams.y;
                float2 screenUV = 2 * i.uv - 1;
                screenUV.y *= 1 / aspect;

               // _Start_Height = 1000;
               // _End_Height = 3000;

                //clip(linearDepth - _Start_Height);

                float3 ro = _WorldSpaceCameraPos;
                float3 rd = normalize(float3(screenUV, 0.5));
                rd = mul(getViewToWorldMatrix(), float4(rd, 1)).xyz;
               // float start = 0;
               // float end = 0;
                //getRayStartandEndLength(start, end, ro, rd);

                
                //clip(start);
               // clip(end);

                //_Start_Pos = ro + rd * start;
                //_End_Pos = ro + rd * end;

                // clip(_Start_Pos.y); 
                
                
               // float4 ray = RayMarching(_Start_Pos, rd);
                float4 ray = RayMarching(_WorldSpaceCameraPos, rd);

                return ray;
            }
            ENDHLSL
        }
    }
}