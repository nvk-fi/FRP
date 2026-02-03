#ifndef FRP_REALTIMELIGHT_INCLUDED
#define FRP_REALTIMELIGHT_INCLUDED

#include "Input.hlsl"
#include "FragmentData.hlsl"
#include "NNARMap.hlsl"

// Calculates the realtime light contribution for a surface.
half3 AccumulateSurfaceRealtimeLight(LitFragmentData fragment, NNAR nnar)
{
	half3 output = 0.0h;

	half3 N2 = nnar.bumpedNormalWSNonLinear;
	float3 V = fragment.V;

	// Loop over the visible lights.
	for (int i = 0; i < _RealtimeLightCount; i++)
	{
		float3 lightPosition = _RealtimeLightPositions[i].xyz;
		float lightRangeSquared = _RealtimeLightPositions[i].w;
		half3 lightDirection = _RealtimeLightDirections[i].xyz;
		half lightSpotAngle = abs(_RealtimeLightDirections[i].w);
		half3 lightColorIntensity = _RealtimeLightColors[i].rgb;
		half lightType = _RealtimeLightColors[i].w;

		// Spotlight
		if (lightType < -0.5h)
		{
			float3 lightToFragment = fragment.positionDisplacedWS - lightPosition;
			float distanceSquared = dot(lightToFragment, lightToFragment);
			if (distanceSquared > lightRangeSquared) continue;

			half3 L = FastSafeNormalize(-lightToFragment);
			half3 H = FastSafeNormalize(L + V);
			half N2dotH = dot(N2, H);
			half N2dotL = dot(N2, L);

			half diffuse = DiffuseTerm(N2dotL);
			half specular = SpecularTerm(N2dotH, nnar.roughness, nnar.shine);
			float distanceAttenuation = DistanceAttenuation_InverseSquareSmoothened(distanceSquared, lightRangeSquared);
			float angleAttenuation = ConeAngleAttenuation(lightDirection, -L, lightSpotAngle);

			output += lightColorIntensity * (diffuse + specular) * distanceAttenuation * angleAttenuation;
		}

		// Pointlight
		else if (lightType > 0.5h)
		{
			float3 fragmentToLight = lightPosition - fragment.positionDisplacedWS;
			float distanceSquared = dot(fragmentToLight, fragmentToLight);
			if (distanceSquared > lightRangeSquared) continue;

			half3 L = FastSafeNormalize(fragmentToLight);
			half3 H = FastSafeNormalize(L + V);
			half N2dotH = dot(N2, H);
			half N2dotL = dot(N2, L);

			half diffuse = DiffuseTerm(N2dotL);
			half specular = SpecularTerm(N2dotH, nnar.roughness, nnar.shine);
			float distanceAttenuation = DistanceAttenuation_InverseSquareSmoothened(distanceSquared, lightRangeSquared);

			output += lightColorIntensity * (diffuse + specular) * distanceAttenuation;
		}

		// Directional light
		else
		{
			half3 L = -lightDirection;
			half N2dotL = dot(N2, L);

			half diffuse = DiffuseTerm(N2dotL);

			output += lightColorIntensity * diffuse;
		}
	}

	return output;
}

// Used to analytically solve the volumetric sample position for a given spotlight.
// Returns the position X where dot(FastSafeNormalize(X - lightPosition), lightDirection) is maximal.
float3 MostAlignedPositionOnSegment(float3 lightPosition, float3 lightDirection, float3 cameraPosition, float3 fragmentPosition)
{
	float3 segmentVector = fragmentPosition - cameraPosition;
	float segmentLengthSquared = dot(segmentVector, segmentVector);
	if (segmentLengthSquared < epsilonFloat)
		return cameraPosition;

	float3 vectorLightToCamera = cameraPosition - lightPosition;
	float vectorLightToCameraLengthSquared = dot(vectorLightToCamera, vectorLightToCamera);

	float bestScore = -1.0f;
	float bestT = 0.0f;

	if (vectorLightToCameraLengthSquared > epsilonFloat)
	{
		float invLength = rsqrt(vectorLightToCameraLengthSquared);
		float score = dot(vectorLightToCamera * invLength, lightDirection);
		bestScore = score;
	}

	float3 vectorLightToFragment = fragmentPosition - lightPosition;
	float vectorLightToFragmentLengthSquared = dot(vectorLightToFragment, vectorLightToFragment);
	if (vectorLightToFragmentLengthSquared > epsilonFloat)
	{
		float invLength = rsqrt(vectorLightToFragmentLengthSquared);
		float score = dot(vectorLightToFragment * invLength, lightDirection);
		if (score > bestScore)
		{
			bestScore = score;
			bestT = 1.0f;
		}
	}

	float dotLightToCamera_LightDirection = dot(vectorLightToCamera, lightDirection);
	float dotSegmentVector_LightDirection = dot(segmentVector, lightDirection);
	float dotLightToCamera_SegmentVector = dot(vectorLightToCamera, segmentVector);

	float denominator = dotSegmentVector_LightDirection * dotLightToCamera_SegmentVector - dotLightToCamera_LightDirection * segmentLengthSquared;
	float numerator = dotLightToCamera_LightDirection * dotLightToCamera_SegmentVector - dotSegmentVector_LightDirection * vectorLightToCameraLengthSquared;

	if (abs(denominator) > epsilonFloat)
	{
		float tCandidate = numerator / denominator;
		if (tCandidate > epsilonFloat && tCandidate < 1.0f - epsilonFloat)
		{
			float3 candidatePoint = cameraPosition + segmentVector * tCandidate;
			float3 vectorLightToCandidate = candidatePoint - lightPosition;
			float candidateLengthSquared = dot(vectorLightToCandidate, vectorLightToCandidate);
			if (candidateLengthSquared > epsilonFloat)
			{
				float invLength = rsqrt(candidateLengthSquared);
				float score = dot(vectorLightToCandidate * invLength, lightDirection);
				if (score > bestScore)
					bestT = tCandidate;
			}
		}
	}

	return cameraPosition + saturate(bestT) * segmentVector;
}

