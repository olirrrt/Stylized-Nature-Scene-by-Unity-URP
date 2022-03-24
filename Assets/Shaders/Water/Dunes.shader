Shader "Unlit/Dunes"
{
    Properties{
        [MainColor] _BaseColor("base color", color) = (1, 1, 1, 1)
        _StandColor("Stand Color", color) = (1, 1, 1, 1)
        _NoiseMap("Noise Map", 2D) = "" {} 
        _Noisestrength("Noise Strength", Range(0, 1)) = 0.3

        _GlitterColor("Glitter Color", color) = (1, 1, 1, 1)
        _RimColor("Rim Color", color) = (1, 1, 1, 1)
        _SpecularColor("Specular Color", color) = (1, 1, 1, 1)

        _HeightMap("Height Map", 2D) = "" {}
        _TessellationUniform ("Tessellation Uniform", Range(1, 64)) = 1
        _DisplacementStrength("Displacement Strength", Range(0, 10)) = 1
    }

    SubShader
    {

        Tags{
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
        "TerrainCompatible" = "True"} 
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
            float4 _RimColor;
            float4 _SpecularColor;
            float4 _StandColor;
            float _Noisestrength;
            float         _DisplacementStrength;


            TEXTURE2D(_NoiseMap);
            SAMPLER(sampler_NoiseMap);
            float4 _NoiseMap_ST;
            float4 _GlitterColor;
            // (1/x, 1/y, x, y)
            float4 _HeightMap_TexelSize;
            float4 _HeightMap_ST;

            TEXTURE2D(_HeightMap);
            SAMPLER(sampler_HeightMap);
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

            

            
            Varyings vert(Attributes i)
            {
                Varyings o;
                o.uv = TRANSFORM_TEX(i.uv, _HeightMap);
                
                i.positionOS.xyz +=_DisplacementStrength* i.normal * SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, o.uv, 0).r;
                float offset=_HeightMap_TexelSize.x * 0.5;
                offset=0.05;
                float2 du = float2(offset, 0);
                float u1 = SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, i.uv - du,0).r;
                float u2 = SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, i.uv + du,0).r;
                float3 tu =float3 (1, u2 - u1, 0);
                
                float2 dv= float2(0, offset);
                float v1 = SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, i.uv - dv,0).r;
                float v2 = SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, i.uv + dv,0).r;
                float3 tv = float3(0, v2 - v1, 1);
                i.normal = normalize(cross(tv, tu));

                ////////////////////////////////////////////////////////////////////////////////////

                o.positionHCS = TransformObjectToHClip(i.positionOS.xyz);
                o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
                o.positionSC = ComputeScreenPos(o.positionHCS);
                
                //o.normal = normalize(i.normal);

                o.normal = TransformObjectToWorldNormal(i.normal);

                return o;
            }

            #include "Tessellation.hlsl"

            half4 frag(Varyings i) : SV_Target
            {

                Light light = GetMainLight();
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.positionWS);
                float3 lightDir = normalize(light.direction);

                float3 Random = SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, TRANSFORM_TEX(i.uv, _NoiseMap)).rgb * 2 - 1;
                i.normal = lerp(normalize(i.normal), Random, _Noisestrength);
                i.normal = normalize(i.normal);

                #define L lightDir
                #define V viewDir
                #define N i.normal

                float NdotL = saturate(dot(N, L));
                float rim = pow(1 - saturate(dot(N, V)), 2);

                float3 H = saturate(normalize(viewDir + lightDir));
                float NdotH = saturate(dot(N, H));
                float specular = pow(NdotH, 2);
                float3 ks = Fresnel_Schlick(viewDir, H, WaterF0);
                float3 kd = float3(1, 1, 1) - ks;
                float3 Ref = reflect(L, Random);
                float RdotV = saturate(dot(Ref, V));
                //  if(RdotV>0.8)RdotV=1;
                //  float4 env=SAMPLE_TEXTURECUBE(unity_SpecCube0,sampler_unity_SpecCube0,ref);
                float4 color;

                color = max(rim * _RimColor, specular * _SpecularColor) + NdotL * _StandColor + (1 - RdotV) * _GlitterColor;

                return color;
            }
            ENDHLSL
        }
    }
}
