using System;
using UnityEngine;

namespace Pipeline
{
	[CreateAssetMenu(menuName = "Rendering/Forward Render Pipeline Settings", fileName = "FRP Settings")]
	public class FRPSettings : ScriptableObject
	{
		[Header("Batching")]
		[InspectorName("SRP Batching")] public bool srpBatchingEnabled = true;

		[Space(10)]
		[Header("Mip Maps")]
		[InspectorName("Bias"), Range(-2f, 2f)] public float mipBias = -0.75f;
		[InspectorName("Reflection Distance Scale"), Range(0f, 1f)] public float mipReflectionDistanceScale = 0.5f;

		[Space(10)]
		[Header("Ambient Lighting")]
		[InspectorName("Color")] public Color ambientLightColor = new(0.03f, 0.04f, 0.05f);
		
		[Space(10)]
		[Header("Light Probes")]
		[InspectorName("L0 Intensity")] public float shL0Intensity = 1f;
		[InspectorName("Desaturation")] public float shDesaturation = 0f;
		[InspectorName("Multiplier")] public float shMultiplier = 1f;

		[Space(10)]
		[Header("Sun Shadow Map")]
		[InspectorName("Ratio For Static Objects"), Range(0f, 1f)] public float sunShadowMapRatioForStaticObjects = 0.5f;
		[InspectorName("Ratio For Dynamic Objects"), Range(0f, 1f)] public float sunShadowMapRatioForDynamicObjects = 0.5f;
		[InspectorName("Resolution")] public int sunShadowMapResolution = 1024;
		[InspectorName("Frustum Distance")] public float sunShadowMapPositionDistance = 50f;
		[InspectorName("Frustum Snap Distance"), Min(1)] public int sunShadowMapPositionSnapDistance = 1;
		[InspectorName("Frustum Width")] public float sunShadowMapFrustumWidth = 50f;
		[InspectorName("Frustum Far")] public float sunShadowMapFrustumFar = 100f;
		[InspectorName("Shadow Bias")] public float sunShadowBias = 0.0018f;
		[InspectorName("Grazing Bias")] public float sunGrazingBias = 0.032f;
		
		[Space(10)]
		[Header("Volumetric Lighting")]
		[Range(0, 1)] public float atmosphereThickness = 0.5f;
		[InspectorName("Volumetric Steps")] [Range(4, 16)] public int sunShadowMapVolumetricSteps = 8;
		
		[Space(10)]
		[Header("Fog")]
		[InspectorName("Color")] public Color fogColor = new(0.64f, 0.7f, 0.8f);
		[InspectorName("Near And Far")] public Vector2 fogRange = new(20, 200);
		[InspectorName("Height"), Range(0, 1)]  public float fogHeight = 0.5f;
		[InspectorName("Sun Bloom Exponent"), Min(0)]public float fogSunBloomExponent = 64f;
		
		[Space(10)]
		[Header("Post Processing")]
		[InspectorName("Material")] public Material ppfxMaterial;
		[InspectorName("Lens Distortion Strength"), Range(0f, 1f)] public float ppfxLensDistortionStrength = 0f;
		[InspectorName("Bloom Threshold"), Range(0f, 2f)] public float ppfxBloomThreshold = 1f;
		[InspectorName("Bloom Intensity"), Range(0f, 1f)] public float ppfxBloomIntensity = 0.5f;
		[InspectorName("Bloom Size"), Range(0f, 4f)] public float ppfxBloomSize = 2f;
		
		public void Apply() => OnApply?.Invoke();
		public event Action OnApply;
	}
}