Shader "Custom/Hidden/AlphaBlend"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex;
            // TEXTURE2D(_CameraOpaqueTexture);
            // SAMPLER(sampler_CameraOpaqueTexture);
            sampler2D _CameraOpaqueTexture;
            fixed4 frag (v2f i) : SV_Target
            {
                float4 color = tex2D(_CameraOpaqueTexture , i.uv);
                float4 cloud  = tex2D(_MainTex, i.uv);
                // just invert the colors
                // col.rgb = 1 - col.rgb;
                // return cloud.a;
               // if(cloud.r < 0.01) cloud.a = 0;
                color.rgb = cloud.rgb * cloud.a + color.rgb * (1 - cloud.a);
                return color;
            }
            ENDCG
        }
    }
}
