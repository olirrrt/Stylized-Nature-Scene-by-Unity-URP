using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class VolumetricCloud : MonoBehaviour
{
    // https://docs.unity3d.com/cn/current/ScriptReference/Bounds.html
    private Vector4 bbox_Min;
    private Vector4 bbox_Max;
    private Material material;
    private Collider m_Collider;
    // private Matrix4x4 WorldToCubeMat;
    static readonly int bboxMinProperty = Shader.PropertyToID("_bbox_Min");
    static readonly int bboxMaxProperty = Shader.PropertyToID("_bbox_Max");
    static readonly int TransformProperty = Shader.PropertyToID("_Transform");


    void UpdateData()
    {
        bbox_Min = m_Collider.bounds.min;
        bbox_Max = m_Collider.bounds.max;


        material.SetVector(bboxMinProperty, bbox_Min);
        material.SetVector(bboxMaxProperty, bbox_Max);

        material.SetVector(TransformProperty, new Vector4(this.transform.position.y, this.transform.lossyScale.y, 0, 0));
        print(bbox_Min + " " + bbox_Max);

        /* Vector3 P = this.transform.position;
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
         */

    }
    void Awake()
    {
        this.m_Collider = this.GetComponent<Collider>();

        this.material = this.GetComponent<MeshRenderer>().material;

        UpdateData();
    }

    void Update()
    {
        // print(new Vector4(this.transform.position.y, this.transform.lossyScale.y, 0, 0));

        //this.transform.position.x += 1 * Time.deltaTime * Time.time;
        this.transform.Translate(0.1f, 0, 0);
        UpdateData();


    }
}
