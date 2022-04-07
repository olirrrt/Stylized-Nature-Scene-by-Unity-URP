Shader "Costumn/Simplest Ray Marching"
{
    Properties
    {
    }

    SubShader
    {
        Tags{
            "RenderType" = "Opaque"
        "RenderPipeline" = "UniversalPipeline"}

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "../Common.hlsl"
        ENDHLSL

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

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
            };

            Varyings vert(Attributes i)
            {
                Varyings o;
                o.positionHCS = TransformObjectToHClip(i.positionOS.xyz);
                o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
                o.positionSS = ComputeScreenPos(o.positionHCS);
                o.normal = TransformObjectToWorldNormal(i.normal);
                o.uv = i.uv;
                return o;
            }

            // https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
            // p:射线pos-物体中心位置
            float sdSphere(float3 p, float radius)
            {
                return length(p) - radius;
            }

            // Box
            float sdBox(float3 p, float3 b)
            {
                float3 q = abs(p) - b;
                return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
            }

            // Torus甜甜圈
            float sdTorus(float3 p, float2 t)
            {
                float2 q = float2(length(p.xz) - t.x, p.y);
                return length(q) - t.y;
            }

            // Cone - exact
            float sdCone(float3 p, float2 c, float h)
            {
                // c is the sin/cos of the angle, h is height
                // Alternatively pass q instead of (c,h),
                // which is the point at the base in 2D
                float2 q = h * float2(c.x / c.y, -1.0);

                float2 w = float2(length(p.xz), p.y);
                float2 a = w - q * clamp(dot(w, q) / dot(q, q), 0.0, 1.0);
                float2 b = w - q * float2(clamp(w.x / q.x, 0.0, 1.0), 1.0);
                float k = sign(q.y);
                float d = min(dot(a, a), dot(b, b));
                float s = max(k * (w.x * q.y - w.y * q.x), k * (w.y - q.y));
                return sqrt(d) * sign(s);
            }

            float sdf(float3 pos)
            {
                float minDis1 = sdSphere(pos - float3(6, 3, 0), 3);
                float minDis2 = sdBox(pos - float3(-6, 3, 0), float3(3, 2.5, 1));
                float minDis3 = sdTorus(pos - float3(-6, -4, 0), float2(2, 1.5));
                float minDis4 = sdCone(pos - float3(6, -2, 0), float2(1, 1), 3);

                return min(minDis4, min(minDis3, min(minDis1, minDis2)));
            }

            #define Radius 4
            #define Center float3(0, 0, 0)

            float3 getNormal(float3 pos)
            {

                float3 delta = float3(0.001, 0, 0);

                float dx = sdSphere(pos + delta.xyy - Center, Radius) - sdSphere(pos - delta.xyy - Center, Radius);
                float dy = sdSphere(pos + delta.yxy - Center, Radius) - sdSphere(pos - delta.yxy - Center, Radius);
                float dz = sdSphere(pos + delta.yyx - Center, Radius) - sdSphere(pos - delta.yyx - Center, Radius);

                return normalize(float3(dx, dy, dz));
            }

            float4 RayMarching(float3 ro, float3 rd)
            {
                #define START_DISTANCE _ProjectionParams.y
                #define END_DISTANCE 100
                #define MAX_ITER 32

                float dis = START_DISTANCE;

                for (int i = 0; i < MAX_ITER; ++i)
                {
                    float3 pos = ro + dis * rd;

                    // 距离其他点的最短距离、最大可以步进的距离
                    // float minDistance = sdSphere(pos - Center, Radius);
                    float minDistance = sdf(pos);

                    // 不是固定步长
                    dis += minDistance;

                    // hit
                    if (minDistance < 0.01)
                    {
                        // return float4(getNormal(pos), 1) * 0.5 + 0.5;
                        return dis / 26;
                    }

                    // 到达最大预设距离
                    if (dis > END_DISTANCE)
                    {
                        break;
                    }
                }
                // 返回背景颜色
                return 0;
            }



            half4 frag(Varyings i) : SV_Target
            {
                // 非后处理：
                // float4 color = RayMarching(_WorldSpaceCameraPos, normalize(-_WorldSpaceCameraPos+i.positionWS));

                // 消除屏幕宽高比影响
                float aspect = _ScreenParams.x / _ScreenParams.y;

                // wrong: float2 screenUV = float2(2 * aspect, 2) * i.positionSS.xy / i.positionSS.w - 1;
                float2 screenUV = 2 * i.uv - 1;

                screenUV.y *= 1 / aspect;
                // screenUV.x *= aspect;

                // ro : ray origin
                // rd : ray direction
                float3 ro = _WorldSpaceCameraPos;

                // https://docs.unity3d.com/Manual/SL-UnityShaderVariables.html
                // _ProjectionParams.y：近平面
                // ?为什么近平面太小
                // float3 rd = normalize(float3(screenUV, _ProjectionParams.y));
                float3 rd = normalize(float3(screenUV, 1.2));

                rd = mul(getViewToWorldMatrix(), float4(rd, 1)).xyz;

                return RayMarching(ro, rd);
            }
            ENDHLSL
        }
    }
}