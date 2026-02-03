#ifndef FRP_REFLECTIONPROBES_INCLUDED
#define FRP_REFLECTIONPROBES_INCLUDED

#include "FragmentData.hlsl"
#include "NNARMap.hlsl"

TEXTURECUBE(unity_SpecCube0);
SAMPLER(samplerunity_SpecCube0);

// Samples the reflection probes with NNAR's properties applied.
half3 SampleReflectionProbes(LitFragmentData fragment, NNAR nnar, half blur, half mipLevel, half distanceBlur)
{
	half lod = max(1.0h, mipLevel * distanceBlur) * (nnar.roughness * 2.0h) * (blur * 10.0h);
	half3 V = fragment.V;
	half3 N = nnar.bumpedNormalWS;
	half3 R = reflect(-V, N);
	half3 sample = Tonemap(SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, R, lod).rgb);
	
	return sample;
}

// Applies the base colour to the reflection.
half3 ApplyReflectionMetalness(half3 reflectionColor, half3 baseColor, half metalness)
{
	half baseLuminosity = saturate(FastLinearLuminosity(baseColor));
	reflectionColor = lerp(reflectionColor * baseLuminosity, reflectionColor * baseColor, metalness);

	return reflectionColor;
}

// Applies the reflection with a support for transparent base materials.
half4 ApplyReflections(half4 inputColor, half3 reflectionColor, half reflectionStrength)
{
	half reflectionLuminosity = FastLinearLuminosity(reflectionColor);
	half alpha = saturate(max(inputColor.a, reflectionLuminosity * reflectionStrength));
	half4 reflectiveSurface = half4(lerp(inputColor.rgb, reflectionColor, reflectionStrength), alpha);

	return reflectiveSurface;
}

#endif // FRP_REFLECTIONPROBES_INCLUDED
