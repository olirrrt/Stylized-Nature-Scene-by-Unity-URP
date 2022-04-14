Shader "Custom/Simple Far Lights"
{
    Properties
    {
        _BaseColor("Base Color", color)  = (1, 1, 1, 1)
        _MainTex ("Texture", 2D) = "white" {}

        _Strength("Strength", range(0,50)) = 6
        [Toggle] _Spark("Spark", float) = 0
    }
    SubShader
    {
        Tags {   
            "Queue" = "Transparent"
            
        }
        Cull OFF
        LOD 100
        Blend SrcAlpha OneMinusSrcAlpha
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            #pragma multi_compile  _SPARK_OFF _SPARK_ON

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _BaseColor;
            float _Strength;
            float _sparkStrength;

            // integer hash
            float hash( int n ) 
            {
                n = (n << 13) ^ n;
                n = n * (n * n * 15731 + 789221) + 1376312589;
                return -1.0+2.0*float( n &  (0x0fffffff))/float(0x0fffffff);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                // float noise = step(0, hash(_Time.y/10));
                //if(noise == 0)_Strength=1;
                
                #if _SPARK_ON
                    
                    //_Strength *= clamp(hash(_Time.y * 10), 0.6, 1);               
                    _Strength *= lerp( 0.6, 1, hash(_Time.y * 10)*0.5+0.5);

                #endif

                col.rgb = _Strength * _BaseColor;
                // apply fog
                //UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
