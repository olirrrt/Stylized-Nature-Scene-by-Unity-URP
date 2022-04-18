Shader "Custom/Snow"
{
    Properties{
        
        
        _HeightMap("Height Map", 2D) = "" {}
        _MapScale ("Map Scale" , Vector) = (1, 1, 0, 0)

        _TessellationUniform ("Tessellation Uniform", Range(1, 64)) = 1

        _DisplacementStrength("Displacement Strength", Range(0, 10)) = 1

        _BaseColor ("Base Color", Color) = (0, 0, 0, 0)
        [NoScaleOffset]_AlbedoMap("Albedo Map", 2D) = "" {}
        [NoScaleOffset]_NormalMap("Normal Map", 2D) ="bump" {}
        [NoScaleOffset]_RoughnessMap("Roughness",2D)=" "{}        
        [NoScaleOffset]_AOMap("AO",2D)=" "{}

        

    }

    SubShader
    {
        Tags{
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
        }

        HLSLINCLUDE            
        
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        
        

        float _DisplacementStrength;

        // (1/x, 1/y, x, y)
        float4 _HeightMap_TexelSize;
        // (tiling, offset)
        float4 _HeightMap_ST;

       // #define _HeightMap _SnowHeightMap
       // #define sampler_HeightMap sampler_SnowHeightMap

        TEXTURE2D(_HeightMap);
        SAMPLER(sampler_HeightMap);

        
        ENDHLSL
        
        Pass
        {
            Tags{"LightMode" = "UniversalForward"}
            HLSLPROGRAM  
            #include "../Surface.hlsl"
            #include "../Common.hlsl"

            #pragma vertex MyTessellationVertexProgram
            #pragma fragment frag
            #pragma hull hull
            #pragma domain domain
            #pragma target 4.6
            #pragma shader_feature _SEPARATE_TOP_MAPS

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            float4 _MapScale;
            float4 _TopBaseColor;
            float _TopThreshold;
            /**float4 _AlbedoMap_ST;
            float4 _NormalMap_ST;
            float4 _AOMap_ST;
            float4 _RoughnessMap_ST;  */ 

            TEXTURE2D(_AlbedoMap);
            SAMPLER(sampler_AlbedoMap);

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            TEXTURE2D(_RoughnessMap);
            SAMPLER(sampler_RoughnessMap); 
            
            TEXTURE2D(_AOMap);
            SAMPLER(sampler_AOMap);
            
            TEXTURE2D(_TopAlbedoMap);
            SAMPLER(sampler_TopAlbedoMap);

            TEXTURE2D(_TopNormalMap);
            SAMPLER(sampler_TopNormalMap);

            TEXTURE2D(_TopRoughnessMap);
            SAMPLER(sampler_TopRoughnessMap); 
            
            TEXTURE2D(_TopAOMap);
            SAMPLER(sampler_TopAOMap);

            // TEXTURE2D(_WaterDepthMap);
            // SAMPLER(sampler_WaterDepthMap);

            

            float3 getVertex(float3 v){

                #define _VertMin 5
                #define _VertMax -5
                #define _UVMin 0
                #define _UVMax 1

                float2 uv=(v.xz - _VertMin) / (_VertMax - _VertMin)* (_UVMax - _UVMin) + _UVMin;
                v += float3(0, 1, 0) * SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap,  uv, 0).r;//*_DisplacementStrength;
                return v;
            }

            
            Varyings vert(Attributes i)
            {
                // Varyings o;
                //  o.uv = TRANSFORM_TEX(i.uv, _HeightMap);
                

                i.positionOS.xyz +=_DisplacementStrength* i.normal * SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, i.uv, 0).r;
                float offset=_HeightMap_TexelSize.x * 0.5;
                offset=0.05;
                float2 du = float2(offset, 0);
                float u1 = SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, i.uv - du,0).r;
                float u2 = SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, i.uv + du,0).r;
                float3 tu =float3 (1, u2 - u1, 0);
                
                float2 dv= float2(0, offset);
                float v1 = SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, i.uv - dv,0).r;
                float v2 = SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, i.uv + dv,0).r;
                float3 tv = float3(0, v2 - v1, 1);
                
                i.normal = normalize(cross(tv, tu));

                ////////////////////////////////////////////////////////////////////////////////////

                ///  o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                //  o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
                // o.positionSC = ComputeScreenPos(o.positionCS);
                
                
                // o.normalWS = TransformObjectToWorldNormal(i.normal);

                // o.fogFactor = ComputeFogFactor(o.positionCS.z);
                //  return o;
                Varyings o;
                
                // Vertex Position
                VertexPositionInputs positionInputs = GetVertexPositionInputs(i.positionOS.xyz);
                o.positionCS = positionInputs.positionCS;
                #ifdef REQUIRES_WORLD_SPACE_POS_INTERPOLATOR
                    o.positionWS = positionInputs.positionWS;
                #endif
                // UVs & Vertex Colour
                ///  o.uv = TRANSFORM_TEX(i.uv, _BaseMap);
                o.uv =  i.uv ;

                // _MapScale
                o.color = i.color;
                
                // View Direction
                o.viewDirWS = GetWorldSpaceViewDir(positionInputs.positionWS);
                
                // Normals & Tangents
                VertexNormalInputs normalInputs = GetVertexNormalInputs(i.normal, i.tangentOS);
                o.normalWS =  normalInputs.normalWS;
                #ifdef _NORMALMAP
                    real sign = i.tangentOS.w * GetOddNegativeScale();
                    o.tangentWS = half4(normalInputs.tangentWS.xyz, sign);
                #endif
                
                // Vertex Lighting & Fog
                half3 vertexLight = VertexLighting(positionInputs.positionWS, normalInputs.normalWS);
                half fogFactor = ComputeFogFactor(positionInputs.positionCS.z);
                o.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
                
                // Baked Lighting & SH (used for Ambient if there is no baked)
                OUTPUT_LIGHTMAP_UV(i.lightmapUV, unity_LightmapST, o.lightmapUV);
                OUTPUT_SH(o.normalWS.xyz, o.vertexSH);
                
                // Shadow Coord
                #ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
                    o.shadowCoord = GetShadowCoord(positionInputs);
                #endif
                return o;
            }

            #include "Tessellation.hlsl"

            float3 BlendTriplanarNormal(float3 mappedNormal, float3 surfaceNormal) {
                float3 n;
                n.xy = mappedNormal.xy + surfaceNormal.xy;
                n.z = mappedNormal.z * surfaceNormal.z;
                return n;
            }
            
            void triplanarProj(float3 positionWS, float3 weight, inout   SurfaceData surfaceData , float4 baseColor,
            Texture2D _AlbedoMap, sampler sampler_AlbedoMap, Texture2D _AOMap, sampler sampler_AOMap, Texture2D  _RoughnessMap, sampler sampler_RoughnessMap){
                
                //float3 N = normalize( normalWS);
                //float3 weight = (abs(N))/(N.x + N.y + N.z);
                
                float3 albedoX = SAMPLE_TEXTURE2D(_AlbedoMap, sampler_AlbedoMap, positionWS.yz * _MapScale.xy).rgb;
                float3 albedoY = SAMPLE_TEXTURE2D(_AlbedoMap, sampler_AlbedoMap, positionWS.xz * _MapScale.xy).rgb;   
                float3 albedoZ = SAMPLE_TEXTURE2D(_AlbedoMap, sampler_AlbedoMap, positionWS.xy * _MapScale.xy).rgb;
                float3 albedo = albedoX * weight.x + albedoY  * weight.y + albedoZ * weight.z;
                surfaceData.albedo =  albedo * baseColor.rgb;

                float3 aoX = SAMPLE_TEXTURE2D(_AOMap, sampler_AOMap, positionWS.yz * _MapScale.xy).rgb;
                float3 aoY = SAMPLE_TEXTURE2D(_AOMap, sampler_AOMap, positionWS.xz * _MapScale.xy).rgb;   
                float3 aoZ = SAMPLE_TEXTURE2D(_AOMap, sampler_AOMap, positionWS.xy * _MapScale.xy).rgb;
                surfaceData.occlusion = (aoX * weight.x + aoY  * weight.y + aoZ * weight.z).r;
                
                float3 roughnessX = SAMPLE_TEXTURE2D(_RoughnessMap, sampler_RoughnessMap, positionWS.yz * _MapScale.xy).rgb;
                float3 roughnessY = SAMPLE_TEXTURE2D(_RoughnessMap, sampler_RoughnessMap, positionWS.xz * _MapScale.xy).rgb;   
                float3 roughnessZ = SAMPLE_TEXTURE2D(_RoughnessMap, sampler_RoughnessMap, positionWS.xy * _MapScale.xy).rgb;
                float roughness = (roughnessX * weight.x + roughnessY  * weight.y + roughnessZ * weight.z).r;
                surfaceData.smoothness = 1-roughness;
                
            }

            half4 frag(Varyings i) : SV_Target
            {   

                clip(i.normalWS.y-0.4);
               // return 1;
                //float4 SnowColor
                //  return SAMPLE_TEXTURE2D(_HeightMap,sampler_HeightMap,i.uv);
                // return float4(i.normalWS.x,i.normalWS.y,i.normalWS.z,1);
                //  if (i.normalWS.y <= 0.9)  return 0;
                // else  return float4(0,1,0,1);
                SurfaceData surfaceData = (SurfaceData)0;
                // triplanar Projection
                float3 N = normalize(i.normalWS);
                float3 weight = (abs(N))/(N.x + N.y + N.z);
                float3 albedo  = float3(0, 0, 0);
                float  ao = 0;
                float roughness = 0; 
                
                float3 tNormalX = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.positionWS.yz * _MapScale.xy));
                float3 tNormalY = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.positionWS.xz * _MapScale.xy));   
                float3 tNormalZ = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.positionWS.xy * _MapScale.xy));
                if (i.normalWS.x < 0) {
                    tNormalX.x *= (-1); 
                }
                if (i.normalWS.y < 0) {
                    tNormalY.x *= (-1); 
                }
                if (i.normalWS.z >= 0) {
                    tNormalZ.x *= (-1);
                }
                
                float3 worldNormalX = BlendTriplanarNormal(tNormalX, i.normalWS.zyx).zyx;
                float3 worldNormalY = BlendTriplanarNormal(tNormalY, i.normalWS.xzy).xzy;
                float3 worldNormalZ = BlendTriplanarNormal(tNormalZ, i.normalWS);                
                
                float3 normalWS = worldNormalX * weight.x + worldNormalY  * weight.y + worldNormalZ * weight.z;
                i.normalWS = normalize(normalWS);
                
                #if defined(_SEPARATE_TOP_MAPS)
                    //
                    if (i.normalWS.y > _TopThreshold) {
                        //return 1;
                        triplanarProj(i.positionWS,weight, surfaceData, _TopBaseColor,
                        _TopAlbedoMap, sampler_TopAlbedoMap, _TopAOMap, sampler_TopAOMap,_TopRoughnessMap, sampler_TopRoughnessMap );
                        
                    }else
                #endif
                triplanarProj(i.positionWS, weight, surfaceData, _BaseColor,
                _AlbedoMap, sampler_AlbedoMap, _AOMap, sampler_AOMap,_RoughnessMap, sampler_RoughnessMap );
                
                ////////////////////////////////////////////////////////////////////////////////////////////////
                // if (i.normalWS.y <= 0.98 )  return 0;
                // else  return float4(0,1,0,1);
                
                

                //surfaceData.albedo =  albedo * _BaseColor.rgb;
                surfaceData.metallic = 0.3;
                //surfaceData.smoothness = 1-roughness;
                //surfaceData.occlusion = ao;
                InputData inputData = InitializeInputData(i, surfaceData.normalTS);
                
                half3 color = UniversalFragmentPBR(inputData, surfaceData);
                
                ////////////////////////////////////////////////////////////////////////////////////////////////

                


                color.rgb = MixFog(color.rgb, inputData.fogCoord);
                return float4(color.x,color.y,color.z,1);
            }
            ENDHLSL
        }
        
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM 
            //  #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "CostumnShadowCasterPass.hlsl"
            // #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.6 

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            // -------------------------------------
            // Universal Pipeline keywords

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #pragma shader_feature _PARALLAX_MAP
            #pragma shader_feature _TESSELLATION_EDGE
            // #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment 
            #pragma vertex MyTessellationVertexProgram
            #pragma hull hull
            #pragma domain domain
            
            
            ENDHLSL
        }

    }
    
    

}
