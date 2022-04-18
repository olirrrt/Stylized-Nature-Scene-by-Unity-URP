using System.Collections;

using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Experimental.Rendering;

public class VolumetricCloud : ScriptableRendererFeature
{
    [System.Serializable]
    public class PassSettings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingTransparents;

        [Range(1, 8)] public int Resolution = 1;
        public Material cloudMaterial;

    }



    class VolCloudPass : ScriptableRenderPass
    {
        const string ProfilerTag = "Volumetric Cloud Pass";

        PassSettings passSettings;

        RenderTargetIdentifier colorBuffer, temporaryBuffer;
        int temporaryBufferID = Shader.PropertyToID("_TemporaryCloudBuffer");

        int Resolution;
        Material cloudMaterial;
        Material blendMaterial;

        public VolCloudPass(PassSettings passSettings)
        {
            this.passSettings = passSettings;
            Resolution = passSettings.Resolution;
            renderPassEvent = passSettings.renderPassEvent;

            cloudMaterial = passSettings.cloudMaterial;
            if (blendMaterial == null) blendMaterial = CoreUtils.CreateEngineMaterial("Custom/Hidden/AlphaBlend");

        }

        // Gets called by the renderer before executing the pass.
        // Can be used to configure render targets and their clearing state.
        // Can be user to create temporary render target textures.
        // If this method is not overriden, the render pass will render to the active camera render target.
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            RenderTextureDescriptor descriptor = renderingData.cameraData.cameraTargetDescriptor;


            descriptor.width /= Resolution;
            descriptor.height /= Resolution;

            // Set the number of depth bits we need for our temporary render texture.
            descriptor.depthBufferBits = 8;

            descriptor.graphicsFormat = GraphicsFormat.R16G16B16A16_SFloat;

            // Enable these if your pass requires access to the CameraDepthTexture or the CameraNormalsTexture.
            // ConfigureInput(ScriptableRenderPassInput.Depth);
            // ConfigureInput(ScriptableRenderPassInput.Normal);

            colorBuffer = renderingData.cameraData.renderer.cameraColorTarget;


            cmd.GetTemporaryRT(temporaryBufferID, descriptor, FilterMode.Bilinear);
            temporaryBuffer = new RenderTargetIdentifier(temporaryBufferID);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, new ProfilingSampler(ProfilerTag)))
            {
                //context.ExecuteCommandBuffer(cmd);
                //cmd.Clear();

                // ?闪烁
                  Blit(cmd, colorBuffer, temporaryBuffer, cloudMaterial, 0);
                  Blit(cmd, temporaryBuffer, colorBuffer, blendMaterial, 0);

               //   Blit(cmd, temporaryBuffer, colorBuffer, cloudMaterial, 0);

            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }


        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            if (cmd == null) throw new ArgumentNullException("cmd");

            cmd.ReleaseTemporaryRT(temporaryBufferID);
        }
    }

    VolCloudPass pass;
    public PassSettings passSettings = new PassSettings();




    // Gets called every time serialization happens./enable/disable the renderer feature.
    public override void Create()
    {
        pass = new VolCloudPass(passSettings);
        pass.renderPassEvent = passSettings.renderPassEvent;
    }

    // Injects one or multiple render passes in the renderer.
    // Gets called when setting up the renderer, once per-camera.
    // Gets called every frame, once per-camera.
    // Will not be called if the renderer feature is disabled in the renderer inspector.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(pass);
    }
}