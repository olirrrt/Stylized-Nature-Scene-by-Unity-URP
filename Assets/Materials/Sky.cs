using System.Collections;
using System.Collections.Generic;
using UnityEngine;
//[ExecuteInEditMode]

public class Sky : MonoBehaviour
{
    //public Sun sun;
    // Start is called before the first frame update
    float angle;// = Time.time % (360);
    [Range(1, 60)]
    public float speed = 5;
    void rotateSun()
    {
        //this.transform.position += new Vector3(0.75f, 0.0f, 0.0f);
        //this.light.
        //this.transform.Rotate(new Vector3(0, 0, 1), Time.time);
       // this.transform.Rotate(0, 0, Time.time * speed/50f , Space.World);
        Shader.SetGlobalVector("_SunDir", this.transform.forward);        
        Shader.SetGlobalFloat("_Speed",speed);

    }
    void OnGUI()
    {
        // string s = "vertex: " + verNum.ToString() + "\nindex: " + idxNum.ToString();
        float t=(Time.time *speed)%24;
        GUI.Label(new Rect(35, 35, 100, 50), (Time.time).ToString()+"\n"+((int)t).ToString()+":00");
    }
    void Start()
    {

    }

    // Update is called once per frame
    void Update()
    {
        rotateSun();
    }
}
