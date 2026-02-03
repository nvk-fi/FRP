#ifndef FRP_BASEMAP_INCLUDED
#define FRP_BASEMAP_INCLUDED

TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

// Samples the BaseMap with the default sampler.
half4 SampleAlbedo(half2 baseUV, half4 baseColor)
{
	return SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV) * baseColor;
}

// Samples the BaseMap at the 0th mip level using point sampler, otherwise the default sampler.
half4 SampleAlbedo(half2 baseUV, half4 baseColor, half mipLevel)
{
	if (mipLevel <= 0.0h)
		return SAMPLE_TEXTURE2D_LOD(_BaseMap, sampler_PointRepeat, baseUV, 0.0h) * baseColor;
	else
		return SAMPLE_TEXTURE2D_LOD(_BaseMap, sampler_BaseMap, baseUV, mipLevel) * baseColor;
}

#endif // FRP_BASEMAP_INCLUDED