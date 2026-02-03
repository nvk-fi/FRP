#ifndef FRP_SHADOWMAP_INCLUDED
#define FRP_SHADOWMAP_INCLUDED

// A normalised ratio for blending the shadow map away at distance.
inline half ShadowMapDistanceBlendRatio(float distanceToCameraSquared, half maxDistance)
{
	float maxDistanceSquared = maxDistance * maxDistance;
	maxDistanceSquared = max(maxDistanceSquared, epsilonFloat);
	half distanceBlendRatio = saturate(distanceToCameraSquared / maxDistanceSquared);

	return distanceBlendRatio;
}

// Holds the shadow map parameters for a fragment.
struct ShadowMapParams
{
	// A bias for the fragment and shadowmap shadow space depth comparison.
	half shadingBias;
	// A varying bias based on NdotL for the fragment and shadowmap shadow space depth comparison.
	half shadingValue;
	// The bias for calculating the grazing value.
	half grazingBias;
	// A normalised weight to attenuate light near grazing angles.
	half grazingValue;
};

inline ShadowMapParams CreateShadowMapParams(half NdotL, half shadingBias, half grazingBias, half zWrite)
{
	half shadingValue = lerp(shadingBias, shadingBias * 0.5h, NdotL); 
	half grazingValue = NdotL - grazingBias;
	grazingValue = saturate(grazingValue / max(2.0h * grazingBias, epsilonHalf));
	grazingValue = max(grazingValue, 1.0h - zWrite); // Allow shadows on transparent backfaces.
	
	ShadowMapParams shadowMapBiases;
	shadowMapBiases.shadingBias = shadingBias;
	shadowMapBiases.shadingValue = shadingValue;
	shadowMapBiases.grazingBias = grazingBias;
	shadowMapBiases.grazingValue = grazingValue;

	return shadowMapBiases;
}

// Samples the ShadowMap for a given fragment position.
half SampleShadowMap(float3 positionWS, float4x4 shadowMapVP, Texture2D shadowMap)
{
	float4 shadowMapCS = mul(shadowMapVP, float4(positionWS, 1.0f));
	float3 shadowMapTXS = shadowMapCS.xyz / max(shadowMapCS.w, epsilonFloat);
	float2 shadowMapUV = shadowMapTXS.xy * 0.5f + 0.5f;
	
	if (any(shadowMapUV < 0.0f) || any(shadowMapUV > 1.0f)) return 1;

	// Depth is enforced to OpenGL format at the renderer.
	float fragmentDepth = shadowMapTXS.z * 0.5f + 0.5f;
	float shadowMapDepth = SAMPLE_TEXTURE2D(shadowMap, sampler_PointClamp, shadowMapUV).r;
	
	half result = step(fragmentDepth, shadowMapDepth);
	return result;
}

// Samples the ShadowMap for a given fragment position with PCF.
half SampleShadowMapPCF(LitFragmentData fragment, ShadowMapParams params, float4x4 shadowMapVP, Texture2D shadowMap, float texelSize)
{
	float4 shadowMapCS = mul(shadowMapVP, float4(fragment.positionFlatWS, 1.0f));
	float3 shadowMapTXS = shadowMapCS.xyz / max(shadowMapCS.w, epsilonFloat);
	float2 shadowMapUV = shadowMapTXS.xy * 0.5f + 0.5f;

	if (any(shadowMapUV < 0.0f) || any(shadowMapUV > 1.0f)) return 1;

	// Depth is enforced to OpenGL format at the renderer.
	float fragmentDepth = shadowMapTXS.z * 0.5f + 0.5f - params.shadingBias;

	// Simple rotated 9-tap Poisson kernel with no trigonometry.
	// Using shadow map texel space to reduce Moiré with world-space patterns.
	float2 texelCoord = shadowMapUV / texelSize;
	float2 noise = Hash22(texelCoord);
	float2 rotationVector = normalize(noise * 2.0f - 1.0f + epsilonFloat);
	float2x2 rotation = float2x2(rotationVector.x, -rotationVector.y, rotationVector.y, rotationVector.x);

	const float2 kernelOffsets[9] =
	{
		float2(+0.00f, +0.00f),
		float2(+0.88f, +0.16f),
		float2(+0.20f, +0.90f),
		float2(-0.68f, +0.73f),
		float2(-0.95f, -0.15f),
		float2(-0.32f, -0.90f),
		float2(+0.52f, -0.75f),
		float2(+0.95f, -0.36f),
		float2(-0.06f, +0.60f)
	};

	float2 kernelScale = float2(texelSize, texelSize) * 2.0f;
	half shadowSum = 0;

	[unroll]
	for (int i = 0; i < 9; i++)
	{
		float2 offset = mul(rotation, kernelOffsets[i]) * kernelScale;
		float2 sampleUV = shadowMapUV + offset;
		float sampleDepth = SAMPLE_TEXTURE2D(shadowMap, sampler_PointClamp, sampleUV).r;
		shadowSum += step(fragmentDepth, sampleDepth);
	}

	half average = shadowSum * (1.0h / 9.0h);
	half result = average * params.grazingValue;
	return result;
}

#endif // FRP_SHADOWMAP_INCLUDED
