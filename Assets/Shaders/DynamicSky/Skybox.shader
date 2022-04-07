Shader "Unlit/Unlit"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}        
        [NoScaleOffset] _RampTex ("Gradient Sky", 2D) = "white" {}
        [NoScaleOffset] _RampTex_2 ("Gradient Sky", 2D) = "white" {}
        [NoScaleOffset] _RampTex_3 ("Gradient Sky", 2D) = "white" {}
        [NoScaleOffset] _RampTex_4 ("Gradient Sky", 2D) = "white" {}
        [NoScaleOffset] _RampTex_5 ("Gradient Sky", 2D) = "white" {}
        [NoScaleOffset] _RampTex_6 ("Gradient Sky", 2D) = "white" {}
        [NoScaleOffset] _RampTex_7 ("Gradient Sky", 2D) = "white" {}
        _CloudTex ("Cloud", 2D) = "white" {}        
        [NoScaleOffset]_CloudNormalTex ("Cloud Normal", 2D) = "bump" {}
        _WindTex ("Wind", 2D) = "white" {}
        _StarTex ("Star", 2D) = "white" {}
        // _NoiseTex("Star", 2D) = "white" {}
        // _MoonMask("Texture", 2D) = "white" {}  
        _SunSize ("Sun Size", Range(0,0.5)) =0.06
        _FogStrength ("Fog Strength", Range(0,1)) =0.2

    }
    SubShader
    {
        Tags {  "RenderPipeline" = "UniversalPipeline"
            "QUEUE"="Background" 
            "RenderType"="Background" 
            "PreviewType"="Skybox"
        }
        // LOD 100
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            // #pragma multi_compile_fog
            #include "UnityCG.cginc"            
            #define PI 3.141592653589793
            #define WHITE float4(1,1,1,1)
            struct TBNMatrix{
                float3 tspace0 ; // tangent.x, bitangent.x, normal.x
                float3 tspace1 ; // tangent.y, bitangent.y, normal.y
                float3 tspace2; // tangent.z, bitangent.z, normal.z
            };
            struct appdata{
                float4 vertex:POSITION;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };
            struct v2f
            {
                float4 vertex : SV_POSITION; 
                float4 localPos : TEXCOORD4;
                
                TBNMatrix tbn: TEXCOORD1;
            };
            
            sampler2D _MainTex,_CloudTex,_WindTex,_StarTex,_CloudNormalTex;          
            sampler2D  _RampTex,_RampTex_2,_RampTex_3,_RampTex_4,_RampTex_5,_RampTex_6,_RampTex_7;
            float4 _MainTex_ST, _NoiseTex_ST, _CloudTex_ST;
            float _SunSize;
            float _FogStrength;

            //float _daySpan;            
            float _Speed;
            
            v2f vert (appdata v)
            {
                v2f o;    
                o.localPos=v.vertex;                         
                o.vertex =  UnityObjectToClipPos(v.vertex);
                float3 wNormal=v.normal;
                float3 wTangent=UnityObjectToWorldDir(v.tangent.xyz);
                float tangentSign = v.tangent.w * unity_WorldTransformParams.w;
                float3 wBitangent = cross(wNormal, wTangent) * tangentSign;   
                TBNMatrix tbn;
                tbn.tspace0 = half3(wTangent.x, wBitangent.x, wNormal.x);
                tbn.tspace1 = half3(wTangent.y, wBitangent.y, wNormal.y);
                tbn.tspace2 = half3(wTangent.z, wBitangent.z, wNormal.z);
                o.tbn=tbn;
                return o;
            }
            
            float2 getUV(float3 v){
                v=normalize(v);  
                return float2(atan2(v.z,v.x)/(2*PI)+0.5,asin(v.y)/PI+0.5);
            }
            // #define isAboveHorizon(v) return v.y>0
            // attenuate越大
            // 随时间插值
            float4 getSunColor(){
                //return (1-attenuate*6)*1;
                return 1;//float4(1,1,0,1);
            }
            // 计算月亮的遮照
            bool inMask(float3 sunPos,float3 v){
                float3 offset=float3(0.3,0.3,-0.2);
                float3 maskPos=normalize(sunPos+offset);
                float radius=0.34;
                return distance(v,maskPos)<radius;
            }
            float getAttenuate(float d){
                // return clamp((1-d) ,0.f,1.f);
                //越大光晕范围越小
                d*=8;
                float kc=1,k1=0.1,kq=1.8;
                return 1.0/(kc+k1*d+kq*d*d);
            }
            float4 getSkyColor(float2 uv){
                const int size=7;            
                int node[size]={4,6,7,12,16,18,20};
                sampler2D textures[size]={_RampTex,_RampTex_2,_RampTex_3,_RampTex_4,_RampTex_5,_RampTex_6,_RampTex_7};
                float flag=(_Time*_Speed ) % 24;
                
                for(int i=0;i<size;i++){
                    if(flag<=node[i] && i==0 || flag>node[size-1]){
                        float t=-node[size-1]+flag;
                        if(t<0)t+=24;                        
                        return lerp(tex2D(textures[size-1],uv),tex2D(textures[0],uv),t/(24-node[size-1]+node[0]));
                    }
                    else if(flag<=node[i]){
                        int idx_early=(i-1+size)%size;                        
                        float4 color_late=tex2D(textures[i],uv);
                        float4 color_early=tex2D(textures[idx_early],uv);
                        
                        return lerp(color_early,color_late, (flag-node[idx_early]) / (node[i]-node[idx_early]));
                    }
                }
                return 1;
            } 
            
            // testcloud
            float4 frag2 (v2f i) : SV_Target{
                float3 v=normalize(i.localPos.xyz);  
                float intensity=1;
                intensity=lerp(0,2,pow(v.y,0.8));
                v.y=1-(0.5*v.y+0.5);
                float2 starUV=float2(v.x,v.z)*(v.y+1);
                return tex2D(_StarTex,starUV)*intensity;
            }

            // 原范围内的数,通过线性映射到新范围内
            float remap(float2 inRange,float2 outRange,float n){
                return outRange.x+(n-inRange.x)*(outRange.y-outRange.x)/(inRange.y-inRange.x);
            }

            float4 getCloud(float3 v,TBNMatrix tbn,float3 lightDir){
                float2 cloudUV=float2(v.x,v.z)/remap(float2(0,1),float2(0.12,1),abs(v.y));
                cloudUV=TRANSFORM_TEX(cloudUV,_CloudTex); 
                float2 offset=tex2D(_WindTex,cloudUV).xy+_Time*0.05;
                //cloudUV+=offset;
                
                float4  cloudColor= tex2D(_CloudTex,cloudUV);

                float3 tnormal=UnpackNormal(tex2D(_CloudNormalTex,cloudUV));    
                float3 normal;
                normal.x = dot(tbn.tspace0, tnormal);
                normal.y = dot(tbn.tspace1, tnormal);
                normal.z = dot(tbn.tspace2, tnormal);
                
                float4 shadowColor=float4(140.f/255,191.f/255,1,1);
                float4 lightColor=float4(1,1,1,1);
                if(dot(normal,lightDir)>0)return lerp(shadowColor,lightColor,pow(dot(normal,lightDir),0.25))*cloudColor;//*10;//float4(1,0,0,1);
                else return cloudColor*shadowColor;//(dot(normal,lightDir)+0.4)*cloudColor;
            }
           
            float4 getStar(float3 v){
                float intensity=1;
                intensity=lerp(0,2,pow(v.y,0.9));
                v.y=1-(0.5*v.y+0.5);
                float2 starUV=float2(v.x,v.z)*(v.y+1);                
                float4  starColor= tex2D(_StarTex,starUV)*intensity;
                return starColor;
            }
            
            float4 frag (v2f i) : SV_Target
            {
                float3 v=normalize(i.localPos.xyz);                
                float3 sunPos=normalize(_WorldSpaceLightPos0.xyz);
                
                float4  cloudColor= getCloud(v,i.tbn,sunPos);
                
                float4  starColor=getStar(v);
                float dis=distance(sunPos,v);
                bool aboveHorizon=i.localPos.y>0;
                
                float4 fogColor=WHITE;//float4(1,0,0,1);
                if(dis<_SunSize && aboveHorizon )
                return getSunColor();
                else{
                    //float4 color = tex2D(_MainTex, getUV(i.localPos.xyz));
                    
                    i.localPos.y=i.localPos.y*0.5+0.5;    
                    float2 uv=float2(1-i.localPos.y,0.5);       
                    float4 color=tex2D(_RampTex_4,uv);
                    
                    //float4 color=getSkyColor(uv);
                    
                    // apply fog
                    //UNITY_APPLY_FOG(i.fogCoord, col);
                    
                  //  if(aboveHorizon)
                 //   color=lerp(color,getSunColor(), getAttenuate(dis));
                  //  if(aboveHorizon)
                  //  color=color*(1-cloudColor.a)+cloudColor*cloudColor.a;
                    //if(starColor.a>0.2)
                    //color=color*(1-starColor.a)+starColor*starColor.a;
                    if(aboveHorizon)
                    color=lerp(fogColor,color,pow(v.y,_FogStrength));
                    return color;
                }
                
            }
            ENDHLSL
        }
    }
}