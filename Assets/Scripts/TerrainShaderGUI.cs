using System.Collections;
using System.Collections.Generic;
using UnityEngine;

using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.Linq;
public class TerrainShaderGUI : CustomShaderGUI
{

    public override void OnGUI(
        MaterialEditor editor, MaterialProperty[] properties
    )
    {
        base.OnGUI(editor, properties);
        editor.TexturePropertySingleLine(
         MakeLabel("Height Map"), FindProperty("_HeightMap")
     );
        editor.ShaderProperty(FindProperty("_TessellationUniform"), MakeLabel("Tessellation Uniform"));
        editor.ShaderProperty(FindProperty("_DisplacementStrength"), MakeLabel("Displacement Strength"));



        DoMaps();
        DoBlending();
        DoOtherSettings();
    }

    void DoMaps()
    {



        editor.ShaderProperty(FindProperty("_MapScale"), MakeLabel("Map Scale"));

        ////////////////////////////////////////////////////////////////////////////////////////////////

        GUILayout.Label("Top Maps", EditorStyles.boldLabel);

        editor.ShaderProperty(FindProperty("_TopThreshold"), MakeLabel("Top Threshold"));

        editor.ShaderProperty(FindProperty("_TopBaseColor"), MakeLabel("Top Base Color"));

        MaterialProperty topAlbedo = FindProperty("_TopAlbedoMap");
        Texture topTexture = topAlbedo.textureValue;
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(MakeLabel("Albedo"), topAlbedo);
        if (EditorGUI.EndChangeCheck() && topTexture != topAlbedo.textureValue)
        {
            SetKeyword("_SEPARATE_TOP_MAPS", topAlbedo.textureValue);
        }


        editor.TexturePropertySingleLine(
            MakeLabel("Normal"), FindProperty("_TopNormalMap")
        );
        editor.TexturePropertySingleLine(
            MakeLabel("AO"), FindProperty("_TopAOMap")
        );
        editor.TexturePropertySingleLine(
            MakeLabel("Roughness"), FindProperty("_TopRoughnessMap")
        );

        ////////////////////////////////////////////////////////////////////////////////////////////////

        GUILayout.Label("Maps", EditorStyles.boldLabel);
        editor.ShaderProperty(FindProperty("_BaseColor"), MakeLabel("Base Color"));

        editor.TexturePropertySingleLine(
           MakeLabel("Albedo"), FindProperty("_AlbedoMap")
       );
        editor.TexturePropertySingleLine(
            MakeLabel("Normal"), FindProperty("_NormalMap")
        );
        editor.TexturePropertySingleLine(
            MakeLabel("AO"), FindProperty("_AOMap")
        );
        editor.TexturePropertySingleLine(
            MakeLabel("Roughness"), FindProperty("_RoughnessMap")
        );



    }

    void DoBlending() { }

    void DoOtherSettings()
    {
        GUILayout.Label("Other Settings", EditorStyles.boldLabel);

        editor.RenderQueueField();
        editor.EnableInstancingField();
    }
}