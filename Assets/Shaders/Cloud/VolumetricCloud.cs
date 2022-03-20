using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class VolumetricCloud : MonoBehaviour
{
    // https://docs.unity3d.com/cn/current/ScriptReference/Bounds.html
    private Vector4 bbox_Min;
    private Vector4 bbox_Max;

    [Range(0, 1)]
    public float _UVScale;

    [Range(0, 1)]
    public float _Step=0.2f;  
    
    [Range(0, 20)]
    public float _Density_Strength=5;
    // private Matrix4x4 WorldToCubeMat;

    void UpdateData()
    {
        Collider m_Collider = this.GetComponent<Collider>();
        bbox_Min = m_Collider.bounds.min;
        bbox_Max = m_Collider.bounds.max;

        //https://docs.unity3d.com/cn/current/ScriptReference/Shader.html
        Shader.SetGlobalVector("_bbox_Min", bbox_Min);
        Shader.SetGlobalVector("_bbox_Max", bbox_Max);

        _UVScale = 0.15f;
        Shader.SetGlobalFloat("_UVScale", _UVScale);


        Vector3 P = this.transform.position;
        Vector3 R = this.transform.right;
        Vector3 U = this.transform.up;
        Vector3 V = this.transform.forward;
        // Vector3 V = -1 * this.transform.forward;

        Matrix4x4 rotateMat = Matrix4x4.identity;
        rotateMat.SetRow(0, new Vector4(R.x, R.y, R.z, 0));
        rotateMat.SetRow(1, new Vector4(U.x, U.y, U.z, 0));
        rotateMat.SetRow(2, new Vector4(V.x, V.y, V.z, 0));

        Matrix4x4 transMat = Matrix4x4.identity;
        transMat.SetColumn(3, new Vector4(-P.x, -P.y, -P.z, 1));

        Matrix4x4 WorldToCubeMat = rotateMat * transMat;

        Shader.SetGlobalMatrix("_WorldToCubeMat", WorldToCubeMat);

        //_Step = 0.2f;
        Shader.SetGlobalFloat("_Step", _Step);
         Shader.SetGlobalFloat("_Density_Strength", _Density_Strength);

    }
    void Start()
    {

        UpdateData();
    }

    void Update()
    {
        // bbox_Min = m_Collider.bounds.min;
        // bbox_Max = m_Collider.bounds.max;
        //UpdateData();
        print(bbox_Min + " " + bbox_Max);
        // lambda?
        //if()
        Shader.SetGlobalFloat("_UVScale", _UVScale);
        Shader.SetGlobalVector("_bbox_Min", bbox_Min);
        Shader.SetGlobalFloat("_Step", _Step);

         Shader.SetGlobalVector("_bbox_Max", bbox_Max);
         Shader.SetGlobalFloat("_Density_Strength", _Density_Strength);

    }
}
