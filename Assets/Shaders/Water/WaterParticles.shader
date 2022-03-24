Shader "Costumn/Water Particles"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}        
        [MainColor]   _BaseColor("Base Color", Color) = (1,1,1,1)
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        _BumpMap("Normal Map", 2D) = "bump" {}

        [HDR] _EmissionColor("Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {}

        _Blend("__mode", Float) = 0.0
        _AlphaClip("__clip", Float) = 0.0
        _BlendOp("__blendop", Float) = 0.0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend", Float) = 10

        [Enum(Off, 0, On, 1)] _ZWrite ("Z Write", Float) = 1       
        _Cull("__cull", Float) = 2.0

        _DistortionMap("Distortion Vectors", 2D) = "bumb" {}
    }
    SubShader
    {
        Tags { 
            // "RenderType" = "Opaque"
            "Queue" = "Transparent"
            "PreviewType" = "Plane"  
        }
        LOD 100 
        HLSLINCLUDE
        
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" 
        
        ENDHLSL
        Pass
        { 

            Blend SrcAlpha OneMinusSrcAlpha
            ZTest on
            ZWrite off

            HLSLPROGRAM
            

            #pragma vertex vert
            #pragma fragment frag

            
            struct appdata
            {
                float4 positionOS : POSITION;
                float4 uv : TEXCOORD0;
                float flipbookBlend : TEXCOORD1;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : VAR_BASE_UV;///?
                float4 vertex : SV_POSITION;		
                float3 flipbookUVB : VAR_FLIPBOOK;   
                float4 positionSS : TEXCOORD0;
                float3 positionWS:TEXCOORD1;
                float3 normal : TEXCOORD2;
            };

            float4 _MainTex_ST; 
            // float4 _ScreenParams;
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            SAMPLER(sampler_unity_SpecCube0);

            TEXTURE2D(_DistortionMap);
            SAMPLER(sampler_DistortionMap);

            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);

            v2f vert (appdata i)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(i.positionOS);	
                o.positionSS=ComputeScreenPos(o.vertex);

                o.positionWS=TransformObjectToWorld(i.positionOS.xyz);

                o.flipbookUVB.xy = TRANSFORM_TEX(i.uv.zw,_MainTex);
                o.flipbookUVB.z = i.flipbookBlend;

                o.uv =TRANSFORM_TEX(i.uv.xy,_MainTex);
                o.normal=TransformObjectToWorldNormal(i.normal);

                return o;
            }

            float3 Refraction(float3 normal,float3 incidentDir){
                float eta=3;

                #define N normal
                #define I incidentDir

                float k=1.0-eta*eta*(1-dot(N,I)*dot(N,I));
                float3 R=eta*I-(eta*dot(N,I)+sqrt(k))*N;
                return R;

            }

            float4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float4 color;
                color  = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,i.uv) ;

                //      baseMap = lerp(
                //    baseMap, SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.flipbookUVB.xy),
                //  i.flipbookUVB.z
                //);
                float3 viewDir=normalize(_WorldSpaceCameraPos - i.positionWS);

                float4 rawMap= SAMPLE_TEXTURE2D(_DistortionMap, sampler_DistortionMap,i.uv);
                i.normal=rawMap.xyz * 2-1;
                //return float4(i.normal,1);
                //DecodeNormal(rawMap, INPUT_PROP(_DistortionStrength)).xy;

                //float3 ref=Refraction(normalize(i.normal),viewDir);
                //color.rgb=SAMPLE_TEXTURECUBE(unity_SpecCube0,sampler_unity_SpecCube0,ref).rgb;
                //color.rgb=SAMPLE_TEXTURE2D(_CameraOpaqueTexture,sampler_CameraOpaqueTexture,i.positionSS.xy/i.positionSS.w+rawMap.xy*2-1).rgb;

                return color; 
            }
            ENDHLSL
        }
        Pass{
            Tags{    "LightMode" = "ShadowCaster"}
        }
    }	 
}
