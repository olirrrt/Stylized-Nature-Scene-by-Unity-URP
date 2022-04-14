Shader "Custom/Grass"
{
    Properties{
        _MainTex("Texture", 2D) = "white" {}         
        [Toggle]_AlphaClip("Alpha clip", float) = 0
        _AlphaClipThreshold("Threshold", Range(0, 1)) = 0.9
        
        _BaseColor("Tint", color) = (1, 1, 1, 1)    
        
        [Toggle]_Animate("Animate", float) = 0 

        _RimColor("Rim Color", color) = (1, 1, 1, 1)  
        _RimStrength("Rim Strength", Range(0, 1)) = 0.4
        // _SpecularColor("Specular Color", color) = (1, 1, 1, 1)        
        // _SpecularStrength("Specular Strength", Range(0, 256)) = 4
        _SSColor("inner color", color) = (1, 0, 0, 1)
        _SSRange("SS Range", Range(0, 128)) = 16
        _SSStrength("SS Strength", Range(0, 1)) = 1
        
    } SubShader
    {
        Tags{
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "opaque"
            
            //    "LightMode" = "ForwardAdd"

        }
        // LOD 100
        Cull off //关掉背面裁剪
        // ZWrite off
        //   ZTest Early
        
        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        ENDHLSL

        Pass
        {
            HLSLPROGRAM

            #pragma multi_compile_instancing
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fog

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            
            //#pragma multi_compile _ _SHADOWS_SOFT
            

            #pragma multi_compile   _ALPHACLIP_OFF _ALPHACLIP_ON
            #pragma multi_compile   _ANIMATE_OFF   _ANIMATE_ON 
            

            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
            float4 _normal;
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

            struct Varyings
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                half fogFactor : TEXCOORD4;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Attributes
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 positionWS : TEXCOORD3; 
                float3 positionOS : TEXCOORD5;
                half fogFactor : TEXCOORD4;  
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            // CBUFFER_START(UnityPerMaterial)
                
                TEXTURE2D(_MainTex);
                SAMPLER(sampler_MainTex);
                // float _SpecularStrength;
                // float4 _SpecularColor;
                float4 _BaseColor;
                TEXTURE2D(_WindTex);
                SAMPLER(sampler_WindTex);
                float4 _WindTex_ST;
                float _WindStrength;
                float _windDir;
                float _WindSpeed;
                float4  _SSColor;
                float _SSStrength;
                float _SSRange;
                float4 _RimColor;
                float _RimStrength;

                float _AlphaClipThreshold;
                float _SubSurfaceDcatterStrength;

                
            // CBUFFER_END

            Attributes vert(Varyings i)
            {
                Attributes o;
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_TRANSFER_INSTANCE_ID(i, o);
                o.positionWS = TransformObjectToWorld(i.positionOS);
                
                #if _ANIMATE_ON
                    float2 uv = o.positionWS.xz / 28.f * 0.5 + 0.5;
                    float2 windSample = SAMPLE_TEXTURE2D_LOD(_WindTex, sampler_WindTex, float2(uv + _Time.y * _WindSpeed),0).xy * 2 - 1;
                    _windDir = float3(windSample, 0);
                    i.positionOS.xyz += _windDir * pow(i.uv.y, 2) * _WindStrength;
                #endif
                
                o.positionHCS = TransformObjectToHClip(i.positionOS); //   UnityObjectToClipPos(i.vertex);
                o.uv = i.uv;
                // float4 tmp = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _normal);
                // o.normal = tmp.xyz;
                o.normalWS = TransformObjectToWorldNormal(i.normal);
                o.positionOS=i.positionOS;

                o.fogFactor = ComputeFogFactor(o.positionHCS.z);
                return o;
            }

            #define _ADDITIONAL_LIGHTS

            float4 frag(Attributes i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                // _RimStrength=0.1;
                //   return _RimStrength;
                float4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);

                #if _ALPHACLIP_ON
                    clip(albedo.a - _AlphaClipThreshold);
                #endif

                albedo *= _BaseColor ;
                float4 color = float4(0, 0, 0, albedo.a);

                Light light = GetMainLight(TransformWorldToShadowCoord(i.positionWS));

                float3 viewDir = normalize(_WorldSpaceCameraPos - i.positionWS);
                float3 lightDir = normalize(light.direction);
                // float3 H = saturate(normalize(viewDir + lightDir));
                float3 N = normalize(i.normalWS);
                
                //float3 N = float3(0,1,1);
                // float3 ref = reflect(-N, viewDir);


                // float NdotH = saturate(dot(N, H));
                float NdotL = saturate(dot(N, lightDir));

                //  float specular = pow(NdotH, _SpecularStrength);
                //color.rgb  =   light.shadowAttenuation * albedo.rgb * light.color * _BaseColor.rgb  + _GlossyEnvironmentColor *albedo.rgb;
                color.rgb  = NdotL * light.color * light.shadowAttenuation    *  albedo.rgb   + _GlossyEnvironmentColor *  albedo.rgb;


                
                float rim = pow(1 - saturate(dot(N, viewDir)), 8)* _RimStrength  ;// * pow(i.positionOS.y, 24) ;//* 0.1;
                
                color += rim * _RimColor ;
                
                float _SSDistortion = 0.5;
                float attenuation = saturate(dot(viewDir, -(lightDir + i.normalWS * _SSDistortion)));
                attenuation = pow(attenuation, _SSRange) * _SSStrength; 
                color += attenuation * _SSColor;// * pow(i.positionOS.y, 2);
                
                color.rgb = MixFog(color.rgb,  i.fogFactor );  
                
                return color;
            }

            ENDHLSL
        }

        Pass{
            Tags{"LightMode" = "ShadowCaster"}
        }
    }
}