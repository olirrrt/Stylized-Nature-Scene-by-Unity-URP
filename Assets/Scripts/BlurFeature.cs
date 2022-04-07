using UnityEngine;
using UnityEngine.Rendering.Universal;

public class BlurFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class PassSettings
    {
        // Where/when the render pass should be injected during the rendering process.
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingTransparents;

     // Used for any potential down-sampling we will do in the pass.
        [Range(1,4)] public int downsample = 1;
        
        // A variable that's specific to the use case of our pass.
        [Range(0, 20)] public int blurStrength = 5;
         [Range(0, 200)] public float blurWidth = 15;
 
        // additional properties ...
        public Material material;

        public RenderTexture rt;

    }

    // References to our pass and its settings.
    BlurPass pass;
    public PassSettings passSettings = new PassSettings();

    // Gets called every time serialization happens.
    // Gets called when you enable/disable the renderer feature.
    // Gets called when you change a property in the inspector of the renderer feature.
    public override void Create()
    {
        // Pass the settings as a parameter to the constructor of the pass.
        pass = new BlurPass(passSettings);
    }

    // Injects one or multiple render passes in the renderer.
    // Gets called when setting up the renderer, once per-camera.
    // Gets called every frame, once per-camera.
    // Will not be called if the renderer feature is disabled in the renderer inspector.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // Here you can queue up multiple passes after each other.
        renderer.EnqueuePass(pass);
        pass.SetCameraColorTarget(renderer.cameraColorTarget);

    }
}
