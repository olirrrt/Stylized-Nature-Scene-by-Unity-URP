Shader "Costumn/Terrain"
{
    Properties{
        [MainColor] _BaseColor("base color", color) = (1, 1, 1, 1)

        _HeightMap("Height Map", 2D) = "" {}
        _TessellationUniform ("Tessellation Uniform", Range(1, 64)) = 1

        _DisplacementStrength("Displacement Strength", Range(0, 10)) = 1

    }

    SubShader
    {
        Tags{
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            //"Queue" = "Transparent"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
        #include "../Common.hlsl"
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
            float _DisplacementStrength;

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

            float3 getVertex(float3 v){

                #define _VertMin 5
                #define _VertMax -5
                #define _UVMin 0
                #define _UVMax 1

                float2 uv=(v.xz - _VertMin) / (_VertMax - _VertMin)* (_UVMax - _UVMin) + _UVMin;
                v += float3(0, 1, 0) * SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap,  uv, 0).r;//*_DisplacementStrength;
                return v;
            }

            
            Varyings vert(Attributes i)
            {
                Varyings o;
                o.uv = TRANSFORM_TEX(i.uv, _HeightMap);
                //o.uv=remap(,i.uv);
                //i.positionOS.xyz += i.normal * SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, o.uv, 0).r;
                /* float3 bitangent = float3(1, 0, 0);
                float3 tangent   = float3(0, 0, 1);
                float offset = 0.01;

                float3 vertexBitangent = getVertex(i.positionOS.xyz + bitangent * offset );
                float3 vertex =i.positionOS.xyz+i.normal * SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, o.uv, 0).r*_DisplacementStrength;
                float3 vertexTangent   = getVertex(i.positionOS.xyz + tangent   * offset);
                float3 newBitangent = vertexBitangent - vertex;
                float3 newTangent   = vertexTangent   - vertex;
                i.normal = cross(newTangent, newBitangent);
                i.positionOS.xyz=vertex;
                // float3 du=i.positionOS.xyz + i.normal * SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, o.uv*offset, 0).r;
                */

                i.positionOS.xyz +=_DisplacementStrength* i.normal * SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, o.uv, 0).r;
                float offset=_HeightMap_TexelSize.x * 0.5;
                offset=0.05;
                float2 du = float2(offset, 0);
                float u1 = SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, i.uv - du,0).r;
                float u2 = SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, i.uv + du,0).r;
                float3 tu =float3 (1, u2 - u1, 0);
                // return float4(normalize(tu), 1);

                float2 dv= float2(0, offset);
                float v1 = SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, i.uv - dv,0).r;
                float v2 = SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, i.uv + dv,0).r;
                float3 tv = float3(0, v2 - v1, 1);
                //return float4(normalize(tv), 1);
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
               // return float4(normalize(i.normal), 1);
                /*
                //bump map:
                float2 du = float2(_HeightMap_TexelSize.x * 0.5, 0);
                float u1 = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, i.uv - du).r;
                float u2 = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, i.uv + du).r;
                float3 tu =float3 (1, u2 - u1, 0);
                // return float4(normalize(tu), 1);

                float2 dv= float2(0, _HeightMap_TexelSize.y * 0.5);
                float v1 = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, i.uv - dv).r;
                float v2 = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, i.uv + dv).r;
                float3 tv = float3(0, v2 - v1, 1);
                //return float4(normalize(tv), 1);
                i.normal = normalize(cross(tv, tu));

                //i.normal = normalize(float3(u1-u2, 1, v1-v2));
                */

                //
                
                
                //  float3 viewDir=normalize(_WorldSpaceCameraPos - i.positionWS);
                // float3 lightDir = normalize(GetMainLight().direction - i.positionWS);

                Light light = GetMainLight();
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.positionWS);
                float3 lightDir = normalize(light.direction);

                return  saturate(dot(normalize(lightDir+viewDir),normalize(i.normal))) +float4(light.color,1)*_BaseColor * dot(lightDir, i.normal); //+0.3;

                return _BaseColor;
            }
            ENDHLSL
        }
    }
}
