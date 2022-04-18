using System.Collections;
using System.Collections.Generic;
using UnityEngine;
[ExecuteInEditMode]
public class NormalsfromViewtoWorld : MonoBehaviour
{

    static int matPropertyToID = Shader.PropertyToID("_CamToWorld");
    private Camera cam;

    private void Start()
    {
        //get the camera and tell it to render a depthnormals texture
        cam = GetComponent<Camera>();
        cam.depthTextureMode = cam.depthTextureMode | DepthTextureMode.DepthNormals;
    }

 
    private void Update()
    {
// Camera.current
        Shader.SetGlobalMatrix(matPropertyToID, cam.cameraToWorldMatrix);
       // print(cam.cameraToWorldMatrix);
        // Graphics.Blit(source, destination, postprocessMaterial);
    }
}