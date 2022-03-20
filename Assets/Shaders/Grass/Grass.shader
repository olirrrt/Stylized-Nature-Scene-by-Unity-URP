Shader "Custom/Grass"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}        
        _WindTex ("Wind", 2D) = "white" {}
        
        _WindSpeed ("Wind Speed", Range(0,10)) =1
        _WindStrength ("Wind Strength", Range(0,10)) =1

    }
    SubShader
    {
        Tags { 
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"="opaque" 	               
            //"Queue" = "Transparent"
            // "RenderType"="Transparent"				
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
            // Blend SrcAlpha OneMinusSrcAlpha   
            //Blend One One              

            ///  AlphaToMask On

            HLSLPROGRAM
            
            #pragma multi_compile_instancing
            #pragma vertex vert
            #pragma fragment frag
            
            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
            float4 _normal;
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

            struct appdata{
                float4 vertex:POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;   
                
                UNITY_VERTEX_INPUT_INSTANCE_ID 

            };

            struct v2f
            {
                float4 vertex : SV_POSITION; 
                float2 uv : TEXCOORD1;                
                float3 normal : TEXCOORD2;                
                float3 worldPos : TEXCOORD3; 

                UNITY_VERTEX_INPUT_INSTANCE_ID 

            };
            
            sampler2D _WindTex;
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            //   TEXTURE2D(_WindTex);
            //   SAMPLER(sampler_WindTex);
            float4 _WindTex_ST;
            float _WindStrength;
            float _windDir;    
            float _WindSpeed;    

            v2f vert (appdata v)
            {
                v2f o;    
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                o.worldPos=TransformObjectToWorld(v.vertex); 
                float2 uv= o.worldPos.xz/28.f*0.5+0.5;
                float2 windSample=tex2Dlod(_WindTex,float4(uv+_Time.y*_WindSpeed,0,0)).xy*2-1;
                _windDir=float3(windSample,0);  
                v.vertex.xyz+=_windDir *pow(v.uv.y,2)*_WindStrength;

                
                o.vertex =TransformObjectToHClip(v.vertex);//   UnityObjectToClipPos(v.vertex);
                o.uv=v.uv;
                float4 tmp=UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_normal);
                o.normal=tmp.xyz;
                

                return o;
            }
            
            #define _ADDITIONAL_LIGHTS

            float4 frag (v2f input) : SV_Target
            {                
                UNITY_SETUP_INSTANCE_ID(input);
                float4 baseColor=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.uv);

                
                float4 color=float4(0,0,0,baseColor.a);

                Light  light=GetMainLight();
                float diff=dot(input.normal,normalize(light.direction))*0.5+0.5;
                color.rgb +=baseColor.rgb*light.color*light.distanceAttenuation*diff;
                
                #ifdef _ADDITIONAL_LIGHTS
                    for(int i=0;i<GetAdditionalLightsCount();i++){
                        light=GetAdditionalLight(i,input.worldPos);
                        float diff=dot(input.normal,normalize(light.direction))*0.5+0.5;
                        color.rgb +=baseColor.rgb*light.color*light.distanceAttenuation*diff;
                    }

                #endif

                clip(color.a-0.4);
                return color;
            }
            
            
            ENDHLSL
        }
    }
}