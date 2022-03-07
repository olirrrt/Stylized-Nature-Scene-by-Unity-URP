using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class GrassSpawner : MonoBehaviour
{
    // [SerializeField]
    // Transform test;

    [SerializeField]
    Material material;

    // [SerializeField]
    //Mesh planeMesh;

    [SerializeField]
    Mesh Grassmesh;

    [SerializeField, Range(1, 1000)]
    int GrassNum;
    [SerializeField]

    public Vector2 size;
    public int seed;
    Matrix4x4[] mats;
    MaterialPropertyBlock block;
    Vector4[] normals;
    void iniMatrices()
    {
        Random.InitState(seed);
        mats = new Matrix4x4[GrassNum];
        normals = new Vector4[GrassNum];
        for (int i = 0; i < GrassNum; i++)
        {
            Vector3 pos = this.transform.position;
            pos.y = 10;//50;
            pos.x += size.x * Random.Range(-0.5f, 0.5f);
            pos.z += size.y * Random.Range(-0.5f, 0.5f);

            Ray ray = new Ray(pos, Vector3.down);
            RaycastHit hit;
            if (Physics.Raycast(ray, out hit))
            {
                pos = hit.point;

                pos += new Vector3(0f, 1f, 0f);

                Vector3 normal = hit.normal;
                normals[i] = new Vector4(normal.x, normal.y, normal.z, 1f);

                float scale = Random.Range(0.5f, 1.2f);
                mats[i] = Matrix4x4.TRS(pos, Quaternion.FromToRotation(Vector3.up, normal), new Vector3(scale, scale, scale));
                // mats[i] = Matrix4x4.TRS(pos, Quaternion.Euler(0,0,0), new Vector3(100, 100, 100));

            }


        }
    }

    void Awake()
    {
        iniMatrices();

    }

    void Update()
    {

        if (block == null)
        {
            block = new MaterialPropertyBlock();
            block.SetVectorArray("_normal", normals);
        }

        //Grassmesh=test.GetCompont<MeshFilter>().mesh;
        Graphics.DrawMeshInstanced(Grassmesh, 0, material, mats, GrassNum, block);
    }
}
