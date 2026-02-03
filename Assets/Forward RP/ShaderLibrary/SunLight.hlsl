#ifndef FRP_SUNLIGHT_INCLUDED
#define FRP_SUNLIGHT_INCLUDED

#include "Input.hlsl"
#include "FragmentData.hlsl"
#include "NNARMap.hlsl"
#include "ShadowMap.hlsl"

TEXTURE2D(_SunShadowMapRT);
float4 _SunShadowMapRT_TexelSize;

// Contains the data required for sun lighting calculations.
struct SunData
{
	half NdotL;
	half N1dotL;
	half N2dotL;
	half N1dotH;
	half N2dotH;
};

inline SunData CreateSunData(LitFragmentData fragment, NNAR nnar, half3 L)
{
	half3 H = FastSafeNormalize(L + fragment.V);
	half3 N = nnar.normalWS;
	half3 N1 = nnar.bumpedNormalWS;
	half3 N2 = nnar.bumpedNormalWSNonLinear;
	
	SunData sunData;
	sunData.NdotL = saturate(dot(N, L));
	sunData.N1dotL = saturate(dot(N1, L));
	sunData.N2dotL = saturate(dot(N2, L));
	sunData.N1dotH = saturate(dot(N1, H));
	sunData.N2dotH = saturate(dot(N2, H));

	return sunData;
}

// Get the smoothened sample from the sun's ShadowMap.
half SampleSunShadowMap(LitFragmentData fragment, ShadowMapParams biases)
{
	half sunShadowMap = SampleShadowMapPCF(fragment, biases, _SunVP, _SunShadowMapRT, _SunShadowMapRT_TexelSize.x);
	return sunShadowMap;
}

// Calculates the sunlight contribution.
inline half3 SunLight(half4 sunColor, half diffuseTermNear, half diffuseTermFar, half specularTerm, half distanceRatio)
{
	half3 sunLight = sunColor.rgb * sunColor.a * lerp(diffuseTermNear, diffuseTermFar, distanceRatio) * (1.0h + specularTerm);

	return sunLight;
}

// Calculates the volumetric sunlight contribution for a fragment.
half AccumulateVolumetricSunLight(PostFragmentData fragment)
{
	half volumetricSunAmount = 0.0h;
	
	int maxTravelSteps = max(_SunParams.z, 1);
	int traveledSteps = 0;
	
	float maxTravelDistance = max(min(fragment.distanceEstimate, _SunParams.w), epsilonFloat);
	float travelIncrement = maxTravelDistance / maxTravelSteps;
	float time = _Time.y % 64.0f;
	float traveledDistance = GenerateHashedRandomFloat(fragment.uv * _ScreenParams.xy * time) * travelIncrement;
	
	// Using a for-loop to keep the compiler happy.
	for (; traveledSteps < maxTravelSteps; traveledSteps++)
	{
		float3 samplePositionWS = _CameraWS - fragment.V * traveledDistance;
		volumetricSunAmount += SampleShadowMap(samplePositionWS, _SunVP, _SunShadowMapRT);
		
		traveledDistance += travelIncrement;
	}
	volumetricSunAmount /= max((half)traveledSteps, 1.0h);
	
	return volumetricSunAmount;
}

#endif // FRP_SUNLIGHT_INCLUDED
