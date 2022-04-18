Shader "Custom/Hidden/Screen Space Snow"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor ("Tint", Color) = (0, 0, 0, 0)
        _MapScale ("Map Scale" , float) = 1
        [NoScaleOffset]_AlbedoMap("Albedo Map", 2D) = "" {}
        [NoScaleOffset]_NormalMap("Normal Map", 2D) ="bump" {}
        [NoScaleOffset]_RoughnessMap("Roughness",2D)=" "{}        
        [NoScaleOffset]_AOMap("AO",2D)=" "{}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always
        HLSLINCLUDE
        inline float DecodeFloatRG( float2 enc )
        {
            float2 kDecodeDot = float2(1.0, 1/255.0);
            return dot( enc, kDecodeDot );
        }   

        inline float3 DecodeViewNormalStereo( float4 enc4 )
        {
            float kScale = 1.7777;
            float3 nn = enc4.xyz*float3(2*kScale,2*kScale,0) + float3(-kScale,-kScale,1);
            float g = 2.0 / dot(nn.xyz,nn.xyz);
            float3 n;
            n.xy = g*nn.xy;
            n.z = g-1;
            return n;
        }

        inline void DecodeDepthNormal( float4 enc, out float depth, out float3 normal )
        {
            depth = DecodeFloatRG (enc.zw);
            normal = DecodeViewNormalStereo (enc);
        }
        ENDHLSL
        
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"           
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "../Surface.hlsl"

            /*   struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };*/

            Varyings vert (Attributes v)
            {
                Varyings o = (Varyings)0;
                o.positionCS = TransformObjectToHClip(v.positionOS);
                o.uv = v.uv;
                


                return o;
            }

            float4x4 _CamToWorld;
            float _MapScale;
            
            TEXTURE2D(_CameraDepthNormalsTexture);           
            SAMPLER(sampler_CameraDepthNormalsTexture);

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            

            TEXTURE2D(_AlbedoMap);
            SAMPLER(sampler_AlbedoMap);

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            TEXTURE2D(_RoughnessMap);
            SAMPLER(sampler_RoughnessMap); 
            
            TEXTURE2D(_AOMap);
            SAMPLER(sampler_AOMap);

            
            
            half4 frag (Varyings i) : SV_Target
            {
                
                half3 normalVS;
                float depth;
                DecodeDepthNormal( SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, i.uv), depth, normalVS);
                
                float3 normalWS = mul( (float3x3)_CamToWorld, normalVS);
                
                //  clip(normalWS );
                // return float4(normalWS,1);
                float up = dot(float3(0,1,0), normalWS);
                up = step( 0.7, up);

                ////////////////////////////////////////////////////////////////////////////////////////////////
                // Sample the depth from the Camera depth texture.
                #if UNITY_REVERSED_Z
                    depth = SampleSceneDepth(i.uv);
                #else
                    // Adjust Z to match NDC for OpenGL ([-1, 1])
                    depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(i.uv));
                #endif
                

                //    float2 p11_22 = float2(unity_CameraProjection._11, unity_CameraProjection._22);
                //     float3 vpos = float3( (i.uv * 2 - 1) / p11_22, -1) * depth;
                //     float4 positionWS = mul(_CamToWorld, float4(vpos, 1));
                //  positionWS += float4(_WorldSpaceCameraPos, 0) / _ProjectionParams.z;
                //positionWS *= _SnowTexScale * _ProjectionParams.z;
                
                float3 positionWS = ComputeWorldSpacePosition(i.uv, depth, UNITY_MATRIX_I_VP);
                
                // return float4(positionWS,1);

                float2 uv =  positionWS.xz * _MapScale;
                
                float4 albedo = SAMPLE_TEXTURE2D(_AlbedoMap, sampler_AlbedoMap,  uv);                
                float  ao = SAMPLE_TEXTURE2D(_AOMap, sampler_AOMap,  uv).r;
                float  roughness = SAMPLE_TEXTURE2D(_RoughnessMap, sampler_RoughnessMap, uv).r;
                float3 normal = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap,  uv));
                
                //  return ao;//float4(normal,1);

                SurfaceData surfaceData = (SurfaceData)0;
                
                surfaceData.albedo =  albedo * _BaseColor.rgb;
                surfaceData.metallic = 0.3;
                surfaceData.smoothness =  1-roughness;
                surfaceData.occlusion = ao;
                //  surfaceData.normalTS = normal;
                
                // surfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_NormalMap, sampler_NormalMap), _MapScale);
                
                InputData inputData = InitializeInputData(i, surfaceData.normalTS);
                inputData.normalWS = float3(normal.x,normal.z,normal.y);

                float4 snowColor = 1;
                snowColor.rgb = UniversalFragmentPBR(inputData, surfaceData);

                // snowColor.rgb = dot(GetMainLight().direction,  normalWS) * albedo.rgb; 
                //  return snowColor;

                float4 color =  SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);  

                snowColor = albedo;

                color = lerp(color, snowColor, up);

                return color;
                
                
            }
            ENDHLSL
        }
    }
}
