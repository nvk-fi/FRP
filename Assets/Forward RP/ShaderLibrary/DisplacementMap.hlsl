#ifndef FRP_DISPLACEMENTMAP_INCLUDED
#define FRP_DISPLACEMENTMAP_INCLUDED

#include "FragmentData.hlsl"

TEXTURE2D(_DisplacementMap);
SAMPLER(sampler_DisplacementMap);

// Samples the DisplacementMap with height scaling and offset.
half SampleDisplacementMap(half2 baseUV, half heightScale, half heightOffset)
{
	half height = 1.0h - SAMPLE_TEXTURE2D(_DisplacementMap, sampler_DisplacementMap, baseUV).r;
	height -= heightOffset;
	height *= heightScale * 0.1h;
	
	return height;
}

// Applies parallax mapping to the UV coordinates based on the displaced height and grazing angle strength.
half2 ApplyParallaxUV(half2 baseUV, LitFragmentData fragment, half grazingAngleStrength)
{
	half grazingFade = saturate(fragment.viewTS.z * (1.0 - grazingAngleStrength) + grazingAngleStrength);
	
	half2 parallaxDirection = fragment.viewTS.xy / fragment.viewTS.z;
	half2 offsetUV = -parallaxDirection * (fragment.displacedHeight * grazingFade);

	const half maxOffsetUV = 0.01h;
	offsetUV = clamp(offsetUV, -maxOffsetUV, maxOffsetUV);
	
	return baseUV + offsetUV;
}

#endif // FRP_DISPLACEMENTMAP_INCLUDED