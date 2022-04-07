Shader "Costumn/Dynamic Sky 2.0"
{
    Properties{
        _WindTex("Wind", 2D) = "white" {} _MainTex("Texture2d", 2D) = "white" {}
        [NoScaleOffset] _RampTex("Gradient Sky", 2D) = "white" {} 
        
        _CloudTex("Cloud", 2D) = "white" {}
        _NoiseTexRGB("RGB NoiseTex", 2D) = "" {}
        _WindTex("Wind", 2D) = "white" {}

        _StarTex("Star", 2D) = "white" {} 
        _NoiseTex("Star Noise", 2D) = "" {} _MoonTex("Moon Texture", 2D) = "white" {} _SunSize("Sun Size", Range(0, 0.5)) = 0.06 _FogStrength("Fog Strength", Range(0, 1)) = 0.2

    } SubShader
    {
        Tags{"RenderPipeline" = "UniversalPipeline"
            "QUEUE" = "Background"
            "RenderType" = "Background"
        "PreviewType" = "Skybox"}
        // LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "../Common.hlsl"
        ENDHLSL

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            // #pragma multi_compile_fog

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float4 positionSS : TEXCOORD2;
                float2 uv : TEXCOORD3;
                float4 positionOS : TEXCOORD4;
            };

            Varyings vert(Attributes i)
            {
                Varyings o;
                o.positionHCS = TransformObjectToHClip(i.positionOS.xyz);
                o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
                o.positionSS = ComputeScreenPos(o.positionHCS);
                o.normal = TransformObjectToWorldNormal(i.normal);
                o.uv = i.uv;
                o.positionOS = i.positionOS;
                return o;
            }

            float3 bR;
            float3 bM;
            float EarthRadius;
            float AtmosRadius;

            float Hr; // Reyleight scattering top
            float Hm; // Mie scattering top

            float3 _Start_Pos;
            float3 _End_Pos;
            float3 _Earth_Center;
            float _Max_Iter;
            float _Max_Iter_Light;

            float g;  // light concentration .76 //.45 //.6  .45 is normaL
            float g2; // = g * g;
            float _end;
            float3 L;
            float3 sunPos;
            float _Main_Light_Intensity;

            int _isNight;
            float _SunSize;
            int isMoon;

            #define GREEN float4(0, 1, 0, 1)
            #define BABYBLUE float4(0, 1, 1, 1)

           float4  _GroundColor;

            TEXTURE2D(_MoonTex);
            SAMPLER(sampler_MoonTex);

            TEXTURE2D(_StarTex);
            SAMPLER(sampler_StarTex);

            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            TEXTURE2D(_CloudTex);
            SAMPLER(sampler_CloudTex);

            TEXTURE2D(_NoiseTexRGB);
            SAMPLER(sampler_NoiseTexRGB);

            void setUp()
            {
                bR = float3(5.8e-6, 1.35e-5, 3.31e-5);
                // bR = float3(58e-6, 135e-5, 331e-5);
                bM = float3(2e-6, 2e-6, 2e-6);
                // const float R0 = 6360e3; //planet radius
                //  const float Ra = 6380e3; //atmosphere radius
                EarthRadius = 6360e3;
                AtmosRadius = 6380e3;

                Hr = 8000.0; // Reyleight scattering top
                Hm = 1200.0; // Mie scattering top

                _Max_Iter = 164;
                _Max_Iter_Light = 8;

                _Earth_Center = float3(0, 0, 0) - float3(0, 1, 0) * (EarthRadius);
                //_Earth_Center = float3(0, -EarthRadius, 0);
                // _Earth_Center =  - float3(0, 1, 0) * (EarthRadius);

                g = 0.945; // light concentration .76 //.45 //.6  .45 is normaL
                g2 = g * g;

                _SunSize = 0.06;
                sunPos = normalize(_MainLightPosition);
                if (sunPos.y < 0)
                {
                    sunPos *= (-1);
                    // ?cannot use casts on l-values
                    // isMoon = true;
                    isMoon = 1;
                    _Main_Light_Intensity = 0.3;
                }
                else
                {
                    isMoon = 0;
                    _Main_Light_Intensity = 10;
                }
            }

            float2 getRaySphereIntersect(float3 P, float3 d, float R)
            {
                // circle center
                float3 C = _Earth_Center;

                float a = dot(d, d);
                float b = 2 * dot(d, P - C);
                float c = dot(P - C, P - C) - R * R;
                float delta = b * b - 4 * a * c;
                if (delta < 0)
                return float2(-1, -1);
                float x1 = (-b - sqrt(delta)) / (2 * a);
                float x2 = (-b + sqrt(delta)) / (2 * a);
                return float2(x1, x2);
            }

            // integer hash
            float hash( int n ) 
            {
                n = (n << 13) ^ n;
                n = n * (n * n * 15731 + 789221) + 1376312589;
                return -1.0+2.0*float( n &  (0x0fffffff))/float(0x0fffffff);
            }

            // gradient noise
            /* float gnoise(float p){
                int i = floor(p);
                float f = frac(p);
                float u = f*f*(3.0-2.0*f);
                return lerp(hash(i+0)*(f-0.0), hash(i+1)*(f-1.0), u);
            }

            //  
            float fbm(float x, float G)
            {    
                // x += 26.06;
                float n = 0.0;
                float s = 1.0;
                float a = 0.0;
                float f = 1.0;    
                for( int i=0; i<16; i++ )
                {
                    n += s*gnoise(x*f);
                    a += s;
                    s *= G;
                    f *= 2.0;
                    x += 0.31;
                }
                return n;
            } */
            // gradient noise
            float  gnoise(float3 p){
                float3 i = floor(p);
                float3 f = frac(p);
                float3 u = f*f*(3.0-2.0*f);
                return lerp(hash(i+0)*(f-0.0), hash(i+1)*(f-1.0), u.z);
                // float2 uv = (p.xy+float2(37.0,17.0)*p.z) + f.xy;                
                // float2 uv = (p.xz+float2(37.0,17.0)*p.y) + f.xz;

                // float2 rg = SAMPLE_TEXTURE2D_LOD( _NoiseTexRGB,sampler_NoiseTexRGB, (uv+ 0.5)/256.0, 0).rg;
                ////  return lerp( rg.x, rg.y, f.z );
            }

            float noise3D(float3 p)
            {
                p.z = frac(p.z)*256.0;
                float iz = floor(p.z);
                float fz = frac(p.z);
                float2 a_off = float2(23.0, 29.0)*(iz)/256.0;
                float2 b_off = float2(23.0, 29.0)*(iz+1.0)/256.0;
                float a = SAMPLE_TEXTURE2D_LOD(_NoiseTexRGB,sampler_NoiseTexRGB,  p.xy + a_off, -999.0).r;
                float b = SAMPLE_TEXTURE2D_LOD(_NoiseTexRGB,sampler_NoiseTexRGB,  p.xy + b_off, -999.0).r;
                return lerp(a, b, fz);
            }
            float noise(   float3 x )
            {
                float3 p = floor(x);
                float3 f = frac(x);
                f = f*f*(3.0-2.0*f);
                
                float2 uv  = (p.xy+float2(37.0,17.0)*p.z);                
                //   float2 uv  = (p.xy+float2(137.0, 0)*p.z);

                float2 rg1 = SAMPLE_TEXTURE2D_LOD(_NoiseTexRGB,sampler_NoiseTexRGB, (uv+ float2(0.5,0.5))/256.0, 0.0 ).yx;
                float2 rg2 = SAMPLE_TEXTURE2D_LOD( _NoiseTexRGB,sampler_NoiseTexRGB,(uv+ float2(1.5,0.5))/256.0, 0.0 ).yx;
                float2 rg3 = SAMPLE_TEXTURE2D_LOD( _NoiseTexRGB,sampler_NoiseTexRGB, (uv+ float2(0.5,1.5))/256.0, 0.0 ).yx;
                float2 rg4 = SAMPLE_TEXTURE2D_LOD( _NoiseTexRGB,sampler_NoiseTexRGB, (uv+ float2(1.5,1.5))/256.0, 0.0 ).yx;
                float2 rg  = lerp( lerp(rg1,rg2,f.x), lerp(rg3,rg4,f.x), f.y );
                
                return lerp( rg.x, rg.y, f.z );
            }
            float fnoise( float3 p  )
            {
                //  p *= 2e-4;
                float f;

                f = 0.5000 * noise(p); p = p * 3.02; //p.y -= t*.2;
                f += 0.2500 * noise(p); p = p * 3.03; //p.y += t*.06;
                f += 0.1250 * noise(p); p = p * 3.01;
                f += 0.0625   * noise(p); p =  p * 3.03;
                f += 0.03125  * noise(p); p =  p * 3.02;
                f += 0.015625 * noise(p);
                return f;
            }

            float3 fbm(float3 x, float G)
            {    
                // x += 26.06;
                float n = 0.0;
                float s = 1.0;
                float a = 0.0;
                float f = 1.0;    
                for( int i=0; i<16; i++ )
                {
                    n += s*gnoise(x*f);
                    //  a += s;
                    s *= G;
                    f *= 2.0;
                    x += 0.31;
                }
                return n;
            } 
            /*     
            #define OCTAVES 6
            float fbm(float3 pos){
                float value =0;
                
                // amplitude 递减，frequency递减
                float A = 1;
                float F = 0;
                for(int i=0; i<OCTAVES; i++){
                    //value += A * SAMPLE_TEXTURE2D(_CloudTex, sampler_CloudTex, uv/F).r;
                    value += A * noise(pos,F);
                    F *=  2.0;
                    A *= 0.5;
                }

                return value+0.1;
            }*/
            //  float getCloudDensity(){
                //     fbm()
            // }

            void getDensity(float3 pos, out float dR, out float dM)
            {
                float height = distance(pos, _Earth_Center) - EarthRadius;
                dR = exp(-height / Hr);
                dM = exp(-height / Hm) + 0.1;
                
                // float _Cloud_Height_Low = 5e3;
                //float _Cloud_Height_Heigh = 75e3;   
                float _Cloud_Height_Low = 5e3;
                float _Cloud_Height_Heigh = 8e3;


                 float cloud=0;
                if(height > _Cloud_Height_Low && height < _Cloud_Height_Heigh){
                    // cloud=fbm(pos )*0.001;//*199;
                    // cloud = fbm(pos  , 0.75) ; 
                    //
                    //cloud*=999;

                //    cloud = fnoise(pos * 0.0003) +0.01;
                  //  cloud = smoothstep(0.44, 0.57, cloud);
                    //cloud*= 80    ;
                }  
                dM += cloud;
            }

            float4 RayMarching(float3 ro, float3 rd)
            {
                Light light = GetMainLight();
                // L = normalize(light.direction);
                L = sunPos;
                float mu = dot(rd, L);
                float opmu2 = 1. + mu * mu;
                float phaseR = 0.0596831 * opmu2;
                float phaseM = 0.1193662 * (1. - g2) * opmu2 / ((2. + g2) * pow(1. + g2 - 2. * g * mu, 1.5));

                float dd = (distance(_Start_Pos, _End_Pos)) / _Max_Iter;
                // float dd =_end/ _Max_Iter;

                float dis = 0;

                float density = 0;
                float3 scatteredLight = 0;
                float transmittance = 1;

                //  float3 viewDir =0 ;

                float3 R = 0;
                float3 M = 0;

                float depthR = 0, depthM = 0;
                for (float i = 0; i < _Max_Iter; ++i)
                {
                    float3 pos = ro + dis * rd;
                    dis += dd;

                    float dR = 0;
                    float dM = 0;
                    getDensity(pos, dR, dM);
                    dR *= dd;
                    dM *= dd;
                    depthR += dR;
                    depthM += dM;

                    float end = getRaySphereIntersect(pos, L, AtmosRadius).y;
                    if (end > 0)
                    {
                        // delta distance towards light
                        float ddl = end / _Max_Iter_Light;
                        float depthRs = 0.0, depthMs = 0.0;
                        for (int j = 0; j < _Max_Iter_Light; ++j)
                        {
                            float3 posl = pos + ddl * L;
                            float dRs, dMs;
                            getDensity(posl, dRs, dMs);
                            depthRs += dRs * ddl;
                            depthMs += dMs * ddl;
                        }

                        float3 A = exp(-(bR * (depthRs + depthR) + bM * (depthMs + depthM)));

                        R += A * dR;
                        M += A * dM;

                    }
                }
                
                scatteredLight = _Main_Light_Intensity * (R * bR * phaseR + M * bM * phaseM);
                float scat = 1.0 - clamp(depthM * 1e-5, 0.0, 1.0);
                //   =  (1- transmittance) * scatteredLight + transmittance * color_bg.rgb ;
                float env = 0.9;
                return (float4(env * pow(scatteredLight, float3(0.4, 0.4, 0.4)), scat));

                return float4(scatteredLight, scat);
            }

            float4 renderSunandMoon(float3 pos, bool isMoon)
            {
                if (distance(sunPos, pos) > _SunSize || pos.y < 0)
                return 0;
                
                if (isMoon)
                {
                    float2 uv = (pos.xy - sunPos.xy) / _SunSize * 0.5 + 0.5;

                    return 0.6 * SAMPLE_TEXTURE2D(_MoonTex, sampler_MoonTex, uv);
                }
                // sun
                else{
                    return _Main_Light_Intensity;
                }
                
            }

            float4 renderStar(float3 v)
            {
                if (v.y < 0)
                return 0;
                float intensity = 8;
                intensity = lerp(0, 2, pow(v.y, 0.9));
                float fade = saturate(1 - 3 * (_MainLightPosition.y));
                // v.y = 1 - ( 0.5 * v.y + 0.5);
                // float2 uv = (v.xz*12);// *(v.y+1);
                // float2 uv = (v.xz*12);// *(v.y+1);
                float _Star_Scale = 0.8;
                float speed = 0.05;
                float2 uv = v.xz / v.y * _Star_Scale + _Time.y * speed;
                float4 starColor = 1 - SAMPLE_TEXTURE2D(_StarTex, sampler_StarTex, uv);

                // return starColor ;

                float noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, uv).r;

                starColor *= step(0.93, starColor.r);

                starColor *= step(0.6, noise) * 100;
                return starColor * fade;
                return pow(starColor, intensity);
            }


            

            float4 frag(Varyings i) : SV_Target
            {

                setUp();
                float3 ro = 0;
                float3 rd = normalize(i.positionOS - ro);

                float start = 500;
                float end = getRaySphereIntersect(ro, rd, AtmosRadius).y;
                if(rd.y<-0.1)return _GroundColor;

                _Start_Pos = ro + rd * start;

                _End_Pos = ro + rd * end;
                _end = end;
                float3 v = normalize(i.positionOS.xyz);

                float dis = distance(sunPos, v);
                bool aboveHorizon = i.positionOS.y > 0;

                float4 sunColor = renderSunandMoon(v, isMoon);

                float4 skyColor = RayMarching(_Start_Pos, rd);
                float4 starColor =  renderStar(v);

                return  skyColor + skyColor.a *(sunColor +starColor); //+float4(0.5,0.2,0.2,1);
            }
            ENDHLSL
        }
    }
}
