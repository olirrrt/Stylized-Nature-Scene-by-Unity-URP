using System.Collections;
using System.Collections.Generic;
using UnityEngine;
[ExecuteInEditMode]
public class WindController : MonoBehaviour
{

    public bool wind;

    [Range(0f, 5f)]
    public float windStrength = 1;
    [Range(0f, 5f)]
    public float windSpeed = 1;
    public Texture2D WindMap;
    static int windMapProperty = Shader.PropertyToID("_WindTex");
    static int windStrengthProperty = Shader.PropertyToID("_WindStrength");
    static int windSpeedProperty = Shader.PropertyToID("_WindSpeed");

    void updateData()
    {
        Shader.SetGlobalFloat(windStrengthProperty, windStrength);
        Shader.SetGlobalFloat(windSpeedProperty, windSpeed);
        Shader.SetGlobalTexture(windMapProperty, WindMap);

    }
    void Awake()
    {
        updateData();
    }
    // Start is called before the first frame update
    void Start()
    {

    }

    // Update is called once per frame
    void Update()
    {
        if (wind) updateData();
    }
}