// Calculates the volumetric realtime light contribution for a fragment.
// RGB = ColourIntensity
half3 AccumulateVolumetricRealtimeLight(PostFragmentData fragment)
{
	half3 output = 0.0h;

	float3 cameraToFragment = fragment.positionEstimateWS - _CameraWS;
	float cameraToFragmentDistance = max(fragment.distanceEstimate, epsilonFloat);
	float inverseCameraToFragmentDistanceSquared = 1.0f / (cameraToFragmentDistance * cameraToFragmentDistance);

	for (int i = 0; i < _RealtimeLightCount; i++)
	{
		const float realtimeLightToSunlightVolumetricsRatio = 0.1f;
		float3 lightPosition = _RealtimeLightPositions[i].xyz;
		float lightRangeSquared = _RealtimeLightPositions[i].w;
		float3 cameraToLight = lightPosition - _CameraWS;
		float sampleRatio = saturate(dot(cameraToLight, cameraToFragment) * inverseCameraToFragmentDistanceSquared);
		float3 closestPoint = _CameraWS + cameraToFragment * sampleRatio;
		float3 sampleToLight = lightPosition - closestPoint;
		float sampleDistanceSquared = dot(sampleToLight, sampleToLight);

		half3 lightDirection = _RealtimeLightDirections[i].xyz;
		half lightSpotAngle = abs(_RealtimeLightDirections[i].w);
		half3 lightColorIntensity = _RealtimeLightColors[i].rgb;
		half lightType = _RealtimeLightColors[i].w;
		half lightVolumetricDensity = saturate(abs(_RealtimeLightColors[i].w) - 1.0h);
		half lightVolumetricGlowEnabled = saturate(sign(_RealtimeLightDirections[i].w));

		// Spotlight
		if (lightType < -onePlusEpsilonHalf)
		{
			if (sampleDistanceSquared > lightRangeSquared) continue;
			
			float distanceAttenuation = DistanceAttenuation_Smoothstep(0.0f, lightRangeSquared, sampleDistanceSquared);
			float3 coneSample = MostAlignedPositionOnSegment(lightPosition, lightDirection, _CameraWS, fragment.positionEstimateWS);
			float angleAttenuation = ConeAngleAttenuation(lightDirection, lightPosition, coneSample, lightSpotAngle);
			float directionAttenuation = DirectionAttenuation(-fragment.V, -lightDirection);
			float attenuation = distanceAttenuation * angleAttenuation * (directionAttenuation * 0.5f + 0.5f);
			attenuation *= realtimeLightToSunlightVolumetricsRatio;
			
			float glow = 1.0f + DistanceAttenuation_InverseSquared(sampleDistanceSquared) * directionAttenuation * lightVolumetricGlowEnabled;

			output += lightColorIntensity * attenuation * glow * _AtmosphereFogColor.a * lightVolumetricDensity;
		}
		
		// Pointlight
		else if (lightType > onePlusEpsilonHalf)
		{
			if (sampleDistanceSquared > lightRangeSquared) continue;
			
			float attenuation = DistanceAttenuation_Smoothstep(0.0f, lightRangeSquared, sampleDistanceSquared);
			attenuation *= realtimeLightToSunlightVolumetricsRatio;
			
			float glow = 1.0f + DistanceAttenuation_InverseSquared(sampleDistanceSquared) * lightVolumetricGlowEnabled;
			
			output += lightColorIntensity * attenuation * glow * _AtmosphereFogColor.a * lightVolumetricDensity;
		}
	}
	return output;
}

#endif // FRP_REALTIMELIGHT_INCLUDED
