#ifndef FRP_TBN_INCLUDED
#define FRP_TBN_INCLUDED

// Tangent, Bitangent, Normal
struct TBN
{
	float3 tangentWS;
	float3 bitangentWS;
	float3 normalWS;
};

inline TBN CreateTBN(float3 tangentWS, float3 bitangentWS, float3 normalWS)
{
	TBN tbn;
	tbn.tangentWS = tangentWS;
	tbn.bitangentWS = bitangentWS;
	tbn.normalWS = normalWS;

	return tbn;
}

#endif // FRP_TBN_INCLUDED