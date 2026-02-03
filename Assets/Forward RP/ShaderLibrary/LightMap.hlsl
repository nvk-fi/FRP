#ifndef FRP_LIGHTMAP_INCLUDED
#define FRP_LIGHTMAP_INCLUDED

#include "NNARMap.hlsl"

TEXTURE2D(unity_Lightmap);
TEXTURE2D(unity_LightmapInd);
TEXTURE2D(unity_ShadowMask);

// Sample the LightMap with NNAR's normal mapping and ambient occlusion.
half3 SampleLightmap(half2 lightmapUV, NNAR nnar)
{
	half3 color = SAMPLE_TEXTURE2D(unity_Lightmap, sampler_LinearClamp, lightmapUV).rgb;
	half3 L = SAMPLE_TEXTURE2D(unity_LightmapInd, sampler_PointClamp, lightmapUV).rgb * 2.0 - 1.0;
	half NdotL = saturate(dot(nnar.bumpedNormalWSNonLinear, L));
	half3 lightmap = color * NdotL;
	lightmap *= nnar.ambientOcclusion;
	
	return lightmap;
}

// Sample the ShadowMask texture.
half SampleShadowMask(half2 lightmapUV)
{
	return SAMPLE_TEXTURE2D(unity_ShadowMask, sampler_LinearClamp, lightmapUV).r;
}

#endif // FRP_LIGHTMAP_INCLUDED