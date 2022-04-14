using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TerrainGenerator : MonoBehaviour
{
    //public Material mat1;
    public Material mat1;
    public Material mat2;
    public Material mat3;// mountain
    public Material mat4;

    public Texture2D splatMap;
    Mesh mesh;
     static int splatMapProperty = Shader.PropertyToID("_splatMap");
    Matrix4x4[] mats3;
    void GenerateTerrain()
    {

        Graphics.DrawMeshInstanced(this.mesh, 0, mat3, mats3);

    }

    void Awake()
    {
        Shader.SetGlobalTexture(splatMapProperty, splatMap);
        this.mesh = GetComponent<MeshFilter>().mesh;
        mats3[0] = this.transform.localToWorldMatrix;
       // mats3[0] = Matrix4x4.TRS(this.transform.position, this.transform.rotation, this.transform.scale);

    }

    // Start is called before the first frame update
    void Start()
    {

    }

    // Update is called once per frame
    void Update()
    {
        GenerateTerrain();
    }
}
