Shader "Universal Render Pipeline/Particles/Unlit/testParticles"
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
    }
    SubShader
    {
        Tags { "RenderType"="Opaque"  "PreviewType" = "Plane"  }
        LOD 100
        HLSLINCLUDE
        
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" 
        
        ENDHLSL
        Pass
        { 
            BlendOp[_BlendOp]
            Blend[_SrcBlend][_DstBlend]
            ZWrite on
            Cull[_Cull]

            HLSLPROGRAM
            

            #pragma vertex vert
            #pragma fragment frag

            
            struct appdata
            {
                float4 vertex : POSITION;
                float4 uv : TEXCOORD0;
                float flipbookBlend : TEXCOORD1;
            };

            struct v2f
            {
                float2 uv : VAR_BASE_UV;///?
                float4 vertex : SV_POSITION;		
                float3 flipbookUVB : VAR_FLIPBOOK;   
                float4 ScreenPos : TEXCOORD0;
            };

            float4 _MainTex_ST; 
            // float4 _ScreenParams;
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);	
                o.ScreenPos=ComputeScreenPos(o.vertex);
                o.flipbookUVB.xy = TRANSFORM_TEX(v.uv.zw,_MainTex);
                o.flipbookUVB.z = v.flipbookBlend;

                o.uv =TRANSFORM_TEX(v.uv.xy,_MainTex);

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // sample the texture
                // 诡异的做法
                // 接近地面的时候才画否则丢弃
                // i.vertex.xy/_ScreenParams.xy会收到renderscale的影响
               // i.ScreenPos.xy/=i.ScreenPos.w;
                //float depth=SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_CameraDepthTexture,i.ScreenPos.xy);//*0.5+0.5;
                float depth =   (_CameraDepthTexture.Sample (sampler_CameraDepthTexture, i.ScreenPos.xy / i.ScreenPos.w).r);
                //  float depth=SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_CameraDepthTexture,i.vertex.xy/_ScreenParams.xy)*0.5+0.5;
                //  float depth=SAMPLE_DEPTH_TEXTURE_LOD(_CameraDepthTexture, sampler_point_clamp,  i.vertex.xy/_ScreenParams.xy, 0);
                //depth=i.vertex.z/20.f;
                // depth/=8;
                return float4(depth,depth,depth,1.f);
                /* float4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,i.uv);
                baseMap = lerp(
                baseMap, SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.flipbookUVB.xy),
                i.flipbookUVB.z
                );
                return baseMap;*/
            }
            ENDHLSL
        }
        Pass{
            Tags{    "LightMode" = "ShadowCaster"}
        }
    }	 
}
