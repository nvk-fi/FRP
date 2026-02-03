#ifndef FRP_NNARMAP_INCLUDED
#define FRP_NNARMAP_INCLUDED

TEXTURE2D(_NNARMap);
SAMPLER(sampler_NNARMap);

#include "TBN.hlsl"

// Holds the normal, ambient occlusion, roughness (and shine) information.
struct NNAR
{
	half3 normalWS;
	half3 bumpedNormalWS;
	half3 bumpedNormalWSNonLinear;
	half ambientOcclusion;
	half roughness;
	half shine;
};

inline half3 GetBumpedNormalWS(half2 normalMap, TBN tbn)
{
	half3 bumpedNormalTS;
	bumpedNormalTS.xy = normalMap * 2.0h - 1.0h;
	bumpedNormalTS.z = sqrt(saturate(1.0h - dot(bumpedNormalTS.xy, bumpedNormalTS.xy)));
	
	half3x3 tangentToWorld = half3x3(
		FastSafeNormalize(tbn.tangentWS),
		FastSafeNormalize(tbn.bitangentWS),
		FastSafeNormalize(tbn.normalWS));
	half3 bumpedNormalWS = mul(bumpedNormalTS, tangentToWorld);

	return bumpedNormalWS;
}

// Amplify low-frequency normal deviations to pop dramatically.
// The theory is to draw the attention to surface details to psychologically compensate for the lack of real-time shadows.
inline half3 GetNonLinearBumpedNormalWS(half3 bumpedNormalWS, TBN tbn, half intensity)
{
	half3 bumpedNormalDelta = (bumpedNormalWS - tbn.normalWS) * intensity * intensity;
	half3 bumpedNormalDeltaNonLinear = sign(bumpedNormalDelta) * pow(abs(bumpedNormalDelta), 0.5h) * 0.5h;
	half3 bumpedNormalWSNonLinear = FastSafeNormalize(tbn.normalWS + bumpedNormalDeltaNonLinear);

	return bumpedNormalWSNonLinear;
}

inline half GetAmbienOcclusion(half sample, half intensity)
{
	half ambientOcclusion = saturate(lerp(1.0h, sample, intensity * 0.5h));
	return ambientOcclusion;
}

inline half GetRoughness(half sample, half intensity)
{
	half roughness = saturate((sample - 0.5h) * intensity + 0.5h);
	return roughness;
}

inline half GetShine(half roughness)
{
	half shine = lerp(0.125h, 64.0h, 1.0h - roughness);
	return shine;
}

// Creates the NNAR sample.
NNAR SampleNNARMap(half2 baseUV, TBN tbn, half3 intensities, half mipLevel)
{
	half4 sample = SAMPLE_TEXTURE2D_LOD(_NNARMap, sampler_PointRepeat, baseUV, mipLevel);
	
	NNAR nnar;
	nnar.normalWS = tbn.normalWS;
	nnar.bumpedNormalWS = GetBumpedNormalWS(sample.xy, tbn);
	nnar.bumpedNormalWSNonLinear = GetNonLinearBumpedNormalWS(nnar.bumpedNormalWS, tbn, intensities.x);
	nnar.ambientOcclusion = GetAmbienOcclusion(sample.z, intensities.y);
	nnar.roughness = GetRoughness(sample.w, intensities.z);
	nnar.shine = GetShine(nnar.roughness);
	
	return nnar;
}

#endif // FRP_NNARMAP_INCLUDED