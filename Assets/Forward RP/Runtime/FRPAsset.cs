using Pipeline;
using UnityEngine;
using UnityEngine.Rendering;

[CreateAssetMenu(menuName = "Rendering/Forward Render Pipeline Asset")]
public class FRPAsset : RenderPipelineAsset<FRP>
{
	[field: SerializeField] public FRPSettings Settings { get; set; }
	public FRP Pipeline { get; private set; }

	// Unity calls this method before rendering the first frame.
	// If a setting on the Render Pipeline Asset changes,
	// Unity destroys the current Render Pipeline Instance and calls this method again before rendering the next frame.
	protected override RenderPipeline CreatePipeline()
	{
		Pipeline = new FRP(Settings ? Settings : CreateInstance<FRPSettings>());
		return Pipeline;
	}
}