Shader "Costumn/Surface"
{
    Properties{
        _BaseMap ("Base Texture", 2D) = "white" {}
        _BaseColor ("Example Colour", Color) = (0, 0.66, 0.73, 1)
        _Smoothness ("Smoothness", Float) = 0.5
        
        [Toggle(_ALPHATEST_ON)] _EnableAlphaTest("Enable Alpha Cutoff", Float) = 0.0
        _Cutoff ("Alpha Cutoff", Float) = 0.5
        
        [Toggle(_NORMALMAP)] _EnableBumpMap("Enable Normal/Bump Map", Float) = 0.0
        _BumpMap ("Normal/Bump Texture", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Float) = 1
        
        [Toggle(_EMISSION)] _EnableEmission("Enable Emission", Float) = 0.0
        _EmissionMap ("Emission Texture", 2D) = "white" {}
        _EmissionColor ("Emission Colour", Color) = (0, 0, 0, 0)
        
    }

    SubShader
    {
        Tags{
            // "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Surface.hlsl"


        

        TEXTURE2D(_HeightMap);
        SAMPLER(sampler_HeightMap);

        
        ENDHLSL
        
        Pass
        {
            Tags{"LightMode" = "UniversalForward"}
            HLSLPROGRAM
            // #pragma vertex MyTessellationVertexProgram
            //#pragma fragment frag
            #pragma vertex vert
            #pragma fragment frag
           // #pragma hull hull
           // #pragma domain domain
           // #pragma target 4.6
         

            
            TEXTURE2D(_AlbedoMap);
            SAMPLER(sampler_AlbedoMap);

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
            #if SHADER_LIBRARY_VERSION_MAJOR < 9
                // This function was added in URP v9.x.x versions
                // If we want to support URP versions before, we need to handle it instead.
                // Computes the world space view direction (pointing towards the viewer).
                float3 GetWorldSpaceViewDir(float3 positionWS) {
                    if (unity_OrthoParams.w == 0) {
                        // Perspective
                        return _WorldSpaceCameraPos - positionWS;
                        } else {
                        // Orthographic
                        float4x4 viewMat = GetWorldToViewMatrix();
                        return viewMat[2].xyz;
                    }
                }
            #endif
            
            Varyings vert(Attributes IN) {
                Varyings OUT;
                
                // Vertex Position
                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionCS = positionInputs.positionCS;
                #ifdef REQUIRES_WORLD_SPACE_POS_INTERPOLATOR
                    OUT.positionWS = positionInputs.positionWS;
                #endif
                // UVs & Vertex Colour
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.color = IN.color;
                
                // View Direction
                OUT.viewDirWS = GetWorldSpaceViewDir(positionInputs.positionWS);
                
                // Normals & Tangents
                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normal, IN.tangentOS);
                OUT.normalWS =  normalInputs.normalWS;
                #ifdef _NORMALMAP
                    real sign = IN.tangentOS.w * GetOddNegativeScale();
                    OUT.tangentWS = half4(normalInputs.tangentWS.xyz, sign);
                #endif
                
                // Vertex Lighting & Fog
                half3 vertexLight = VertexLighting(positionInputs.positionWS, normalInputs.normalWS);
                half fogFactor = ComputeFogFactor(positionInputs.positionCS.z);
                OUT.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
                
                // Baked Lighting & SH (used for Ambient if there is no baked)
                OUTPUT_LIGHTMAP_UV(IN.lightmapUV, unity_LightmapST, OUT.lightmapUV);
                OUTPUT_SH(OUT.normalWS.xyz, OUT.vertexSH);
                
                // Shadow Coord
                #ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
                    OUT.shadowCoord = GetShadowCoord(positionInputs);
                #endif
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target {
                SurfaceData surfaceData = InitializeSurfaceData(IN);
                InputData inputData = InitializeInputData(IN, surfaceData.normalTS);
                
                // In URP v10+ versions we could use this :
                // half4 color = UniversalFragmentPBR(inputData, surfaceData);
                
                // But for other versions, we need to use this instead.
                // We could also avoid using the SurfaceData struct completely, but it helps to organise things.
                half4 color = UniversalFragmentPBR(inputData, surfaceData.albedo, surfaceData.metallic, 
                surfaceData.specular, surfaceData.smoothness, surfaceData.occlusion, 
                surfaceData.emission, surfaceData.alpha);
                
                color.rgb = MixFog(color.rgb, inputData.fogCoord);
                
                // color.a = OutputAlpha(color.a);
                // Not sure if this is important really. It's implemented as :
                // saturate(outputAlpha + _DrawObjectPassData.a);
                // Where _DrawObjectPassData.a is 1 for opaque objects and 0 for alpha blended.
                // But it was added in URP v8, and versions before just didn't have it.
                // And I'm writing thing for v7.3.1 currently
                // We could still saturate the alpha to ensure it doesn't go outside the 0-1 range though :
                color.a = saturate(color.a);
                
                return color;
            }
            ENDHLSL
        }
        Pass
        {
            //  Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            
            
            
        }

    }
}
