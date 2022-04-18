using System.Collections;
using System.Collections.Generic;
using UnityEngine;
 
[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class GetWaterDepth : MonoBehaviour
{
    public RenderTexture rt;
    RenderTexture tempBuffer;
 
    Camera cam;

    int width = 512;
    int height = 512;
    //int width = (int)(Screen.width); 
    // int height = (int)(Screen.height);
     private static readonly int waterDepthMap = Shader.PropertyToID("_WaterDepthTex");
    void getHeightRT()
    {


    }
    void Awake()
    {


        cam = GetComponent<Camera>();
        cam.enabled = true;

       // if (tempBuffer == null)
         //   tempBuffer = new RenderTexture(1024, 1024, 24, RenderTextureFormat.Depth, RenderTextureReadWrite.Linear);

        if (rt == null)
            rt = new RenderTexture(1024, 1024, 24, RenderTextureFormat.Depth, RenderTextureReadWrite.Linear);



        // if (heightMaterial == null)
       // heightMaterial = new Material(Shader.Find("Custom/Hidden/Height"));

        //  Graphics.Blit(rt, tempBuffer, heightMaterial,0);
        // Graphics.Blit(tempBuffer, rt);
        //  tempBuffer.Release();

        cam.targetTexture = rt;
        cam.Render();

       // snowMaterial.SetTexture("_HeightMap", rt);
        Shader.SetGlobalTexture(waterDepthMap,   cam.targetTexture);
        cam.enabled = false;
        cam.targetTexture = null;


    }
    void Ondestory()
    {
        rt.Release();

    }

    // Update is called once per frame
    void Update()
    {

    }
}
