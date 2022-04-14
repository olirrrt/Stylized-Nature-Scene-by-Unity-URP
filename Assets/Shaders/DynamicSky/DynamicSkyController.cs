using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class DynamicSkyController : MonoBehaviour
{

    //[Header("Skybox Settings")]
    public Light sun;
    // public Light moon;
    [Range(-90, 90)]
    public float sunAxis = -90;
    public bool play;
    public Gradient sunColor;
    public Gradient groundColor;
    public Gradient fogColor;
    // 每秒度数，“一天”时长360/timeElapseSpeed
    [Range(0.001f, 360f)]
    public float timeElapseSpeed = 60f;
    public Material skybox;

    float daySpan;

    float lastTime;
    float myTime;
    bool flag = true;

    async void UpdateByTime()
    {


        float t = remapTime();




        sun.transform.rotation *= Quaternion.AngleAxis(Time.deltaTime * timeElapseSpeed, Vector3.up);
        sun.color = sunColor.Evaluate(t);
        skybox.SetColor("_GroundColor", groundColor.Evaluate(t));
        RenderSettings.fogColor = fogColor.Evaluate(t);


    }
    void OnGUI()
    {
        // string s = "vertex: " + verNum.ToString() + "\nindex: " + idxNum.ToString();
       // float t = remapTime();
        //GUI.Label(new Rect(35, 35, 100, 50), t.ToString() + " " + "_isNight" + flag);
    }

    float remapTime()
    {
        //float 
        // print(Time.time + " 度数" + (Time.time % daySpan / daySpan) + " ");
        // if ( lastTime != Time.time)
        return (Time.time) % daySpan / daySpan;
    }
    void Awake()
    {
        lastTime = Time.time;
        myTime = Time.time;
        daySpan = 360f / timeElapseSpeed;
        sun.transform.rotation = Quaternion.AngleAxis(sunAxis, Vector3.forward);
        RenderSettings.fog = true;

    }

    // Update is called once per frame
    void Update()
    {
        //if (play && lastTime != Time.time)
        if (play)
        {
            UpdateByTime();
         //   if (lastTime != Time.time)
           //     myTime
        //     lastTime = Time.time;
        }

    }
}
