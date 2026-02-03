#ifndef FRP_DEPTH_PASS_INCLUDED
#define FRP_DEPTH_PASS_INCLUDED

#include "../ShaderLibrary/Common.hlsl"
#include "../ShaderLibrary/Transform.hlsl"

struct LitAttributes
{
	float4 positionOS : POSITION;
};

struct Varyings
{
	float4 positionCS : SV_POSITION;
	float depth01 : TEXCOORD0;
};

Varyings DepthVertex(LitAttributes input)
{
	Varyings output = (Varyings)0;
	
	output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

	float depth = output.positionCS.z / output.positionCS.w;
	#if UNITY_REVERSED_Z
	depth = 1.0 - depth;
	#elif UNITY_NEAR_CLIP_VALUE < 0
	depth = depth * 0.5 + 0.5;
	#endif
	output.depth01 = saturate(depth);
	
	return output;
}

float DepthFragment(Varyings input) : SV_TARGET
{
	return input.depth01;
}

#endif // FRP_DEPTH_PASS_INCLUDED
