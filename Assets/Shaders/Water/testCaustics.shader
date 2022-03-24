Shader "Costumn/Caustics"
{
    Properties{
        [MainColor] _BaseColor("base color", color) = (0.5, 0.5, 0.5, 1)
        _CausticsMap ("Caustics Map", 2D) = "" {}
        _SplitRGB_Strength("SplitRGB Strength",Range(0,1))=0.3

    }

    SubShader
    {
        Tags{
            "RenderPipeline" = "UniversalPipeline"
        "RenderType" = "Opaque"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
        ENDHLSL

        Pass
        {

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            float4 _BaseColor;
            float _SplitRGB_Strength;

            TEXTURE2D(_CausticsMap);
            SAMPLER(sampler_CausticsMap);

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

                o.normal=TransformObjectToWorldNormal(i.normal);
                o.positionHCS = TransformObjectToHClip(i.positionOS.xyz);
                o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
                o.positionSC = ComputeScreenPos(o.positionHCS);
                o.uv = i.uv;

                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float2 uv=i.uv/1.5;
                float4 caustics;// = SAMPLE_TEXTURE2D(_CausticsMap,sampler_CausticsMap,i.uv/1.5);
                #define s _SplitRGB_Strength
                float r=SAMPLE_TEXTURE2D(_CausticsMap,sampler_CausticsMap,uv+float2(s,+s)).r;
                float g=SAMPLE_TEXTURE2D(_CausticsMap,sampler_CausticsMap,uv+float2(s,-s)).g;
                float b=SAMPLE_TEXTURE2D(_CausticsMap,sampler_CausticsMap,uv+float2(-s,-s)).b;
                caustics=float4(r,g,b,1);
                // return float4(normalize(i.normal) * 0.5 + 0.5, 1);
                return caustics+_BaseColor;
                //  float3 viewDir=normalize(_WorldSpaceCameraPos - i.positionWS);
                // float3 lightDir = normalize(GetMainLight().direction - i.positionWS);
                //  return 0.3+ dot(normalize(lightDir+viewDir),normalize(i.normal))+_BaseColor * dot(lightDir, normalize(i.normal)); //+0.3;

                return _BaseColor;
            }
            ENDHLSL
        }
    }
}
