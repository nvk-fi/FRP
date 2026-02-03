using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Pipeline
{
	[Serializable]
	public class FRP : RenderPipeline
	{
		public readonly FRPRenderer Renderer;
		public readonly FRPSettings Settings;

		public FRP(FRPSettings frpSettings)
		{
			Renderer = new FRPRenderer(frpSettings);
			Settings = frpSettings;

			Settings.OnApply += Renderer.ApplySettings;
		}

		[Obsolete] protected override void Render(ScriptableRenderContext context, Camera[] cameras) { }
		protected override void Render(ScriptableRenderContext context, List<Camera> cameras)
		{
			FRPRenderer.Awake();
			
			Renderer.RenderSunShadowMap(context);
			
			foreach (var camera in cameras)
				Renderer.RenderCamera(context, camera);
		}

		protected override void Dispose(bool disposing)
		{
			if (Settings) Settings.OnApply -= Renderer.ApplySettings;
			if (disposing) Renderer?.Dispose();
			base.Dispose(disposing);
		}
	}
}