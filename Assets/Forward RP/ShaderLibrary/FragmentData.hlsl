#ifndef FRP_FRAGMENTDATA_INCLUDED
#define FRP_FRAGMENTDATA_INCLUDED

#include "TBN.hlsl"

// Holds the fragment data for Lit shader.
struct LitFragmentData
{
	float3 positionFlatWS;
	float3 positionDisplacedWS;
	float3 V;
	float3 viewTS;
	float distanceEstimate;
	float distanceSquared;
	half displacedHeight;
};

inline LitFragmentData CreateLitFragmentData(float3 fragmentPositionWS, float3 cameraPositionWS, TBN tbn, half displacedHeight)
{
	LitFragmentData fragment;
	fragment.positionFlatWS = fragmentPositionWS;
	fragment.positionDisplacedWS = fragmentPositionWS + tbn.normalWS * displacedHeight;
	float3 fragmentToCamera = cameraPositionWS - fragment.positionDisplacedWS;
	fragment.V = FastSafeNormalize(fragmentToCamera);
	fragment.viewTS = float3(
		dot(fragment.V, tbn.tangentWS),
		dot(fragment.V, tbn.bitangentWS),
		dot(fragment.V, tbn.normalWS)
	);
	fragment.distanceSquared = dot(fragmentToCamera, fragmentToCamera);
	fragment.distanceEstimate = 1.0f / rsqrt(max(fragment.distanceSquared, epsilonFloat));
	fragment.displacedHeight = displacedHeight;

	return fragment;
}

// Holds the fragment data for PostProcessing shader.
struct PostFragmentData
{
	float2 uv;
	float3 positionEstimateWS;
	float3 V;
	float distanceEstimate;
};

inline PostFragmentData CreatePostFragmentData(float3 cameraPosition, float3 V, float distanceEstimate, float2 uv)
{
	PostFragmentData fragment;
	fragment.uv = uv;
	fragment.positionEstimateWS = cameraPosition - V * distanceEstimate;
	fragment.V = V;
	fragment.distanceEstimate = distanceEstimate;
	
	return fragment;
}

#endif // FRP_FRAGMENTDATA_INCLUDED
