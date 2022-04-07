using UnityEngine;
using System.Collections;
//using System.Collections.Generic;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]

public class PlanarReflection : MonoBehaviour
{


    //[SerializeField]
    RenderTexture rt;
    RenderTexture tempBuffer;

    [SerializeField]
    [Range(0.1f, 1)] float _textureResolution;

    public bool isBlur;
    [Range(0, 20)] public int blurStrength = 5;
    [Range(0, 200)] public float blurWidth = 15;

    [SerializeField]
    GameObject plane;
    private Camera cam;// = null;
                       // Renderer rend;

    static readonly int BlurStrengthProperty = Shader.PropertyToID("_BlurStrength");
    static readonly int BlurWidthProperty = Shader.PropertyToID("_BlurWidth");

    void Start()
    {
        // 必须有meshrenderer才能调用OnWillRenderObject
        // rend = GetComponent<Renderer>();
    }

    void getReflectionRT()
    {
        // SceneCamera Main Camera
        // current：null
        // current要挂一个相机并且enable
        //print(Camera.current.name + " " + Camera.main.name);

        // https://docs.unity3d.com/ScriptReference/RenderTexture-ctor.html
        if (rt == null)
            rt = RenderTexture.GetTemporary((int)(Screen.width * _textureResolution), (int)(Screen.height * _textureResolution), 0);

        //cam = new Camera();
        cam = this.GetComponent<Camera>();
        //scene窗口
        if (Camera.current != null)
            cam.CopyFrom(Camera.current);
        //play 窗口
        else if (Camera.main != null)
            cam.CopyFrom(Camera.main);

        //??一次只能有一个相机enabled
        // gamewindow是main camera啊
        cam.enabled = true;



        //  Camera.current只读 

        cam.targetTexture = rt;

        // 方法一
        // Matrix4x4 reverse = Matrix4x4.identity;
        // reverse[2, 2] = -1;
        //cam.transform.position = getRefMat(plane.transform.up, plane.transform.position).MultiplyPoint(cam.transform.position);
        // cam.worldToCameraMatrix = reverse * cam.worldToCameraMatrix;

        cam.worldToCameraMatrix = cam.worldToCameraMatrix * getRefMat(plane.transform.up, plane.transform.position);


        // https://docs.unity3d.com/ScriptReference/Camera.CalculateObliqueMatrix.html
        // var normal = plane.transform.up;
        // var d = -Vector3.Dot(normal, plane.transform.position);
        // var viewSpacePlane = cam.worldToCameraMatrix.inverse.transpose * (new Vector4(normal.x, normal.y, normal.z, d));
        // cam.projectionMatrix = cam.CalculateObliqueMatrix(viewSpacePlane);

        // 调整背面裁剪
        GL.invertCulling = true;
        cam.Render();
        GL.invertCulling = false;

        ////////////////////////////////////////////////////////////////////////
        // 竖直方向高斯模糊
        // 伪造掠角镜面反射
        if (isBlur)
        {
            if (tempBuffer == null)
                tempBuffer = RenderTexture.GetTemporary((int)(Screen.width * _textureResolution), (int)(Screen.height * _textureResolution), 0);
            Material blurMaterial = new Material(Shader.Find("Hidden/Box Blur"));


            blurMaterial.SetInt(BlurStrengthProperty, this.blurStrength);
            blurMaterial.SetFloat(BlurWidthProperty, this.blurWidth);
            Graphics.Blit(rt, tempBuffer, blurMaterial, 0);
            Graphics.Blit(tempBuffer, rt);
            tempBuffer.Release();
        }

        ////////////////////////////////////////////////////////////////////////

        //material.SetTexture("_PlanarReflectionTexture", rt);
        Shader.SetGlobalTexture("_PlanarReflectionTexture", rt);
        cam.targetTexture = null;

        cam.enabled = false;
    }

    // 调用renderer之前

    void OnWillRenderObject()
    {
        getReflectionRT();
    }


    static Matrix4x4 getRefMat(Vector3 n, Vector3 p)
    {
        Matrix4x4 mat = new Matrix4x4();
        mat.SetRow(0, new Vector4(1 - 2 * n.x * n.x, -2 * n.x * n.y, -2 * n.x * n.z, 2 * Vector3.Dot(p, n) * n.x));
        mat.SetRow(1, new Vector4(-2 * n.x * n.y, 1 - 2 * n.y * n.y, -2 * n.y * n.z, 2 * Vector3.Dot(p, n) * n.y));
        mat.SetRow(2, new Vector4(-2 * n.x * n.z, -2 * n.y * n.z, 1 - 2 * n.z * n.z, 2 * Vector3.Dot(p, n) * n.z));
        mat.SetRow(3, new Vector4(0, 0, 0, 1));
        return mat;
    }
    void Awake()
    {

    }
    void Ondestory()
    {
        rt.Release();

    }

    void Update()
    {
        getReflectionRT();
    }
}
