#ifndef FRP_FOG_INCLUDED
#define FRP_FOG_INCLUDED

// Returns the factor of how much given a distance lies within the fog.
inline float FogDistanceFactor(float fragmentDistance, float fogStart, float fogEnd)
{
	float factor = (fragmentDistance - fogStart) / max(fogEnd - fogStart, epsilonFloat);
	factor = saturate(factor);
	
	return factor;
}

// Returns the sunshine's bloom factor to fog.
inline float FogSunBloomFactor(float3 viewDirection, float3 sunDirection, float sunBloomExponent)
{
	float VoS = dot(viewDirection, sunDirection);
	float alignment = saturate(VoS * 0.5f + 0.5f);
	float factor = pow(alignment, sunBloomExponent);
	factor = saturate(factor);
	
	return factor;
}

// Returns the factor of how much fog is left in any given view direction height.
inline float FogHeightFactor(float3 viewDirection, float maxNormalizedHeight)
{
	float VdotU = saturate(dot(viewDirection, float3(0.0f, 1.0f, 0.0f)));
	float factor = 1.0f - saturate(VdotU / maxNormalizedHeight);
	factor = saturate(smoothstep(0.0f, 1.0f, factor));
	
	return factor;
}

#endif // FRP_FOG_INCLUDED