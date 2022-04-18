//using System.Collections;
//using System.Collections.Generic;

using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
public class ScreenSpaceSnow : ScriptableRendererFeature
{

    [System.Serializable]
    public class ScreenSpaceSnowSettings
    {
        //[Header("Properties")]
        //[Range(0.1f, 1f)]
        public Material snowMaterial;


    }

    class ScreenSpaceSnowPass : ScriptableRenderPass
    {

           Material snowMaterial;

        RenderTargetIdentifier colorBuffer, temporaryBuffer;

        readonly static int tempBufferID = Shader.PropertyToID("_TemporaryBuffer");
        private RenderTargetIdentifier cameraColorTargetIdent;


        // 构造函数传递设置
        public ScreenSpaceSnowPass(ScreenSpaceSnowSettings settings)
        {
            //snowMaterial = new Material(Shader.Find("Custom/Hidden/Screen Space Snow"));           
             snowMaterial = settings.snowMaterial;

        }



        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in a performant manner.
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            //   get a copy of the current camera’s RenderTextureDescriptor.
            RenderTextureDescriptor descriptor = renderingData.cameraData.cameraTargetDescriptor;

            // 2 disable the depth buffer 
            // Set the number of depth bits we need for our temporary render texture.
            descriptor.depthBufferBits = 0;

            colorBuffer = renderingData.cameraData.renderer.cameraColorTarget;

            cmd.GetTemporaryRT(tempBufferID, descriptor, FilterMode.Bilinear);
            temporaryBuffer = new RenderTargetIdentifier(tempBufferID);
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {


            CommandBuffer cmd = CommandBufferPool.Get();


            using (new ProfilingScope(cmd, new ProfilingSampler("Screen Space Snow")))
            {

                Blit(cmd, colorBuffer, temporaryBuffer, snowMaterial);
                Blit(cmd, temporaryBuffer, colorBuffer);

            }


            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(tempBufferID);

        }
    }

    ScreenSpaceSnowPass m_ScriptablePass;
    public ScreenSpaceSnowSettings settings = new ScreenSpaceSnowSettings();

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new ScreenSpaceSnowPass(settings);

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    // Called every frame, once per camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);

    }
}


