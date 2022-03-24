Shader "Costumn/Wave"
{
    Properties{
        [MainColor] _BaseColor("base color", color) = (1, 1, 1, 1)
        _TessellationUniform ("Tessellation Uniform", Range(1, 64)) = 1
        _Steepness("Steepness", Range(0, 5)) = 0.5

        _Wavelength("Wavelength", Range(0, 15)) = 1 _Direction("Direction (2D)", Vector) = (1, 0, 0, 0)

        _WaveA("Wave A (dir, steep, wavelength)", Vector) = (1, 0, 0.5, 10)
        _WaveB("Wave B (dir, steep, wavelength)", Vector) = (1, 0, 0.5, 10)
        _WaveC("Wave C (dir, steep, wavelength)", Vector) = (1, 0, 0.5, 10)

    }

    SubShader
    {
        Tags{
            //"RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"        
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"

        #include "WaterLibrary.hlsl"

        ENDHLSL

        Pass
        {

            HLSLPROGRAM
            #pragma vertex MyTessellationVertexProgram
            #pragma fragment frag
            #pragma hull hull
            #pragma domain domain
            #pragma target 4.6

            float4 _BaseColor;

            float _Wavelength;

            float2 _Direction;
            float _Steepness;

            float4 _WaveA;
            float4 _WaveB;
            float4 _WaveC;


            SAMPLER(sampler_unity_SpecCube0);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD2;
                float4 positionSC : TEXCOORD3;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
            };

            #define PI 3.1415926

            //////////////////////////////////////////////////////////////////////////////////////////////////////
            void DirectWave()
            {
            }

            float3 GerstnerWave(float4 wave, float3 v, inout float3 Tangent, inout float3 Bitangent)
            {

                #define g 9.8

                #define Steepness wave.z
                #define L wave.w

                
                float2 D = normalize(wave.xy)/10.0;
                //CircleWave(D,v.xz,float2(0,0));
                float W = 2 * PI / L;
                float S = sqrt(g / W);
                float A = Steepness / W;

                //+：向内运动，-：向外运动
                float P = W * (dot(D, v.xz) - S * _Time.y);

                // T:对(x+Dxcos(x), y=sin(Dx+Dz),  z+Dzcos(x)) x求导
                Tangent += normalize(float3(1 - D.x * D.x * W * A * sin(P), D.x * W * A * cos(P), 1 - D.x * D.y * sin(P)));
                // B:对z求导
                Bitangent += float3(-D.x * D.y * sin(P), D.y * W * A * cos(P), 1 - D.x * D.x * W * A * sin(P));

                // return normalize(cross(Bitangent, Tangent));
                return float3(A * D.x * cos(P), A * sin(P), A * D.y * cos(P));
            }

            Varyings vert(Attributes i)
            {
                Varyings o;

                float3 Tangent = 0;
                float3 Bitangent = 0;
                i.positionOS.xyz  += GerstnerWave(_WaveA, i.positionOS.xyz, Tangent, Bitangent);
                i.positionOS.xyz  += GerstnerWave(_WaveB, i.positionOS.xyz, Tangent, Bitangent);
                i.positionOS.xyz  += GerstnerWave(_WaveC, i.positionOS.xyz, Tangent, Bitangent);

                float3 normal = normalize(cross(Bitangent, Tangent));
                o.normal =  normal;
                
                /* o.normal=TransformObjectToWorldNormal(i.normal);*/
                o.positionHCS = TransformObjectToHClip(i.positionOS.xyz);
                o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
                o.positionSC = ComputeScreenPos(o.positionHCS);
                o.uv = i.uv;

                return o;
            }

            #include "Tessellation.hlsl"
            
            half4 frag(Varyings i) : SV_Target
            {

                 return float4((i.normal), 1);
                //  float3 viewDir=normalize(_WorldSpaceCameraPos - i.positionWS);
                // float3 lightDir = normalize(GetMainLight().direction - i.positionWS);
                //  return 0.3+ dot(normalize(lightDir+viewDir),normalize(i.normal))+_BaseColor * dot(lightDir, normalize(i.normal)); //+0.3;


                Light light=GetMainLight();
                float3 viewDir=normalize(_WorldSpaceCameraPos - i.positionWS);
                float3 lightDir=normalize(light.direction);
                float3 h=saturate(normalize(viewDir + lightDir));
                float3 ks=Fresnel_Schlick(viewDir, h, WaterF0);
                float3 kd=float3(1, 1, 1)-ks;
                float3 ref=reflect(-viewDir, i.normal);
                float4 env=SAMPLE_TEXTURECUBE(unity_SpecCube0,sampler_unity_SpecCube0,ref);    
                float4 color;

                float2 screenUV=i.positionSC.xy/i.positionSC.w;
                float4 undercolor=SAMPLE_TEXTURE2D(_CameraOpaqueTexture,sampler_CameraOpaqueTexture,screenUV);

                color.rgb=undercolor.rgb*kd+ks*env.rgb+_BaseColor.rgb*0.5;
                color.a=1;
                return color;
            }
            ENDHLSL
        }
    }
}
